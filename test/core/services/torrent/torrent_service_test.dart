import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:retry/retry.dart';
import 'package:unyo/config/config.dart' as config;
import 'package:unyo/core/di/locator.dart';
import 'package:unyo/core/services/api/http/api_response.dart';
import 'package:unyo/core/services/api/http/http_exception.dart';
import 'package:unyo/core/services/api/http/http_service.dart';
import 'package:unyo/core/services/torrent/torrent_service.dart';

class NativeServerTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class RecordingHttpService extends HttpService {
  final requests =
      <
        ({
          String endpoint,
          Map<String, String>? headers,
          Object? body,
          bool ignoreCache,
        })
      >[];

  RecordingHttpService()
    : super(
        timeout: const Duration(seconds: 1),
        retryOptions: const RetryOptions(maxAttempts: 1),
      );

  @override
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    bool ignoreCache = false,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    requests.add((
      endpoint: endpoint,
      headers: headers,
      body: body,
      ignoreCache: ignoreCache,
    ));
    return super.post<T>(
      endpoint,
      headers: headers,
      body: body,
      ignoreCache: ignoreCache,
      fromJson: fromJson,
    );
  }
}

void main() {
  NativeServerTestBinding();
  const hash = '0000000000000000000000000000000000000000';
  late Directory supportDirectory;
  late RecordingHttpService httpService;
  late HttpClient client;
  final services = <TorrentService>[];

  Future<TorrentService> startService() async {
    final service = TorrentService();
    services.add(service);
    // The first API call must wait for the authenticated child to be ready.
    await service.getTorrent(hash);
    return service;
  }

  Uri endpoint(TorrentService service) =>
      Uri.parse(service.getStreamUrl(hash, 1)).replace(path: '/torrents');

  Future<int> request(
    Uri uri, {
    String? authorization,
    String? action,
    String? origin,
  }) async {
    final request = await client.openUrl(action == null ? 'GET' : 'POST', uri);
    if (authorization != null) {
      request.headers.set(HttpHeaders.authorizationHeader, authorization);
    }
    if (origin != null) {
      request.headers.set('Origin', origin);
    }
    if (action != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'action': action}));
    }
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  Future<String> authorizationFor(TorrentService service) async {
    // Credentials belong to the disposable fixture, never a user's server.
    final sessions = await Directory(
      '${supportDirectory.path}/torrserver',
    ).list().where((e) => e is Directory).toList();
    for (final session in sessions) {
      final accounts =
          jsonDecode(await File('${session.path}/accs.db').readAsString())
              as Map<String, dynamic>;
      final password = accounts['unyo'] as String;
      expect(base64Url.decode(password), hasLength(32));
      final authorization =
          'Basic ${base64Encode(utf8.encode('unyo:$password'))}';
      if (await request(
            endpoint(service),
            authorization: authorization,
            action: 'list',
          ) ==
          200) {
        return authorization;
      }
    }
    throw StateError('No credentials for fixture server');
  }

  setUp(() async {
    await sl.reset();
    supportDirectory = await Directory.systemTemp.createTemp(
      'unyo-torrent-test-',
    );
    sl.registerSingleton<Directory>(
      supportDirectory,
      instanceName: config.applicationSupportDirectory,
    );
    sl.registerSingleton<Logger>(Logger(level: Level.off));
    httpService = RecordingHttpService();
    sl.registerSingleton<HttpService>(httpService);
    client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
  });

  tearDown(() async {
    for (final service in services) {
      await service.stopServer();
    }
    services.clear();
    client.close(force: true);
    httpService.client.close();
    await sl.reset();
    await supportDirectory.delete(recursive: true);
  });

  test(
    'control API is loopback-only and requires instance credentials',
    () async {
      final service = await startService();
      final uri = endpoint(service);
      final authorization = await authorizationFor(service);
      expect(uri.host, '127.0.0.1');
      expect(uri.port, isNot(8090));
      expect(service.torrentProcess, isNotNull);

      for (final action in ['list', 'wipe']) {
        expect(await request(uri, action: action), 401);
        expect(
          await request(
            uri,
            action: action,
            authorization: 'Basic d3Jvbmc6d3Jvbmc=',
          ),
          401,
        );
        expect(
          await request(
            uri,
            action: action,
            origin: 'https://untrusted.example',
          ),
          401,
        );
        expect(
          await request(uri, action: action, authorization: authorization),
          200,
        );
      }
      expect(await request(uri.replace(path: '/shutdown')), 401);

      // A loopback URL in the client alone would not pass these listener checks.
      await expectLater(
        Socket.connect(
          InternetAddress.loopbackIPv6,
          uri.port,
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<SocketException>()),
      );
      for (final interface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final address in interface.addresses.where(
          (address) => !address.isLoopback,
        )) {
          await expectLater(
            Socket.connect(
              address,
              uri.port,
              timeout: const Duration(seconds: 1),
            ),
            throwsA(isA<SocketException>()),
          );
        }
      }

      await expectLater(
        service.addTorrent('invalid'),
        throwsA(
          isA<HttpServerException>().having(
            (e) => e.statusCode,
            'status',
            isNot(401),
          ),
        ),
      );
      await service.getTorrent(hash);
      await service.removeTorrent(hash);
      for (final action in ['wipe', 'add', 'get', 'rem']) {
        final requests = httpService.requests.where(
          (request) => (request.body as Map?)?['action'] == action,
        );
        expect(requests, isNotEmpty);
        for (final request in requests) {
          expect(request.endpoint, uri.toString());
          expect(
            request.headers?[HttpHeaders.authorizationHeader] ??
                request.headers?['Authorization'],
            authorization,
          );
          expect(request.ignoreCache, isTrue);
        }
      }
      expect(service.getStreamUrl(hash, 1), '${uri.origin}/play/$hash/1');
      expect(
        await request(
          uri.replace(path: '/shutdown'),
          authorization: authorization,
        ),
        200,
      );
      expect(
        await service.torrentProcess!.exitCode.timeout(
          const Duration(seconds: 10),
        ),
        0,
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'instances use separate ports and credentials and stop only their own process',
    () async {
      final first = await startService();
      final firstAuthorization = await authorizationFor(first);
      final second = await startService();
      final secondAuthorization = await authorizationFor(second);
      expect(endpoint(first).port, isNot(endpoint(second).port));
      expect(firstAuthorization, isNot(secondAuthorization));
      expect(
        await request(
          endpoint(first),
          authorization: secondAuthorization,
          action: 'wipe',
        ),
        401,
      );
      expect(
        await request(
          endpoint(second),
          authorization: firstAuthorization,
          action: 'wipe',
        ),
        401,
      );
      await first.stopServer();
      expect(
        await request(
          endpoint(second),
          authorization: secondAuthorization,
          action: 'list',
        ),
        200,
      );
      await second.stopServer();
      expect(
        await Directory(
          '${supportDirectory.path}/torrserver',
        ).list().where((e) => e is Directory).toList(),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'startup and shutdown leave an unrelated listener on 8090 untouched',
    () async {
      HttpServer sentinel;
      try {
        sentinel = await HttpServer.bind(InternetAddress.loopbackIPv4, 8090);
      } on SocketException {
        markTestSkipped(
          'Port 8090 is already occupied; never contact an existing server.',
        );
        return;
      }
      addTearDown(() => sentinel.close(force: true));
      var requests = 0;
      sentinel.listen((request) {
        requests++;
        request.response.write('{}');
        request.response.close();
      });
      final service = await startService();
      await service.stopServer();
      expect(requests, 0);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

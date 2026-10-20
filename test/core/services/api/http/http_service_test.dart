import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:unyo/core/di/locator.dart';
import 'package:unyo/core/services/api/graphql/graphql_service.dart';
import 'package:unyo/core/services/api/http/api_response.dart';
import 'package:unyo/core/services/api/http/http_service.dart';

String _readUser(Map<String, dynamic> json) => json['user'] as String;

void main() {
  late HttpServer server;
  late HttpService service;
  late String endpoint;
  late int requestCount;

  setUp(() async {
    await sl.reset();
    sl.registerSingleton<Logger>(Logger(level: Level.off));
    service = HttpService();
    requestCount = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // The literal 127.0.0.1 is excluded from caching and would mask the bug.
    endpoint = 'http://localhost:${server.port}';
    server.listen((request) async {
      await request.drain<void>();
      requestCount++;
      final authorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      final user = authorization?.replaceFirst('Bearer ', '') ?? 'anonymous';
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          request.uri.path == '/graphql'
              ? {
                  'data': {'user': user},
                }
              : {'user': user},
        ),
      );
      await request.response.close();
    });
  });

  tearDown(() async {
    service.client.close();
    await server.close(force: true);
    await sl.reset();
  });

  for (final method in ['GET', 'POST']) {
    Future<ApiResponse<String>> request({
      Map<String, String>? headers,
      bool ignoreCache = false,
    }) {
      if (method == 'GET') {
        return service.get(
          endpoint,
          headers: headers,
          ignoreCache: ignoreCache,
          fromJson: _readUser,
        );
      }
      return service.post(
        endpoint,
        headers: headers,
        body: const {'query': 'user'},
        ignoreCache: ignoreCache,
        fromJson: _readUser,
      );
    }

    for (final header in ['Authorization', 'authorization', 'AUTHORIZATION']) {
      test(
        '$method bypasses the cache for $header across accounts and logout',
        () async {
          final accountA = await request(headers: {header: 'Bearer account-A'});
          final accountB = await request(headers: {header: 'Bearer account-B'});
          final accountAAgain = await request(
            headers: {header: 'Bearer account-A'},
          );

          expect(accountA.data, 'account-A');
          expect(accountB.data, 'account-B');
          expect(accountAAgain.data, 'account-A');
          expect(requestCount, 3);

          // Logging out must not expose a cached authenticated response.
          // Empty headers match the old key after Authorization was filtered out.
          final anonymous = await request(headers: const {});
          final anonymousAgain = await request(headers: const {});
          expect(anonymous.data, 'anonymous');
          expect(anonymousAgain.data, 'anonymous');
          expect(requestCount, 4);

          // An existing anonymous cache entry must not satisfy an authorized call.
          final afterLogin = await request(
            headers: {header: 'Bearer account-B'},
          );
          expect(afterLogin.data, 'account-B');
          expect(requestCount, 5);

          // Refreshing an authorized request must not evict or replace public data.
          final refreshed = await request(
            headers: {header: 'Bearer account-A'},
            ignoreCache: true,
          );
          final afterLogout = await request(headers: const {});
          expect(refreshed.data, 'account-A');
          expect(afterLogout.data, 'anonymous');
          expect(requestCount, 6);
        },
      );
    }

    test('$method still caches requests without headers', () async {
      expect((await request()).data, 'anonymous');
      expect((await request()).data, 'anonymous');
      expect(requestCount, 1);
    });
  }

  test(
    'GraphQL Viewer queries stay isolated across accounts and logout',
    () async {
      final graphql = GraphQLService(
        httpService: service,
        endpoint: '$endpoint/graphql',
      );

      final accountA = await graphql.query(
        query: 'query { user }',
        headers: const {'Authorization': 'Bearer account-A'},
        fromJson: _readUser,
      );
      final accountB = await graphql.query(
        query: 'query { user }',
        headers: const {'Authorization': 'Bearer account-B'},
        fromJson: _readUser,
      );
      final anonymous = await graphql.query(
        query: 'query { user }',
        headers: const {},
        fromJson: _readUser,
      );

      expect(accountA.data, 'account-A');
      expect(accountB.data, 'account-B');
      expect(anonymous.data, 'anonymous');
      expect(requestCount, 3);
    },
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:unyo/config/config.dart' as config;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:system_info3/system_info3.dart';
import 'package:unyo/core/di/locator.dart';
import 'package:unyo/core/services/api/http/http_exception.dart';
import 'package:unyo/core/services/api/http/empty_api_response.dart';
import 'package:unyo/core/services/api/http/http_service.dart';
import 'package:unyo/domain/entities/torrent/torrent_status.dart';

class TorrentService {
  static const String _servicesDir = "services";
  static const String _torrentServerName = "torrserver";
  static const String _packageAssetsDir = "assets";
  final HttpService _httpService = sl<HttpService>();
  final Logger _logger = sl<Logger>();
  Process? torrentProcess;
  Directory? _sessionDirectory;
  late final Future<void> _ready;
  late final String _endpoint;
  late final Map<String, String> _headers;
  bool _serverExited = false;

  TorrentService() {
    _ready = _initTorrentServer();
    // Initialization errors are logged below and propagated to API callers.
    _ready.ignore();
  }

  Future<void> _initTorrentServer() async {
    try {
      final supportDirectory = sl<Directory>(
        instanceName: config.applicationSupportDirectory,
      );
      final torrServerPath = await _loadTorrServerIfNeeded(supportDirectory);
      final sessionDirectory = await Directory(
        path.dirname(torrServerPath),
      ).createTemp('session-');
      _sessionDirectory = sessionDirectory;
      final random = Random.secure();
      final password = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      await File(
        path.join(sessionDirectory.path, 'accs.db'),
      ).writeAsString(jsonEncode({'unyo': password}), flush: true);
      _headers = {
        'Authorization': 'Basic ${base64Encode(utf8.encode('unyo:$password'))}',
      };
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      _endpoint = 'http://${config.localhost}:$port';
      await _startServer(torrServerPath, port, sessionDirectory);
      await _waitUntilReady();
      await _wipeAllTorrents();
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to start private torrent server',
        error: e,
        stackTrace: stackTrace,
      );
      await _disposeServer();
      rethrow;
    }
  }

  Future<String> _loadTorrServerIfNeeded(Directory supportDirectory) async {
    String torrentServerPath = path.join(
      supportDirectory.path,
      _torrentServerName,
      _torrentServerName + (Platform.isWindows ? ".exe" : ""),
    );
    File torrServer = File(torrentServerPath);
    bool needsCopy = false;
    if (!(await torrServer.exists())) {
      needsCopy = true;
    } else {
      String assetPath =
          "$_packageAssetsDir/$_servicesDir/$_torrentServerName/${SysInfo.kernelArchitecture == ProcessorArchitecture.x86_64 ? "amd64" : "arm64"}/${Platform.operatingSystem}/${_torrentServerName + (Platform.isWindows ? ".exe" : "")}";
      String existingFileHash = await _computeFileHash(torrServer);
      String assetHash = await _computeAssetHash(assetPath);
      if (existingFileHash != assetHash) {
        needsCopy = true;
      }
    }

    if (needsCopy) {
      _logger.i("Copying new torrent server binary to $torrentServerPath");
      await _copyAssetToFile(
        "$_packageAssetsDir/$_servicesDir/$_torrentServerName/${SysInfo.kernelArchitecture == ProcessorArchitecture.x86_64 ? "amd64" : "arm64"}/${Platform.operatingSystem}/${_torrentServerName + (Platform.isWindows ? ".exe" : "")}",
        torrentServerPath,
      );
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', torrentServerPath]);
    }
    return torrentServerPath;
  }

  Future<String> _computeFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> _computeAssetHash(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<File> _copyAssetToFile(String assetPath, String outPath) async {
    final byteData = await rootBundle.load(assetPath);
    final buffer = byteData.buffer.asUint8List();
    final file = File(outPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(buffer, flush: true);
    return file;
  }

  Future<void> _startServer(
    String torrServerPath,
    int port,
    Directory sessionDirectory,
  ) async {
    // Set working directory to the binary's location so generated files are created there
    final workingDir = path.dirname(torrServerPath);
    torrentProcess = await Process.start(
      torrServerPath,
      [
        '--ip',
        config.localhost,
        '--port',
        '$port',
        '--httpauth',
        '--path',
        sessionDirectory.path,
      ],
      mode: ProcessStartMode.normal,
      workingDirectory: workingDir,
    );
    torrentProcess!.stdout.drain<void>();
    torrentProcess!.stderr.drain<void>();
    torrentProcess!.exitCode.then((_) => _serverExited = true);
  }

  Future<void> _waitUntilReady() async {
    final startupTime = Stopwatch()..start();
    while (startupTime.elapsed < const Duration(seconds: 10)) {
      if (_serverExited) {
        throw StateError('Torrent server exited during startup');
      }
      try {
        await _httpService.post<EmptyApiResponse>(
          '$_endpoint/torrents',
          headers: _headers,
          body: {'action': 'list'},
          fromJson: EmptyApiResponse.fromJson,
          ignoreCache: true,
        );
        // Fail closed if the listener does not actually enforce authentication.
        try {
          await _httpService.post<EmptyApiResponse>(
            '$_endpoint/torrents',
            body: {'action': 'list'},
            fromJson: EmptyApiResponse.fromJson,
            ignoreCache: true,
          );
        } on HttpServerException catch (e) {
          if (e.statusCode == 401 && !_serverExited) return;
          rethrow;
        }
        throw StateError('Torrent server accepted an unauthenticated request');
      } on StateError {
        rethrow;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    throw StateError('Timed out starting private torrent server');
  }

  Future<void> stopServer() async {
    try {
      await _ready;
    } catch (_) {
      // Initialization already cleaned up a failed child process.
    }
    await _disposeServer();
  }

  Future<void> _disposeServer() async {
    final process = torrentProcess;
    torrentProcess = null;
    if (process != null) {
      process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return process.exitCode;
        },
      );
    }
    final sessionDirectory = _sessionDirectory;
    _sessionDirectory = null;
    if (sessionDirectory != null) {
      await sessionDirectory.delete(recursive: true);
    }
  }

  Future<void> _wipeAllTorrents() async {
    try {
      await _httpService.post<EmptyApiResponse>(
        "$_endpoint/torrents",
        headers: _headers,
        body: {"action": "wipe"},
        fromJson: EmptyApiResponse.fromJson,
        ignoreCache: true,
      );
      _logger.i("All torrents wiped from torrserver");
    } catch (e) {
      _logger.w("Failed to wipe torrents: $e");
    }
  }

  Future<TorrentStatus> addTorrent(
    String link, {
    String? title,
    String? poster,
    String? category,
    bool saveToDb = true,
  }) async {
    await _ready;
    _logger.i("Adding torrent to torrserver: $link");
    final body = {
      "action": "add",
      "link": link,
      if (title != null) "title": title,
      if (poster != null) "poster": poster,
      if (category != null) "category": category,
      "save_to_db": saveToDb,
    };
    final response = await _httpService.post<TorrentStatus>(
      "$_endpoint/torrents",
      headers: _headers,
      body: body,
      fromJson: TorrentStatusModel.fromJson,
      ignoreCache: true,
    );
    if (response.statusCode >= 300) {
      throw Exception("Failed to add torrent: ${response.statusCode}");
    }
    return response.data;
  }

  Future<TorrentStatus?> getTorrent(String hash) async {
    await _ready;
    final body = {"action": "get", "hash": hash};
    try {
      final response = await _httpService.post<TorrentStatus>(
        "$_endpoint/torrents",
        headers: _headers,
        body: body,
        fromJson: TorrentStatusModel.fromJson,
        ignoreCache: true,
      );
      if (response.statusCode >= 300) {
        return null;
      }
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<void> removeTorrent(String hash) async {
    await _ready;
    _logger.i("Removing torrent from torrserver: $hash");
    final body = {"action": "rem", "hash": hash};
    try {
      await _httpService.post<EmptyApiResponse>(
        "$_endpoint/torrents",
        headers: _headers,
        body: body,
        fromJson: EmptyApiResponse.fromJson,
        ignoreCache: true,
      );
    } catch (e) {
      _logger.w("Failed to remove torrent $hash: $e");
    }
  }

  String getStreamUrl(String hash, int fileIndex) {
    return "$_endpoint/play/$hash/$fileIndex";
  }
}

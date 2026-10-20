import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unyo/domain/entities/torrent/torrent_status.dart';

void main() {
  late Map<String, dynamic> response;

  setUp(() {
    // Captured from the bundled MatriX.137 using a local two-file torrent.
    response =
        jsonDecode(File('test/fixtures/torrent_added.json').readAsStringSync())
            as Map<String, dynamic>;
  });

  test('decodes bundled-server metadata even while stat is zero', () {
    final status = TorrentStatusModel.fromJson(response);

    expect(status.stat, 0);
    expect(status.statString, 'Torrent added');
    expect(status.torrentSize, 2);
    expect(status.fileStats.map((file) => file.id), [1, 2]);
    expect(status.fileStats.first.path, 'Unyo regression/Episode 01.mkv');
    expect(status.fileStats.first.length, 1);
  });

  test('decodes optional snake_case status fields', () {
    final status = TorrentStatusModel.fromJson({
      ...response,
      'download_speed': 12.5,
      'upload_speed': 2,
      'active_peers': 3,
      'total_peers': 4,
      'connected_seeders': 5,
      'preloaded_bytes': 6,
      'preload_size': 7,
    });

    expect(status.downloadSpeed, 12.5);
    expect(status.uploadSpeed, 2.0);
    expect(status.activePeers, 3);
    expect(status.totalPeers, 4);
    expect(status.connectedSeeders, 5);
    expect(status.preloadedBytes, 6);
    expect(status.preloadSize, 7);
  });

  test('keeps the empty metadata default before files are available', () {
    response.remove('file_stats');
    expect(TorrentStatusModel.fromJson(response).fileStats, isEmpty);
  });

  test('serializes status using the same server keys', () {
    final status = TorrentStatusModel.fromJson(response);
    final json = jsonDecode(jsonEncode(status)) as Map<String, dynamic>;

    expect(json['stat_string'], 'Torrent added');
    expect(json['torrent_size'], 2);
    expect(json['file_stats'], response['file_stats']);
    expect(json.containsKey('fileStats'), isFalse);
    expect(jsonDecode(jsonEncode(TorrentStatusModel.fromJson(json))), json);
  });
}

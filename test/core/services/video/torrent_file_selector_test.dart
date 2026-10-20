import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unyo/core/services/video/torrent_file_selector.dart';
import 'package:unyo/domain/entities/torrent/torrent_file_stat.dart';
import 'package:unyo/domain/entities/torrent/torrent_status.dart';

void main() {
  test(
    'first and second playlist entries use native file IDs at stat zero',
    () {
      final response =
          jsonDecode(
                File('test/fixtures/torrent_added.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final status = TorrentStatusModel.fromJson(response);

      expect(status.stat, 0);
      expect(selectTorrentFileIndex(status.fileStats, 0), 1);
      expect(selectTorrentFileIndex(status.fileStats, 1), 2);
    },
  );

  test('missing metadata falls back to a positive one-based file ID', () {
    expect(selectTorrentFileIndex([], 0), 1);
    expect(selectTorrentFileIndex([], 1), 2);
    expect(selectTorrentFileIndex([], -1), 1);
  });

  test('filename matching preserves actual IDs ahead of numeric matching', () {
    const files = [
      TorrentFileStat(id: 1, length: 1, path: 'episode 2'),
      TorrentFileStat(id: 8, length: 1, path: 'episode 1'),
    ];

    expect(selectTorrentFileIndex(files, 0), 8);
    expect(selectTorrentFileIndex(files, 1), 1);
  });

  test('numeric matching uses the one-based episode number', () {
    const files = [
      TorrentFileStat(id: 2, length: 1, path: 'beta.mkv'),
      TorrentFileStat(id: 1, length: 1, path: 'alpha.mkv'),
    ];

    expect(selectTorrentFileIndex(files, 0), 1);
    expect(selectTorrentFileIndex(files, 1), 2);
  });

  test('single-file torrents retain their native file ID', () {
    const files = [TorrentFileStat(id: 7, length: 1, path: 'movie.mkv')];

    expect(selectTorrentFileIndex(files, 0), 7);
    expect(selectTorrentFileIndex(files, 3), 7);
  });

  test('unmatched episodes fall back to an actual file ID', () {
    const files = [
      TorrentFileStat(id: 9, length: 1, path: 'alpha.mkv'),
      TorrentFileStat(id: 7, length: 1, path: 'beta.mkv'),
    ];

    expect(selectTorrentFileIndex(files, 2), 9);
  });
}

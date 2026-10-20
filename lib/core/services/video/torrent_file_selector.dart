import 'package:collection/collection.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:unyo/domain/entities/torrent/torrent_file_stat.dart';

int selectTorrentFileIndex(List<TorrentFileStat> files, int episodeIndex) {
  // Playlist indices are zero-based; TorrServer file IDs start at one.
  final episodeNumber = episodeIndex < 0 ? 1 : episodeIndex + 1;
  if (files.isEmpty) return episodeNumber;
  if (files.length == 1) return files.first.id;

  // Strategy 1: Fuzzy match filename against episode patterns
  final patterns = [
    "episode $episodeNumber",
    "e$episodeNumber",
    "ep$episodeNumber",
    episodeNumber.toString().padLeft(2, '0'),
  ];
  final List<(int, TorrentFileStat)> allScores = [];
  for (final pattern in patterns) {
    for (final file in files) {
      final fileName = file.path.toLowerCase();
      final score = tokenSortRatio(pattern, fileName);
      allScores.add((score, file));
    }
  }
  allScores.sort((a, b) => b.$1.compareTo(a.$1));
  if (allScores.isNotEmpty && allScores.first.$1 > 60) {
    return allScores.first.$2.id;
  }

  // Strategy 2: Direct id match with the one-based episode number
  final directMatch = files.firstWhereOrNull((f) => f.id == episodeNumber);
  if (directMatch != null) return directMatch.id;

  // Strategy 3: Fallback to first file
  return files.first.id;
}

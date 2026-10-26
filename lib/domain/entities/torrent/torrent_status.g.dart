// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'torrent_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TorrentStatusModel _$TorrentStatusModelFromJson(Map<String, dynamic> json) =>
    _TorrentStatusModel(
      hash: json['hash'] as String,
      name: json['name'] as String,
      title: json['title'] as String,
      poster: json['poster'] as String,
      category: json['category'] as String,
      stat: (json['stat'] as num).toInt(),
      statString: json['stat_string'] as String?,
      downloadSpeed: (json['download_speed'] as num?)?.toDouble(),
      uploadSpeed: (json['upload_speed'] as num?)?.toDouble(),
      activePeers: (json['active_peers'] as num?)?.toInt(),
      totalPeers: (json['total_peers'] as num?)?.toInt(),
      connectedSeeders: (json['connected_seeders'] as num?)?.toInt(),
      torrentSize: (json['torrent_size'] as num?)?.toInt(),
      preloadedBytes: (json['preloaded_bytes'] as num?)?.toInt(),
      preloadSize: (json['preload_size'] as num?)?.toInt(),
      fileStats:
          (json['file_stats'] as List<dynamic>?)
              ?.map((e) => TorrentFileStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TorrentFileStat>[],
    );

Map<String, dynamic> _$TorrentStatusModelToJson(_TorrentStatusModel instance) =>
    <String, dynamic>{
      'hash': instance.hash,
      'name': instance.name,
      'title': instance.title,
      'poster': instance.poster,
      'category': instance.category,
      'stat': instance.stat,
      'stat_string': instance.statString,
      'download_speed': instance.downloadSpeed,
      'upload_speed': instance.uploadSpeed,
      'active_peers': instance.activePeers,
      'total_peers': instance.totalPeers,
      'connected_seeders': instance.connectedSeeders,
      'torrent_size': instance.torrentSize,
      'preloaded_bytes': instance.preloadedBytes,
      'preload_size': instance.preloadSize,
      'file_stats': instance.fileStats,
    };

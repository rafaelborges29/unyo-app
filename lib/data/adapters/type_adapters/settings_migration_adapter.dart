import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:unyo/core/enums/episode_service.dart';
import 'package:unyo/core/enums/service.dart';
import 'package:unyo/domain/entities/extension/extension.dart';
import 'package:unyo/domain/entities/user/settings.dart';

// Read legacy fields while retaining the generated current-schema writer.
class SettingsMigrationAdapter extends SettingsModelAdapter {
  @override
  SettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    const defaults = SettingsModel();

    return SettingsModel(
      language: fields[0] as String? ?? defaults.language,
      service: fields[1] as Service? ?? defaults.service,
      episodeService: fields[2] as EpisodeService? ?? defaults.episodeService,
      installedAnimeExtensions:
          (fields[3] as List?)?.cast<Extension>() ??
          defaults.installedAnimeExtensions,
      installedMangaExtensions:
          (fields[4] as List?)?.cast<Extension>() ??
          defaults.installedMangaExtensions,
      mediaExtensionConfigs:
          (fields[7] as Map?)?.cast<String, Extension>() ??
          defaults.mediaExtensionConfigs,
      mediaTitleLanguage: fields[8] as String? ?? defaults.mediaTitleLanguage,
      episodeTitleLanguage:
          fields[9] as String? ?? defaults.episodeTitleLanguage,
      enableDiscordRichPresence:
          fields[10] as bool? ?? defaults.enableDiscordRichPresence,
      automaticallySkipOpening:
          fields[11] as bool? ?? defaults.automaticallySkipOpening,
      automaticallySkipEnding:
          fields[12] as bool? ?? defaults.automaticallySkipEnding,
      manualSkipTime: (fields[13] as num?)?.toInt() ?? defaults.manualSkipTime,
      autoPlayNextEpisode: fields[14] as bool? ?? defaults.autoPlayNextEpisode,
      enableOpenSubtitlesIntegration:
          fields[15] as bool? ?? defaults.enableOpenSubtitlesIntegration,
      enableNsfwContent: fields[16] as bool? ?? defaults.enableNsfwContent,
      themeColor: fields[17] as Color? ?? defaults.themeColor,
      useWallpaperAsThemeColor:
          fields[18] as bool? ?? defaults.useWallpaperAsThemeColor,
      // Prefer the current lists, including empty lists, over legacy URLs.
      aniyomiExtensionsRepositories:
          (fields[19] as List?)?.cast<String>() ??
          (fields[5] == null
              ? defaults.aniyomiExtensionsRepositories
              : [fields[5] as String]),
      tachiyomiExtensionsRepositories:
          (fields[20] as List?)?.cast<String>() ??
          (fields[6] == null
              ? defaults.tachiyomiExtensionsRepositories
              : [fields[6] as String]),
    );
  }
}

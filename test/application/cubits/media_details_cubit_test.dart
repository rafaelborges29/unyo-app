import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unyo/application/cubits/anime_details_cubit.dart';
import 'package:unyo/application/cubits/manga_details_cubit.dart';
import 'package:unyo/core/di/locator.dart';
import 'package:unyo/core/enums/service.dart';
import 'package:unyo/core/notification/anime_genres_notifier.dart';
import 'package:unyo/core/notification/anime_notifier.dart';
import 'package:unyo/core/notification/episode_info_notifier.dart';
import 'package:unyo/core/notification/episodes_notifier.dart';
import 'package:unyo/core/notification/extension_notifier.dart';
import 'package:unyo/core/notification/manga_genres_notifier.dart';
import 'package:unyo/core/notification/manga_notifier.dart';
import 'package:unyo/core/notification/media_list_entry_notifier.dart';
import 'package:unyo/core/notification/media_list_notifier.dart';
import 'package:unyo/core/notification/reload/reload_notifier.dart';
import 'package:unyo/core/notification/reload/reload_type.dart';
import 'package:unyo/core/notification/user_notifier.dart';
import 'package:unyo/core/notification/video_info_notifier.dart';
import 'package:unyo/core/services/api/http/http_exception.dart';
import 'package:unyo/data/repositories/extension_repository_aniyomi.dart';
import 'package:unyo/data/repositories/user_repository_anilist.dart';
import 'package:unyo/domain/entities/list/media_list_entry.dart';
import 'package:unyo/domain/entities/media/anime.dart';
import 'package:unyo/domain/entities/media/anime_details.dart';
import 'package:unyo/domain/entities/media/episode_info.dart';
import 'package:unyo/domain/entities/media/manga.dart';
import 'package:unyo/domain/entities/media/manga_details.dart';
import 'package:unyo/domain/entities/media/media_character.dart';
import 'package:unyo/domain/entities/user/settings.dart';
import 'package:unyo/domain/entities/user/user.dart';
import 'package:unyo/domain/repositories/anime_repository.dart';
import 'package:unyo/domain/repositories/episode_repository.dart';
import 'package:unyo/domain/repositories/manga_repository.dart';

class MockAnimeRepository extends Mock implements AnimeRepository {}

class MockMangaRepository extends Mock implements MangaRepository {}

class MockEpisodeRepository extends Mock implements EpisodeRepository {}

class MockExtensionRepository extends Mock implements ExtensionRepositoryAniyomi {}

class MockUserRepository extends Mock implements UserRepositoryAnilist {}

class MockBuildContext extends Mock implements BuildContext {}

Future<void> flushAsync() => Future<void>.delayed(Duration.zero);

void main() {
  final user = UserModel.empty().copyWith(id: 'user-1');
  final animeA = AnimeModel.empty().copyWith(id: 1);
  final animeB = AnimeModel.empty().copyWith(id: 2);
  final mangaA = MangaModel.empty().copyWith(id: 1);
  final mangaB = MangaModel.empty().copyWith(id: 2);
  final entryA = MediaListEntryModel.empty().copyWith(
    progress: 24,
    score: 10,
    status: 'COMPLETED',
    startedAt: ['1', '1', '2026'],
    completedAt: ['24', '1', '2026'],
  );
  final entryB = MediaListEntryModel.empty().copyWith(
    progress: 1,
    score: 5,
    status: 'CURRENT',
    startedAt: ['2', '2', '2026'],
  );
  final characterA = MediaCharacterModel.empty().copyWith(id: 1);
  final characterB = MediaCharacterModel.empty().copyWith(id: 2);
  final detailsA = AnimeDetailsModel(mediaListEntry: entryA, recommendedAnimes: [animeA], characters: [characterA]);
  final detailsB = AnimeDetailsModel(mediaListEntry: entryB, recommendedAnimes: [animeB], characters: [characterB]);

  late UserNotifier users;
  late MediaListNotifier mediaLists;
  late MockExtensionRepository extensions;
  late MockUserRepository userRepository;

  setUpAll(() {
    registerFallbackValue(UserModel.empty());
    registerFallbackValue(AnimeModel.empty());
    registerFallbackValue(MangaModel.empty());
    registerFallbackValue(MediaListEntryModel.empty());
  });

  setUp(() async {
    await sl.reset();
    sl.registerSingleton<Logger>(Logger(level: Level.off));
    users = UserNotifier()..updateUser(user);
    mediaLists = MediaListNotifier();
    extensions = MockExtensionRepository();
    userRepository = MockUserRepository();
  });

  tearDown(() async {
    users.dispose();
    mediaLists.dispose();
    await sl.reset();
  });

  group('AnimeDetailsCubit', () {
    late AnimeDetailsCubit cubit;
    late MockAnimeRepository repository;
    late MockEpisodeRepository episodes;
    late AnimeNotifier selection;
    late AnimeGenresNotifier genres;
    late VideoInfoNotifier videos;
    late EpisodesInfoNotifier episodeInfo;
    late MediaListEntryNotifier entries;
    late ExtensionNotifier extensionSelection;
    late EpisodesNotifier selectedEpisodes;
    late ReloadNotifier reload;
    late MockBuildContext context;

    setUp(() async {
      repository = MockAnimeRepository();
      episodes = MockEpisodeRepository();
      selection = AnimeNotifier();
      genres = AnimeGenresNotifier();
      videos = VideoInfoNotifier();
      episodeInfo = EpisodesInfoNotifier();
      entries = MediaListEntryNotifier();
      extensionSelection = ExtensionNotifier();
      selectedEpisodes = EpisodesNotifier();
      reload = ReloadNotifier();
      context = MockBuildContext();
      when(() => context.mounted).thenReturn(false);
      when(() => repository.getMediaCoverImages(any())).thenAnswer((_) async => []);
      when(() => extensions.getInstalledAnimeExtensions(any())).thenAnswer((_) async => {});
      when(() => repository.getAnimeDetails(any(), any())).thenAnswer((_) async => (true, detailsB));
      when(() => repository.getMediaListEntry(any(), any(), ignoreCache: true)).thenAnswer((_) async => entryB);
      when(() => repository.updateMediaListEntry(any(), any(), any())).thenAnswer((_) async => entryB);
      when(
        () => episodes.getEpisodeInfo(
          malId: any(named: 'malId'),
          anilistId: any(named: 'anilistId'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => episodes.getAlternativeImage(
          malId: any(named: 'malId'),
          anilistId: any(named: 'anilistId'),
        ),
      ).thenAnswer((_) async => '');
      cubit = AnimeDetailsCubit(
        repository,
        episodes,
        users,
        selection,
        genres,
        mediaLists,
        videos,
        extensions,
        userRepository,
        episodeInfo,
        entries,
        extensionSelection,
        selectedEpisodes,
        reload,
      );
      await flushAsync();
    });

    tearDown(() async {
      if (!cubit.isClosed) await cubit.close();
      await flushAsync();
      selection.dispose();
      genres.dispose();
      videos.dispose();
      episodeInfo.dispose();
      entries.dispose();
      extensionSelection.dispose();
      selectedEpisodes.dispose();
      reload.dispose();
    });

    test('late A details cannot overwrite B or save A values for B', () async {
      final pendingA = Completer<(bool, AnimeDetails)>();
      final pendingB = Completer<(bool, AnimeDetails)>();
      when(() => repository.getAnimeDetails(animeA, any())).thenAnswer((_) => pendingA.future);
      when(() => repository.getAnimeDetails(animeB, any())).thenAnswer((_) => pendingB.future);
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      selection.updateSelectedAnime(animeB);
      await flushAsync();
      pendingB.complete((true, detailsB));
      await flushAsync();
      pendingA.complete((true, detailsA));
      await flushAsync();

      expect(cubit.state.selectedAnime, animeB);
      expect(cubit.state.mediaListEntry, entryB);
      expect(cubit.state.newMediaListEntry, entryB);
      expect(cubit.state.characters.$1, isTrue);
      expect(cubit.state.characters.$2, [characterB]);
      expect(cubit.state.recommendations.$1, isTrue);
      expect(cubit.state.recommendations.$2, [animeB]);
      await cubit.updateMediaListEntry(context);
      verify(() => repository.updateMediaListEntry(entryB, animeB, user)).called(1);
    });

    test('selection clears A data and blocks editing and saving until B loads', () async {
      when(() => repository.getAnimeDetails(animeA, any())).thenAnswer((_) async => (true, detailsA));
      when(
        () => episodes.getEpisodeInfo(malId: -1, anilistId: 1),
      ).thenAnswer((_) async => [EpisodeInfoModel.empty().copyWith(id: 1)]);
      when(() => episodes.getAlternativeImage(malId: -1, anilistId: 1)).thenAnswer((_) async => 'A image');
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      final pendingB = Completer<(bool, AnimeDetails)>();
      when(() => repository.getAnimeDetails(animeB, any())).thenAnswer((_) => pendingB.future);
      selection.updateSelectedAnime(animeB);
      await flushAsync();

      expect(cubit.state.mediaListEntry, MediaListEntryModel.empty());
      expect(cubit.state.newMediaListEntry, MediaListEntryModel.empty());
      expect(cubit.state.characters.$1, isFalse);
      expect(cubit.state.characters.$2, isEmpty);
      expect(cubit.state.recommendations.$1, isFalse);
      expect(cubit.state.recommendations.$2, isEmpty);
      expect(cubit.state.episodesInfo, isEmpty);
      expect(cubit.state.alternateImage, isEmpty);
      expect(entries.currentMediaListEntry, MediaListEntryModel.empty());
      expect(episodeInfo.currentEpisodeInfo, isEmpty);
      cubit.openAnimeDetailsMediaEntryDialog(context);
      await cubit.updateMediaListEntryProgress(24);
      await cubit.updateMediaListEntryScore(10);
      await cubit.updateMediaListEntryStatus('COMPLETED');
      await cubit.updateMediaListEntryRepeat(3);
      await cubit.updateMediaListEntryStartedAt(context);
      await cubit.updateMediaListEntryCompletedAt(context);
      await cubit.updateMediaListEntry(context);
      expect(cubit.state.newMediaListEntry, MediaListEntryModel.empty());
      expect(cubit.state.effects, isEmpty);
      verifyNever(() => repository.updateMediaListEntry(any(), any(), any()));

      pendingB.complete((true, detailsB));
      await flushAsync();
      await cubit.updateMediaListEntryProgress(2);
      expect(cubit.state.newMediaListEntry.progress, 2);
      cubit.openAnimeDetailsMediaEntryDialog(context);
      expect(cubit.state.effects, hasLength(1));
    });

    test('A to B to A ignores the first A response', () async {
      final firstA = Completer<(bool, AnimeDetails)>();
      when(() => repository.getAnimeDetails(animeA, any())).thenAnswer((_) => firstA.future);
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      selection.updateSelectedAnime(animeB);
      await flushAsync();
      when(() => repository.getAnimeDetails(animeA, any())).thenAnswer((_) async => (true, detailsB));
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      firstA.complete((true, detailsA));
      await flushAsync();
      expect(cubit.state.selectedAnime, animeA);
      expect(cubit.state.mediaListEntry, entryB);
    });

    test('late A response cannot enable saving while B is pending or failed', () async {
      final pendingA = Completer<(bool, AnimeDetails)>();
      final pendingB = Completer<(bool, AnimeDetails)>();
      when(() => repository.getAnimeDetails(animeA, any())).thenAnswer((_) => pendingA.future);
      when(() => repository.getAnimeDetails(animeB, any())).thenAnswer((_) => pendingB.future);
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      selection.updateSelectedAnime(animeB);
      await flushAsync();
      pendingA.complete((true, detailsA));
      await flushAsync();
      await cubit.updateMediaListEntry(context);
      expect(cubit.state.mediaListEntry, MediaListEntryModel.empty());
      pendingB.completeError(HttpServerException(500));
      await flushAsync();
      await cubit.updateMediaListEntry(context);
      verifyNever(() => repository.updateMediaListEntry(any(), any(), any()));
    });

    test('late entry reload cannot overwrite B or its shared entry notifier', () async {
      final oldEntry = Completer<MediaListEntry>();
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      when(() => repository.getMediaListEntry(animeA, any(), ignoreCache: true)).thenAnswer((_) => oldEntry.future);
      reload.emitReload(ReloadType.videoMediaListEntryUpdated);
      await flushAsync();
      selection.updateSelectedAnime(animeB);
      await flushAsync();
      reload.emitReload(ReloadType.animeMediaListEntryUpdated);
      await flushAsync();
      oldEntry.complete(entryA);
      await flushAsync();
      expect(cubit.state.mediaListEntry, entryB);
      expect(cubit.state.newMediaListEntry, entryB);
      expect(entries.currentMediaListEntry, entryB);
    });

    test('late episode and image responses cannot overwrite B', () async {
      final oldEpisodes = Completer<List<EpisodeInfo>>();
      final oldImage = Completer<String>();
      final episodeB = EpisodeInfoModel.empty().copyWith(id: 2);
      when(() => episodes.getEpisodeInfo(malId: -1, anilistId: 1)).thenAnswer((_) => oldEpisodes.future);
      when(() => episodes.getAlternativeImage(malId: -1, anilistId: 1)).thenAnswer((_) => oldImage.future);
      when(() => episodes.getEpisodeInfo(malId: -1, anilistId: 2)).thenAnswer((_) async => [episodeB]);
      when(() => episodes.getAlternativeImage(malId: -1, anilistId: 2)).thenAnswer((_) async => 'B image');
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      selection.updateSelectedAnime(animeB);
      await flushAsync();
      oldEpisodes.complete([EpisodeInfoModel.empty().copyWith(id: 1)]);
      oldImage.complete('A image');
      await flushAsync();
      expect(cubit.state.episodesInfo, [episodeB]);
      expect(episodeInfo.currentEpisodeInfo, [episodeB]);
      expect(cubit.state.alternateImage, 'B image');
    });

    test('late fallback recommendations cannot overwrite B', () async {
      final trending = Completer<(bool, List<Anime>)>();
      when(
        () => repository.getAnimeDetails(animeA, any()),
      ).thenAnswer((_) async => (true, detailsA.copyWith(recommendedAnimes: [])));
      when(() => repository.getTrendingAnimes(1, any())).thenAnswer((_) => trending.future);
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      selection.updateSelectedAnime(animeB);
      await flushAsync();
      trending.complete((true, [animeA]));
      await flushAsync();
      expect(cubit.state.recommendations.$1, isTrue);
      expect(cubit.state.recommendations.$2, [animeB]);
      verifyNever(() => episodes.getAlternativeImage(malId: -1, anilistId: 1));
    });

    for (final changeService in [false, true]) {
      test('rejects old details after ${changeService ? 'service' : 'user'} changes', () async {
        final oldDetails = Completer<(bool, AnimeDetails)>();
        when(() => repository.getAnimeDetails(animeA, user)).thenAnswer((_) => oldDetails.future);
        selection.updateSelectedAnime(animeA);
        await flushAsync();
        final nextUser = changeService
            ? user.copyWith(settings: const SettingsModel(service: Service.shikimori))
            : user.copyWith(id: 'user-2');
        users.updateUser(nextUser);
        await flushAsync();
        oldDetails.complete((true, detailsA));
        await flushAsync();
        expect(cubit.state.loggedUser, nextUser);
        expect(cubit.state.mediaListEntry, entryB);
        verify(() => repository.getAnimeDetails(animeA, nextUser)).called(1);
      });
    }

    test('late failure for A does not add an error to B', () async {
      final oldDetails = Completer<(bool, AnimeDetails)>();
      when(() => repository.getAnimeDetails(animeA, any())).thenAnswer((_) => oldDetails.future);
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      selection.updateSelectedAnime(animeB);
      await flushAsync();
      oldDetails.completeError(HttpServerException(500));
      await flushAsync();
      expect(cubit.state.mediaListEntry, entryB);
      expect(cubit.state.effects, isEmpty);
    });

    test('pending details, episodes and image cannot emit after close', () async {
      final pendingDetails = Completer<(bool, AnimeDetails)>();
      final pendingEpisodes = Completer<List<EpisodeInfo>>();
      final pendingImage = Completer<String>();
      when(() => episodes.getEpisodeInfo(malId: -1, anilistId: 1)).thenAnswer((_) => pendingEpisodes.future);
      when(() => episodes.getAlternativeImage(malId: -1, anilistId: 1)).thenAnswer((_) => pendingImage.future);
      selection.updateSelectedAnime(animeA);
      await flushAsync();
      when(() => repository.getAnimeDetails(animeB, any())).thenAnswer((_) => pendingDetails.future);
      selection.updateSelectedAnime(animeB);
      await flushAsync();
      await cubit.close();
      final closedState = cubit.state;
      pendingDetails.complete((true, detailsB));
      pendingEpisodes.complete([]);
      pendingImage.complete('A image');
      await flushAsync();
      expect(cubit.state, closedState);
    });
  });

  group('MangaDetailsCubit', () {
    late MangaDetailsCubit cubit;
    late MockMangaRepository repository;
    late MangaNotifier selection;
    late MangaGenresNotifier genres;
    late MangaDetailsModel mangaDetailsA;
    late MangaDetailsModel mangaDetailsB;

    setUp(() async {
      repository = MockMangaRepository();
      selection = MangaNotifier();
      genres = MangaGenresNotifier();
      mangaDetailsA = MangaDetailsModel(mediaListEntry: entryA, recommendedMangas: [mangaA], characters: [characterA]);
      mangaDetailsB = MangaDetailsModel(mediaListEntry: entryB, recommendedMangas: [mangaB], characters: [characterB]);
      when(() => repository.getMediaCoverImages(any())).thenAnswer((_) async => []);
      when(() => extensions.getInstalledMangaExtensions(any())).thenAnswer((_) async => {});
      when(() => repository.getMangaDetails(any(), any())).thenAnswer((_) async => (true, mangaDetailsB));
      cubit = MangaDetailsCubit(repository, users, selection, genres, mediaLists, extensions, userRepository);
      await flushAsync();
    });

    tearDown(() async {
      if (!cubit.isClosed) await cubit.close();
      selection.dispose();
      genres.dispose();
    });

    test('clears A on selection and rejects A details arriving after B', () async {
      when(() => repository.getMangaDetails(mangaA, any())).thenAnswer((_) async => (true, mangaDetailsA));
      selection.updateSelectedManga(mangaA);
      await flushAsync();
      final oldDetails = Completer<(bool, MangaDetails)>();
      when(() => repository.getMangaDetails(mangaA, any())).thenAnswer((_) => oldDetails.future);
      selection.updateSelectedManga(mangaA);
      await flushAsync();
      expect(cubit.state.mediaListEntry, MediaListEntryModel.empty());
      expect(cubit.state.characters.$1, isFalse);
      expect(cubit.state.characters.$2, isEmpty);
      expect(cubit.state.recommendations.$1, isFalse);
      expect(cubit.state.recommendations.$2, isEmpty);
      selection.updateSelectedManga(mangaB);
      await flushAsync();
      oldDetails.complete((true, mangaDetailsA));
      await flushAsync();
      expect(cubit.state.selectedManga, mangaB);
      expect(cubit.state.mediaListEntry, entryB);
      expect(cubit.state.characters.$1, isTrue);
      expect(cubit.state.characters.$2, [characterB]);
      expect(cubit.state.recommendations.$1, isTrue);
      expect(cubit.state.recommendations.$2, [mangaB]);
    });

    test('late fallback recommendations cannot overwrite B', () async {
      final trending = Completer<(bool, List<Manga>)>();
      when(
        () => repository.getMangaDetails(mangaA, any()),
      ).thenAnswer((_) async => (true, mangaDetailsA.copyWith(recommendedMangas: [])));
      when(() => repository.getTrendingMangas(1, any())).thenAnswer((_) => trending.future);
      selection.updateSelectedManga(mangaA);
      await flushAsync();
      selection.updateSelectedManga(mangaB);
      await flushAsync();
      trending.complete((true, [mangaA]));
      await flushAsync();
      expect(cubit.state.recommendations.$1, isTrue);
      expect(cubit.state.recommendations.$2, [mangaB]);
    });

    test('rejects old details after user changes', () async {
      final oldDetails = Completer<(bool, MangaDetails)>();
      when(() => repository.getMangaDetails(mangaA, user)).thenAnswer((_) => oldDetails.future);
      selection.updateSelectedManga(mangaA);
      await flushAsync();
      final nextUser = user.copyWith(id: 'user-2');
      users.updateUser(nextUser);
      await flushAsync();
      oldDetails.complete((true, mangaDetailsA));
      await flushAsync();
      expect(cubit.state.loggedUser, nextUser);
      expect(cubit.state.mediaListEntry, entryB);
    });

    test('pending details cannot emit after close', () async {
      final pendingDetails = Completer<(bool, MangaDetails)>();
      when(() => repository.getMangaDetails(mangaA, any())).thenAnswer((_) => pendingDetails.future);
      selection.updateSelectedManga(mangaA);
      await flushAsync();
      await cubit.close();
      final closedState = cubit.state;
      pendingDetails.complete((true, mangaDetailsA));
      await flushAsync();
      expect(cubit.state, closedState);
    });
  });
}

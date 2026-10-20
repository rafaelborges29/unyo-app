import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jni/jni.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unyo/application/cubits/anime_details_cubit.dart';
import 'package:unyo/application/effects/app_effects.dart';
import 'package:unyo/core/di/locator.dart';
import 'package:unyo/core/notification/anime_genres_notifier.dart';
import 'package:unyo/core/notification/anime_notifier.dart';
import 'package:unyo/core/notification/episode_info_notifier.dart';
import 'package:unyo/core/notification/episodes_notifier.dart';
import 'package:unyo/core/notification/extension_notifier.dart';
import 'package:unyo/core/notification/media_list_entry_notifier.dart';
import 'package:unyo/core/notification/media_list_notifier.dart';
import 'package:unyo/core/notification/reload/reload_notifier.dart';
import 'package:unyo/core/notification/user_notifier.dart';
import 'package:unyo/core/notification/video_info_notifier.dart';
import 'package:unyo/data/models/anilist/user/anilist_user_model.dart';
import 'package:unyo/data/repositories/extension_repository_aniyomi.dart';
import 'package:unyo/data/repositories/user_repository_anilist.dart';
import 'package:unyo/domain/entities/extension/extension.dart';
import 'package:unyo/domain/entities/extension/video.dart' as ext;
import 'package:unyo/domain/entities/media/anime.dart';
import 'package:unyo/domain/entities/media/anime_details.dart';
import 'package:unyo/domain/entities/media/title.dart';
import 'package:unyo/domain/entities/user/settings.dart';
import 'package:unyo/domain/entities/user/user.dart';
import 'package:unyo/domain/repositories/anime_repository.dart';
import 'package:unyo/domain/repositories/episode_repository.dart';
import 'package:unyo/presentation/drawers/anime_server_selection_drawer.dart';
import 'package:unyo_lib/jmodels/jsanime.dart';
import 'package:unyo_lib/jmodels/jsepisode.dart';
import 'package:unyo_lib/jmodels/jvideo.dart';

class MockAnimeRepository extends Mock implements AnimeRepository {}

class MockEpisodeRepository extends Mock implements EpisodeRepository {}

class MockExtensionRepository extends Mock
    implements ExtensionRepositoryAniyomi {}

class MockUserRepository extends Mock implements UserRepositoryAnilist {}

class MockJSAnime extends Mock implements JSAnime {}

class MockJSEpisode extends Mock implements JSEpisode {}

class MockJVideo extends Mock implements JVideo {}

class MockJString extends Mock implements JString {}

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  final animeA = AnimeModel.empty().copyWith(
    id: 1,
    title: const TitleModel(
      userPreferred: 'Anime A',
      english: 'A English',
      nativeTitle: 'A Native',
      romaji: 'A Romaji',
    ),
  );
  final animeB = AnimeModel.empty().copyWith(
    id: 2,
    title: const TitleModel(
      userPreferred: 'Anime B',
      english: 'B English',
      nativeTitle: 'B Native',
      romaji: 'B Romaji',
    ),
  );
  final extensionA = ExtensionModel.empty().copyWith(
    name: 'Extension A',
    pkg: 'extension.a',
  );
  final extensionB = ExtensionModel.empty().copyWith(
    name: 'Extension B',
    pkg: 'extension.b',
  );
  final user = AnilistUserModel(
    id: '1',
    name: 'Test',
    settings: SettingsModel.empty(),
    avatarImage: '',
    bannerImage: '',
    accessCode: '',
    accessToken: '',
    refreshToken: '',
  );
  late AnimeDetailsCubit cubit;
  late MockAnimeRepository animeRepository;
  late MockEpisodeRepository episodeRepository;
  late MockExtensionRepository extensionRepository;
  late MockUserRepository userRepository;
  late UserNotifier userNotifier;
  late AnimeNotifier animeNotifier;
  late AnimeGenresNotifier genresNotifier;
  late MediaListNotifier mediaListNotifier;
  late VideoInfoNotifier videoNotifier;
  late EpisodesInfoNotifier episodeInfoNotifier;
  late MediaListEntryNotifier entryNotifier;
  late ExtensionNotifier extensionNotifier;
  late EpisodesNotifier episodesNotifier;
  late ReloadNotifier reloadNotifier;
  late JSAnime matchA;
  late JSAnime matchB;
  late JSEpisode episodeA;

  // Mock JNI model boundaries; these cubit tests do not start a JVM.
  JSAnime match(String title) {
    final result = MockJSAnime();
    final jTitle = MockJString();
    when(() => jTitle.toDartString()).thenReturn(title);
    when(() => result.getTitle()).thenReturn(jTitle);
    return result;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> selectB({bool savedExtension = false}) async {
    if (savedExtension) {
      userNotifier.updateUser(
        user.copyWith(
          settings: SettingsModel(mediaExtensionConfigs: {'2': extensionB}),
        ),
      );
      await settle();
    }
    animeNotifier.updateSelectedAnime(animeB);
    await settle();
  }

  Future<AnimeServerSelectionDrawer> openDrawer() async {
    cubit.clearEffects();
    await cubit.openAnimeServerSelectionDrawer(MockBuildContext(), 0);
    return cubit.state.effects
            .whereType<ShowDrawerDialogEffect>()
            .single
            .drawerDialog
        as AnimeServerSelectionDrawer;
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(UserModel.empty());
    registerFallbackValue(AnimeModel.empty());
    registerFallbackValue(ExtensionModel.empty());
  });

  setUp(() async {
    await sl.reset();
    sl.registerSingleton<Logger>(Logger(level: Level.off));
    animeRepository = MockAnimeRepository();
    episodeRepository = MockEpisodeRepository();
    extensionRepository = MockExtensionRepository();
    userRepository = MockUserRepository();
    userNotifier = UserNotifier()..updateUser(user);
    animeNotifier = AnimeNotifier()..updateSelectedAnime(animeA);
    genresNotifier = AnimeGenresNotifier();
    mediaListNotifier = MediaListNotifier();
    videoNotifier = VideoInfoNotifier();
    episodeInfoNotifier = EpisodesInfoNotifier();
    entryNotifier = MediaListEntryNotifier();
    extensionNotifier = ExtensionNotifier();
    episodesNotifier = EpisodesNotifier();
    reloadNotifier = ReloadNotifier();
    matchA = match('Anime A');
    matchB = match('Anime B');
    episodeA = MockJSEpisode();
    when(
      () => animeRepository.getMediaCoverImages(any()),
    ).thenAnswer((_) async => []);
    when(() => animeRepository.getAnimeDetails(any(), any())).thenAnswer(
      (_) async => (
        true,
        AnimeDetailsModel.empty().copyWith(recommendedAnimes: [animeB]),
      ),
    );
    when(
      () => episodeRepository.getEpisodeInfo(
        malId: any(named: 'malId'),
        anilistId: any(named: 'anilistId'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => episodeRepository.getAlternativeImage(
        malId: any(named: 'malId'),
        anilistId: any(named: 'anilistId'),
      ),
    ).thenAnswer((_) async => '');
    when(
      () => extensionRepository.getInstalledAnimeExtensions(any()),
    ).thenAnswer((_) async => {extensionA, extensionB});
    when(
      () => extensionRepository.getAnimeSearchResults(any(), any()),
    ).thenAnswer((_) async => []);
    when(
      () => extensionRepository.getAnimeSearchResults('Anime A', extensionA),
    ).thenAnswer((_) async => [matchA]);
    when(
      () => extensionRepository.getAnimeSearchResults('Anime B', extensionB),
    ).thenAnswer((_) async => [matchB]);
    when(
      () => extensionRepository.getAnimeEpisodeList(matchA, extensionA),
    ).thenAnswer((_) async => [episodeA]);
    when(() => userRepository.updateUserInfo(any())).thenAnswer((
      invocation,
    ) async {
      userNotifier.updateUser(invocation.positionalArguments.first as User);
    });
    cubit = AnimeDetailsCubit(
      animeRepository,
      episodeRepository,
      userNotifier,
      animeNotifier,
      genresNotifier,
      mediaListNotifier,
      videoNotifier,
      extensionRepository,
      userRepository,
      episodeInfoNotifier,
      entryNotifier,
      extensionNotifier,
      episodesNotifier,
      reloadNotifier,
    );
    await settle();
  });

  tearDown(() async {
    await cubit.close();
    userNotifier.dispose();
    animeNotifier.dispose();
    genresNotifier.dispose();
    mediaListNotifier.dispose();
    videoNotifier.dispose();
    episodeInfoNotifier.dispose();
    entryNotifier.dispose();
    extensionNotifier.dispose();
    episodesNotifier.dispose();
    reloadNotifier.dispose();
    await sl.reset();
  });

  test(
    'changing title clears extension state and shared playback selection',
    () async {
      await cubit.selectAnimeExtension(extensionA.name);
      await openDrawer();
      final oldVideo = ext.Video.empty();
      // Arrange an already-open, ready server drawer without native video decoding.
      cubit.emit(
        cubit.state.copyWith(
          extensionVideoResults: [oldVideo],
          selectedAnimeResultIndex: 1,
          animeServerDialogReady: true,
          animeServerDialogLoading: true,
        ),
      );
      expect(episodesNotifier.currentJSEpisodes, [episodeA]);

      await selectB();

      expect(cubit.state.selectedAnime, animeB);
      expect(cubit.state.selectedExtension, isNull);
      expect(cubit.state.extensionAnimeResults, isEmpty);
      expect(cubit.state.selectedAnimeResultIndex, 0);
      expect(cubit.state.extensionEpisodeResults, isEmpty);
      expect(cubit.state.extensionVideoResults, isEmpty);
      expect(cubit.state.animeServerDialogReady, isFalse);
      expect(cubit.state.animeServerDialogLoading, isFalse);
      expect(cubit.state.installedExtensions, {extensionA, extensionB});
      expect(extensionNotifier.currentExtension, ExtensionModel.empty());
      expect(episodesNotifier.currentJSEpisodes, isEmpty);
      cubit.clearEffects();
      await cubit.navigateToVideoPlayer(oldVideo, 0, 0);
      expect(cubit.state.effects.whereType<PushRouteEffect>(), isEmpty);
    },
  );

  test(
    'changing title restores its saved extension and searches its title',
    () async {
      await cubit.selectAnimeExtension(extensionA.name);
      await selectB(savedExtension: true);

      expect(cubit.state.selectedExtension, extensionB);
      expect(cubit.state.extensionAnimeResults, [matchB]);
      expect(extensionNotifier.currentExtension, extensionB);
      verify(
        () => extensionRepository.getAnimeSearchResults('Anime B', extensionB),
      ).called(1);
      verifyNever(
        () => extensionRepository.getAnimeSearchResults('Anime B', extensionA),
      );
    },
  );

  test(
    'initial extension load restores the latest title, not the initial one',
    () async {
      await cubit.close();
      final installed = Completer<Set<Extension>>();
      when(
        () => extensionRepository.getInstalledAnimeExtensions(any()),
      ).thenAnswer((_) => installed.future);
      userNotifier.updateUser(
        user.copyWith(
          settings: SettingsModel(mediaExtensionConfigs: {'2': extensionB}),
        ),
      );
      cubit = AnimeDetailsCubit(
        animeRepository,
        episodeRepository,
        userNotifier,
        animeNotifier,
        genresNotifier,
        mediaListNotifier,
        videoNotifier,
        extensionRepository,
        userRepository,
        episodeInfoNotifier,
        entryNotifier,
        extensionNotifier,
        episodesNotifier,
        reloadNotifier,
      );
      await selectB();
      installed.complete({extensionA, extensionB});
      await settle();
      expect(cubit.state.selectedExtension, extensionB);
      expect(cubit.state.extensionAnimeResults, [matchB]);
    },
  );

  for (final result in ['match', 'empty', 'error']) {
    test('ignores late search $result from the previous title', () async {
      final pending = Completer<List<JSAnime>>();
      when(
        () => extensionRepository.getAnimeSearchResults('Anime A', extensionA),
      ).thenAnswer((_) => pending.future);
      final selecting = cubit.selectAnimeExtension(extensionA.name);
      await settle();
      await selectB(savedExtension: true);
      cubit.clearEffects();
      if (result == 'error') {
        pending.completeError(StateError('old search failed'));
      } else {
        pending.complete(result == 'empty' ? [] : [matchA]);
      }
      await selecting;
      expect(cubit.state.extensionAnimeResults, [matchB]);
      expect(cubit.state.selectedExtension, extensionB);
      expect(cubit.state.effects, isEmpty);
      verifyNever(
        () =>
            extensionRepository.getAnimeSearchResults('A English', extensionA),
      );
    });
  }

  test(
    'ignores late search from the previous extension on the same title',
    () async {
      final pending = Completer<List<JSAnime>>();
      when(
        () => extensionRepository.getAnimeSearchResults('Anime A', extensionA),
      ).thenAnswer((_) => pending.future);
      when(
        () => extensionRepository.getAnimeSearchResults('Anime A', extensionB),
      ).thenAnswer((_) async => [matchB]);
      final selecting = cubit.selectAnimeExtension(extensionA.name);
      await settle();
      await cubit.selectAnimeExtension(extensionB.name);
      pending.complete([matchA]);
      await selecting;
      expect(cubit.state.extensionAnimeResults, [matchB]);
      expect(cubit.state.selectedExtension, extensionB);
    },
  );

  test(
    'returning to the same title and extension still rejects the old search',
    () async {
      final pending = Completer<List<JSAnime>>();
      when(
        () => extensionRepository.getAnimeSearchResults('Anime A', extensionA),
      ).thenAnswer((_) => pending.future);
      final selecting = cubit.selectAnimeExtension(extensionA.name);
      await settle();
      await selectB();
      final currentMatch = match('Anime A');
      when(
        () => extensionRepository.getAnimeSearchResults('Anime A', extensionA),
      ).thenAnswer((_) async => [currentMatch]);
      animeNotifier.updateSelectedAnime(animeA);
      await settle();
      expect(cubit.state.extensionAnimeResults, [currentMatch]);
      pending.complete([matchA]);
      await selecting;
      expect(cubit.state.selectedAnime, animeA);
      expect(cubit.state.selectedExtension, extensionA);
      expect(cubit.state.extensionAnimeResults, [currentMatch]);
    },
  );

  test(
    'late settings save cannot start an old extension search for the new title',
    () async {
      final saving = Completer<void>();
      when(
        () => userRepository.updateUserInfo(any()),
      ).thenAnswer((_) => saving.future);
      final selecting = cubit.selectAnimeExtension(extensionA.name);
      await selectB();
      saving.complete();
      await selecting;
      verifyNever(
        () => extensionRepository.getAnimeSearchResults(any(), any()),
      );
      expect(cubit.state.selectedExtension, isNull);
    },
  );

  test(
    'late episode results cannot repopulate playback state or open a drawer',
    () async {
      await cubit.selectAnimeExtension(extensionA.name);
      final pending = Completer<List<JSEpisode>>();
      when(
        () => extensionRepository.getAnimeEpisodeList(matchA, extensionA),
      ).thenAnswer((_) => pending.future);
      final opening = cubit.openAnimeServerSelectionDrawer(
        MockBuildContext(),
        0,
      );
      await selectB();
      cubit.clearEffects();
      pending.complete([episodeA]);
      await opening;
      expect(cubit.state.extensionEpisodeResults, isEmpty);
      expect(episodesNotifier.currentJSEpisodes, isEmpty);
      expect(cubit.state.animeServerDialogLoading, isFalse);
      expect(cubit.state.effects, isEmpty);
    },
  );

  test(
    'late videos and an old drawer callback cannot make the new title playable',
    () async {
      await cubit.selectAnimeExtension(extensionA.name);
      final drawer = await openDrawer();
      final pending = Completer<List<JVideo>>();
      when(
        () => extensionRepository.getAnimeVideoList(episodeA, extensionA),
      ).thenAnswer((_) => pending.future);
      final loading = drawer.onOpen();
      await selectB();
      cubit.clearEffects();
      pending.complete([MockJVideo()]);
      expect(await loading, isFalse);
      expect(await drawer.onOpen(), isFalse);
      expect(cubit.state.extensionVideoResults, isEmpty);
      expect(cubit.state.animeServerDialogReady, isFalse);
      expect(cubit.state.effects, isEmpty);
      verify(
        () => extensionRepository.getAnimeVideoList(episodeA, extensionA),
      ).called(1);
    },
  );

  test(
    'clicking an episode before a new match exists does not index an empty list',
    () async {
      await cubit.selectAnimeExtension(extensionA.name);
      await selectB();
      await cubit.openAnimeServerSelectionDrawer(MockBuildContext(), 0);
      expect(cubit.state.animeServerDialogLoading, isFalse);
      expect(cubit.state.effects.whereType<ShowDrawerDialogEffect>(), isEmpty);
      verifyNever(
        () => extensionRepository.getAnimeEpisodeList(matchA, extensionA),
      );
    },
  );

  test('a title with no extension matches keeps playback empty', () async {
    when(
      () => extensionRepository.getAnimeSearchResults('Anime A', extensionA),
    ).thenAnswer((_) async => []);
    await cubit.selectAnimeExtension(extensionA.name);
    expect(cubit.state.extensionAnimeResults, isEmpty);
    expect(cubit.state.selectedAnimeResultIndex, 0);
    expect(
      cubit.state.effects.whereType<ShowSnackbarEffect>().last.message,
      contains('No results found'),
    );
    await cubit.openAnimeServerSelectionDrawer(MockBuildContext(), 0);
    expect(cubit.state.animeServerDialogLoading, isFalse);
  });
}

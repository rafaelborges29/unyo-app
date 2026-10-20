// Internal dependencies
import 'package:unyo/core/di/locator.dart';
import 'package:unyo/core/enums/service.dart';
import 'package:unyo/data/repositories/anime_repository_anilist.dart';
import 'package:unyo/data/repositories/anime_repository_shikimori.dart';
import 'package:unyo/domain/entities/media/anime.dart';
import 'package:unyo/domain/entities/media/anime_details.dart';
import 'package:unyo/domain/entities/list/media_list_entry.dart';
import 'package:unyo/domain/entities/user/user.dart';
import 'package:unyo/domain/repositories/anime_repository.dart';

/// Factory that resolves the correct [AnimeRepository] implementation
/// based on the user's selected metadata [Service].
///
/// Currently supports:
/// - [Service.anilist] → delegates to [AnimeRepositoryAnilist]
/// - [Service.shikimori] → delegates to [AnimeRepositoryShikimori]
/// - All other services → throws [UnsupportedError] without contacting another provider
class AnimeRepositoryFactory implements AnimeRepository {
  final AnimeRepositoryAnilist _animeRepositoryAnilist = sl<AnimeRepositoryAnilist>();
  final AnimeRepositoryShikimori _animeRepositoryShikimori = sl<AnimeRepositoryShikimori>();

  AnimeRepository _resolveRepository(User loggedUser) {
    switch (loggedUser.settings.service) {
      case Service.anilist:
        return _animeRepositoryAnilist;
      case Service.shikimori:
        return _animeRepositoryShikimori;
      case Service.mal:
      case Service.kitsu:
      case Service.simkl:
        throw UnsupportedError('Anime metadata is not supported for ${loggedUser.settings.service.name}');
    }
  }

  @override
  Future<(bool, List<Anime>)> getRecentlyReleasedAnimes(int page, User loggedUser, {bool ignoreCache = false}) async {
    return _resolveRepository(loggedUser).getRecentlyReleasedAnimes(page, loggedUser, ignoreCache: ignoreCache);
  }

  @override
  Future<(bool, List<Anime>)> getTrendingAnimes(int page, User loggedUser, {bool ignoreCache = false}) async {
    return _resolveRepository(loggedUser).getTrendingAnimes(page, loggedUser, ignoreCache: ignoreCache);
  }

  @override
  Future<(bool, List<Anime>)> getPopularAnimes(int page, User loggedUser, {bool ignoreCache = false}) async {
    return _resolveRepository(loggedUser).getPopularAnimes(page, loggedUser, ignoreCache: ignoreCache);
  }

  @override
  Future<(bool, List<Anime>)> getRecentlyCompletedAnimes(int page, User loggedUser, {bool ignoreCache = false}) async {
    return _resolveRepository(loggedUser).getRecentlyCompletedAnimes(page, loggedUser, ignoreCache: ignoreCache);
  }

  @override
  Future<(bool, List<Anime>)> getUpcomingAnimes(int page, User loggedUser, {bool ignoreCache = false}) async {
    return _resolveRepository(loggedUser).getUpcomingAnimes(page, loggedUser, ignoreCache: ignoreCache);
  }

  @override
  Future<Map<String, List<Anime>>> getCalendarReleases(int page, User loggedUser) async {
    return _resolveRepository(loggedUser).getCalendarReleases(page, loggedUser);
  }

  @override
  Future<(bool, AnimeDetails)> getAnimeDetails(Anime selectedAnime, User loggedUser) async {
    return _resolveRepository(loggedUser).getAnimeDetails(selectedAnime, loggedUser);
  }

  @override
  Future<Map<String, (bool, List<String>)>> getUserAnimeAdvancedSearchFilters(User loggedUser) async {
    return _resolveRepository(loggedUser).getUserAnimeAdvancedSearchFilters(loggedUser);
  }

  @override
  Future<List<Anime>> performAnimeAdvancedSearch(
    String query,
    List<String> selectedGenres,
    String? selectedSeason,
    String? selectedFormat,
    int? selectedYear,
    String? selectedAiringStatus,
    String sort,
    int page,
    User loggedUser,
  ) async {
    return _resolveRepository(loggedUser).performAnimeAdvancedSearch(
      query,
      selectedGenres,
      selectedSeason,
      selectedFormat,
      selectedYear,
      selectedAiringStatus,
      sort,
      page,
      loggedUser,
    );
  }

  @override
  Future<List<String>> getMediaCoverImages(User loggedUser, {bool ignoreCache = false}) async {
    return _resolveRepository(loggedUser).getMediaCoverImages(loggedUser, ignoreCache: ignoreCache);
  }

  @override
  Future<MediaListEntry> updateMediaListEntry(
    MediaListEntry newMediaListEntry,
    Anime selectedAnime,
    User loggedUser,
  ) async {
    return _resolveRepository(loggedUser).updateMediaListEntry(newMediaListEntry, selectedAnime, loggedUser);
  }

  @override
  Future<MediaListEntry> getMediaListEntry(Anime selectedAnime, User loggedUser, {bool ignoreCache = false}) async {
    return _resolveRepository(loggedUser).getMediaListEntry(selectedAnime, loggedUser, ignoreCache: ignoreCache);
  }
}

// External dependencies
import 'dart:async';
import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:logger/logger.dart';
import 'package:unyo/core/di/locator.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelfio;
import 'package:unyo/core/services/api/dto/anilist/auth_token_dto.dart';
import 'package:unyo/core/services/api/dto/anilist/media_collection_graphql_entity.dart';
import 'package:unyo/data/models/anilist/media/anilist_anime_model.dart';
import 'package:unyo/data/models/anilist/media/anilist_manga_model.dart';
import 'package:unyo/data/repositories/repository_mixin.dart';
import 'package:unyo/domain/entities/media/anime.dart';
import 'package:unyo/domain/entities/media/manga.dart';
import 'package:unyo/domain/entities/user/settings.dart';
import 'package:url_launcher/url_launcher.dart';

//Internal dependencies
import 'package:unyo/core/notification/user_notifier.dart';
import 'package:unyo/core/services/api/graphql/queries/anilist_queries.dart' as anilist_queries;
import 'package:unyo/config/config.dart' as config;
import 'package:unyo/core/services/api/dto/anilist/viewer_graphql_entity.dart';
import 'package:unyo/core/services/api/graphql/graphql_response.dart';
import 'package:unyo/core/services/api/graphql/graphql_service.dart';
import 'package:unyo/core/services/api/http/api_response.dart';
import 'package:unyo/core/services/api/http/http_service.dart';
import 'package:unyo/data/models/anilist/user/anilist_user_model.dart';
import 'package:unyo/domain/repositories/repositories.dart';
import 'package:unyo/domain/entities/user/user.dart';

class UserRepositoryAnilist with RepositoryMixin implements UserRepository {
  final Logger _logger = sl<Logger>();
  final HttpService _httpService = sl<HttpService>();
  final GraphQLService _anilistGraphQLService = sl<GraphQLService>(
    instanceName: config.anilistGraphQlService,
  );
  final UserNotifier _newUserNotifier;
  final UserNotifier _loggedUserNotifier;
  late Box<AnilistUserModel> _anilistUsersBox;
  _AnilistLoginSession? _loginSession;

  UserRepositoryAnilist(this._newUserNotifier, this._loggedUserNotifier);

  @override
  Future<List<User>> fetchAllLoggedInUsers() async {
    _anilistUsersBox = await Hive.openBox<AnilistUserModel>("anilistUsers");
    return [..._anilistUsersBox.values];
  }

  @override
  Future<void> attemptCreateUser() async {
    // Reserve ownership before binding so concurrent attempts reuse this session.
    if (_loginSession != null) return;
    final session = _AnilistLoginSession();
    _loginSession = session;
    _logger.i("Creating Anilist user");
    session.server = shelfio.serve(
      (request) => _handleLoginRequest(request, session),
      'localhost',
      9999,
    );
    try {
      await session.server;
      if (session.cancelled) return;
      session.timeout = Timer(const Duration(minutes: 5), () async {
        _logger.i("Anilist authorization timed out");
        await _closeLoginSession(session);
      });
      _logger.i("Launching Anilist authorization URL");
      final loginUri = Uri.parse(config.anilistAuthUrl);
      if (!await canLaunchUrl(loginUri)) {
        throw StateError('Could not launch Anilist authorization URL');
      }
      if (session.cancelled) return;
      if (!await launchUrl(loginUri)) {
        throw StateError('Could not launch Anilist authorization URL');
      }
    } catch (_, stackTrace) {
      await _closeLoginSession(session);
      _logger.e("Could not start Anilist authorization", stackTrace: stackTrace);
      throw StateError('Could not start Anilist authorization');
    }
  }

  Future<void> cancelCreateUser() async {
    final session = _loginSession;
    if (session != null) await _closeLoginSession(session);
  }

  Future<void> _closeLoginSession(_AnilistLoginSession session, {bool force = true}) async {
    try {
      await session.close(force: force);
    } finally {
      if (identical(_loginSession, session)) _loginSession = null;
    }
  }

  @override
  Future<void> updateUserInfo(User user) async {
    _anilistUsersBox = await Hive.openBox<AnilistUserModel>("anilistUsers");
    if (_anilistUsersBox.containsKey(user.name)) {
      _logger.w("User ${user.name} already exists in the registered anilist users, updating info");
      await _anilistUsersBox.put(user.name, user as AnilistUserModel);
    } else {
      _logger.i("Adding new user ${user.name} to the registered anilist users");
      await _anilistUsersBox.put(user.name, user as AnilistUserModel);
    }
    _loggedUserNotifier.updateUser(user);
  }

  @override
  Future<List<Anime>> getUserWatchingList(User user, {bool ignoreCache = false}) async {
    Map<String, String> graphQlHeaders = {
      "Authorization": "Bearer ${(user as AnilistUserModel).accessToken}",
    };
    ApiGraphQLResponse<MediaCollectionGraphqlDtoData> mediaCollection = await _anilistGraphQLService
        .query<MediaCollectionGraphqlDtoData>(
          query: anilist_queries.mediaListCollectionQuery,
          fromJson: MediaCollectionGraphqlDtoData.fromJson,
          variables: {"userName": user.name, "userId": user.id, "type": "ANIME"},
          headers: graphQlHeaders,
          ignoreCache: ignoreCache
        );
    throwIfGraphQlError(mediaCollection);
    MediaCollectionGraphqlDtoDataMediaListCollectionLists? watchingList =
        mediaCollection.data.mediaListCollection.lists
            .where((collection) => collection.name == "Watching")
            .firstOrNull;
    List<MediaCollectionGraphqlDtoDataMediaListCollectionListsEntriesMedia> mediaEntries =
        watchingList?.entries
            .map((entry) => entry.media)
            .toList() ?? [];
    return mediaEntries.map((mediaEntry) => AnilistAnimeModel.fromUserMediaEntry(mediaEntry)).toList();
  }

  @override
  Future<List<Manga>> getUserReadingList(User user, {bool ignoreCache = false}) async {
    Map<String, String> graphQlHeaders = {
      "Authorization": "Bearer ${(user as AnilistUserModel).accessToken}",
    };
    ApiGraphQLResponse<MediaCollectionGraphqlDtoData> mediaCollection = await _anilistGraphQLService
        .query<MediaCollectionGraphqlDtoData>(
          query: anilist_queries.mediaListCollectionQuery,
          fromJson: MediaCollectionGraphqlDtoData.fromJson,
          variables: {"userName": user.name, "userId": user.id, "type": "MANGA"},
          headers: graphQlHeaders,
          ignoreCache: ignoreCache
        );
    throwIfGraphQlError(mediaCollection);
    MediaCollectionGraphqlDtoDataMediaListCollectionLists? readingList =
        mediaCollection.data.mediaListCollection.lists
            .where((collection) => collection.name == "Reading")
            .firstOrNull;
    List<MediaCollectionGraphqlDtoDataMediaListCollectionListsEntriesMedia> mediaEntries =
        readingList?.entries
            .map((entry) => entry.media)
            .toList() ?? [];
    return mediaEntries.map((mediaEntry) => AnilistMangaModel.fromUserMediaEntry(mediaEntry)).toList();
  }

  @override
  Future<Map<String, List<Anime>>> getUserAnimeLists(User user) async {
    Map<String, String> graphQlHeaders = {
      "Authorization": "Bearer ${(user as AnilistUserModel).accessToken}",
    };
    ApiGraphQLResponse<MediaCollectionGraphqlDtoData> mediaCollection = await _anilistGraphQLService
        .query<MediaCollectionGraphqlDtoData>(
          query: anilist_queries.mediaListCollectionQuery,
          fromJson: MediaCollectionGraphqlDtoData.fromJson,
          variables: {"userName": user.name, "userId": user.id, "type": "ANIME"},
          headers: graphQlHeaders,
        );
    throwIfGraphQlError(mediaCollection);
    Map<String, List<Anime>> userAnimeLists = Map.fromEntries(
      mediaCollection.data.mediaListCollection.lists.map(
        (collection) => MapEntry(
          collection.name,
          collection.entries.map((entry) => AnilistAnimeModel.fromUserMediaEntry(entry.media)).toList()
              as List<Anime>,
        ),
      ),
    );
    return userAnimeLists;
  }

  @override
  Future<Map<String, List<Manga>>> getUserMangaLists(User user) async {
    Map<String, String> graphQlHeaders = {
      "Authorization": "Bearer ${(user as AnilistUserModel).accessToken}",
    };
    ApiGraphQLResponse<MediaCollectionGraphqlDtoData> mediaCollection = await _anilistGraphQLService
        .query<MediaCollectionGraphqlDtoData>(
          query: anilist_queries.mediaListCollectionQuery,
          fromJson: MediaCollectionGraphqlDtoData.fromJson,
          variables: {"userName": user.name, "userId": user.id, "type": "MANGA"},
          headers: graphQlHeaders,
        );
    throwIfGraphQlError(mediaCollection);
    Map<String, List<Manga>> userMangaLists = Map.fromEntries(
      mediaCollection.data.mediaListCollection.lists.map(
        (collection) => MapEntry(
          collection.name,
          collection.entries.map((entry) => AnilistMangaModel.fromUserMediaEntry(entry.media)).toList()
              as List<Manga>,
        ),
      ),
    );
    return userMangaLists;
  }

  Future<ApiResponse<AuthTokenEntity>> getAuthToken(String accessCode) async {
    Map<String, dynamic> body = {
      "grant_type": "authorization_code",
      "client_id": config.anilistClientId,
      "client_secret": config.anilistClientSecret,
      "redirect_uri": config.anilistRedirectUri,
      "code": accessCode,
    };
    return _httpService.post<AuthTokenEntity>(
      config.anilistOAuthEndpoint,
      fromJson: AuthTokenEntity.fromJson,
      body: body,
    );
  }

  Future<shelf.Response> _handleLoginRequest(shelf.Request request, _AnilistLoginSession session) async {
    if (session.cancelled || session.handlingCallback) {
      return shelf.Response.badRequest(body: 'Authorization is no longer pending.');
    }
    session.handlingCallback = true;
    try {
      _logger.i("Handling login request from Anilist at ${request.requestedUri.path}");
      String accessCode = request.requestedUri.queryParameters['code']!;
      await _createUser(accessCode, session);
      return shelf.Response.ok('Authorization successful. You can close this window.');
    } catch (e, stackTrace) {
      _logger.e("Error Handling login request: $e", stackTrace: stackTrace);
      return shelf.Response.internalServerError(
        body: "Something went wrong D:, please verify your internet connection and try again",
      );
    } finally {
      _logger.i("Closing Anilist login server");
      await _closeLoginSession(session, force: false);
    }
  }

  Future<void> _createUser(String accessCode, _AnilistLoginSession session) async {
    _anilistUsersBox = await Hive.openBox<AnilistUserModel>("anilistUsers");
    if (session.cancelled) return;
    ApiResponse<AuthTokenEntity> authToken = await getAuthToken(accessCode);
    if (session.cancelled) return;
    Map<String, String> graphQlHeaders = {"Authorization": "Bearer ${authToken.data.accessToken}"};
    ApiGraphQLResponse<ViewerGraphqlEntity> viewerDto = await _anilistGraphQLService
        .query<ViewerGraphqlEntity>(
          query: anilist_queries.viewerQuery,
          fromJson: ViewerGraphqlEntity.fromJson,
          headers: graphQlHeaders,
        );
    if (session.cancelled) return;
    throwIfGraphQlError(viewerDto);
    AnilistUserModel newAnilistUser = AnilistUserModel(
      id: viewerDto.data.viewer.id.toString(),
      name: viewerDto.data.viewer.name,
      settings: SettingsModel.empty(),
      avatarImage: viewerDto.data.viewer.avatar.medium,
      bannerImage: viewerDto.data.viewer.bannerImage,
      accessCode: accessCode,
      accessToken: authToken.data.accessToken,
      refreshToken: authToken.data.refreshToken,
    );
    await updateUserInfo(newAnilistUser);
    if (!session.cancelled) _newUserNotifier.updateUser(newAnilistUser);
  }
}

class _AnilistLoginSession {
  late final Future<HttpServer> server;
  Timer? timeout;
  bool cancelled = false;
  bool handlingCallback = false;
  Future<void>? _closing;

  Future<void> close({bool force = true}) {
    cancelled = true;
    timeout?.cancel();
    return _closing ??= _closeServer(force);
  }

  Future<void> _closeServer(bool force) async {
    final HttpServer boundServer;
    try {
      boundServer = await server;
    } catch (_) {
      // A failed bind has no listener to close; the caller reports the failure.
      return;
    }
    await boundServer.close(force: force);
  }
}

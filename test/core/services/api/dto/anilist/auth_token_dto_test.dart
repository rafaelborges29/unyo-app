import 'package:flutter_test/flutter_test.dart';
import 'package:unyo/core/services/api/dto/anilist/auth_token_dto.dart';

void main() {
  group('AuthTokenEntity.fromJson', () {
    test('accepts an AniList response without a refresh token', () {
      final token = AuthTokenEntity.fromJson({
        'token_type': 'Bearer',
        'expires_in': 31536000,
        'access_token': 'example',
      });

      expect(token.accessToken, 'example');
      expect(token.refreshToken, isEmpty);
    });

    test('accepts a null refresh token', () {
      final token = AuthTokenEntity.fromJson({
        'access_token': 'example',
        'refresh_token': null,
      });

      expect(token.accessToken, 'example');
      expect(token.refreshToken, isEmpty);
    });

    test('preserves a refresh token when present', () {
      final token = AuthTokenEntity.fromJson({
        'access_token': 'example',
        'refresh_token': 'legacy-token',
      });

      expect(token.accessToken, 'example');
      expect(token.refreshToken, 'legacy-token');
    });

    test('still rejects a missing access token', () {
      expect(() => AuthTokenEntity.fromJson({}), throwsA(isA<TypeError>()));
    });

    test('still rejects an invalid access token type', () {
      expect(
        () => AuthTokenEntity.fromJson({'access_token': 123}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}

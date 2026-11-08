import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persiste el par de tokens de sesión en el almacén seguro del sistema
/// (Keychain en iOS/macOS, EncryptedSharedPreferences en Android).
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _kAccess = 'upb.access_token';
  static const _kRefresh = 'upb.refresh_token';

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<String?> get accessToken => _storage.read(key: _kAccess);
  Future<String?> get refreshToken => _storage.read(key: _kRefresh);

  Future<bool> get hasSession async => (await accessToken) != null;

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}

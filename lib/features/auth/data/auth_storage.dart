import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  static const String _selectedEstablishmentIdKey = 'selected_establishment_id';
  static const String _selectedEstablishmentNameKey =
      'selected_establishment_name';
  static const String _selectedEstablishmentRoleKey =
      'selected_establishment_role';

  static const String _savedPhoneKey = 'saved_phone';
  static const String _savedPasswordKey = 'saved_password';
  static const String _biometricEnabledKey = 'biometric_enabled';

  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<void> saveSelectedEstablishment({
    required int establishmentId,
    required String establishmentName,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedEstablishmentIdKey, establishmentId);
    await prefs.setString(_selectedEstablishmentNameKey, establishmentName);
    await prefs.setString(_selectedEstablishmentRoleKey, role);
  }

  static Future<int?> getSelectedEstablishmentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_selectedEstablishmentIdKey);
  }

  static Future<String?> getSelectedEstablishmentName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedEstablishmentNameKey);
  }

  static Future<String?> getSelectedEstablishmentRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedEstablishmentRoleKey);
  }

  static Future<void> clearSelectedEstablishment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedEstablishmentIdKey);
    await prefs.remove(_selectedEstablishmentNameKey);
    await prefs.remove(_selectedEstablishmentRoleKey);
  }

  static Future<void> saveLoginCredentials({
    required String phone,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedPhoneKey, phone);
    await prefs.setString(_savedPasswordKey, password);
  }

  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedPhoneKey);
  }

  static Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedPasswordKey);
  }

  static Future<void> clearSavedLoginCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPhoneKey);
    await prefs.remove(_savedPasswordKey);
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await clearSelectedEstablishment();
    await clearSavedLoginCredentials();
    await prefs.remove(_biometricEnabledKey);
  }
}
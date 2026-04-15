import '../../../../core/network/api_client.dart';

class AuthApi {
  static Future<Map<String, dynamic>> requestCode(String phone) async {
    final response = await ApiClient.dio.post(
      '/api/v1/auth/request-code',
      data: {
        'phone': phone,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }

  static Future<Map<String, dynamic>> verifyCode({
    required String phone,
    required String code,
    required String deviceId,
    required String platform,
    String? fullName,
  }) async {
    final response = await ApiClient.dio.post(
      '/api/v1/auth/verify-code',
      data: {
        'phone': phone,
        'code': code,
        'device_id': deviceId,
        'platform': platform,
        'full_name': fullName,
      },
    );
    return Map<String, dynamic>.from(response.data);
  }
}
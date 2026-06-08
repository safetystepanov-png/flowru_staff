import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffPushDeviceApi {
  static const String _deviceIdKey = 'flowru_staff_device_id';

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_deviceIdKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final generated = 'staff-${_platform()}-$now';
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  static Future<void> _sendDebug({
    required String stage,
    required String message,
    String appVersion = '',
  }) async {
    try {
      final accessToken = await AuthStorage.getAccessToken();
      if (accessToken == null || accessToken.trim().isEmpty) {
        debugPrint('Staff push debug skipped: no access token stage=$stage');
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/devices/debug'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'stage': stage,
          'message': message,
          'platform': _platform(),
          'app_version': appVersion,
        }),
      );

      debugPrint('Staff push debug status=${response.statusCode} body=${response.body}');
    } catch (e, st) {
      debugPrint('Staff push debug error: $e');
      debugPrint('$st');
    }
  }

  static Future<bool> _waitForApnsToken({
    required String appVersion,
  }) async {
    if (kIsWeb || !Platform.isIOS) {
      return true;
    }

    for (var attempt = 1; attempt <= 8; attempt++) {
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null && apnsToken.trim().isNotEmpty) {
          await _sendDebug(
            stage: 'apns_token_ok',
            message: 'APNS token received on attempt $attempt',
            appVersion: appVersion,
          );
          return true;
        }

        await _sendDebug(
          stage: 'apns_token_wait',
          message: 'APNS token is empty on attempt $attempt',
          appVersion: appVersion,
        );
      } catch (e) {
        await _sendDebug(
          stage: 'apns_token_error',
          message: 'attempt $attempt: $e',
          appVersion: appVersion,
        );
      }

      await Future.delayed(Duration(milliseconds: 700 * attempt));
    }

    await _sendDebug(
      stage: 'apns_token_timeout',
      message: 'APNS token was not available after retries',
      appVersion: appVersion,
    );
    return false;
  }

  static void registerCurrentDeviceTokenInBackground({
    String appVersion = '',
  }) {
    Future<void>(() async {
      await registerCurrentDeviceToken(appVersion: appVersion);
    });
  }
  static Future<void> registerCurrentDeviceToken({
    String appVersion = '',
  }) async {
    await _sendDebug(
      stage: 'start',
      message: 'registerCurrentDeviceToken called',
      appVersion: appVersion,
    );

    try {
      final accessToken = await AuthStorage.getAccessToken();
      if (accessToken == null || accessToken.trim().isEmpty) {
        debugPrint('Staff push register skipped: no access token');
        return;
      }

      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await _sendDebug(
        stage: 'permission_status',
        message: permission.authorizationStatus.toString(),
        appVersion: appVersion,
      );

      final apnsReady = await _waitForApnsToken(appVersion: appVersion);
      if (!apnsReady) {
        return;
      }

      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e, st) {
        debugPrint('FCM getToken error: $e');
        debugPrint('$st');
        await _sendDebug(
          stage: 'fcm_get_token_error',
          message: e.toString(),
          appVersion: appVersion,
        );
        return;
      }

      if (fcmToken == null || fcmToken.trim().isEmpty) {
        debugPrint('Staff push register skipped: empty FCM token');
        await _sendDebug(
          stage: 'empty_fcm_token',
          message: 'FirebaseMessaging.getToken returned empty token',
          appVersion: appVersion,
        );
        return;
      }

      await _sendDebug(
        stage: 'fcm_token_ok',
        message: 'FCM token received',
        appVersion: appVersion,
      );

      final deviceId = await _getOrCreateDeviceId();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/devices/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'device_id': deviceId,
          'platform': _platform(),
          'push_token': fcmToken,
          'app_version': appVersion,
        }),
      );

      debugPrint(
        'Staff push register status=${response.statusCode} body=${response.body}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _sendDebug(
          stage: 'register_http_error',
          message: 'status=${response.statusCode} body=${response.body}',
          appVersion: appVersion,
        );
      } else {
        await _sendDebug(
          stage: 'register_success',
          message: 'push token saved',
          appVersion: appVersion,
        );
      }
    } catch (e, st) {
      debugPrint('Staff push register error: $e');
      debugPrint('$st');
      await _sendDebug(
        stage: 'register_exception',
        message: e.toString(),
        appVersion: appVersion,
      );
    }
  }

  static void listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      debugPrint('Staff FCM token refreshed: $token');
      await registerCurrentDeviceToken(appVersion: '1.0.1+13');
    });
  }
}



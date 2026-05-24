import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> _requestNotificationPermissions() async {
  final messaging = FirebaseMessaging.instance;

  final settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  debugPrint('FCM permission status: ${settings.authorizationStatus}');
}

Future<void> _printFcmToken() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('FCM TOKEN: $token');
  } catch (e, st) {
    debugPrint('FCM TOKEN ERROR: $e');
    debugPrint('$st');
  }
}

void _setupForegroundMessageHandler() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('FCM onMessage: ${message.messageId}');
    debugPrint('FCM title: ${message.notification?.title}');
    debugPrint('FCM body: ${message.notification?.body}');
    debugPrint('FCM data: ${message.data}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('FCM onMessageOpenedApp: ${message.messageId}');
    debugPrint('FCM opened data: ${message.data}');
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Безопасная инициализация Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e, stack) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint('Stack trace: $stack');
    // Продолжаем работу, но push-уведомления не будут работать
  }

  // Запрашиваем разрешения и инициализируем FCM только если Firebase инициализирована
  if (Firebase.apps.isNotEmpty) {
    await _requestNotificationPermissions();
    await _printFcmToken();
    _setupForegroundMessageHandler();

    if (!kIsWeb) {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM initialMessage: ${initialMessage.messageId}');
        debugPrint('FCM initial data: ${initialMessage.data}');
      }
    }
  } else {
    debugPrint('Firebase not available, skipping FCM setup');
  }

  runApp(const FlowruStaffApp());
}
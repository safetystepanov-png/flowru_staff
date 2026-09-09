import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

class BusinessUpdateChecker {
  static bool _shown = false;

  static Future<void> checkAndShow(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (kIsWeb || _shown) return;

    final String? platform;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        platform = 'android';
        break;
      case TargetPlatform.iOS:
        platform = 'ios';
        break;
      default:
        platform = null;
    }

    if (platform == null) return;

    // Даём splash-экрану завершиться.
    await Future<void>.delayed(const Duration(milliseconds: 3400));

    try {
      final packageInfo = await PackageInfo.fromPlatform();

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/business/app/version'
        '?platform=$platform',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('Business update check HTTP ${response.statusCode}');
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final data = Map<String, dynamic>.from(decoded);

      final latestVersion = (data['latest_version'] ?? '').toString().trim();

      if (latestVersion.isEmpty) return;

      final currentVersion =
          '${packageInfo.version}+${packageInfo.buildNumber}';

      if (!_isRemoteNewer(latestVersion, currentVersion)) {
        return;
      }

      final downloadUrl = (data['download_url'] ?? '').toString().trim();

      final message =
          (data['message'] ?? 'Доступна новая версия Flowru Business.')
              .toString()
              .trim();

      final forceUpdate = data['force_update'] == true;

      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      _shown = true;

      await showDialog<void>(
        context: context,
        barrierDismissible: !forceUpdate,
        builder: (dialogContext) {
          return PopScope(
            canPop: !forceUpdate,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              title: const Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFE9F9FA),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(
                        Icons.system_update_rounded,
                        color: Color(0xFF0BAEBB),
                        size: 25,
                      ),
                    ),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Доступно обновление',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                message.isEmpty
                    ? 'Доступна новая версия Flowru Business.'
                    : message,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: Color(0xFF557186),
                  fontWeight: FontWeight.w500,
                ),
              ),
              actions: [
                if (!forceUpdate)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Позже'),
                  ),
                FilledButton.icon(
                  onPressed: downloadUrl.isEmpty
                      ? null
                      : () async {
                          final uri = Uri.tryParse(downloadUrl);
                          if (uri == null) return;

                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Обновить'),
                ),
              ],
            ),
          );
        },
      );
    } catch (e, st) {
      debugPrint('Business update check failed: $e');
      debugPrint('$st');
    }
  }

  static bool _isRemoteNewer(String remote, String current) {
    final remoteParsed = _parseVersion(remote);
    final currentParsed = _parseVersion(current);

    for (var i = 0; i < 3; i++) {
      if (remoteParsed.$1[i] > currentParsed.$1[i]) {
        return true;
      }
      if (remoteParsed.$1[i] < currentParsed.$1[i]) {
        return false;
      }
    }

    return remoteParsed.$2 > currentParsed.$2;
  }

  static (List<int>, int) _parseVersion(String value) {
    final split = value.trim().split('+');

    final versionParts = split.first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();

    while (versionParts.length < 3) {
      versionParts.add(0);
    }

    final build = split.length > 1 ? int.tryParse(split[1]) ?? 0 : 0;

    return (versionParts.take(3).toList(growable: false), build);
  }
}

from pathlib import Path

path = Path(r"lib\app\app.dart")
s = path.read_text(encoding="utf-8")

# 1) Добавляем импорты
imports_to_add = [
    "import 'package:flutter/foundation.dart';",
    "import 'package:flutter/services.dart';",
    "import 'package:local_auth/local_auth.dart';",
]

for imp in imports_to_add:
    if imp not in s:
        # вставляем после первого flutter import
        marker = "import 'package:flutter/material.dart';"
        if marker in s:
            s = s.replace(marker, marker + "\n" + imp)
        else:
            s = imp + "\n" + s

# 2) Добавляем поля в _AppBootstrapScreenState
old = """class _AppBootstrapScreenState extends State<_AppBootstrapScreen> {
  late Future<_BootstrapState> _future;"""

new = """class _AppBootstrapScreenState extends State<_AppBootstrapScreen> {
  late Future<_BootstrapState> _future;
  final LocalAuthentication _localAuth = LocalAuthentication();"""

if old in s and new not in s:
    s = s.replace(old, new)

# 3) Заменяем _resolve полностью
start = s.find("  Future<_BootstrapState> _resolve() async {")
if start == -1:
    raise SystemExit("Не нашёл начало _resolve")

end = s.find("\n  Future<void> _retry() async {", start)
if end == -1:
    raise SystemExit("Не нашёл конец _resolve")

new_resolve = r'''  Future<_BootstrapState> _resolve() async {
    String? token = await AuthStorage.getAccessToken();
    final refreshToken = await AuthStorage.getRefreshToken();
    final biometricEnabled = await AuthStorage.isBiometricEnabled();

    final hasToken = token != null && token.trim().isNotEmpty;
    final hasRefresh = refreshToken != null && refreshToken.trim().isNotEmpty;

    if (!hasToken && !hasRefresh) {
      return const _BootstrapState.unauthorized();
    }

    if (!kIsWeb && biometricEnabled && hasRefresh) {
      final unlocked = await _unlockWithBiometric();
      if (!unlocked) {
        return const _BootstrapState.unauthorized();
      }

      final refreshedToken = await _refreshAccessToken(refreshToken.trim());
      if (refreshedToken != null && refreshedToken.trim().isNotEmpty) {
        token = refreshedToken.trim();
      }
    } else if (!hasToken && hasRefresh) {
      final refreshedToken = await _refreshAccessToken(refreshToken.trim());
      if (refreshedToken != null && refreshedToken.trim().isNotEmpty) {
        token = refreshedToken.trim();
      }
    }

    if (token == null || token.trim().isEmpty) {
      return const _BootstrapState.unauthorized();
    }

    try {
      return await _resolveProfileByToken(token.trim());
    } catch (_) {
      if (hasRefresh) {
        final refreshedToken = await _refreshAccessToken(refreshToken.trim());
        if (refreshedToken != null && refreshedToken.trim().isNotEmpty) {
          try {
            return await _resolveProfileByToken(refreshedToken.trim());
          } catch (_) {}
        }
      }

      await AuthStorage.clearSessionButKeepBiometric();
      return const _BootstrapState.unauthorized();
    }
  }

  Future<bool> _unlockWithBiometric() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final biometrics = await _localAuth.getAvailableBiometrics();

      if (!supported || (!canCheck && biometrics.isEmpty)) {
        return true;
      }

      return await _localAuth.authenticate(
        localizedReason: 'Войдите в Flowru Staff',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _refreshAccessToken(String refreshToken) async {
    try {
      final result = await UserApi().refresh(
        refreshToken: refreshToken,
        deviceId: kIsWeb ? 'staff-web' : 'staff-mobile',
        platform: kIsWeb ? 'web' : 'mobile',
      );

      if (!result.ok) return null;

      await AuthStorage.saveAccessToken(result.accessToken);
      await AuthStorage.saveRefreshToken(result.refreshToken);

      return result.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<_BootstrapState> _resolveProfileByToken(String token) async {
    final profile = await UserApi.getAccessProfile(token);

    if (!profile.hasAccess || profile.establishments.isEmpty) {
      await AuthStorage.clearAll();
      return _BootstrapState.revoked(profile: profile);
    }

    final savedEstablishmentId = await AuthStorage.getSelectedEstablishmentId();
    final savedEstablishmentName =
        await AuthStorage.getSelectedEstablishmentName();
    final savedRole = await AuthStorage.getSelectedEstablishmentRole();

    if (savedEstablishmentId != null) {
      final matched = profile.establishments.cast<AccessProfileEstablishment?>()
          .firstWhere(
            (e) => e?.id == savedEstablishmentId && (e?.accessActive ?? false),
            orElse: () => null,
          );

      if (matched != null) {
        final effectiveName =
            (savedEstablishmentName != null && savedEstablishmentName.trim().isNotEmpty)
                ? savedEstablishmentName.trim()
                : matched.name;
        final effectiveRole =
            (savedRole != null && savedRole.trim().isNotEmpty)
                ? savedRole.trim()
                : matched.role;

        await AuthStorage.saveSelectedEstablishment(
          establishmentId: matched.id,
          establishmentName: effectiveName,
          role: effectiveRole,
        );

        return _BootstrapState.authorizedWithSelection(
          profile: profile,
          establishmentId: matched.id,
          establishmentName: effectiveName,
          role: effectiveRole,
        );
      } else {
        await AuthStorage.clearSelectedEstablishment();
      }
    }

    final activeEstablishments = profile.establishments
        .where((e) => e.accessActive)
        .toList();

    if (activeEstablishments.length == 1) {
      final single = activeEstablishments.first;

      await AuthStorage.saveSelectedEstablishment(
        establishmentId: single.id,
        establishmentName: single.name,
        role: single.role,
      );

      return _BootstrapState.authorizedWithSelection(
        profile: profile,
        establishmentId: single.id,
        establishmentName: single.name,
        role: single.role,
      );
    }

    return _BootstrapState.authorized(profile: profile);
  }
'''

s = s[:start] + new_resolve + s[end:]

path.write_text(s, encoding="utf-8")
print("app.dart patched: biometric bootstrap added")

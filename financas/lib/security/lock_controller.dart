import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Controla o bloqueio do app por PIN e biometria.
///
/// O PIN nunca é salvo em texto: guardamos um hash SHA-256 iterado com sal
/// aleatório no armazenamento seguro do Android (Keystore).
class LockController extends ChangeNotifier with WidgetsBindingObserver {
  LockController({FlutterSecureStorage? storage, LocalAuthentication? auth})
    : _storage = storage ?? const FlutterSecureStorage(),
      _auth = auth ?? LocalAuthentication();

  static const _kHash = 'pin_hash';
  static const _kSalt = 'pin_salt';
  static const _kLength = 'pin_length';
  static const _kBiometric = 'biometric_enabled';

  /// Tempo em segundo plano após o qual o app pede o PIN de novo.
  static const relockAfter = Duration(seconds: 30);
  static const maxAttempts = 5;
  static const lockoutDuration = Duration(seconds: 30);
  static const _hashIterations = 10000;

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  bool initialized = false;
  bool hasPin = false;
  bool locked = true;
  int pinLength = 4;
  bool biometricEnabled = false;
  bool biometricAvailable = false;

  int _failedAttempts = 0;
  DateTime? lockoutUntil;
  DateTime? _backgroundedAt;
  bool _authenticating = false;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    final hash = await _storage.read(key: _kHash);
    hasPin = hash != null;
    pinLength = int.tryParse(await _storage.read(key: _kLength) ?? '') ?? 4;
    biometricEnabled = await _storage.read(key: _kBiometric) == 'true';
    try {
      biometricAvailable =
          await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      biometricAvailable = false;
    }
    locked = hasPin;
    initialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!hasPin || _authenticating) return;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null && DateTime.now().difference(since) >= relockAfter) {
          lock();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void lock() {
    if (!hasPin || locked) return;
    locked = true;
    notifyListeners();
  }

  bool get isLockedOut =>
      lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);

  /// Verifica o PIN e desbloqueia o app se estiver correto.
  Future<bool> unlockWithPin(String pin) async {
    if (isLockedOut) return false;
    final ok = await _checkPin(pin);
    if (ok) {
      _failedAttempts = 0;
      lockoutUntil = null;
      locked = false;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= maxAttempts) {
        _failedAttempts = 0;
        lockoutUntil = DateTime.now().add(lockoutDuration);
      }
    }
    notifyListeners();
    return ok;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!biometricEnabled || !biometricAvailable) return false;
    final ok = await authenticateBiometric(
      'Desbloqueie para ver suas finanças',
    );
    if (ok) {
      _failedAttempts = 0;
      locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// Mostra o diálogo de biometria do sistema.
  Future<bool> authenticateBiometric(String reason) async {
    _authenticating = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    } finally {
      _authenticating = false;
      _backgroundedAt = null;
    }
  }

  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kHash, value: _hash(pin, salt));
    await _storage.write(key: _kLength, value: '${pin.length}');
    hasPin = true;
    pinLength = pin.length;
    locked = false;
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final ok = await authenticateBiometric(
        'Confirme sua biometria para ativar',
      );
      if (!ok) return;
    }
    await _storage.write(key: _kBiometric, value: '$enabled');
    biometricEnabled = enabled;
    notifyListeners();
  }

  Future<bool> _checkPin(String pin) async {
    final salt = await _storage.read(key: _kSalt);
    final hash = await _storage.read(key: _kHash);
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  static String _randomSalt() {
    final r = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String _hash(String pin, String salt) {
    var bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < _hashIterations; i++) {
      bytes = Uint8List.fromList(sha256.convert(bytes).bytes);
    }
    return base64Encode(bytes);
  }
}

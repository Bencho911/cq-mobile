import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'cart.dart';
import 'loyalty.dart';
import 'notifications.dart';
import 'orders.dart';
import 'preferences.dart';

/// Cuenta del cliente. Hasta que el backend exponga usuarios, la cuenta vive
/// en el teléfono: los datos en preferencias y el PIN (como hash con sal)
/// en el llavero seguro del sistema (Keychain / Keystore).

enum AuthProvider { phone, apple, google }

class UserAccount {
  const UserAccount({
    required this.name,
    required this.createdAt,
    this.phone,
    this.cedula,
    this.email,
    this.provider = AuthProvider.phone,
  });

  final String name;
  final String? phone;
  final String? cedula;
  final String? email;
  final AuthProvider provider;
  final DateTime createdAt;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
  String get initial => name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  /// "+57 313 892 4671".
  String? get phoneLabel {
    final p = phone;
    if (p == null || p.length != 10) return p;
    return '+57 ${p.substring(0, 3)} ${p.substring(3, 6)} ${p.substring(6)}';
  }

  UserAccount copyWith({String? name, String? phone, String? cedula, String? email}) => UserAccount(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        cedula: cedula ?? this.cedula,
        email: email ?? this.email,
        provider: provider,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'cedula': cedula,
        'email': email,
        'provider': provider.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserAccount.fromJson(Map<String, dynamic> j) => UserAccount(
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String?,
        cedula: j['cedula'] as String?,
        email: j['email'] as String?,
        provider: AuthProvider.values.asNameMap()[j['provider']] ?? AuthProvider.phone,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      );
}

class AuthState {
  const AuthState({this.account, this.loggedIn = false, this.locked = false, this.biometricEnabled = false, this.hasPin = false});

  /// Cuenta guardada en el teléfono (aunque haya cerrado sesión).
  final UserAccount? account;
  final bool loggedIn;

  /// Sesión abierta pero bloqueada: pide Face ID / huella o el PIN.
  final bool locked;
  final bool biometricEnabled;
  final bool hasPin;

  AuthState copyWith({UserAccount? Function()? account, bool? loggedIn, bool? locked, bool? biometricEnabled, bool? hasPin}) => AuthState(
        account: account != null ? account() : this.account,
        loggedIn: loggedIn ?? this.loggedIn,
        locked: locked ?? this.locked,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        hasPin: hasPin ?? this.hasPin,
      );
}

/// Error con un mensaje listo para mostrar al cliente.
class AuthException implements Exception {
  const AuthException(this.message, {this.detail});
  final String message;
  final String? detail;
  @override
  String toString() => message;
}

/// Inicio de sesión cancelado por el cliente: no se muestra nada.
class AuthCancelled implements Exception {
  const AuthCancelled();
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());
final localAuthProvider = Provider<LocalAuthentication>((ref) => LocalAuthentication());

class AuthNotifier extends Notifier<AuthState> {
  static const _accountKey = 'cq.account';
  static const _sessionKey = 'cq.session';
  static const _biometricKey = 'cq.biometric';
  static const _pinKey = 'cq.pin';

  /// Código de verificación del registro (MOCK: no hay SMS todavía).
  String? _pendingOtp;

  @override
  AuthState build() {
    final prefs = ref.read(prefsProvider);
    UserAccount? account;
    final raw = prefs.getString(_accountKey);
    if (raw != null) {
      try {
        account = UserAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final loggedIn = account != null && (prefs.getBool(_sessionKey) ?? false);
    final biometric = prefs.getBool(_biometricKey) ?? false;
    // El PIN vive en el llavero: se confirma en segundo plano.
    Future.microtask(_refreshHasPin);
    return AuthState(account: account, loggedIn: loggedIn, locked: loggedIn && biometric, biometricEnabled: biometric);
  }

  Future<void> _refreshHasPin() async {
    final has = (await _readPin()) != null;
    if (has != state.hasPin) state = state.copyWith(hasPin: has);
  }

  FlutterSecureStorage get _secure => ref.read(secureStorageProvider);

  Future<String?> _readPin() async {
    try {
      return await _secure.read(key: _pinKey);
    } catch (_) {
      return null;
    }
  }

  void _saveAccount(UserAccount a) {
    ref.read(prefsProvider).setString(_accountKey, jsonEncode(a.toJson()));
    state = state.copyWith(account: () => a);
  }

  void _setSession(bool loggedIn) {
    ref.read(prefsProvider).setBool(_sessionKey, loggedIn);
    state = state.copyWith(loggedIn: loggedIn, locked: false);
  }

  // ── Registro con celular ──

  /// Guarda los datos del registro (aún sin sesión) y "envía" el código.
  /// Devuelve el código porque no hay SMS (MOCK): la app lo muestra.
  String startRegistration({required String name, required String phone, required String cedula}) {
    if (state.account != null && state.account!.phone != phone) _forgetPreviousUser();
    _saveAccount(UserAccount(name: name.trim(), phone: phone, cedula: cedula, createdAt: DateTime.now()));
    return resendOtp();
  }

  /// Nuevo código de 5 dígitos (MOCK).
  String resendOtp() {
    final code = (Random.secure().nextInt(90000) + 10000).toString();
    _pendingOtp = code;
    return code;
  }

  bool verifyOtp(String code) => _pendingOtp != null && code == _pendingOtp;

  // ── PIN ──

  String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  /// Guarda el PIN y abre la sesión (fin del registro o "olvidé mi PIN").
  Future<void> setPin(String pin) async {
    final salt = base64Url.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    await _secure.write(key: _pinKey, value: '$salt\$${_hash(pin, salt)}');
    state = state.copyWith(hasPin: true);
    _setSession(true);
  }

  Future<bool> checkPin(String pin) async {
    final stored = await _readPin();
    if (stored == null) return false;
    final parts = stored.split(r'$');
    return parts.length == 2 && _hash(pin, parts[0]) == parts[1];
  }

  // ── Ingreso ──

  /// ¿Hay una cuenta con este celular en el teléfono?
  bool hasAccountFor(String phone) => state.account?.phone == phone;

  /// Ingreso con PIN. Lanza [AuthException] si no coincide.
  Future<void> loginWithPin(String pin) async {
    if (!await checkPin(pin)) throw const AuthException('El PIN no coincide.', detail: 'Revisa los números e inténtalo de nuevo.');
    _setSession(true);
  }

  /// Desbloquea con el PIN (pantalla de bloqueo).
  Future<void> unlockWithPin(String pin) => loginWithPin(pin);

  // ── Biometría ──

  /// ¿El teléfono tiene Face ID / Touch ID / huella configurados?
  Future<bool> biometricsAvailable() async {
    try {
      final auth = ref.read(localAuthProvider);
      return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await ref.read(localAuthProvider).authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
    } on PlatformException catch (e) {
      debugPrint('[auth] biometría: ${e.code} ${e.message}');
      throw const AuthException('No pudimos usar la biometría.', detail: 'Revisa que Face ID o la huella estén activos en el teléfono.');
    }
  }

  /// Activa o desactiva el ingreso con biometría (pide confirmarla al activar).
  Future<void> setBiometric(bool enabled) async {
    if (enabled) {
      if (!await biometricsAvailable()) {
        throw const AuthException('Este teléfono no tiene biometría configurada.', detail: 'Activa Face ID o la huella en los ajustes del teléfono.');
      }
      if (!await _authenticate('Confirma para entrar con biometría a Café Quindío')) throw const AuthCancelled();
    }
    ref.read(prefsProvider).setBool(_biometricKey, enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  /// Desbloquea o ingresa con biometría. Devuelve `false` si el cliente cancela.
  Future<bool> unlockWithBiometrics() async {
    if (!state.biometricEnabled || state.account == null) return false;
    final ok = await _authenticate('Entra a Café Quindío');
    if (ok) _setSession(true);
    return ok;
  }

  /// Bloquea la sesión (al volver a la app tras un rato, si hay biometría).
  void lock() {
    if (state.loggedIn && state.biometricEnabled) state = state.copyWith(locked: true);
  }

  // ── Apple y Google ──

  static const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  bool _googleReady = false;

  Future<void> signInWithGoogle() async {
    if (_googleIosClientId.isEmpty && defaultTargetPlatform == TargetPlatform.iOS) {
      throw const AuthException('Google aún no está configurado en esta versión.',
          detail: 'Falta el ID de cliente de Google (GOOGLE_IOS_CLIENT_ID). Por ahora entra con tu celular.');
    }
    try {
      final google = GoogleSignIn.instance;
      if (!_googleReady) {
        await google.initialize(
          clientId: _googleIosClientId.isEmpty ? null : _googleIosClientId,
          serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
        );
        _googleReady = true;
      }
      final user = await google.authenticate();
      _socialLogin(name: user.displayName ?? user.email.split('@').first, email: user.email, provider: AuthProvider.google);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const AuthCancelled();
      debugPrint('[auth] Google: ${e.code} ${e.description}');
      throw const AuthException('No pudimos entrar con Google.', detail: 'Inténtalo de nuevo o entra con tu celular.');
    } catch (e) {
      debugPrint('[auth] Google: $e');
      throw const AuthException('No pudimos entrar con Google.', detail: 'Inténtalo de nuevo o entra con tu celular.');
    }
  }

  Future<void> signInWithApple() async {
    if (!await SignInWithApple.isAvailable()) {
      throw const AuthException('Iniciar con Apple no está disponible en este teléfono.');
    }
    try {
      final cred = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.fullName, AppleIDAuthorizationScopes.email]);
      // Apple solo entrega nombre y correo la primera vez: se conservan los guardados.
      final previous = state.account?.provider == AuthProvider.apple ? state.account : null;
      final name = [cred.givenName, cred.familyName].whereType<String>().join(' ').trim();
      _socialLogin(
        name: name.isNotEmpty ? name : (previous?.name ?? 'Cliente Café Quindío'),
        email: cred.email ?? previous?.email,
        provider: AuthProvider.apple,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw const AuthCancelled();
      debugPrint('[auth] Apple: ${e.code} ${e.message}');
      throw const AuthException('No pudimos entrar con Apple.',
          detail: 'En instalaciones de prueba (Sideloadly) Apple no lo permite. Entra con tu celular o con Google.');
    } catch (e) {
      debugPrint('[auth] Apple: $e');
      throw const AuthException('No pudimos entrar con Apple.', detail: 'Inténtalo de nuevo o entra con tu celular.');
    }
  }

  void _socialLogin({required String name, String? email, required AuthProvider provider}) {
    final current = state.account;
    // Misma persona (mismo correo): se conservan celular y cédula.
    final account = current != null && email != null && current.email == email
        ? current.copyWith(name: current.name.isEmpty ? name : null)
        : UserAccount(name: name, email: email, provider: provider, createdAt: DateTime.now());
    if (current != null && !identical(account, current) && current.email != email) _forgetPreviousUser();
    _saveAccount(account);
    _setSession(true);
  }

  /// El teléfono guarda una sola cuenta: si entra otra persona, se borran
  /// los pedidos, puntos, avisos y el PIN de la anterior.
  void _forgetPreviousUser() {
    final prefs = ref.read(prefsProvider);
    for (final k in const [
      'cq.orders',
      'cq.loyalty',
      'cq.loyalty.seen',
      'cq.notifications',
      'cq.preferences',
      'cq.voucher',
      'cq.ready-shown',
      'cq-cart-v1',
      _biometricKey,
    ]) {
      prefs.remove(k);
    }
    _secure.delete(key: _pinKey).catchError((_) {});
    state = state.copyWith(biometricEnabled: false, hasPin: false);
    ref
      ..invalidate(ordersProvider)
      ..invalidate(loyaltyProvider)
      ..invalidate(notificationsProvider)
      ..invalidate(preferencesProvider)
      ..invalidate(cartProvider);
  }

  // ── Perfil y salida ──

  void updateProfile({String? name, String? phone, String? cedula, String? email}) {
    final a = state.account;
    if (a != null) _saveAccount(a.copyWith(name: name, phone: phone, cedula: cedula, email: email));
  }

  /// Cierra la sesión: la cuenta y sus datos quedan en el teléfono.
  Future<void> logout() async {
    if (state.account?.provider == AuthProvider.google) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    _setSession(false);
  }

  /// Borra la cuenta y todo lo guardado en el teléfono.
  Future<void> deleteAccount() async {
    await logout();
    await ref.read(prefsProvider).clear();
    try {
      await _secure.deleteAll();
    } catch (_) {}
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

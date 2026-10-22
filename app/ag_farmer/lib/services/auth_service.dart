import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/agro_user_profile.dart';
import 'api_client.dart';
import 'client_log.dart';

/// Local session user — auth via backend only (no Firebase client keys).
class AuthSessionUser {
  AuthSessionUser({
    required this.uid,
    this.phoneNumber,
    this.email,
    this.displayName,
  });

  final String uid;
  final String? phoneNumber;
  final String? email;
  final String? displayName;
}

class AuthService extends ChangeNotifier {
  /// Web OAuth client — required for Google ID token (public client id, not service key)
  static const String _fallbackGoogleClientId =
      '621096737592-abjvope8i0jgc0gdg7201a48sb5ltkn1.apps.googleusercontent.com';

  AuthSessionUser? _user;
  AgroUserProfile? _profile;
  bool _ready = false;
  bool _busy = false;
  String? _error;
  String? _googleClientId;
  bool _googleReady = false;

  AuthSessionUser? get user => _user;
  AgroUserProfile? get profile => _profile;
  bool get ready => _ready;
  bool get busy => _busy;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  /// Only a loaded profile can ask for more details. A saved login stays in.
  bool get needsProfileCompletion =>
      _user != null &&
      _profile != null &&
      (!_profile!.profileComplete || !_hasMobile(_profile!.phone));

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    await ApiClient.instance.loadSession();
    final uid = ApiClient.instance.uid;
    if (ApiClient.instance.hasSession && uid != null && uid.isNotEmpty) {
      _user = AuthSessionUser(
        uid: uid,
        email: ApiClient.instance.email,
      );
    }
    _ready = true;
    notifyListeners();

    try {
      final cfg = await ApiClient.instance.config();
      final auth = cfg['auth'];
      if (auth is Map && auth['googleClientId'] != null) {
        _googleClientId = '${auth['googleClientId']}';
      }
    } catch (_) {}

    if (_user != null) {
      await _loadProfile(_user!.uid);
      notifyListeners();
    }
  }

  Future<void> _applySession(Map<String, dynamic> res) async {
    final token = '${res['token'] ?? ''}';
    final uid = '${res['uid'] ?? ''}';
    if (token.isEmpty || uid.isEmpty) {
      throw Exception('Login token missing');
    }
    final name = '${res['name'] ?? ''}';
    final email = '${res['email'] ?? ''}';
    final phone = '${res['phone'] ?? ''}';

    await ApiClient.instance.setSession(
      token: token,
      uid: uid,
      email: email.isEmpty ? null : email,
    );

    _user = AuthSessionUser(
      uid: uid,
      email: email.isEmpty ? null : email,
      phoneNumber: phone.isEmpty ? null : phone,
      displayName: name.isEmpty ? null : name,
    );

    final profileMap = res['profile'];
    if (profileMap is Map) {
      _profile = AgroUserProfile.fromMap(
        uid,
        Map<dynamic, dynamic>.from(profileMap),
      );
    } else {
      _profile = AgroUserProfile(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        provider: '${res['authMode'] ?? 'email'}'.contains('google')
            ? 'google'
            : 'email',
        profileComplete: res['needsProfileCompletion'] != true,
      );
    }
    _requireMobile();
  }

  void _requireMobile() {
    final profile = _profile;
    if (profile == null || _hasMobile(profile.phone)) return;
    _profile = profile.copyWith(profileComplete: false);
  }

  bool _hasMobile(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return true;
    if (digits.length == 12 && digits.startsWith('91')) return true;
    if (digits.length == 11 && digits.startsWith('0')) return true;
    return false;
  }

  Future<void> _loadProfile(String uid) async {
    try {
      final res = await ApiClient.instance.call('users.me', auth: true);
      final map = res['user'];
      if (map is Map) {
        _profile = AgroUserProfile.fromMap(
          uid,
          Map<dynamic, dynamic>.from(map),
        );
        _user = AuthSessionUser(
          uid: uid,
          phoneNumber: _profile?.phone,
          email: _profile?.email,
          displayName: _profile?.name,
        );
        final em = _profile?.email;
        final tok = ApiClient.instance.token;
        if (em != null && em.isNotEmpty && tok != null && tok.isNotEmpty) {
          await ApiClient.instance.setSession(token: tok, uid: uid, email: em);
        }
        _requireMobile();
      }
    } catch (e) {
      debugPrint('Profile load via API failed: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _mapErr(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    final lower = raw.toLowerCase();
    if (lower.contains('email_in_use') || lower.contains('already')) {
      return 'email_in_use';
    }
    if (lower.contains('account_pending_deletion')) return 'account_pending_deletion';
    if (lower.contains('invalid_email')) return 'invalid_email';
    if (lower.contains('weak_password')) return 'weak_password';
    if (lower.contains('bad_credentials')) return 'bad_credentials';
    if (lower.contains('accept_policy')) return 'accept_policy';
    if (lower.contains('invalid_phone')) return 'invalid_phone';
    if (lower.contains('account_not_found')) return 'account_not_found';
    if (lower.contains('email_send_failed')) return 'email_send_failed';
    if (lower.contains('email_auth_disabled')) return 'email_auth_disabled';
    if (lower.contains('no_phone_on_account')) return 'no_phone_on_account';
    if (lower.contains('invalid_otp')) return 'invalid_otp';
    if (lower.contains('otp_expired')) return 'otp_expired';
    if (lower.contains('service_unavailable') ||
        lower.contains('firebase_auth_unavailable') ||
        lower.contains('unavailable') ||
        lower.contains('उपलब्ध नहीं')) {
      return 'service_unavailable';
    }
    if (lower.contains('rate_limit') || lower.contains('too_many')) {
      return 'rate_limit_exceeded';
    }
    if (lower.contains('network') || lower.contains('unreachable')) {
      return 'network';
    }
    return raw;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String address,
    required String phone,
    required String password,
    required int age,
    required bool acceptedPolicy,
  }) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.call(
        'auth.register',
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'address': address.trim(),
          'phone': phone.trim(),
          'password': password,
          'age': age,
          'acceptedPolicy': acceptedPolicy,
        },
      );
      await _applySession(res);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapErr(e);
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.call(
        'auth.login',
        data: {'email': email.trim(), 'password': password},
      );
      await _applySession(res);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapErr(e);
      _busy = false;
      ClientLog.login(_error, screen: 'login');
      notifyListeners();
      return false;
    }
  }

  /// Returns masked phone / optional debugOtp when SMS_PROVIDER=log
  Future<Map<String, dynamic>?> requestPasswordReset({
    required String email,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.call(
        'auth.password.forgot',
        data: {'email': email.trim()},
      );
      _busy = false;
      notifyListeners();
      return res;
    } catch (e) {
      _error = _mapErr(e);
      _busy = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.call(
        'auth.password.reset',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
        },
      );
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapErr(e);
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      // Refresh client id if backend was down at cold start
      if (_googleClientId == null || _googleClientId!.isEmpty) {
        try {
          final cfg = await ApiClient.instance.config();
          final auth = cfg['auth'];
          if (auth is Map && auth['googleClientId'] != null) {
            _googleClientId = '${auth['googleClientId']}';
          }
        } catch (_) {}
        _googleClientId ??= _fallbackGoogleClientId;
      }

      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(serverClientId: _googleClientId);
        _googleReady = true;
        debugPrint('GoogleSignIn ready clientId=$_googleClientId');
      }

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google ID token missing. Add SHA-1 in Firebase/Google Cloud for com.agfarmer.app',
        );
      }

      debugPrint('Google Sign-In OK → ${googleUser.email}');

      final res = await ApiClient.instance.call(
        'auth.google',
        data: {'idToken': idToken, 'name': googleUser.displayName},
      );
      await _applySession(res);
      _busy = false;
      notifyListeners();
      return true;
    } on GoogleSignInException catch (e) {
      debugPrint('GoogleSignInException: ${e.code} ${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _error = null; // user dismissed sheet
        _busy = false;
        notifyListeners();
        return false;
      }
      final desc = '${e.description ?? ''} ${e.code.name}'.toLowerCase();
      if (desc.contains('10') ||
          desc.contains('developer') ||
          desc.contains('sha') ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        _error =
            'Google setup incomplete. SHA-1 missing or wrong OAuth client.';
      } else {
        ClientLog.login(_error, screen: 'google');
        _error = e.description ?? e.code.name;
      }
      _busy = false;
      notifyListeners();
      return false;
    } catch (e, st) {
      debugPrint('Google sign-in failed: $e\n$st');
      _error = _mapErr(e);
      _busy = false;
      ClientLog.login(_error, screen: 'google');
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeGoogleProfile({
    required String phone,
    required int age,
    required bool acceptedPolicy,
    String? name,
  }) async {
    if (_user == null) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.call(
        'auth.profile.complete',
        auth: true,
        data: {
          'phone': phone.trim(),
          'age': age,
          'acceptedPolicy': acceptedPolicy,
          if (name != null) 'name': name.trim(),
        },
      );
      await _applySession(res);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapErr(e);
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    if (_user == null) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.instance.call('users.me.delete', auth: true);
      if (res['scheduled'] != true) {
        throw Exception('delete_failed');
      }
      await ApiClient.instance.clearSession();
      _user = null;
      _profile = null;
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapErr(e);
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await ApiClient.instance.clearSession();
    _user = null;
    _profile = null;
    notifyListeners();
  }
}

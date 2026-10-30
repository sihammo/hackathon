import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/models.dart';
import 'db.dart';
import 'mock_db.dart';

/// Error carrying a localization key (see core/l10n.dart).
class AuthFailure implements Exception {
  final String key;
  const AuthFailure(this.key);
  @override
  String toString() => key;
}

/// Username + password auth on top of Firebase Authentication.
/// Firebase stores only a salted hash of the password; the app never stores it.
class AuthService {
  final Db db;
  final FirebaseAuth? _auth;

  AuthService(this.db, [FirebaseAuth? auth])
      : _auth = auth ?? (Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null);

  bool get isMock => _auth == null || db is MockDb;

  static final usernameRegex = RegExp(r'^[a-z0-9_.]{3,20}$');

  static String normalize(String username) => username.trim().toLowerCase();

  static String emailFor(String username) =>
      '${normalize(username)}@${AppConstants.usernameDomain}';

  Stream<User?> authChanges() => _auth?.authStateChanges() ?? const Stream.empty();

  Future<void> signIn(String username, String password) async {
    if (isMock) return;
    final u = normalize(username);
    if (!usernameRegex.hasMatch(u)) throw const AuthFailure('err_bad_credentials');
    try {
      await _auth!.signInWithEmailAndPassword(email: emailFor(u), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_map(e.code));
    }
  }

  Future<void> signUp({
    required String fullName,
    required String username,
    required String password,
    required String phone,
    required int wilayaCode,
  }) async {
    if (isMock) return;
    final u = normalize(username);
    if (!usernameRegex.hasMatch(u)) throw const AuthFailure('err_username_format');
    UserCredential cred;
    try {
      cred = await _auth!.createUserWithEmailAndPassword(email: emailFor(u), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_map(e.code));
    }
    try {
      await db.createUserProfile(
        uid: cred.user!.uid,
        fullName: fullName.trim(),
        username: u,
        phone: phone.trim(),
        wilayaCode: wilayaCode,
      );
    } catch (e) {
      // Roll back the auth account so the username can be reused.
      try {
        await cred.user?.delete();
      } catch (_) {}
      throw const AuthFailure('err_generic');
    }
  }

  Future<void> signOut() => _auth?.signOut() ?? Future.value();

  static String _map(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return 'err_bad_credentials';
      case 'email-already-in-use':
        return 'err_username_taken';
      case 'weak-password':
        return 'err_weak_password';
      case 'user-disabled':
        return 'err_disabled';
      case 'too-many-requests':
        return 'err_too_many';
      case 'network-request-failed':
        return 'err_network';
      default:
        return 'err_generic';
    }
  }
}

/// Holds the signed-in user's profile and decides which home to show.
class SessionController extends ChangeNotifier {
  final AuthService auth;
  final Db db;

  AppUser? user;
  bool loading = true;

  /// Localization key of the last session error (shown on the login screen).
  String? lastError;

  bool _signingUp = false;
  StreamSubscription? _authSub;
  StreamSubscription? _userSub;

  SessionController(this.auth, this.db) {
    if (auth.isMock) {
      loading = false;
    } else {
      _authSub = auth.authChanges().listen(_onAuth);
    }
  }

  void _onAuth(User? fu) {
    _userSub?.cancel();
    _userSub = null;
    if (fu == null) {
      user = null;
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    _userSub = db.userDoc(fu.uid).snapshots().listen((snap) {
      if (!snap.exists) {
        if (!_signingUp) {
          lastError = 'err_no_profile';
          auth.signOut();
        }
        return;
      }
      final u = AppUser.fromDoc(snap);
      if (u.disabled) {
        lastError = 'err_disabled';
        user = null;
        auth.signOut();
        return;
      }
      user = u;
      loading = false;
      notifyListeners();
    }, onError: (_) {
      lastError = 'err_network';
      user = null;
      loading = false;
      notifyListeners();
      auth.signOut();
    });
  }

  Future<void> signIn(String username, String password) async {
    lastError = null;
    if (auth.isMock) {
      final u = username.trim().toLowerCase();
      if (u == 'admin') {
        user = MockDb.demoAdmin;
      } else {
        final mockDb = db is MockDb ? (db as MockDb) : null;
        user = mockDb?.findUserByUsername(u) ?? MockDb.demoUser;
      }
      loading = false;
      notifyListeners();
      return;
    }
    return auth.signIn(username, password);
  }

  void loginAsDemoUser() {
    user = MockDb.demoUser;
    lastError = null;
    loading = false;
    notifyListeners();
  }

  void loginAsDemoAdmin() {
    user = MockDb.demoAdmin;
    lastError = null;
    loading = false;
    notifyListeners();
  }

  Future<void> updateUser(Map<String, dynamic> data) async {
    if (user == null) return;
    await db.updateUser(user!.uid, data);
    if (auth.isMock) {
      if (db is MockDb) {
        final fresh = (db as MockDb).findUserById(user!.uid);
        if (fresh != null) {
          user = fresh;
          notifyListeners();
          return;
        }
      }
      user = user!.copyWith(
        fullName: data['fullName'] as String?,
        phone: data['phone'] as String?,
        wilayaCode: data['wilayaCode'] as int?,
        vehicleType: data.containsKey('vehicleType')
            ? VehicleType.fromId(data['vehicleType'] as String?)
            : null,
        testMode: data['testMode'] as bool?,
        testPhoneNumber: data['testPhoneNumber'] as String?,
        avatarUrl: data.containsKey('avatarUrl') ? (data['avatarUrl'] as String?) : null,
      );
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String fullName,
    required String username,
    required String password,
    required String phone,
    required int wilayaCode,
  }) async {
    lastError = null;
    if (auth.isMock) {
      final u = username.trim().toLowerCase();
      final newUser = AppUser(
        uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName.trim(),
        username: u,
        phone: phone.trim(),
        wilayaCode: wilayaCode,
        role: 'user',
        disabled: false,
        createdAt: DateTime.now(),
        vehicleType: VehicleType.car,
        testMode: true,
        testPhoneNumber: '0555999888',
      );
      if (db is MockDb) {
        (db as MockDb).addUser(newUser);
      }
      user = newUser;
      loading = false;
      notifyListeners();
      return;
    }
    _signingUp = true;
    try {
      await auth.signUp(
        fullName: fullName,
        username: username,
        password: password,
        phone: phone,
        wilayaCode: wilayaCode,
      );
    } finally {
      _signingUp = false;
    }
  }

  Future<void> signOut() async {
    if (auth.isMock) {
      user = null;
      notifyListeners();
      return;
    }
    return auth.signOut();
  }

  void clearError() {
    lastError = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}

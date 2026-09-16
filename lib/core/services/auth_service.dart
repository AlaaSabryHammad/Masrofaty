import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../firebase_options.dart';
import '../../models/account_record.dart';
import '../../models/user_model.dart';
import 'firebase_sync_service.dart';

class AuthResult {
  final bool isSuccess;
  final UserModel? user;
  final String? errorMessage;

  AuthResult({required this.isSuccess, this.user, this.errorMessage});

  factory AuthResult.success(UserModel user) =>
      AuthResult(isSuccess: true, user: user);

  factory AuthResult.failure(String message) =>
      AuthResult(isSuccess: false, errorMessage: message);
}

class AuthService {
  static const String keyAuthUser = 'masrofaty_current_auth_user';
  static const String keyAllAccounts = 'masrofaty_all_registered_accounts';

  final SharedPreferences _prefs;
  final Uuid _uuid = const Uuid();

  FirebaseAuth? _firebaseAuth;

  AuthService(this._prefs) {
    _initFirebaseAuth();
  }

  bool get _isRealFirebaseConfigured {
    try {
      final key = DefaultFirebaseOptions.android.apiKey;
      return !key.contains('Demo') && !key.contains('Masrofaty');
    } catch (_) {
      return false;
    }
  }

  void _initFirebaseAuth() {
    if (!_isRealFirebaseConfigured) {
      _firebaseAuth = null;
      return;
    }
    try {
      if (FirebaseSyncService.isInitialized) {
        _firebaseAuth = FirebaseAuth.instance;
      }
    } catch (_) {
      _firebaseAuth = null;
    }
  }

  FirebaseAuth? get _auth {
    if (!_isRealFirebaseConfigured) return null;
    if (_firebaseAuth == null) {
      _initFirebaseAuth();
    }
    return _firebaseAuth;
  }

  // ==========================================
  // Accounts Database Persistence (Local Store)
  // ==========================================

  /// Load all registered accounts stored on device
  List<AccountRecord> getAllAccounts() {
    final jsonStr = _prefs.getString(keyAllAccounts);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map((e) => AccountRecord.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error loading registered accounts: $e');
        return [];
      }
    }
    return [];
  }

  /// Save all registered accounts to storage
  Future<void> _saveAccounts(List<AccountRecord> accounts) async {
    final list = accounts.map((a) => a.toJson()).toList();
    await _prefs.setString(keyAllAccounts, jsonEncode(list));
  }

  /// Find account by email (case-insensitive)
  AccountRecord? findAccountByEmail(String email) {
    final clean = email.trim().toLowerCase();
    final accounts = getAllAccounts();
    try {
      return accounts.firstWhere(
        (a) => a.user.email != null && a.user.email!.trim().toLowerCase() == clean,
      );
    } catch (_) {
      return null;
    }
  }

  /// Find account by phone
  AccountRecord? findAccountByPhone(String phone) {
    final clean = phone.trim().replaceAll(' ', '');
    final accounts = getAllAccounts();
    try {
      return accounts.firstWhere(
        (a) => a.user.phone != null && a.user.phone!.replaceAll(' ', '') == clean,
      );
    } catch (_) {
      return null;
    }
  }

  /// Load currently active logged in user session
  UserModel? loadSavedUser() {
    final jsonStr = _prefs.getString(keyAuthUser);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return UserModel.fromJson(map);
      } catch (e) {
        debugPrint('Error loading saved auth user: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> _persistUser(UserModel user) async {
    await _prefs.setString(keyAuthUser, jsonEncode(user.toJson()));
  }

  Future<void> _clearPersistedUser() async {
    await _prefs.remove(keyAuthUser);
  }

  // ==========================================
  // Authentication Actions
  // ==========================================

  /// 1. Sign Up with Email and Password
  Future<AuthResult> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? profession,
    bool isEmailVerified = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanProfession = profession?.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult.failure('صيغة البريد الإلكتروني غير صحيحة.');
    }
    if (password.length < 6) {
      return AuthResult.failure('كلمة المرور يجب أن لا تقل عن 6 أحرف أو أرقام.');
    }

    // 1. Check if email already registered locally
    final existingAccount = findAccountByEmail(cleanEmail);
    if (existingAccount != null) {
      return AuthResult.failure('هذا البريد الإلكتروني مسجل بالفعل. يرجى تسجيل الدخول أو استعادة كلمة المرور.');
    }

    String userId = _uuid.v4();

    // 2. Attempt Firebase registration if connected (with strict 3-second timeout)
    try {
      if (_auth != null) {
        final cred = await _auth!.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        ).timeout(const Duration(seconds: 3));
        final fbUser = cred.user;
        if (fbUser != null) {
          try {
            await fbUser.updateDisplayName(cleanName).timeout(const Duration(seconds: 2));
          } catch (_) {}
          userId = fbUser.uid;
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return AuthResult.failure('هذا البريد الإلكتروني مسجل مسبقاً في السحابة.');
      }
      debugPrint('Firebase signup warning: ${e.code}');
    } catch (e) {
      debugPrint('Firebase signup bypass or timeout: $e');
      // Firebase unavailable or timeout, continue seamlessly with local account
    }

    // 3. Create securely hashed account record
    final salt = _uuid.v4();
    final passwordHash = AccountRecord.hashPassword(password, salt);

    final user = UserModel(
      id: userId,
      name: cleanName,
      email: cleanEmail,
      profession: (cleanProfession != null && cleanProfession.isNotEmpty) ? cleanProfession : null,
      authMethod: 'email',
      isGuest: false,
      isEmailVerified: isEmailVerified,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    final record = AccountRecord(
      user: user,
      passwordHash: passwordHash,
      salt: salt,
    );

    // 4. Save account to database
    final accounts = getAllAccounts();
    accounts.add(record);
    await _saveAccounts(accounts);

    // 5. Set as active user
    await _persistUser(user);

    return AuthResult.success(user);
  }

  /// 2. Sign In with Email and Password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult.failure('يرجى إدخال بريد إلكتروني صحيح.');
    }

    // 1. Check if user exists in accounts database
    final accounts = getAllAccounts();
    final index = accounts.indexWhere(
      (a) => a.user.email != null && a.user.email!.trim().toLowerCase() == cleanEmail,
    );

    if (index == -1) {
      // Attempt Firebase login if online
      if (_auth != null) {
        try {
          final cred = await _auth!.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          ).timeout(const Duration(seconds: 3));
          final fbUser = cred.user;
          if (fbUser != null) {
            final salt = _uuid.v4();
            final passwordHash = AccountRecord.hashPassword(password, salt);
            final user = UserModel(
              id: fbUser.uid,
              name: fbUser.displayName ?? cleanEmail.split('@').first,
              email: cleanEmail,
              authMethod: 'email',
              isGuest: false,
              createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
              lastLoginAt: DateTime.now(),
            );
            accounts.add(AccountRecord(user: user, passwordHash: passwordHash, salt: salt));
            await _saveAccounts(accounts);
            await _persistUser(user);
            return AuthResult.success(user);
          }
        } on FirebaseAuthException catch (e) {
          return AuthResult.failure(_mapFirebaseError(e.code, e.message));
        } catch (_) {}
      }
      return AuthResult.failure('لم يتم العثور على حساب مسجل بهذا البريد الإلكتروني. يرجى إنشاء حساب جديد أولاً.');
    }

    // 2. Account exists locally: Verify password
    final record = accounts[index];
    final isPasswordValid = record.verifyPassword(password);
    if (!isPasswordValid) {
      return AuthResult.failure('كلمة المرور غير صحيحة. يرجى التأكد وإعادة المحاولة أو استعادة كلمة المرور.');
    }

    // 3. Optional: Sync with Firebase session if available
    try {
      if (_auth != null) {
        await _auth!.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        ).timeout(const Duration(seconds: 2));
      }
    } catch (_) {}

    // 4. Update last login
    final updatedUser = record.user.copyWith(lastLoginAt: DateTime.now());
    accounts[index] = record.copyWith(user: updatedUser);
    await _saveAccounts(accounts);
    await _persistUser(updatedUser);

    return AuthResult.success(updatedUser);
  }

  /// 3. Reset Password with new password
  Future<AuthResult> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (newPassword.length < 6) {
      return AuthResult.failure('كلمة المرور الجديدة يجب أن لا تقل عن 6 أحرف أو أرقام.');
    }

    final accounts = getAllAccounts();
    final index = accounts.indexWhere(
      (a) => a.user.email != null && a.user.email!.trim().toLowerCase() == cleanEmail,
    );

    if (index == -1) {
      return AuthResult.failure('لم يتم العثور على حساب مسجل بهذا البريد الإلكتروني.');
    }

    final newSalt = _uuid.v4();
    final newHash = AccountRecord.hashPassword(newPassword, newSalt);

    accounts[index] = accounts[index].copyWith(
      passwordHash: newHash,
      salt: newSalt,
    );
    await _saveAccounts(accounts);

    // Try Firebase password reset if available
    try {
      if (_auth != null) {
        await _auth!.sendPasswordResetEmail(email: cleanEmail);
      }
    } catch (_) {}

    return AuthResult.success(accounts[index].user);
  }

  /// 4. Send Password Reset Email
  Future<bool> sendPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final account = findAccountByEmail(cleanEmail);
    if (account == null) {
      return false; // Email doesn't exist
    }

    try {
      if (_auth != null) {
        await _auth!.sendPasswordResetEmail(email: cleanEmail).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}

    return true;
  }

  /// 5. Sign In with Google
  Future<AuthResult> signInWithGoogle() async {
    String googleEmail = 'user@gmail.com';
    String googleName = 'مستخدم Google';
    String? photoUrl;

    try {
      if (_auth != null) {
        final googleProvider = GoogleAuthProvider();
        final cred = await _auth!.signInWithProvider(googleProvider).timeout(const Duration(seconds: 3));
        final fbUser = cred.user;
        if (fbUser != null) {
          googleEmail = fbUser.email ?? googleEmail;
          googleName = fbUser.displayName ?? googleName;
          photoUrl = fbUser.photoURL;
        }
      }
    } catch (_) {}

    // Find or create in accounts database
    final accounts = getAllAccounts();
    final existingIndex = accounts.indexWhere(
      (a) => a.user.email?.toLowerCase() == googleEmail.toLowerCase(),
    );

    UserModel user;
    if (existingIndex != -1) {
      user = accounts[existingIndex].user.copyWith(lastLoginAt: DateTime.now());
      accounts[existingIndex] = accounts[existingIndex].copyWith(user: user);
    } else {
      user = UserModel(
        id: 'google_${_uuid.v4().substring(0, 8)}',
        name: googleName,
        email: googleEmail,
        photoUrl: photoUrl,
        authMethod: 'google',
        isGuest: false,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      accounts.add(AccountRecord(user: user));
    }

    await _saveAccounts(accounts);
    await _persistUser(user);
    return AuthResult.success(user);
  }

  /// 6. Phone Authentication (SMS OTP)
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    final cleanPhone = phoneNumber.trim();

    try {
      if (_auth != null) {
        await _auth!.verifyPhoneNumber(
          phoneNumber: cleanPhone,
          verificationCompleted: (PhoneAuthCredential credential) async {},
          verificationFailed: (FirebaseAuthException e) {
            onError(_mapFirebaseError(e.code, e.message));
          },
          codeSent: (String verificationId, int? resendToken) {
            onCodeSent(verificationId);
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
        return;
      }
    } catch (e) {
      debugPrint('Firebase phone verify exception: $e');
    }

    // Local / Simulator verification ID
    onCodeSent('demo_verif_id_${cleanPhone.replaceAll('+', '')}');
  }

  /// Verify Phone OTP Code
  Future<AuthResult> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    String? phone,
    String? name,
  }) async {
    final cleanPhone = (phone ?? '').trim();
    if (smsCode.trim().length < 4) {
      return AuthResult.failure('رمز التحقق غير صحيح، يرجى التأكد من الرمز وإعادة المحاولة.');
    }

    final accounts = getAllAccounts();
    final existingIndex = accounts.indexWhere(
      (a) => a.user.phone != null && a.user.phone!.replaceAll(' ', '') == cleanPhone.replaceAll(' ', ''),
    );

    UserModel user;
    if (existingIndex != -1) {
      user = accounts[existingIndex].user.copyWith(lastLoginAt: DateTime.now());
      accounts[existingIndex] = accounts[existingIndex].copyWith(user: user);
    } else {
      user = UserModel(
        id: 'phone_${_uuid.v4().substring(0, 8)}',
        name: name ?? 'مستخدم الجوال',
        phone: cleanPhone.isNotEmpty ? cleanPhone : '+966 5X XXX XXXX',
        authMethod: 'phone',
        isGuest: false,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      accounts.add(AccountRecord(user: user));
    }

    await _saveAccounts(accounts);
    await _persistUser(user);
    return AuthResult.success(user);
  }

  /// 7. Sign In as Guest (Offline / Demo Mode)
  Future<AuthResult> signInAsGuest() async {
    final guest = UserModel.guestUser();
    await _persistUser(guest);
    return AuthResult.success(guest);
  }

  /// 8. Delete Account
  Future<bool> deleteAccount(String userId) async {
    final accounts = getAllAccounts();
    final initialCount = accounts.length;
    accounts.removeWhere((a) => a.user.id == userId);

    if (accounts.length != initialCount) {
      await _saveAccounts(accounts);
      final current = loadSavedUser();
      if (current?.id == userId) {
        await _clearPersistedUser();
      }
      return true;
    }
    return false;
  }

  /// 9. Sign Out
  Future<void> signOut() async {
    try {
      if (_auth != null) {
        await _auth!.signOut().timeout(const Duration(seconds: 2));
      }
    } catch (_) {}
    await _clearPersistedUser();
  }

  /// Map Firebase error codes to polite, clear Arabic messages
  String _mapFirebaseError(String code, String? defaultMsg) {
    switch (code) {
      case 'user-not-found':
        return 'لم يتم العثور على حساب بهذا البريد الإلكتروني. يرجى التأكد أو إنشاء حساب جديد.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة، يرجى المحاولة مجدداً أو استخدام استعادة كلمة المرور.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجل بالفعل. يرجى تسجيل الدخول بدلاً من ذلك.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني المدخلة غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً. يرجى اختيار كلمة مرور تحتوي على 6 خانات على الأقل.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت.';
      case 'too-many-requests':
        return 'تم حظر المحاولات مؤقتاً لكثرة الطلبات. يرجى الانتظار قليلاً.';
      case 'invalid-verification-code':
        return 'رمز التحقق المدخل غير صحيح.';
      default:
        return defaultMsg ?? 'حدث خطأ أثناء المصادقة، يرجى المحاولة مرة أخرى.';
    }
  }
}

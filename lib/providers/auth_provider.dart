import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/services/email_otp_service.dart';
import '../core/services/storage_service.dart';
import '../models/user_model.dart';
import 'user_profile_provider.dart';
import 'workspace_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserProfileProvider? _userProfileProvider;
  final StorageService? _storageService;
  final WorkspaceProvider? _workspaceProvider;
  final VoidCallback? _onUserChanged;
  final EmailOtpService _emailOtpService = EmailOtpService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(
    this._authService, [
    this._userProfileProvider,
    this._storageService,
    this._workspaceProvider,
    this._onUserChanged,
  ]) {
    _currentUser = _authService.loadSavedUser();
    if (_currentUser != null) {
      _storageService?.setCurrentUserId(_currentUser!.id);
      _workspaceProvider?.initForUser(_currentUser!.id);
      if (_userProfileProvider != null) {
        _userProfileProvider.initForUser(_currentUser!.id, _currentUser);
      }
      if (!_currentUser!.isGuest) {
        _storageService?.initOrMigrateUser(_currentUser!.id).then((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onUserChanged?.call();
          });
        }).catchError((e) {
          debugPrint('[AuthProvider] Startup Firestore sync notice: $e');
        });
      }
    }
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isGuest => _currentUser?.isGuest ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  EmailOtpService get emailOtpService => _emailOtpService;

  bool isEmailAlreadyRegistered(String email) =>
      _authService.findAccountByEmail(email) != null;

  Future<OtpSendResult> sendEmailOtp({
    required String email,
    required String name,
  }) async {
    return await _emailOtpService.sendOtp(
      email: email,
      userName: name,
    );
  }

  OtpVerifyResult verifyEmailOtp({
    required String email,
    required String otp,
  }) {
    return _emailOtpService.verifyOtp(
      email: email,
      inputOtp: otp,
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetLoading() {
    if (_isLoading) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _syncToProfile(UserModel user) {
    if (_userProfileProvider == null) return;
    if (!user.isGuest) {
      try {
        _userProfileProvider.initForUser(user.id, user);
      } catch (_) {}
    }
  }

  void _handleUserLoggedIn(UserModel user) {
    _currentUser = user;
    try { _storageService?.setCurrentUserId(user.id); } catch (_) {}
    try { _workspaceProvider?.initForUser(user.id); } catch (_) {}
    try { _syncToProfile(user); } catch (_) {}
    try { _onUserChanged?.call(); } catch (_) {}

    if (!user.isGuest) {
      _storageService?.initOrMigrateUser(user.id).then((_) {
        _onUserChanged?.call();
      }).catchError((e) {
        debugPrint('[AuthProvider] Login Firestore sync notice: $e');
      });
    }
  }

  Future<bool> registerWithEmail({
    required String name,
    required String email,
    required String password,
    String? profession,
    bool isEmailVerified = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
        profession: profession,
        isEmailVerified: isEmailVerified,
      );

      if (result.isSuccess && result.user != null) {
        try {
          await _storageService?.migrateGuestDataToUser(result.user!.id);
        } catch (_) {}
        _handleUserLoggedIn(result.user!);
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'فشل إنشاء الحساب';
        return false;
      }
    } catch (e, stack) {
      debugPrint('registerWithEmail exception: $e\n$stack');
      _errorMessage = 'حدث خطأ أثناء إنشاء الحساب، يرجى المحاولة مجدداً.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (result.isSuccess && result.user != null) {
        _handleUserLoggedIn(result.user!);
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'فشل تسجيل الدخول';
        return false;
      }
    } catch (e, stack) {
      debugPrint('loginWithEmail exception: $e\n$stack');
      _errorMessage = 'حدث خطأ أثناء تسجيل الدخول، يرجى التأكد من البيانات.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();
      if (result.isSuccess && result.user != null) {
        _handleUserLoggedIn(result.user!);
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'تعذر إتمام الدخول بحساب جوجل';
        return false;
      }
    } catch (e) {
      _errorMessage = 'فشل الدخول بحساب جوجل';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendPhoneOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPhoneOtp(
        phoneNumber: phone,
        onCodeSent: (vId) {
          _isLoading = false;
          notifyListeners();
          onCodeSent(vId);
        },
        onError: (err) {
          _isLoading = false;
          _errorMessage = err;
          notifyListeners();
          onError(err);
        },
      );
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل إرسال رمز التحقق';
      notifyListeners();
      onError(_errorMessage!);
    }
  }

  Future<bool> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    String? phone,
    String? name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyPhoneOtp(
        verificationId: verificationId,
        smsCode: smsCode,
        phone: phone,
        name: name,
      );

      if (result.isSuccess && result.user != null) {
        _handleUserLoggedIn(result.user!);
        return true;
      } else {
        _errorMessage = result.errorMessage ?? 'رمز التحقق غير صحيح';
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء التحقق';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginAsGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInAsGuest();
      _currentUser = result.user;
      try { _storageService?.setCurrentUserId(null); } catch (_) {}
      try { _storageService?.setCurrentWorkspaceId(null); } catch (_) {}
      try { _workspaceProvider?.initForUser('guest'); } catch (_) {}
      try { _onUserChanged?.call(); } catch (_) {}
    } catch (e) {
      _errorMessage = 'تعذر الدخول كضيف';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    return await _authService.sendPasswordReset(email);
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    return await _authService.resetPassword(
      email: email,
      newPassword: newPassword,
    );
  }

  Future<bool> deleteAccount(String userId) async {
    try {
      final success = await _authService.deleteAccount(userId);
      if (success) {
        if (_currentUser?.id == userId) {
          _currentUser = null;
          try { _storageService?.setCurrentUserId(null); } catch (_) {}
          try { _storageService?.setCurrentWorkspaceId(null); } catch (_) {}
          try { _onUserChanged?.call(); } catch (_) {}
        }
        notifyListeners();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
      try { _storageService?.setCurrentUserId(null); } catch (_) {}
      try { _storageService?.setCurrentWorkspaceId(null); } catch (_) {}
      try { _userProfileProvider?.initForUser('guest', null); } catch (_) {}
      try { _onUserChanged?.call(); } catch (_) {}
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

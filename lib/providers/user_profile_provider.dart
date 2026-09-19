import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../core/services/firestore_service.dart';

class UserProfileProvider extends ChangeNotifier {
  static const String keyProfileLegacy = 'masrofaty_user_profile';
  final SharedPreferences _prefs;

  String? _userId;
  late UserProfileModel _profile;

  void _safeNotifyListeners() {
    if (!hasListeners) return;
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks ||
        binding.schedulerPhase == SchedulerPhase.midFrameMicrotasks) {
      binding.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    } else {
      notifyListeners();
    }
  }

  UserProfileProvider(this._prefs) {
    _profile = UserProfileModel.defaultProfile();
  }

  UserProfileModel get profile => _profile;
  String? get currentUserId => _userId;

  String get _profileKey => (_userId != null && _userId!.isNotEmpty)
      ? 'masrofaty_user_profile_$_userId'
      : keyProfileLegacy;

  /// Initialize and load profile strictly isolated for a given user
  void initForUser(String userId, UserModel? user) {
    _userId = userId;
    final jsonStr = _prefs.getString(_profileKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _profile = UserProfileModel.fromJson(map);

        // If user object has newer or specific identity attributes, sync them gracefully
        if (user != null && !user.isGuest) {
          bool needsUpdate = false;
          String newName = _profile.name;
          String newEmail = _profile.email;
          String newTitle = _profile.title;
          String newPhone = _profile.phone;
          String newAvatar = _profile.avatarPath;

          // Always prefer real user name from authentication over placeholder or mismatch
          if (user.name.isNotEmpty &&
              (_profile.name == 'مستخدم مصروفاتي' ||
               _profile.name == 'عبدالله الشمري' ||
               _profile.name == 'مستخدم Google' ||
               _profile.name != user.name)) {
            newName = user.name;
            needsUpdate = true;
          }
          if (user.email != null && user.email!.isNotEmpty && _profile.email != user.email) {
            newEmail = user.email!;
            needsUpdate = true;
          }
          if (user.photoUrl != null && user.photoUrl!.isNotEmpty && _profile.avatarPath != user.photoUrl) {
            newAvatar = user.photoUrl!;
            needsUpdate = true;
          }
          if (user.profession != null && user.profession!.isNotEmpty && _profile.title == 'مستثمر طموح 🚀') {
            newTitle = user.profession!;
            needsUpdate = true;
          }
          if (user.phone != null && user.phone!.isNotEmpty && _profile.phone.isEmpty) {
            newPhone = user.phone!;
            needsUpdate = true;
          }

          if (needsUpdate) {
            _profile = _profile.copyWith(
              name: newName,
              email: newEmail,
              title: newTitle,
              phone: newPhone,
              avatarPath: newAvatar,
            );
            _saveProfile();
          }
        }
      } catch (_) {
        _profile = user != null ? UserProfileModel.fromUserModel(user) : UserProfileModel.defaultProfile();
        _saveProfile();
      }
    } else {
      // No saved profile for this user yet - create fresh dedicated profile
      _profile = user != null ? UserProfileModel.fromUserModel(user) : UserProfileModel.defaultProfile();
      _saveProfile();
    }

    _safeNotifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? title,
    String? email,
    String? phone,
    double? monthlyBudget,
    String? bio,
    String? avatarPath,
  }) async {
    _profile = _profile.copyWith(
      name: name,
      title: title,
      email: email,
      phone: phone,
      monthlyBudget: monthlyBudget,
      bio: bio,
      avatarPath: avatarPath,
    );
    await _saveProfile();
    _safeNotifyListeners();
  }

  Future<void> _saveProfile() async {
    await _prefs.setString(_profileKey, jsonEncode(_profile.toJson()));
    if (_userId != null && _userId!.isNotEmpty && _userId != 'guest') {
      try {
        FirestoreService.instance.saveProfile(_userId!, _profile);
      } catch (_) {}
    }
  }
}

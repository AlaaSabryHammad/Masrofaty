import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';

class UserProfileProvider extends ChangeNotifier {
  static const String keyProfileLegacy = 'masrofaty_user_profile';
  final SharedPreferences _prefs;

  String? _userId;
  late UserProfileModel _profile;

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

          if (user.name.isNotEmpty && (_profile.name == 'مستخدم مصروفاتي' || _profile.name == 'عبدالله الشمري')) {
            newName = user.name;
            needsUpdate = true;
          }
          if (user.email != null && user.email!.isNotEmpty && _profile.email != user.email) {
            newEmail = user.email!;
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

    notifyListeners();
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
    notifyListeners();
  }

  Future<void> _saveProfile() async {
    await _prefs.setString(_profileKey, jsonEncode(_profile.toJson()));
  }
}

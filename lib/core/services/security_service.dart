import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String keyPinEnabled = 'masrofaty_pin_enabled';
  static const String keyPinCode = 'masrofaty_pin_code';

  final SharedPreferences _prefs;
  bool _isSessionUnlocked = false;

  SecurityService(this._prefs) {
    if (!isPinEnabled) {
      _isSessionUnlocked = true;
    }
  }

  bool get isPinEnabled => _prefs.getBool(keyPinEnabled) ?? false;
  bool get isLocked => isPinEnabled && !_isSessionUnlocked;

  Future<void> setPin(String pin) async {
    await _prefs.setString(keyPinCode, pin);
    await _prefs.setBool(keyPinEnabled, true);
    _isSessionUnlocked = true;
  }

  Future<void> disablePin() async {
    await _prefs.remove(keyPinCode);
    await _prefs.setBool(keyPinEnabled, false);
    _isSessionUnlocked = true;
  }

  bool verifyPin(String enteredPin) {
    final saved = _prefs.getString(keyPinCode);
    if (saved == enteredPin) {
      _isSessionUnlocked = true;
      return true;
    }
    return false;
  }

  void lockSession() {
    if (isPinEnabled) {
      _isSessionUnlocked = false;
    }
  }
}

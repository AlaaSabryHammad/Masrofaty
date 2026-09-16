import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'user_model.dart';

class AccountRecord {
  final UserModel user;
  final String? passwordHash;
  final String? salt;

  AccountRecord({
    required this.user,
    this.passwordHash,
    this.salt,
  });

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  bool verifyPassword(String password) {
    if (passwordHash == null || salt == null) return false;
    final hash = hashPassword(password, salt!);
    return hash == passwordHash;
  }

  AccountRecord copyWith({
    UserModel? user,
    String? passwordHash,
    String? salt,
  }) {
    return AccountRecord(
      user: user ?? this.user,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
    );
  }

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'passwordHash': passwordHash,
    'salt': salt,
  };

  factory AccountRecord.fromJson(Map<String, dynamic> json) => AccountRecord(
    user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    passwordHash: json['passwordHash'] as String?,
    salt: json['salt'] as String?,
  );
}

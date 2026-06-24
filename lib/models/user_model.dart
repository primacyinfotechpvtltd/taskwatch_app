import 'dart:convert';

class UserModel {
  final int userId;
  final String name;
  final String email;
  final String token;
  final String? imageUrl;
  final Map<String, dynamic> json;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.token,
    required this.imageUrl,
    required this.json,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'],
      name: json['name'],
      email: json['email'],
      token: json['token'],
      imageUrl: json['image_url'],
      json: json,
    );
  }

  @override
  String toString() {
    return jsonEncode(json);
  }
}
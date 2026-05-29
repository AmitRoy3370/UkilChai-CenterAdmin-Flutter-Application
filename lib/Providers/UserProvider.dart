// lib/Providers/UserProvider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/BaseURL.dart' as BASE_URL;

class UserProvider extends ChangeNotifier {
  String? _userId;
  String? _userName;
  bool _isLoading = false;

  String? get userId => _userId;
  String? get userName => _userName;
  bool get isLoading => _isLoading;

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final token = prefs.getString('jwt_token');

    if (userId != null && token != null && userId.isNotEmpty) {
      _userId = userId;
      await fetchUserData(token, userId);
    } else {
      _userId = null;
      _userName = null;
      notifyListeners();
    }
  }

  Future<void> fetchUserData(String token, String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}user/$userId"),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _userName = data['name'] ?? "User";
        _userId = userId;
      } else {
        _userName = null;
        _userId = null;
      }
    } catch (e) {
      print('Error fetching user data: $e');
      _userName = null;
      _userId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('userId');
    _userId = null;
    _userName = null;
    notifyListeners();
  }

  Future<void> refreshAfterLogin() async {
    await loadUserData();
  }
}
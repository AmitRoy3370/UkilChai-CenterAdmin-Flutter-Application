import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import './Admin.dart';

class AdminService {
  static String baseUrl =
      "${BASE_URL.Urls().baseURL}admin";

  // 🔐 Get JWT token
  Future<String> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token") ?? "";
  }

  // ================= GET ALL ADMINS =================
  Future<List<Admin>> getAll() async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse("$baseUrl/all"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      List list = jsonDecode(res.body);
      return list.map((e) => Admin.fromJson(e)).toList();
    }

    throw Exception(res.body);
  }

  // ================= FIND BY USER ID =================
  Future<Admin> findByUserId(String userId) async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse("$baseUrl/by-user/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      return Admin.fromJson(jsonDecode(res.body));
    }

    throw Exception(res.body);
  }

  // ================= FIND BY SPECIALITY =================
  Future<List<Admin>> findBySpeciality(String speciality) async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse("$baseUrl/by-speciality/$speciality"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      List list = jsonDecode(res.body);
      return list.map((e) => Admin.fromJson(e)).toList();
    }

    throw Exception(res.body);
  }

  // ================= ❌ DELETE ADMIN =================
  Future<void> deleteAdmin(String adminId, String userId) async {
    final token = await _getToken();

    final res = await http.delete(
      Uri.parse("$baseUrl/delete/$adminId/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }
}

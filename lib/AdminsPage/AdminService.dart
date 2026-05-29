import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import 'AdminDTO.dart';

class AdminService {
  static String baseUrl = "${BASE_URL.Urls().baseURL}admin";

  // 🔐 Get JWT token
  Future<String> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token") ?? "";
  }

  // ================= GET ALL ADMINS =================
  Future<List<AdminDTO>> getAll() async {
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
      return list.map((e) => AdminDTO.fromJson(e)).toList();
    }

    throw Exception(res.body);
  }

  // ================= FIND BY USER ID =================
  Future<AdminDTO> findByUserId(String userId) async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse("$baseUrl/by-user/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      return AdminDTO.fromJson(jsonDecode(res.body));
    }

    throw Exception(res.body);
  }

  // ================= FIND BY SPECIALITY =================
  Future<List<AdminDTO>> findBySpeciality(String speciality) async {
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
      return list.map((e) => AdminDTO.fromJson(e)).toList();
    }

    throw Exception(res.body);
  }

  // ================= ADD ADMIN =================
  Future<Map<String, dynamic>> addAdmin(Map<String, dynamic> adminData, String userId) async {
    final token = await _getToken();

    final res = await http.post(
      Uri.parse("$baseUrl/add/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(adminData),
    );

    if (res.statusCode == 201) {
      return {
        'success': true,
        'data': jsonDecode(res.body),
        'message': 'Admin added successfully'
      };
    }

    return {
      'success': false,
      'message': res.body,
    };
  }

  // ================= UPDATE ADMIN =================
  Future<Map<String, dynamic>> updateAdmin(
    Map<String, dynamic> adminData,
    String adminId,
    String userId,
  ) async {
    final token = await _getToken();

    final res = await http.put(
      Uri.parse("$baseUrl/update/$adminId/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(adminData),
    );

    if (res.statusCode == 200) {
      return {
        'success': true,
        'data': jsonDecode(res.body),
        'message': 'Admin updated successfully'
      };
    }

    return {
      'success': false,
      'message': res.body,
    };
  }

  // ================= DELETE ADMIN =================
  Future<Map<String, dynamic>> deleteAdmin(String adminId, String userId) async {
    final token = await _getToken();

    final res = await http.delete(
      Uri.parse("$baseUrl/delete/$adminId/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      return {
        'success': true,
        'message': jsonDecode(res.body),
      };
    }

    return {
      'success': false,
      'message': res.body,
    };
  }

  // ================= HELPER: Get Admin Full Name =================
  Future<String> getAdminName(String adminId) async {
    try {
      // If you have a method to get admin by ID, use it here
      // For now, we'll fetch all admins and find by ID
      final admins = await getAll();
      final admin = admins.firstWhere(
        (a) => a.id == adminId,
        orElse: () => throw Exception('Admin not found'),
      );
      return admin.userName;
    } catch (e) {
      return "Unknown Admin";
    }
  }
}
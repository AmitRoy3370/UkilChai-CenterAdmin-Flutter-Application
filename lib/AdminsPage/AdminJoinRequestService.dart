import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/AuthService.dart';
import './AdminJoinRequest.dart';
import './AdminJoinRequestDTO.dart';
import '../Utils/BaseURL.dart' as BASE_URL;

class AdminJoinRequestService {
  static String baseUrl =
      "${BASE_URL.Urls().baseURL}adminJoinRequest";

  final token = AuthService.getToken();

  // ---------- GET ALL ----------
  Future<List<AdminJoinRequestDTO>> getAll() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";

    final res = await http.get(
        Uri.parse("$baseUrl/all"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        }
    );

    if (res.statusCode == 200) {

      print("res.body : ${res.body}");

      List list = jsonDecode(res.body);

      print("list : ${list.length}");

      return list.map((e) => AdminJoinRequestDTO.fromJson(e)).toList();
    }
    throw Exception(res.body);
  }

  // ---------- FIND BY USER ID ----------
  Future<AdminJoinRequestDTO> findByUserId(String userName) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";

    final userIdFindingUrl = Uri.parse("${BASE_URL.Urls().baseURL}user/find/name/$userName");

    final userFindingResponse = await http.get(
      userIdFindingUrl,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if(userFindingResponse.statusCode != 200) {

      throw Exception();

    }

    final userId = jsonDecode(userFindingResponse.body)["id"];

    final res =
    await http.get(
        Uri.parse("$baseUrl/findByUser/$userId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        }
    );

    if (res.statusCode == 200) {
      return AdminJoinRequestDTO.fromJson(jsonDecode(res.body));
    }
    throw Exception(res.body);
  }

  // ---------- SEARCH BY SPECIALITY ----------
  Future<List<AdminJoinRequestDTO>> searchBySpeciality(
      String speciality) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";

    final res =
    await http.get(
        Uri.parse("$baseUrl/search/$speciality"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        }
    );

    if (res.statusCode == 200) {
      List list = jsonDecode(res.body);
      return list.map((e) => AdminJoinRequestDTO.fromJson(e)).toList();
    }
    throw Exception(res.body);
  }

  // ---------- HANDLE JOIN REQUEST (FIXED) ----------
  Future<void> handleJoinRequest(
      String adminJoinRequestId,
      String userId,
      String response,
      ) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";

    print("Sending request to: $baseUrl/handle/$adminJoinRequestId/$userId/$response");
    print("AdminJoinRequestId: $adminJoinRequestId");
    print("UserId: $userId");
    print("Response: $response");

    final res = await http.post(
      Uri.parse(
        "$baseUrl/handle/$adminJoinRequestId/$userId/$response",
      ),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("Response status code: ${res.statusCode}");
    print("Response body: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }


  // ---------- DELETE ----------
  Future<void> delete(String adminId, String userId) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";

    final res = await http
        .delete(Uri.parse("$baseUrl/delete/$adminId/$userId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        }
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }
}
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import './Admin.dart';
import './AdvocateSpeciality.dart';

class AdminDetailsPage extends StatefulWidget {
  final Admin admin;

  const AdminDetailsPage({super.key, required this.admin});

  @override
  State<AdminDetailsPage> createState() => _AdminDetailsPageState();
}

class _AdminDetailsPageState extends State<AdminDetailsPage> {
  Map<String, dynamic>? user;
  Map<String, dynamic>? contactInfo;
  Map<String, dynamic>? location;

  bool isHisAdmin = false;
  bool loading = true;
  Uint8List? imageBytes;

  @override
  void initState() {
    super.initState();
    fetchAllDetails();
    isDeletableAdmin();
  }

  Future<void> deleteAdmin() async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();

    final deleteAdminUri = Uri.parse(
      "${BASE_URL.Urls().baseURL}admin/delete/${widget.admin.id}/$userId",
    );

    final deleteAdminResponse = await http.delete(
      deleteAdminUri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (deleteAdminResponse.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Admin deleted successfully")),
      );

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to delete admin")));
    }
  }

  Future<void> isDeletableAdmin() async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();

    if (token == null || userId == null) return;

    final centerAdminUri = Uri.parse(
      "${BASE_URL.Urls().baseURL}center-admin/by-user/$userId",
    );

    final centerAdminResponse = await http.get(
      centerAdminUri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (centerAdminResponse.statusCode == 200) {
      final centerAdminData = jsonDecode(centerAdminResponse.body);

      if (centerAdminData["admins"].contains(widget.admin.id)) {
        isHisAdmin = true;
      } else {
        isHisAdmin = false;
      }
    } else {
      isHisAdmin = false;
    }
  }

  // ================= LOAD PROFILE IMAGE =================
  Future<void> loadProfileImage(String profileImageId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || profileImageId.isEmpty) return;

      final url = "${BASE_URL.Urls().baseURL}user/download/$profileImageId";

      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token", "Accept": "image/*"},
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        setState(() => imageBytes = response.bodyBytes);
      }
    } catch (e) {
      debugPrint("Image load error: $e");
    }
  }

  // ================= FETCH ALL DETAILS =================
  Future<void> fetchAllDetails() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token") ?? "";

    try {
      // 1️⃣ USER INFO
      final userRes = await http.get(
        Uri.parse(
          "${BASE_URL.Urls().baseURL}user/search?userId=${widget.admin.userId}",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (userRes.statusCode == 200) {
        user = jsonDecode(userRes.body);

        final profileImageId = user?["profileImageId"];
        if (profileImageId != null && profileImageId.toString().isNotEmpty) {
          await loadProfileImage(profileImageId.toString());
        }
      }

      // 2️⃣ CONTACT INFO (SINGLE OBJECT)
      final contactRes = await http.get(
        Uri.parse(
          "${BASE_URL.Urls().baseURL}user/contact-info/user?userId=${widget.admin.userId}",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (contactRes.statusCode == 200 && contactRes.body.isNotEmpty) {
        contactInfo = jsonDecode(contactRes.body);
      }

      // 3️⃣ LOCATION (SINGLE OBJECT)
      final locRes = await http.get(
        Uri.parse(
          "${BASE_URL.Urls().baseURL}userLocation/findByUserId/${widget.admin.userId}",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (locRes.statusCode == 200 && locRes.body.isNotEmpty) {
        location = jsonDecode(locRes.body);
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    }

    setState(() => loading = false);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Details")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== USER INFO =====
                  Text(
                    "User Info",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: imageBytes != null
                            ? MemoryImage(imageBytes!)
                            : null,
                        child: imageBytes == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Name: ${user?["name"] ?? "N/A"}"),
                          Text("User ID: ${widget.admin.userId}"),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // ===== SPECIALITIES =====
                  Text(
                    "Specialities",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: widget.admin.advocateSpeciality
                        .map((e) => Chip(label: Text(specialityLabel(e))))
                        .toList(),
                  ),

                  const Divider(height: 24),

                  // ===== CONTACT INFO =====
                  Text(
                    "Contact Info",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  contactInfo != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Email: ${contactInfo!["email"] ?? "N/A"}"),
                            Text("Phone: ${contactInfo!["phone"] ?? "N/A"}"),
                          ],
                        )
                      : const Text("No contact info found"),

                  const Divider(height: 24),

                  // ===== LOCATION =====
                  Text(
                    "Location",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  location != null
                      ? ListTile(
                          title: Text(location!["locationName"] ?? "No name"),
                          subtitle: Text(
                            "Lat: ${location!["lattitude"]}, Long: ${location!["longitude"]}",
                          ),
                        )
                      : const Text("No location found"),
                  const Divider(height: 32),

                  if (isHisAdmin)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete Admin"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Confirm Delete"),
                              content: const Text(
                                "Are you sure you want to delete this admin? This action cannot be undone.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await deleteAdmin();
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

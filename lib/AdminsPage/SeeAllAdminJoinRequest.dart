import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/AuthService.dart';
import './AdminJoinRequestDTO.dart';
import './AdminJoinRequestService.dart';
import '../Utils/AdvocateSpeciality.dart';
import '../Utils/BaseURL.dart' as BASE_URL;

class AdminJoinRequestPage extends StatefulWidget {
  const AdminJoinRequestPage({super.key});

  @override
  State<AdminJoinRequestPage> createState() => _AdminJoinRequestPageState();
}

class _AdminJoinRequestPageState extends State<AdminJoinRequestPage> {
  final service = AdminJoinRequestService();
  List<AdminJoinRequestDTO> list = [];
  bool loading = true;

  AdvocateSpeciality? selectedSpeciality;
  final TextEditingController userIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    try {
      list = await service.getAll();
    } catch (e) {
      print("Error loading all: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading requests: $e")),
        );
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<String> _getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("userId") ?? "";
  }

  Future<void> searchByUser() async {
    if (userIdCtrl.text.isEmpty) return;
    setState(() => loading = true);
    try {
      final result = await service.findByUserId(userIdCtrl.text.trim());
      list = [result];
    } catch (e) {
      print("Error searching user: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found")),
        );
      }
      list = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> searchBySpeciality(String speciality) async {
    setState(() => loading = true);
    try {
      list = await service.searchBySpeciality(speciality);
    } catch (e) {
      print("Error searching speciality: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error searching speciality")),
        );
      }
      list = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<String?> getName(String userId) async {
    print("userId in getName :- $userId");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";

    final nameResponse = await http.get(
      Uri.parse("${BASE_URL.Urls().baseURL}user/search?userId=$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("name status :- ${nameResponse.statusCode}");

    if (nameResponse.statusCode == 200) {
      final name = jsonDecode(nameResponse.body)["name"];
      print("name :- $name");
      return name;
    }

    return null;
  }

  Future<void> handleRequest(String id, String userId, String response) async {
    try {
      await service.handleJoinRequest(id, userId, response);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request $response successfully")),
        );
      }
      await loadAll();
    } catch (e) {
      print("Error handling request: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to $response request: $e")),
        );
      }
    }
  }

  Future<void> deleteRequest(String id, String userId) async {
    try {
      await service.delete(id, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request deleted successfully")),
        );
      }
      await loadAll();
    } catch (e) {
      print("Error deleting request: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete request: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Admin Join Requests",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: loadAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // -------- USER ID SEARCH --------
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: userIdCtrl,
              style: GoogleFonts.inter(color: Colors.grey[800]),
              decoration: InputDecoration(
                hintText: "Search by User ID",
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.deepPurple.shade600),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[400]),
                  onPressed: () {
                    userIdCtrl.clear();
                    loadAll();
                  },
                ),
              ),
              onSubmitted: (value) => searchByUser(),
            ),
          ),

          // -------- SPECIALITY DROPDOWN --------
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<AdvocateSpeciality>(
                hint: Text(
                  "Search by Speciality",
                  style: GoogleFonts.inter(color: Colors.grey[600]),
                ),
                value: selectedSpeciality,
                isExpanded: true,
                items: AdvocateSpeciality.values.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.label,
                      style: GoogleFonts.inter(color: Colors.grey[800]),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedSpeciality = value;
                    });
                    searchBySpeciality(value.name);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // -------- LIST --------
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No join requests found",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final r = list[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.deepPurple.shade100,
                                    child: Text(
                                      r.userName.isNotEmpty
                                          ? r.userName[0].toUpperCase()
                                          : "U",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // User Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.userName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "User ID: ${r.userId.substring(0, 8)}...",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (r.id != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            "Request ID: ${r.id!.substring(0, 8)}...",
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Action Buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // ACCEPT BUTTON
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.check_circle, color: Colors.green.shade700),
                                          tooltip: "Accept",
                                          onPressed: () async {
                                            await handleRequest(r.id!, await _getUserId(), "ACCEPT");
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // REJECT BUTTON
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.cancel, color: Colors.orange.shade700),
                                          tooltip: "Reject",
                                          onPressed: () async {
                                            await handleRequest(r.id!, await _getUserId(), "REJECT");
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // DELETE BUTTON
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.delete, color: Colors.red.shade700),
                                          tooltip: "Delete",
                                          onPressed: () async {
                                            await deleteRequest(r.id!, await _getUserId());
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Specialities
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Legal Specialities",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: r.advocateSpeciality.map((e) {
                                      return Chip(
                                        label: Text(
                                          e.label,
                                          style: GoogleFonts.inter(fontSize: 11),
                                        ),
                                        backgroundColor: Colors.deepPurple.shade50,
                                        labelStyle: TextStyle(color: Colors.deepPurple.shade700),
                                        avatar: Icon(e.icon, size: 14, color: Colors.deepPurple.shade600),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
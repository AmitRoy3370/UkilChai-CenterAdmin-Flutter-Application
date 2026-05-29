import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import 'AdminDTO.dart';
import '../Utils/AdvocateSpeciality.dart';
import '../ChatRelatedPages/chat_screen.dart';

class AdminDetailsPage extends StatefulWidget {
  final AdminDTO admin;

  const AdminDetailsPage({super.key, required this.admin});

  @override
  State<AdminDetailsPage> createState() => _AdminDetailsPageState();
}

class _AdminDetailsPageState extends State<AdminDetailsPage> {
  Map<String, dynamic>? user;
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
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete admin")),
      );
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
      
      if (centerAdminData["admins"] != null && 
          centerAdminData["admins"].contains(widget.admin.id)) {
        isHisAdmin = true;
      } else {
        isHisAdmin = false;
      }
    } else {
      isHisAdmin = false;
    }
    
    if (mounted) setState(() {});
  }

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
        if (mounted) {
          setState(() => imageBytes = response.bodyBytes);
        }
      }
    } catch (e) {
      debugPrint("Image load error: $e");
    }
  }

  Future<void> fetchAllDetails() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token") ?? "";

    try {
      if (widget.admin.profileImageId != null && widget.admin.profileImageId!.isNotEmpty) {
        await loadProfileImage(widget.admin.profileImageId!);
      }

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
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  void _startChat() async {
    // TODO: Implement chat functionality
    // You can navigate to a chat page with this admin
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Starting chat with ${widget.admin.userName}..."),
        behavior: SnackBarBehavior.floating,
      ),
    );
   
    final userId = await _getUserId();
    final userName = await getName(userId);

    final otherUserId = widget.admin.userId;
    final otherUserName = widget.admin.userName;

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUser: otherUserId,
            othersName: otherUserName,
            myName: userName,
            currentUser: userId,
          ),
        ),
      );

  }
  
  Future<String> _getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("userId") ?? "";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Admin Details",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== PROFILE HEADER CARD =====
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A237E), Color(0xFF283593)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A237E).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundImage: imageBytes != null
                                ? MemoryImage(imageBytes!)
                                : null,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: imageBytes == null
                                ? Text(
                                    widget.admin.userName.isNotEmpty
                                        ? widget.admin.userName[0].toUpperCase()
                                        : "A",
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.admin.userName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Admin ID: ${widget.admin.id.substring(0, 8)}...",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "User ID: ${widget.admin.userId.substring(0, 8)}...",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ===== ADMIN INFORMATION CARD =====
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.admin_panel_settings, color: Colors.deepPurple.shade600, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Admin Information",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            icon: Icons.badge,
                            label: "Admin Name",
                            value: widget.admin.userName,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            icon: Icons.qr_code,
                            label: "Admin ID",
                            value: widget.admin.id,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            icon: Icons.person,
                            label: "User ID",
                            value: widget.admin.userId,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            icon: Icons.image,
                            label: "Profile Image ID",
                            value: widget.admin.profileImageId ?? "Not provided",
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ===== SPECIALITIES CARD =====
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.star, color: Colors.deepPurple.shade600, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Legal Specialities",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (widget.admin.advocateSpeciality.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  "No specialities assigned",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.admin.advocateSpeciality
                                  .map((e) => Chip(
                                        label: Text(
                                          e.label,
                                          style: GoogleFonts.inter(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.deepPurple.shade50,
                                        labelStyle: TextStyle(color: Colors.deepPurple.shade700),
                                        avatar: Icon(e.icon, size: 16, color: Colors.deepPurple.shade600),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ===== USER DETAILS CARD (from User API) =====
                  if (user != null)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.person_outline, color: Colors.deepPurple.shade600, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "User Account Details",
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              icon: Icons.badge,
                              label: "Full Name",
                              value: user?["name"] ?? "Not provided",
                            ),
                            if (user?["email"] != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                icon: Icons.email,
                                label: "Email",
                                value: user?["email"] ?? "Not provided",
                              ),
                            ],
                            if (user?["phone"] != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                icon: Icons.phone,
                                label: "Phone",
                                value: user?["phone"] ?? "Not provided",
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ===== CHAT BUTTON =====
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(
                        "Chat with ${widget.admin.userName.split(' ')[0]}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _startChat,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ===== DELETE BUTTON =====
                  if (isHisAdmin)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text(
                          "Delete Admin",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.grey.shade900,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: Text(
                                "Confirm Delete",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: Text(
                                "Are you sure you want to delete this admin? This action cannot be undone.",
                                style: GoogleFonts.inter(color: Colors.grey.shade300),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(
                                    "Cancel",
                                    style: GoogleFonts.inter(color: Colors.grey.shade400),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Delete"),
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Colors.deepPurple.shade600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
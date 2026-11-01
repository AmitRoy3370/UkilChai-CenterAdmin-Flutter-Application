import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as NavigatorPageRoute;
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';

import '../AdvocatePages/AdvocateDetailsModel.dart';
import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as baseURL;

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'dart:convert';

import '../CaseRelatedPages/AddCaseRequestPage.dart';
import '../CaseRelatedPages/case_model.dart';
import '../ChatRelatedPages/chat_screen.dart';
import '../PostRelatedPages/AdvocatePost.dart';
import '../PostRelatedPages/PostService.dart';
import '../PostRelatedPages/post_card.dart';
import '../PostRelatedPages/post_response.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import 'advocate_join_request.dart';
import 'advocate_join_request_dto_model.dart';
import 'advocate_join_request_service.dart';
import '../CaseRelatedPages/AttachmentViewer.dart'; // 👈 Import the viewer

class AdvocateJoinRequestDetails extends StatefulWidget {
  final AdvocateJoinRequestDTO advocateDetailsModel;

  const AdvocateJoinRequestDetails({
    super.key,
    required this.advocateDetailsModel,
  });

  @override
  State<AdvocateJoinRequestDetails> createState() =>
      AdvocateJoinRequestDetailsState();
}

class AdvocateJoinRequestDetailsState
    extends State<AdvocateJoinRequestDetails> {
  int totalCases = 0;
  bool loading = true;
  List<PostResponse> posts = [];

  double averageRating = 0.0;
  int totalRatings = 0;
  int highestRating = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    //fetchTotalCases();
    //loadPosts();
    //fetchRatings();
  }

  Future<void> fetchRatings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final response = await http.get(
      Uri.parse(
        "${BASE_URL.Urls().baseURL}advocate-rating/advocate/${widget.advocateDetailsModel.id}",
      ),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      List data = [];

      if (decoded is List) {
        data = decoded;
      } else if (decoded["data"] != null) {
        data = decoded["data"];
      }

      if (data.isEmpty) return;

      int sum = 0;
      int maxRating = 0;

      for (var r in data) {
        int rating = r["rating"] ?? 0;
        sum += rating;
        if (rating > maxRating) maxRating = rating;
      }

      setState(() {
        totalRatings = data.length;
        averageRating = sum / data.length;
        highestRating = maxRating;
      });
    }
  }

  Future<List?> fetchTotalCases() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    print("advocate id :- ${widget.advocateDetailsModel.id}");

    final response = await http.get(
      Uri.parse(
        "${baseURL.Urls().baseURL}case/advocate/${widget.advocateDetailsModel.id}",
      ),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return decoded.map((e) => CaseModel.fromJson(e)).toList();
      }

      if (decoded["data"] != null) {
        var list = (decoded["data"] as List)
            .map((e) => CaseModel.fromJson(e))
            .toList();

        setState(() {
          totalCases = list.length;
        });

        return list;
      }

      return [];
    }
    return null;
  }

  Future<void> loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final data = await PostService.fetchSpecificAdvocatesPosts(
      widget.advocateDetailsModel.id,
      token,
    );
    setState(() {
      posts = data;
      loading = false;
    });
  }

  /// ================= PROFILE IMAGE =================
  Future<Uint8List?> fetchProfileImage() async {
    final imageId = widget.advocateDetailsModel.profileImageId;
    if (imageId == null || imageId.isEmpty) return null;

    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}user/download/$imageId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  /// ================= CV FETCH =================
  Future<Uint8List?> fetchCv() async {
    final token = await AuthService.getToken();
    final userId = widget.advocateDetailsModel.userId;

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}advocate/cv/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  // ---------------- GET USER NAME ----------------
  Future<String> getNameFromUser(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final url = "${BASE_URL.Urls().baseURL}user/search?userId=$userId";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "content-type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body["name"] ?? "";
    }
    return "";
  }

  void downloadPdfWeb(List<int> bytes) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "file.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> downloadPdfMobile(List<int> bytes) async {
    final dir = await getTemporaryDirectory();

    final file = File('${dir.path}/advocate_cv.pdf');

    await file.writeAsBytes(bytes, flush: true);

    await OpenFilex.open(file.path);
  }

  /// ================= OPEN CV =================
  Future<void> downloadAndOpenCV() async {
    final token = await AuthService.getToken();
    final userId = widget.advocateDetailsModel.userId;

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}advocateJoinRequest/cv/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No CV available")));
      return;
    }

    final bytes = response.bodyBytes;

    // 🌐 WEB
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute("download", "advocate_cv.pdf")
        ..click();

      html.Url.revokeObjectUrl(url);
      return;
    }

    // 📱 MOBILE
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/advocate_cv.pdf');

    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD — Admin panel design (Deny only)
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Advocate Details"),
        backgroundColor: Colors.white70,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// ================= PROFILE =================
            Center(
              child: Column(
                children: [
                  FutureBuilder<Uint8List?>(
                    future: fetchProfileImage(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircleAvatar(
                          radius: 55,
                          child: Icon(Icons.person, size: 55),
                        );
                      }

                      return CircleAvatar(
                        radius: 55,
                        backgroundImage: MemoryImage(snapshot.data!),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Personal Info
                  _buildSectionTitle("Personal Information"),
                  _buildCard([
                    _buildRow(
                      "Name",
                      widget.advocateDetailsModel.userName ?? 'N/A',
                    ),
                    _buildRow(
                      "Full Name",
                      widget.advocateDetailsModel.fullName ?? 'N/A',
                    ),
                    _buildRow(
                      "Email",
                      widget.advocateDetailsModel.email ?? 'N/A',
                    ),
                    _buildRow(
                      "Phone",
                      widget.advocateDetailsModel.phone ?? 'N/A',
                    ),
                    _buildRow(
                      "District",
                      widget.advocateDetailsModel.district ?? 'N/A',
                    ),
                    _buildRow(
                      "Location",
                      widget.advocateDetailsModel.locationName ?? 'N/A',
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Advocate Info
                  _buildSectionTitle("Advocate Information"),
                  _buildCard([
                    _buildRow(
                      "Specialities",
                      widget.advocateDetailsModel.advocateSpeciality.join(', '),
                    ),
                    _buildRow(
                      "Experience",
                      "${widget.advocateDetailsModel.experience} years",
                    ),
                    _buildRow(
                      "License Key",
                      widget.advocateDetailsModel.licenseKey ?? 'N/A',
                    ),
                    _buildRow(
                      "Degrees",
                      widget.advocateDetailsModel.degrees.join(', '),
                    ),
                    _buildRow(
                      "Working Exp. Summary",
                      widget.advocateDetailsModel.workingExperiences.join(', '),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Working Experience Details
                  if (widget.advocateDetailsModel.workingExperience !=
                      null) ...[
                    _buildSectionTitle("Working Experience Details"),
                    _buildCard([
                      _buildRow(
                        "Bar Association",
                        widget
                                .advocateDetailsModel
                                .workingExperience!
                                .barAssociation ??
                            'N/A',
                      ),
                      _buildRow(
                        "Enrolment",
                        widget
                                .advocateDetailsModel
                                .workingExperience!
                                .barControllEnrolment ??
                            'N/A',
                      ),
                      _buildRow(
                        "Primary Practice",
                        widget
                                .advocateDetailsModel
                                .workingExperience!
                                .primaryPractice ??
                            'N/A',
                      ),
                      _buildRow(
                        "Current Chamber",
                        widget
                            .advocateDetailsModel
                            .workingExperience!
                            .currentChemberName,
                      ),
                      _buildRow(
                        "Practice Years",
                        "${widget.advocateDetailsModel.workingExperience!.yearOfLegalPractice}",
                      ),
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // Additional Info
                  if (widget.advocateDetailsModel.additionalInfo != null) ...[
                    _buildSectionTitle("Additional Information"),
                    _buildCard([
                      _buildRow(
                        "NID Number",
                        widget.advocateDetailsModel.additionalInfo!.nidNumber ??
                            'N/A',
                      ),
                      _buildRow(
                        "Address",
                        widget
                                .advocateDetailsModel
                                .additionalInfo!
                                .parmanentAdress ??
                            'N/A',
                      ),
                      _buildRow(
                        "City",
                        widget
                                .advocateDetailsModel
                                .additionalInfo!
                                .cityOfUpozila ??
                            'N/A',
                      ),
                      _buildRow(
                        "WhatsApp",
                        widget
                                .advocateDetailsModel
                                .additionalInfo!
                                .whatsAppNumber ??
                            'N/A',
                      ),
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // Documents
                  if (widget.advocateDetailsModel.documents != null &&
                      widget
                          .advocateDetailsModel
                          .documents!
                          .attachments
                          .isNotEmpty) ...[
                    _buildSectionTitle("Uploaded Documents"),
                    _buildCard([
                      for (var doc
                          in widget.advocateDetailsModel.documents!.attachments)
                        InkWell(
                          onTap: () async {
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            final token = prefs.getString('jwt_token') ?? '';
                            final userId = prefs.getString('userId') ?? '';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  backgroundColor: Colors.black,
                                  appBar: AppBar(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    title: const Text("Document Viewer"),
                                  ),
                                  // 👈 Using the CaseAttachmentView widget here
                                  body: CaseAttachmentView(
                                    attachmentId: doc,
                                    jwtToken: token,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.attach_file,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    doc,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ]),
                  ],

                  const SizedBox(height: 30),

                  if (widget.advocateDetailsModel.cvHexKey != null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () async {
                        await downloadAndOpenCV();
                      },
                      child: Text(
                        "Download cv",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () async {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      final token = prefs.getString('jwt_token') ?? '';
                      final userId = prefs.getString('userId') ?? '';
                      final myName = await getNameFromUser(userId);

                      Navigator.push(
                        context,
                        NavigatorPageRoute.MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUser: widget.advocateDetailsModel.userId ?? '',
                            othersName:
                                widget.advocateDetailsModel.fullName ??
                                widget.advocateDetailsModel.userName ??
                                '',
                            currentUser: userId,
                            myName: myName ?? '',
                          ),
                        ),
                      );
                    },
                    child: Text(
                      "Chat with ${widget.advocateDetailsModel.fullName ?? widget.advocateDetailsModel.userName}",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildResponseSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= UI HELPERS =================
  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value ?? "Not available",
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listSection(String title, List<String> items) {
    return _section(
      title,
      items.isEmpty
          ? [
              const Text(
                "No data available",
                style: TextStyle(color: Colors.red),
              ),
            ]
          : items.map((e) => _row(Icons.check_circle, e)).toList(),
    );
  }

  Widget buildStarRating(double rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 22);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 22);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 22);
        }
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DENY ROW  (center admin keeps Deny only)
  // ═══════════════════════════════════════════════════════════════════
  Widget buildResponseSection() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token') ?? '';
          final userId = prefs.getString('userId') ?? '';

          final response = await http.delete(
            Uri.parse(
              "${BASE_URL.Urls().baseURL}advocateJoinRequest/delete/${widget.advocateDetailsModel.id}?userId=$userId",
            ),
            headers: {"Authorization": "Bearer $token"},
          );

          if (response.statusCode == 200) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Request removed")),
            );

            // ✅ Return `true` so the list page knows to refresh.
            Navigator.pop(context, true);
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Request not removed")),
            );
          }
        },
        icon: const Icon(Icons.cancel, color: Colors.white, size: 20),
        label: const Text(
          "Deny",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
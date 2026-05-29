import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'SeeAllCases.dart';
import 'case_judgment_service.dart';
import 'CaseJudgmentModel.dart';
import './AppealCasePage.dart';
import './case_model.dart';
import 'package:advocatechaicenteradmin/Utils/BaseURL.dart' as BASE_URL;
import 'package:advocatechaicenteradmin/Auth/AuthService.dart';
import '../CaseRelatedPages/CaseHomePage.dart';
import 'AttachmentViewer.dart';
import 'case_tracking.dart';
import '../PageTransition.dart';

class CaseDetailsPage extends StatefulWidget {
  final CaseModel caseModel;
  final String? userId;
  final VoidCallback? onDeleted;

  const CaseDetailsPage({
    super.key,
    required this.caseModel,
    this.userId,
    this.onDeleted,
  });

  @override
  State<CaseDetailsPage> createState() => _CaseDetailsPageState();
}

class _CaseDetailsPageState extends State<CaseDetailsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isDeleting = false;
  bool isOwner = false;

  final String baseUrl = "${BASE_URL.Urls().baseURL}case";
  final List<PageTransitionType> _transitionTypes = AnimatedRoute.getCompanySafeAnimations();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  PageTransitionType _getRandomTransition() {
    final random = Random().nextInt(_transitionTypes.length);
    return _transitionTypes[random];
  }

  void _navigateWithRandomTransition(BuildContext context, Widget page) {
    NavigationHelper.push(
      context,
      page,
      transitionType: _getRandomTransition(),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> openAttachment(String attachmentId, {bool view = false}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final jwtToken = prefs.getString('jwt_token') ?? '';

    final url = Uri.parse(
      '${BASE_URL.Urls().baseURL}case/attachment/$attachmentId',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $jwtToken'},
    );

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$attachmentId');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    } else {
      throw Exception('Failed to download attachment: ${response.statusCode}');
    }
  }

  Future<CaseJudgment?> loadJudgment() {
    return CaseJudgmentService.getByCase(widget.caseModel.id);
  }

  Future<bool> isMyCase() async {
    final prefs = await SharedPreferences.getInstance();
    final myUserId = prefs.getString('userId');
    final token = prefs.getString('jwt_token');

    final centerAdminResponse = await http.get(
      Uri.parse("${BASE_URL.Urls().baseURL}center-admin/by-user/$myUserId"),
      headers: {
        "content-type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    bool isCenterAdmin = false;

    if (centerAdminResponse.statusCode == 200) {
      final body = jsonDecode(centerAdminResponse.body);
      final advocates = body["advocates"];

      if (advocates is List &&
          advocates.isNotEmpty &&
          advocates.contains(widget.caseModel.advocateId)) {
        isCenterAdmin = true;
      }
    }

    return myUserId != null && (myUserId == widget.caseModel.userId || isCenterAdmin);
  }

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

  Future<String> getNameFromAdvocate(String advocateId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final url = "${BASE_URL.Urls().baseURL}advocate/$advocateId";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "content-type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final userId = body["userId"];
      return getNameFromUser(userId);
    }
    return "";
  }

  Future<bool> deleteCase(BuildContext context) async {
    final url = "$baseUrl/${widget.caseModel.id}/${widget.caseModel.userId}";
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          "content-type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Case deleted successfully")),
        );
        return true;
      } else {
        throw body["error"] ?? "Delete failed";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return false;
    }
  }

  Future<void> confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete Case",
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete this case?\nThis action cannot be undone.",
          style: GoogleFonts.inter(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      setState(() => _isDeleting = true);
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Deleting Case",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                "Deleting case...\nPlease wait",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey.shade300),
              ),
            ],
          ),
        ),
      );

      final success = await deleteCase(context);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        setState(() => _isDeleting = false);
      }

      if (success && mounted) {
        widget.onDeleted?.call();
        _navigateWithRandomTransition(context, const CaseHomePage());
      }
    }
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String value,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.deepPurple).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor ?? Colors.deepPurple.shade600, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.insert_drive_file, color: Colors.deepPurple.shade600, size: 22),
        ),
        title: Text(
          id.length > 35 ? '${id.substring(0, 32)}...' : id,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, color: Colors.deepPurple.shade600, size: 22),
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) {
                  final token = prefs.getString('jwt_token') ?? '';
                  _navigateWithRandomTransition(
                    context,
                    CaseAttachmentView(attachmentId: id, jwtToken: token),
                  );
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.download, color: Colors.deepPurple.shade600, size: 22),
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) {
                  final token = prefs.getString('jwt_token') ?? '';
                  _navigateWithRandomTransition(
                    context,
                    CaseAttachmentView(attachmentId: id, jwtToken: token),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon),
        label: Text(
          isLoading ? "Processing..." : label,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        onPressed: isLoading ? null : onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Case Details",
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
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF1A237E),
                Color(0xFF283593),
                Color(0xFF3949AB),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header Card
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.gavel, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.caseModel.caseName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "ID: ${widget.caseModel.id.substring(0, 8)}...",
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Information Grid
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
                            child: Icon(Icons.info_outline, color: Colors.deepPurple.shade600, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Case Information",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.5,
                        children: [
                          _buildInfoCard(title: "Case Type", icon: Icons.category, value: widget.caseModel.caseType, iconColor: Colors.blue),
                          _buildInfoCard(title: "Client Name", icon: Icons.person, value: widget.caseModel.userName, iconColor: Colors.green),
                          _buildInfoCard(title: "Advocate", icon: Icons.gavel, value: widget.caseModel.advocateName ?? "Not Assigned", iconColor: Colors.purple),
                          _buildInfoCard(title: "Issued Date", icon: Icons.calendar_today, value: widget.caseModel.issuedTime, iconColor: Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Attachments Card
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
                            child: Icon(Icons.attachment, size: 22, color: Colors.deepPurple.shade600),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Attachments",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${widget.caseModel.attachmentsId.length} files",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepPurple.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.caseModel.attachmentsId.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.attach_file_outlined, size: 60, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  "No attachments available",
                                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...widget.caseModel.attachmentsId.map((id) => _buildAttachmentTile(id)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              FutureBuilder<bool>(
                future: isMyCase(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  }

                  final isOwner = snapshot.hasData && snapshot.data == true;

                  return Column(
                    children: [
                      // Case Tracking Button
                      _buildActionButton(
                        icon: Icons.track_changes,
                        label: "Case Tracking",
                        color: Colors.deepPurple.shade600,
                        onPressed: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => Center(
                              child: Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 16),
                                      Text(
                                        "Loading Case Tracking...\nPlease wait",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );

                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('jwt_token') ?? '';
                          final userId = prefs.getString('userId') ?? '';

                          final advocateName = await getNameFromAdvocate(widget.caseModel.advocateId);
                          final nameResponse = await http.get(
                            Uri.parse('${BASE_URL.Urls().baseURL}user/search?userId=$userId'),
                            headers: {
                              "content-type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                          );

                          String? myName;
                          if (nameResponse.statusCode == 200) {
                            final body = jsonDecode(nameResponse.body);
                            myName = body["name"] ?? "";
                          }

                          String? advocateUserId;
                          final response = await http.get(
                            Uri.parse("${BASE_URL.Urls().baseURL}advocate/${widget.caseModel.advocateId}"),
                            headers: {
                              "content-type": "application/json",
                              "Authorization": "Bearer $token",
                            },
                          );

                          if (response.statusCode == 200) {
                            final body = jsonDecode(response.body);
                            advocateUserId = body["userId"];
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            _navigateWithRandomTransition(
                              context,
                              CaseTracking(
                                caseId: widget.caseModel.id,
                                caseName: widget.caseModel.caseName,
                                caseLawyer: advocateName,
                                issuedTime: widget.caseModel.issuedTime,
                                token: token,
                                advocateUserId: advocateUserId,
                                userName: myName,
                                userId: widget.caseModel.userId == userId ? userId : null,
                                advocateId: widget.caseModel.advocateId,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Delete Button (only for owner)
                      
                        _buildActionButton(
                          icon: Icons.delete_outline,
                          label: "Delete Case",
                          color: Colors.red.shade600,
                          onPressed: () => confirmDelete(context),
                          isLoading: _isDeleting,
                        ),
                      const SizedBox(height: 12),

                      if (isOwner)
                      // Appeal Button
                      FutureBuilder<CaseJudgment?>(
                        future: loadJudgment(),
                        builder: (context, snapshot) {
                          if (!isOwner || !snapshot.hasData || snapshot.data == null) {
                            return const SizedBox();
                          }

                          final judgment = snapshot.data!;
                          final today = DateTime.now();
                          final judgmentDate = judgment.date;
                          final canAppeal = judgmentDate.isBefore(
                            DateTime(today.year, today.month, today.day),
                          ) && widget.caseModel.userId == widget.userId;

                          if (!canAppeal) return const SizedBox();

                          return _buildActionButton(
                            icon: Icons.gavel,
                            label: "Case Appeal",
                            color: Colors.orange.shade600,
                            onPressed: () async {
                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              final token = prefs.getString('jwt_token') ?? '';
                              final userId = prefs.getString('userId') ?? '';
                              _navigateWithRandomTransition(
                                context,
                                AppealCasePage(
                                  token: token,
                                  caseId: widget.caseModel.id,
                                  userId: userId,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
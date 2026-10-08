// answer_tile.dart — Center Admin with "my advocate" delete permission
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';

import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as baseURL;
import 'answer_response.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnswerTile extends StatefulWidget {
  final AnswerResponse answer;
  final VoidCallback? onRefresh;

  const AnswerTile({
    required this.answer,
    super.key,
    this.onRefresh,
  });

  @override
  State<AnswerTile> createState() => _AnswerTileState();
}

class _AnswerTileState extends State<AnswerTile> {
  String? currentUserId;
  bool _isDeleting = false;

  // ✅ Center-admin state
  bool _isCenterAdmin = false;
  List<String> _myAdvocateIds = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMyAdvocateIds();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      currentUserId = prefs.getString('userId');
    });
  }

  /// ✅ Load the current center-admin's advocate list
  /// (same endpoint used by AdvocateDetails.isMyAdvocate()).
  Future<void> _loadMyAdvocateIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final userId = prefs.getString('userId') ?? '';

      if (userId.isEmpty) return;

      final response = await http.get(
        Uri.parse("${baseURL.Urls().baseURL}center-admin/by-user/$userId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> advocateIds = body["advocates"] ?? [];

        if (!mounted) return;
        setState(() {
          _isCenterAdmin = true;
          _myAdvocateIds = advocateIds.map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      // Not a center admin — leave defaults
      print('Center admin check failed: $e');
    }
  }

  /// ✅ Can the current user delete this answer?
  /// Yes if:
  ///   - the answer's advocateId is in this admin's advocate list
  ///   - OR the answer belongs to this admin themself (self-authored)
  bool get _canDelete {
    final answerAdvocateId = widget.answer.advocateId;
    if (answerAdvocateId == null || answerAdvocateId.isEmpty) {
      return false;
    }

    if (!_isCenterAdmin) return false;

    // My advocate check
    return _myAdvocateIds.contains(answerAdvocateId);
  }

  // ── Attachment detection ────────────────────────────────────────────────
  bool get hasAttachment {
    return widget.answer.attachmentId != null &&
        widget.answer.attachmentId!.isNotEmpty &&
        widget.answer.attachmentId != "null" &&
        widget.answer.attachmentId != "attachmentId";
  }

  // ── Name helpers ────────────────────────────────────────────────────────
  Future<String> getNameFromUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url = "${baseURL.Urls().baseURL}user/search?userId=$userId";
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url = "${baseURL.Urls().baseURL}advocate/$advocateId";
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

  // ── Attachment download & open ──────────────────────────────────────────
  String _getExtensionFromContentType(String? contentType) {
    if (contentType == null) return ".bin";
    if (contentType.contains("pdf")) return ".pdf";
    if (contentType.contains("jpeg")) return ".jpeg";
    if (contentType.contains("jpg")) return ".jpg";
    if (contentType.contains("png")) return ".png";
    if (contentType.contains("word")) return ".docx";
    return ".bin";
  }

  Future<void> openAttachment(
      BuildContext context, String attachmentId) async {
    try {
      final url = "${baseURL.Urls().baseURL}answers/download?attachmentId=$attachmentId";
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode != 200) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Download failed")),
        );
        return;
      }

      String fileName = "attachment";
      final disposition = response.headers['content-disposition'];
      if (disposition != null) {
        final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
        if (match != null) fileName = match.group(1)!;
      }

      final contentType =
          response.headers['content-type'] ?? "application/octet-stream";
      if (!fileName.contains(".")) {
        fileName += _getExtensionFromContentType(contentType);
      }

      if (kIsWeb) {
        final blob = html.Blob([response.bodyBytes], contentType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath = "${dir.path}/$fileName";
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(filePath);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Attachment error: $e")),
      );
    }
  }

  // ── Delete answer ───────────────────────────────────────────────────────
  Future<void> _deleteAnswer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Delete Answer",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          "Are you sure you want to delete this answer?",
          style: GoogleFonts.inter(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final userId = prefs.getString('userId') ?? '';

      final deleteResponse = await http.delete(
        Uri.parse(
            "${baseURL.Urls().baseURL}answers/delete/${widget.answer.id}?userId=$userId"),
        headers: {
          "content-type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (!mounted) return;

      if (deleteResponse.statusCode == 200 ||
          deleteResponse.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Answer deleted successfully",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onRefresh?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to delete answer",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e", style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.withOpacity(0.05),
              Colors.blue.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: advocate name + delete button ────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    size: 14,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.answer.advocateFullName ??
                        widget.answer.advocateName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                // ✅ Delete only if this answer is from one of my advocates
                if (_canDelete)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                    onPressed: _isDeleting ? null : _deleteAnswer,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Answer message ───────────────────────────────────────
            Text(
              widget.answer.message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),

            // ── Attachment ───────────────────────────────────────────
            if (hasAttachment)
              InkWell(
                onTap: () =>
                    openAttachment(context, widget.answer.attachmentId!),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "View Attachment",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
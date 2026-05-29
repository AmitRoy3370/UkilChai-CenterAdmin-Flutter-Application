// question_card.dart - Center Admin (Redesigned)
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:advocatechaicenteradmin/QuestionPages/question_response.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:html' as html;
import '../Auth/AuthService.dart';
import '../Utils/AdvocateSpeciality.dart';
import '../Utils/BaseURL.dart' as baseURL;
import '../Utils/BaseURL.dart' as BASE_URL;
import 'AnswerModel.dart';
import 'AnswerService.dart';
import 'AnswerTile.dart';
import 'QuestionModel.dart';
import 'QuestionService.dart';
import '../PageTransition.dart';

class QuestionCard extends StatefulWidget {
  final QuestionResponse question;
  final VoidCallback refreshMethod;

  const QuestionCard({
    required this.question,
    required this.refreshMethod,
    super.key,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  String currentUserId = "";
  bool isMyQuestion = false;
  bool _isAdmin = false;

  PlatformFile? selectedFile;
  String? fileName;
  String? fileExtension;

  final List<PageTransitionType> _smoothAnimations = AnimatedRoute.getCompanySafeAnimations();

  PageTransitionType _getRandomAnimation() {
    final random = Random().nextInt(_smoothAnimations.length);
    return _smoothAnimations[random];
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );

    if (result == null) return;

    final file = result.files.first;

    setState(() {
      selectedFile = file;
      fileName = file.name;
      fileExtension = file.extension;
    });
  }

  @override
  void initState() {
    super.initState();
    loadUser();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final userId = prefs.getString('userId') ?? '';
    
    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}center-admin/by-user/$userId"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (response.statusCode == 200) {
      setState(() {
        _isAdmin = true;
      });
    }
  }

  Future<void> loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString("userId") ?? "";

    setState(() {
      isMyQuestion = currentUserId == widget.question.userId;
    });
  }

  String _getExtensionFromContentType(String? contentType) {
    if (contentType == null) return ".bin";
    if (contentType.contains("pdf")) return ".pdf";
    if (contentType.contains("jpeg")) return ".jpeg";
    if (contentType.contains("jpg")) return ".jpg";
    if (contentType.contains("png")) return ".png";
    if (contentType.contains("word")) return ".docx";
    if (contentType.contains("excel")) return ".xlsx";
    if (contentType.contains("text")) return ".txt";
    return ".bin";
  }

  Future<void> openAttachment(BuildContext context, String attachmentId) async {
    try {
      final url = "${baseURL.Urls().baseURL}questions/downloadQuestionContent?attachmentId=$attachmentId";
      final token = await AuthService.getToken();

      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode != 200) {
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

      final contentType = response.headers['content-type'] ?? "application/octet-stream";
      if (!fileName.contains(".")) fileName += _getExtensionFromContentType(contentType);

      if (kIsWeb) {
        final blob = html.Blob([response.bodyBytes], contentType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)..setAttribute("download", fileName)..click();
        html.Url.revokeObjectUrl(url);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath = "${dir.path}/$fileName";
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Attachment error: $e")),
      );
    }
  }

  Future<String> getNameFromUser(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url = "${BASE_URL.Urls().baseURL}user/search?userId=$userId";
    final response = await http.get(
      Uri.parse(url),
      headers: {"content-type": "application/json", "Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body["name"] ?? "";
    }
    return "";
  }

  String? getMimeType(String? extension) {
    if (extension == null) return null;
    extension = extension.toLowerCase();
    switch (extension) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'pdf': return 'application/pdf';
      case 'mp4': return 'video/mp4';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt': return 'text/plain';
      default: return 'application/octet-stream';
    }
  }

  void showEditDialog() {
    TextEditingController messageController = TextEditingController(text: widget.question.message);
    String selectedType = widget.question.questionType.apiValue;
    
    selectedFile = null;
    fileName = null;
    fileExtension = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Edit Question", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    style: GoogleFonts.inter(),
                    decoration: InputDecoration(
                      labelText: "Message",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: AdvocateSpeciality.values.map((e) {
                      return DropdownMenuItem(value: e.name, child: Text(e.label));
                    }).toList(),
                    onChanged: (v) => selectedType = v!,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await pickFile();
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text("Choose Attachment"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (fileName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(fileName!, style: GoogleFonts.inter(color: Colors.green)),
                    ),
                  if (widget.question.attachmentId != null && widget.question.attachmentId!.isNotEmpty && selectedFile == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Current attachment will be replaced if you choose a new one",
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text("Updating question...", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF1A237E)),
                              const SizedBox(height: 10),
                              Text("Please wait...", style: GoogleFonts.inter()),
                            ],
                          ),
                        );
                      },
                    );

                    try {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('jwt_token') ?? '';

                      final uri = Uri.parse("${baseURL.Urls().baseURL}questions/update");
                      var request = http.MultipartRequest("PUT", uri);
                      request.headers["Authorization"] = "Bearer $token";

                      request.fields["userId"] = widget.question.userId;
                      request.fields["usersId"] = widget.question.userId;
                      request.fields["message"] = messageController.text.trim();
                      request.fields["questionType"] = selectedType;
                      request.fields["questionId"] = widget.question.id!;
                      
                      if (widget.question.attachmentId != null && widget.question.attachmentId!.isNotEmpty && selectedFile == null) {
                        request.fields["attachmentId"] = widget.question.attachmentId!;
                      } else {
                        request.fields["attachmentId"] = "attachmentId";
                      }

                      if (selectedFile != null) {
                        final mimeTypeStr = getMimeType(fileExtension);
                        http.MediaType? contentType = mimeTypeStr != null
                            ? http.MediaType.parse(mimeTypeStr)
                            : null;

                        if (kIsWeb) {
                          if (selectedFile!.bytes != null) {
                            request.files.add(
                              http.MultipartFile.fromBytes(
                                "file",
                                selectedFile!.bytes!,
                                filename: selectedFile!.name,
                                contentType: contentType,
                              ),
                            );
                          }
                        } else {
                          if (selectedFile!.path != null) {
                            request.files.add(
                              await http.MultipartFile.fromPath(
                                "file",
                                selectedFile!.path!,
                                filename: selectedFile!.name,
                                contentType: contentType,
                              ),
                            );
                          } else if (selectedFile!.bytes != null) {
                            request.files.add(
                              http.MultipartFile.fromBytes(
                                "file",
                                selectedFile!.bytes!,
                                filename: selectedFile!.name,
                                contentType: contentType,
                              ),
                            );
                          }
                        }
                      }

                      final streamedResponse = await request.send();
                      final response = await http.Response.fromStream(streamedResponse);

                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) Navigator.pop(context);

                      if (response.statusCode == 200 || response.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Question updated successfully", style: GoogleFonts.inter()),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        widget.refreshMethod();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed: ${response.body}", style: GoogleFonts.inter()),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Update failed: $e", style: GoogleFonts.inter()),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAttachment = widget.question.attachmentId != null && 
                               widget.question.attachmentId!.isNotEmpty && 
                               widget.question.attachmentId != "null" &&
                               widget.question.attachmentId != "attachmentId";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF283593)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.question.questionType.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Show menu for own questions OR for admin
                    if (isMyQuestion || _isAdmin)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                        itemBuilder: (context) => [
                          if (isMyQuestion)
                            const PopupMenuItem(value: "edit", child: Text("Edit")),
                          const PopupMenuItem(value: "delete", child: Text("Delete")),
                        ],
                        onSelected: (value) async {
                          if (value == "edit" && isMyQuestion) {
                            showEditDialog();
                          }
                          if (value == "delete") {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Text("Deleting question...", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(color: Colors.red),
                                      const SizedBox(height: 10),
                                      Text("Please wait...", style: GoogleFonts.inter()),
                                    ],
                                  ),
                                );
                              },
                            );

                            final res = await QuestionService.deleteQuestion(
                              questionId: widget.question.id!,
                              userId: currentUserId,
                            );
                            
                            if (context.mounted) Navigator.pop(context);
                            
                            if (res) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Question deleted successfully", style: GoogleFonts.inter()),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              widget.refreshMethod();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Failed to delete question", style: GoogleFonts.inter()),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // User Name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
                      child: Text(
                        widget.question.userName.isNotEmpty ? widget.question.userName[0].toUpperCase() : "U",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A237E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.question.userName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Question Message
                Text(
                  widget.question.message,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Only show attachment button if attachment actually exists
                if (hasAttachment)
                  InkWell(
                    onTap: () => openAttachment(context, widget.question.attachmentId!),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_file, size: 16, color: const Color(0xFF1A237E)),
                          const SizedBox(width: 6),
                          Text(
                            "View Attachment",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.open_in_new, size: 14, color: const Color(0xFF1A237E)),
                        ],
                      ),
                    ),
                  ),

                const Divider(color: Colors.grey, height: 24),

                // Answers Section
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      widget.question.answers.isEmpty ? "No answers yet" : "Answers (${widget.question.answers.length})",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (widget.question.answers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "Be the first to answer this question",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    children: widget.question.answers.map((a) => AnswerTile(
                      answer: a, 
                      onRefresh: widget.refreshMethod,
                    )).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
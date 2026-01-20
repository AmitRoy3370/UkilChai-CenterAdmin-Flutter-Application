import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as baseURL;
import 'QuestionModel.dart';
import 'QuestionService.dart';
import 'package:http/http.dart' as http;
import 'package:advocatechaicenteradmin/Utils/BaseURL.dart' as BASEURL;

class QuestionListPage extends StatelessWidget {
  const QuestionListPage({super.key});

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
      final url =
          "${baseURL.Urls().baseURL}questions/downloadQuestionContent?attachmentId=$attachmentId";

      final token = await AuthService.getToken();

      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Download failed")));
        return;
      }

      // 🔹 Extract filename from header
      String fileName = "attachment";
      final disposition = response.headers['content-disposition'];
      if (disposition != null) {
        final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
        if (match != null) {
          fileName = match.group(1)!;
        }
      }

      // 🔹 Get content type
      final contentType = response.headers['content-type'] ?? "application/octet-stream";

      // 🔹 Add extension if missing
      if (!fileName.contains(".")) {
        fileName += _getExtensionFromContentType(contentType);
      }

      // ==========================================
      // 🌐 WEB
      // ==========================================
      if (kIsWeb) {
        final blob = html.Blob([response.bodyBytes], contentType);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();

        html.Url.revokeObjectUrl(url);
        return;
      }

      // ==========================================
      // 📱 MOBILE
      // ==========================================
      final dir = await getApplicationDocumentsDirectory();
      final filePath = "${dir.path}/$fileName";

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      await OpenFilex.open(filePath);

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Attachment error: $e")));
    }
  }

  Future<String> getName(var q) async {
    print("userId in getName function :- ${q.userId}");

    final userURL = Uri.parse(
      "${BASEURL.Urls().baseURL}user/search?userId=${q.userId}",
    );

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("jwt_token");

    print("token in get name function :- $token");

    final userResponse = await http.get(
      userURL,
      headers: {"Authorization": "Bearer $token"},
    );

    print("user response :- ${userResponse.statusCode}");

    final user = jsonDecode(userResponse.body);

    final userName = user["name"];

    print("name :- $userName");

    return userName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(title: const Text("Legal Questions")),
      body: FutureBuilder<List<QuestionModel>>(
        future: QuestionService.getAllQuestions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final q = list[i];

              var userName = "";

              getName(q).then((value) {
                userName = value;
              });

              print("user name in list :- $userName");

              return Card(
                color: const Color(0xFF1C1C1C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.questionType,
                        style: const TextStyle(color: Colors.orange),
                      ),
                      FutureBuilder<String>(
                        future: getName(q),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Text(
                              "Loading user...",
                              style: TextStyle(color: Colors.grey),
                            );
                          }

                          return Text(
                            snapshot.data!,
                            style: const TextStyle(color: Colors.orange),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        q.message,
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (q.attachmentId != null)
                        InkWell(
                          onTap: () => openAttachment(context, q.attachmentId!),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: const [
                                Icon(Icons.attach_file, color: Colors.orange),
                                SizedBox(width: 6),
                                Text(
                                  "View Attachment",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    decoration: TextDecoration.underline,
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
            },
          );
        },
      ),
    );
  }
}

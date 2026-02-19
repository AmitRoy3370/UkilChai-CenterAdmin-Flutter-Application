import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import './AdvocatePost.dart';
import 'PostAttachmentViewer.dart';
import 'reaction_bar.dart';

class PostCard extends StatelessWidget {
  final AdvocatePost post;
  final VoidCallback onDelete;

  const PostCard({super.key, required this.post, required this.onDelete});

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

  Future<bool> isMyAdvocate(String? advocateId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final userId = prefs.getString('userId') ?? '';

    final centerAdminResponse = await http.get(
      Uri.parse("${BASE_URL.Urls().baseURL}center-admin/by-user/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (centerAdminResponse.statusCode == 200) {
      final centerAdminBody = jsonDecode(centerAdminResponse.body);
      final advocateIds = centerAdminBody["advocates"] as List<dynamic>;

      return advocateIds.contains(advocateId);
    } else {
      return false;
    }
  }

  Future<void> deletePost(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final userId = prefs.getString('userId') ?? '';

    final response = await http.delete(
      Uri.parse(
        "${BASE_URL.Urls().baseURL}advocate/posts/delete/${post.id}/$userId",
      ),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post deleted successfully")),
      );
      onDelete();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to delete post")));
    }
  }

  // ---------------- GET ADVOCATE NAME ----------------
  Future<String> getNameFromAdvocate(String advocateId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final url = "${BASE_URL.Urls().baseURL}advocate/$advocateId";

    //print("token from name of advocate :- $token");

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "content-type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      //print("find advocate ${advocateId} from name from advocate....");

      final body = jsonDecode(response.body);
      final userId = body["userId"];

      //print("userId :- ${userId}");

      return getNameFromUser(userId);
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER ROW (NAME + THREE DOT)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// Advocate Name
                Expanded(
                  child: FutureBuilder<String>(
                    future: getNameFromAdvocate(post.advocateId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text("Loading...");
                      }
                      if (!snapshot.hasData || snapshot.hasError) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        snapshot.data!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                ),

                /// THREE DOT MENU
                FutureBuilder<bool>(
                  future: isMyAdvocate(post.advocateId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == false) {
                      return const SizedBox.shrink();
                    }

                    return PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == "delete") {
                          final confirm = await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Delete Post"),
                              content: const Text(
                                "Are you sure you want to delete this post?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await deletePost(context);
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: "delete",
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Delete Post"),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            /// POST TYPE
            Text(
              post.postType,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            /// POST CONTENT
            Text(post.postContent),

            const Divider(),

            /// ATTACHMENT BUTTON
            if (post.attachmentId != null && post.attachmentId!.isNotEmpty)
              ElevatedButton(
                onPressed: () async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  final token = prefs.getString('jwt_token') ?? '';

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostAttachmentView(
                        attachmentId: post.attachmentId!,
                        jwtToken: token,
                      ),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.attachment),
                    SizedBox(width: 8),
                    Text("View Attachment"),
                  ],
                ),
              ),

            /// REACTION BAR
            ReactionBar(postId: post.id),
          ],
        ),
      ),
    );
  }
}

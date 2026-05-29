// post_card.dart - Redesigned
import 'dart:convert';
import '../PostRelatedPages/post_response.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Utils/AdvocateSpeciality.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import './AdvocatePost.dart';
import 'PostAttachmentViewer.dart';
import 'reaction_bar.dart';

class PostCard extends StatefulWidget {
  final PostResponse post;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function? onReactionChanged;
  final bool? canReact;

  const PostCard({
    super.key,
    required this.post,
    this.onEdit,
    this.onDelete,
    this.onReactionChanged,
    this.canReact,
  });

  @override
  State<StatefulWidget> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // Check if attachment exists (not null, not empty, not "null")
  bool get hasAttachment {
    return widget.post.attachmentId != null &&
        widget.post.attachmentId!.isNotEmpty &&
        widget.post.attachmentId != "null" &&
        widget.post.attachmentId != "attachmentId";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Avatar
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A237E),
                              Color(0xFF283593),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.post.advocateName.isNotEmpty
                                ? widget.post.advocateName[0].toUpperCase()
                                : "A",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post.advocateName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1A237E),
                                    Color(0xFF283593),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.post.postType.label,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onDelete != null)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                          onSelected: (value) {
                            if (value == 'delete') {
                              widget.onDelete?.call();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Post Content
                  Text(
                    widget.post.postContent,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Attachment Button - Only shows if attachment exists
                  if (hasAttachment)
                    InkWell(
                      onTap: () async {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('jwt_token') ?? '';

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostAttachmentView(
                              attachmentId: widget.post.attachmentId!,
                              jwtToken: token,
                            ),
                          ),
                        );
                      },
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

                  // Reaction Bar
                  ReactionBar(
                    postResponse: widget.post,
                    onReactionChanged: (reaction, action) {
                      setState(() {
                        widget.onReactionChanged?.call(reaction, action);
                      });
                    },
                    canReact: widget.canReact ?? true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
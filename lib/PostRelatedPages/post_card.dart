// post_card.dart — Center Admin with advocate-scoped delete permission
// No edit option is offered by default — only Delete for the current
// user's advocates. Parent can still pass `onEdit` if it wants to inject
// an Edit action explicitly.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Utils/AdvocateSpeciality.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import './AdvocatePost.dart';
import 'PostAttachmentViewer.dart';
import 'reaction_bar.dart';
import 'attachment_widget.dart';
import 'post_response.dart';
import 'PostService.dart';
import '../PageTransition.dart';
import '../AdvocatePages/AdvocateDetails.dart';
import '../AdvocatePages/AdvocateDetailsModel.dart';

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
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final List<PageTransitionType> _smoothAnimations =
      AnimatedRoute.getCompanySafeAnimations();

  bool _isExpanded = false;
  static const int _maxLines = 3;
  static const int _minCharLength = 100;

  // ── Center-admin state ──────────────────────────────────────────────────
  bool _isCenterAdmin = false;
  List<String> _myAdvocateIds = [];
  bool _checkingAdmin = true;

  PageTransitionType _getRandomAnimation() {
    final random = Random().nextInt(_smoothAnimations.length);
    return _smoothAnimations[random];
  }

  // ── Attachment detection ────────────────────────────────────────────────
  bool get hasAttachment {
    return widget.post.attachmentId != null &&
        widget.post.attachmentId!.isNotEmpty &&
        widget.post.attachmentId != "null" &&
        widget.post.attachmentId != "attachmentId";
  }

  // ── Long content detection ──────────────────────────────────────────────
  bool get _isLongContent =>
      widget.post.postContent.length > _minCharLength;

  // ── Can the current user DELETE this post? ───────────────────────────────
  // Yes if this post belongs to one of MY advocates.
  bool get _canDeletePost {
    final postAdvocateId = widget.post.advocateId;
    if (postAdvocateId == null || postAdvocateId.isEmpty) return false;
    if (!_isCenterAdmin) return false;
    return _myAdvocateIds.contains(postAdvocateId);
  }

  // Should the overlay menu appear at all?
  bool get _showMenu {
    // Parent explicitly asked for menu items?
    final parentWants = widget.onEdit != null || widget.onDelete != null;
    // Or built-in permission grants something?
    final builtIn = _canDeletePost;
    return parentWants || builtIn;
  }

  @override
  void initState() {
    super.initState();
    _loadMyAdvocateIds();
  }

  /// Loads the current center-admin's advocate list — same call used by
  /// `AdvocateDetails.isMyAdvocate()`.
  Future<void> _loadMyAdvocateIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      final token = prefs.getString('jwt_token') ?? '';

      if (userId.isEmpty) {
        if (mounted) setState(() => _checkingAdmin = false);
        return;
      }

      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}center-admin/by-user/$userId"),
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
          _myAdvocateIds =
              advocateIds.map((e) => e.toString()).toList();
          _checkingAdmin = false;
        });
      } else {
        if (mounted) setState(() => _checkingAdmin = false);
      }
    } catch (_) {
      if (mounted) setState(() => _checkingAdmin = false);
    }
  }

  // ── Navigate to attachment viewer ───────────────────────────────────────
  Future<void> _navigateToAttachmentViewer(String attachmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostAttachmentView(
          attachmentId: attachmentId,
          jwtToken: token,
        ),
      ),
    );
  }

  // ── Navigate to advocate profile ────────────────────────────────────────
  Future<void> _navigateToAdvocateProfile(String advocateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}advocate/$advocateId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final AdvocateDetailsModel advocate =
            AdvocateDetailsModel.fromJson(responseData);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AdvocateDetails(advocateDetailsModel: advocate),
          ),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print("❌ Error loading advocate: $e");
    }
  }

  // ── Delete post (with confirmation) ─────────────────────────────────────
  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Delete Post",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          "Are you sure you want to delete this post? "
          "This action cannot be undone.",
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

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Deleting post...",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 10),
            Text("Please wait...", style: GoogleFonts.inter()),
          ],
        ),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final userId = prefs.getString('userId') ?? '';

      final success = await PostService.deletePost(
        postId: widget.post.id!,
        userId: userId,
        token: token,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Post deleted successfully",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onDelete?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to delete post",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Delete failed: $e", style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
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
                // ── Header ───────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.purple.shade400,
                            Colors.blue.shade400,
                          ],
                        ),
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
                          GestureDetector(
                            onTap: () => _navigateToAdvocateProfile(
                                widget.post.advocateId),
                            child: Text(
                              widget.post.advocateFullName ??
                                  widget.post.advocateName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Specialty pill badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.blue.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.post.postType.icon,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.post.postType.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ Overlay menu — Delete only (unless the parent
                    //    explicitly injected an Edit action).
                    if (!_checkingAdmin && _showMenu)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            color: Colors.grey.shade600),
                        onSelected: (value) {
                          if (value == 'edit') {
                            widget.onEdit?.call();
                          } else if (value == 'delete') {
                            if (widget.onDelete != null) {
                              widget.onDelete!.call();
                            } else {
                              _deletePost();
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          // Edit appears ONLY when the parent supplied
                          // an explicit onEdit callback.
                          if (widget.onEdit != null)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit,
                                      color: Colors.blue, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),

                          // Delete appears when the parent supplied onDelete
                          // OR when I can delete (my advocate's post).
                          if (widget.onDelete != null || _canDeletePost)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: Colors.red, size: 18),
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

                // ── Post content ─────────────────────────────────────────
                _buildPostContent(),
                const SizedBox(height: 12),

                // ── Attachment ───────────────────────────────────────────
                if (hasAttachment)
                  AttachmentWidget(
                    attachmentId: widget.post.attachmentId!,
                    height: 150,
                    onViewAttachment: _navigateToAttachmentViewer,
                  ),

                const Divider(color: Colors.grey, height: 24),

                // ── Reactions ────────────────────────────────────────────
                ReactionBar(
                  postResponse: widget.post,
                  onReactionChanged: (reaction, action) {
                    setState(() {
                      widget.onReactionChanged?.call(reaction, action);
                    });
                  },
                  canReact: widget.canReact ?? true,
                  // ReactionBar decides who can delete which reactions
                  isMyAdvocatePost: _canDeletePost,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Post content with See more / See less ───────────────────────────────
  Widget _buildPostContent() {
    final text = widget.post.postContent;

    if (!_isLongContent) {
      return Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: Colors.grey[700],
          height: 1.4,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.grey[700],
            height: 1.4,
          ),
          maxLines: _isExpanded ? null : _maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isExpanded ? 'See less' : 'See more',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 18,
                color: Colors.blue.shade600,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
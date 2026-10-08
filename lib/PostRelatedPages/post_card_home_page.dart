// post_card_home_page.dart — Center Admin with advocate-scoped delete permission
// No edit option is offered by default — only Delete.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import '../AdvocatePages/AdvocateDetailsModel.dart';
import '../AdvocatePages/AdvocateDetails.dart';
import 'attachment_widget.dart';
import 'PostAttachmentViewer.dart';
import 'post_response.dart';
import 'PostService.dart';
import 'single_post_page.dart';

class PostCardHomePage extends StatefulWidget {
  final PostResponse post;

  /// Called after the current user successfully deletes the post.
  final VoidCallback? onChanged;

  const PostCardHomePage({
    super.key,
    required this.post,
    this.onChanged,
  });

  @override
  State<PostCardHomePage> createState() => _PostCardHomePageState();
}

class _PostCardHomePageState extends State<PostCardHomePage> {
  String? _token;
  bool _isExpanded = false;

  // ── Center-admin state ────────────────────────────────────────────────
  bool _isCenterAdmin = false;
  List<String> _myAdvocateIds = [];
  bool _checkingAdmin = true;

  @override
  void initState() {
    super.initState();
    _loadTokenAndAdmin();
  }

  // ── Load token + center-admin info ────────────────────────────────────
  Future<void> _loadTokenAndAdmin() async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();

    if (!mounted) return;
    setState(() {
      _token = token;
    });

    await _loadMyAdvocateIds(userId);
  }

  /// Loads the current center-admin's advocate list — same call used by
  /// `AdvocateDetails.isMyAdvocate()`.
  Future<void> _loadMyAdvocateIds(String? userId) async {
    try {
      final token = _token ?? await AuthService.getToken();
      final uid = userId ?? await AuthService.getUserId();

      if (uid == null || uid.isEmpty) {
        if (mounted) setState(() => _checkingAdmin = false);
        return;
      }

      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}center-admin/by-user/$uid"),
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

  // ── Permission getter ─────────────────────────────────────────────────

  /// Can the current user DELETE this post?
  /// Yes when the post belongs to one of my advocates.
  bool get _canDeletePost {
    final postAdvocateId = widget.post.advocateId;
    if (postAdvocateId == null || postAdvocateId.isEmpty) return false;
    if (!_isCenterAdmin) return false;
    return _myAdvocateIds.contains(postAdvocateId);
  }

  // ── Formatting helpers ─────────────────────────────────────────────────
  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  // ── Navigation ──────────────────────────────────────────────────────────
  void _navigateToAttachmentViewer(String attachmentId) {
    if (_token == null || _token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to view attachment')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostAttachmentView(
          attachmentId: attachmentId,
          jwtToken: _token!,
        ),
      ),
    );
  }

  Future<void> _navigateToSinglePost() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SinglePostPage(
          post: widget.post,
          canReact: true,
          onReactionChanged: (reaction, action) {
            // no-op
          },
        ),
      ),
    );

    if (mounted) {
      widget.onChanged?.call();
    }
  }

  Future<void> _navigateToAdvocateProfile(String advocateId) async {
    try {
      final token = await AuthService.getToken();

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
      } else {
        // ignore: avoid_print
        print("❌ Failed to load advocate details: ${response.statusCode}");
      }
    } catch (e) {
      // ignore: avoid_print
      print("❌ Error loading advocate: $e");
    }
  }

  // ── Delete post (with confirmation + loading) ─────────────────────────
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
      final token = _token ?? await AuthService.getToken();
      final userId = await AuthService.getUserId();

      final success = await PostService.deletePost(
        postId: widget.post.id!,
        userId: userId ?? '',
        token: token ?? '',
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
        widget.onChanged?.call();
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
    return GestureDetector(
      onTap: _navigateToSinglePost,
      child: SizedBox(
        width: 280,
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ─────────────────────────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        widget.post.advocateName.isNotEmpty
                            ? widget.post.advocateName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            widget.post.formattedPostType,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // View pill
                    GestureDetector(
                      onTap: _navigateToSinglePost,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility,
                                color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'View',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ✅ Overlay menu — Delete only
                    if (!_checkingAdmin && _canDeletePost)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deletePost();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Content ────────────────────────────────────────────
                if (widget.post.postContent.isNotEmpty) _buildPostContent(),

                const SizedBox(height: 8),

                // ── Attachment ─────────────────────────────────────────
                if (widget.post.hasAttachment)
                  AttachmentWidget(
                    attachmentId: widget.post.attachmentId!,
                    height: 120,
                    onViewAttachment: _navigateToAttachmentViewer,
                  ),

                const SizedBox(height: 8),

                // ── Reaction + comment row ─────────────────────────────
                _buildReactionAndCommentRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostContent() {
    final text = widget.post.postContent;
    final shouldShowMore = text.length > 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shouldShowMore)
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          )
        else ...[
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey[700],
            ),
            maxLines: _isExpanded ? null : 2,
            overflow: _isExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            softWrap: true,
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Text(
              _isExpanded ? 'Show less' : 'Show more',
              style: GoogleFonts.inter(
                color: Colors.blue.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReactionAndCommentRow() {
    final totalReactions = widget.post.totalReactions;
    final commentCount = widget.post.reactions.length;

    return Row(
      children: [
        GestureDetector(
          onTap: () => _showReactionDialog(context),
          child: Row(
            children: [
              Icon(
                Icons.favorite,
                size: 14,
                color: totalReactions > 0
                    ? Colors.red.shade400
                    : Colors.grey.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                _formatCount(totalReactions),
                style: TextStyle(
                  fontSize: 11,
                  color: totalReactions > 0
                      ? Colors.grey.shade700
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            Icon(
              Icons.comment,
              size: 14,
              color: commentCount > 0
                  ? Colors.grey.shade700
                  : Colors.grey.shade400,
            ),
            const SizedBox(width: 4),
            Text(
              _formatCount(commentCount),
              style: TextStyle(
                fontSize: 11,
                color: commentCount > 0
                    ? Colors.grey.shade700
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: _navigateToSinglePost,
          icon: Icon(Icons.open_in_new,
              size: 16, color: Colors.green.shade600),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'View Details',
        ),
      ],
    );
  }

  void _showReactionDialog(BuildContext context) {
    if (widget.post.reactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reactions yet'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reactions (${widget.post.reactions.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.post.reactions.length,
                  itemBuilder: (context, index) {
                    final reaction = widget.post.reactions[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          reaction.userName?.isNotEmpty == true
                              ? reaction.userName![0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(reaction.userName ?? 'Unknown User'),
                      subtitle:
                          Text(reaction.postReaction?.label ?? ''),
                      trailing: Icon(
                        _getReactionIcon(
                            reaction.postReaction?.label ?? ''),
                        color: Colors.amber,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getReactionIcon(String reactionType) {
    switch (reactionType.toLowerCase()) {
      case 'like':
        return Icons.thumb_up;
      case 'love':
        return Icons.favorite;
      case 'haha':
        return Icons.emoji_emotions;
      case 'wow':
        return Icons.emoji_events;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'angry':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.thumb_up;
    }
  }
}
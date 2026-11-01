import '../PostRelatedPages/post_response.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import './AdvocatePost.dart';
import './PostService.dart';
import './post_card.dart';
import '../HomePage.dart';
import '../main.dart';

class PostFeedPage extends StatefulWidget {
  const PostFeedPage({super.key});

  @override
  State<PostFeedPage> createState() => _PostFeedPageState();
}

class _PostFeedPageState extends State<PostFeedPage> {
  bool loading = true;
  List<PostResponse> posts = [];

  // ✅ Cached future so rebuilds don't re-fire the HTTP request.
  late Future<List<PostResponse>> _postsFuture;

  @override
  void initState() {
    super.initState();
    // Kick off the load exactly once.
    _postsFuture = getPosts();
  }

  // Method to navigate to main page
  void _navigateToMainPage() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MyHomePage(title: 'উকিল')),
      (route) => false,
    );
  }

  Future<List<PostResponse>> getPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final data = await PostService.fetchAllPosts(token);

    return data.reversed.toList();
  }

  /// ✅ Trigger a fresh fetch (pull-to-refresh, retry button, etc.).
  /// Does **not** rebuild on its own — the FutureBuilder listens to it.
  Future<void> _reload() async {
    final future = getPosts();
    setState(() {
      _postsFuture = future;
    });
    // Let RefreshIndicator wait for completion, and swallow errors so the
    // indicator hides even on failure (FutureBuilder will show the error).
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Advocate Posts",
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: _navigateToMainPage,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: Colors.purple,
        child: FutureBuilder<List<PostResponse>>(
          // ✅ Bind to the cached future, not a new one per build.
          future: _postsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.purple),
                    SizedBox(height: 16),
                    Text('Loading posts...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            final posts = snapshot.data ?? [];

            if (posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No posts available',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              // Keep the RefreshIndicator scrollable even with few items.
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (_, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  onReactionChanged: (reaction, action) {
                    // ✅ No setState here — the FutureBuilder future is
                    //    cached, so this won't trigger a refetch. PostCard
                    //    already updates its own reaction list locally.
                    //    If you want the parent to reflect the change,
                    //    keep setState (it's now cheap — no HTTP refire).
                    setState(() {});
                  },
                  canReact: true,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
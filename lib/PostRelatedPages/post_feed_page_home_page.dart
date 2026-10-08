// post_feed_page_home_page.dart - ডিবাগ সংস্করণ

import '../PostRelatedPages/post_card_home_page.dart';
import '../PostRelatedPages/post_response.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './PostService.dart';
import '../Utils/AdvocateSpeciality.dart';
import '../HomePage.dart';
import '../main.dart';

class PostFeedPageHomePage extends StatefulWidget {
  final String? initialPostType;

  const PostFeedPageHomePage({
    super.key,
    this.initialPostType,
  });

  @override
  State<PostFeedPageHomePage> createState() => _PostFeedPageHomePageState();
}

class _PostFeedPageHomePageState extends State<PostFeedPageHomePage> {
  bool loading = true;
  bool isLoggedIn = true;
  List<PostResponse> posts = [];
  String? _selectedPostType;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedPostType = widget.initialPostType;
    loadPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadPosts() async {
    setState(() {
      loading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      /*if (token.isEmpty) {
        setState(() {
          loading = false;
          isLoggedIn = false;
        });
        return;
      }*/

      List<PostResponse> data;
      
      if (_selectedPostType != null && _selectedPostType!.isNotEmpty) {
        data = await PostService.fetchPostsByType(
          postType: _selectedPostType!,
          token: token,
        );
      } else {
        data = await PostService.fetchAllPosts(token);
      }
      
      setState(() {
        posts = data;
        posts = posts.reversed.toList();
        loading = false;
        isLoggedIn = true;
      });
    } catch (e) {
      setState(() {
        loading = false;
        isLoggedIn = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedPostType != null 
              ? '${_getTypeLabel(_selectedPostType!)} Posts'
              : 'All Posts',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>     Navigator.push(
                                     context,
                                     MaterialPageRoute(builder: (context) =>  MyHomePage(title: 'উকিল')),
                                     
                                     ),
        ),
        actions: [
          if (_selectedPostType != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedPostType = null;
                });
                loadPosts();
              },
              tooltip: 'Clear filter',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadPosts,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // 🔥 এরর মেসেজ
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loadPosts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // ========== লগইন না থাকলে ==========
    if (!isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "Log in first",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "to watch the posts",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            /*ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                "Login Now",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),*/
          ],
        ),
      );
    }

    // ========== লোডিং ==========
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      );
    }

    // ========== পোস্ট খালি ==========
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.post_add,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedPostType != null 
                  ? 'No posts found for this category'
                  : 'No posts available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedPostType != null 
                  ? 'Try selecting another category'
                  : 'Check back later for updates',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            if (_selectedPostType != null)
              const SizedBox(height: 16),
            if (_selectedPostType != null)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedPostType = null;
                  });
                  loadPosts();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.grey.shade700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // ========== পোস্ট লিস্ট ==========
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: PostCardHomePage(
            post: posts[index],
          ),
        );
      },
    );
  }

  String _getTypeLabel(String typeValue) {
    try {
      final speciality = AdvocateSpecialityExt.fromApi(typeValue);
      return speciality.label;
    } catch (e) {
      return typeValue;
    }
  }
}
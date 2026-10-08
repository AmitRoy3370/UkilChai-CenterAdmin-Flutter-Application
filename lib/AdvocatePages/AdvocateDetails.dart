// lib/AdvocatePages/AdvocateDetails.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as NavigatorPageRoute;
import 'package:http/http.dart' as http;
import 'dart:html' as html;

import 'package:advocatechaicenteradmin/AdvocatePages/AdvocateDetailsModel.dart';
import 'package:advocatechaicenteradmin/Auth/AuthService.dart';
import 'package:advocatechaicenteradmin/Utils/BaseURL.dart' as baseURL;

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'dart:convert';

import '../CaseRelatedPages/AddCaseRequestPage.dart';
import '../CaseRelatedPages/case_model.dart';
import '../ChatRelatedPages/chat_screen.dart';
import '../PostRelatedPages/AdvocatePost.dart';
import '../PostRelatedPages/PostService.dart';
import '../PostRelatedPages/post_card.dart';
import '../PostRelatedPages/post_response.dart';
import '../Utils/BaseURL.dart' as BASE_URL;

// ✅ NEW: Bookmark service (same one used by the user panel)
import 'BookmarkService.dart';

// ✅ NEW: Google fonts (used by the bookmark button styling — optional but nice)
import 'package:google_fonts/google_fonts.dart';

class AdvocateDetails extends StatefulWidget {
  final AdvocateDetailsModel advocateDetailsModel;

  const AdvocateDetails({super.key, required this.advocateDetailsModel});

  @override
  State<AdvocateDetails> createState() => AdvocateDetailsState();
}

class AdvocateDetailsState extends State<AdvocateDetails> {
  int totalCases = 0;
  bool loading = true;
  List<PostResponse> posts = [];

  double averageRating = 0.0;
  int totalRatings = 0;
  int highestRating = 0;

  // ✅ Bookmark state
  bool _isBookmarked = false;
  bool _bookmarkBusy = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchTotalCases();
    loadPosts();
    fetchRatings();
    _loadBookmarkState(); // ✅ NEW
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // ✅ BOOKMARK LOGIC (snapshot-based, per-user)
  // ═══════════════════════════════════════════════════════════════════

  /// Load current bookmark state for this advocate.
  Future<void> _loadBookmarkState() async {
    final id = widget.advocateDetailsModel.id ?? '';
    if (id.isEmpty) return;

    final me = await AuthService.getUserId();
    BookmarkService.setCurrentUser(me);

    final saved = await BookmarkService.isBookmarked(id);
    if (!mounted) return;
    setState(() => _isBookmarked = saved);
  }

  /// Toggle bookmark — saves a full snapshot (including profile image).
  Future<void> _toggleBookmark() async {
    if (_bookmarkBusy) return;

    final model = widget.advocateDetailsModel;
    final id = model.id ?? '';
    if (id.isEmpty) return;

    final me = await AuthService.getUserId();
    BookmarkService.setCurrentUser(me);

    setState(() => _bookmarkBusy = true);

    try {
      final currentlySaved = await BookmarkService.isBookmarked(id);

      // ---- REMOVE ----
      if (currentlySaved) {
        await BookmarkService.remove(id);

        if (!mounted) return;
        setState(() {
          _isBookmarked = false;
          _bookmarkBusy = false;
        });
        _showSnack('Removed from bookmarks', false);
        return;
      }

      // ---- ADD ----
      Uint8List? imageBytes;
      try {
        imageBytes = await fetchProfileImage();
      } catch (_) {}

      final snapshot = SavedAdvocateSnapshot(
        id: id,
        userId: model.userId,
        name: model.name,
        fullName: model.fullName,
        profileImageId: model.profileImageId,
        advocateSpeciality:
            model.advocateSpeciality.map((e) => e.toString()).toList(),
        locationName: model.locationName,
        district: model.district,
        experience: model.experience,
        profileImageBytes: imageBytes,
      );

      await BookmarkService.add(snapshot);

      if (!mounted) return;
      setState(() {
        _isBookmarked = true;
        _bookmarkBusy = false;
      });
      _showSnack('Saved to bookmarks', true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bookmarkBusy = false);
      _showSnack('Bookmark failed: $e', false);
    }
  }

  void _showSnack(String msg, bool positive) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            positive ? Colors.green.shade600 : Colors.grey.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EXISTING FETCH LOGIC
  // ═══════════════════════════════════════════════════════════════════

  Future<void> fetchRatings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final response = await http.get(
      Uri.parse(
        "${BASE_URL.Urls().baseURL}advocate-rating/advocate/${widget.advocateDetailsModel.id}",
      ),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      List data = [];

      if (decoded is List) {
        data = decoded;
      } else if (decoded["data"] != null) {
        data = decoded["data"];
      }

      if (data.isEmpty) return;

      int sum = 0;
      int maxRating = 0;

      for (var r in data) {
        int rating = r["rating"] ?? 0;
        sum += rating;
        if (rating > maxRating) maxRating = rating;
      }

      setState(() {
        totalRatings = data.length;
        averageRating = sum / data.length;
        highestRating = maxRating;
      });
    }
  }

  Future<List?> fetchTotalCases() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    print("advocate id :- ${widget.advocateDetailsModel.id}");

    final response = await http.get(
      Uri.parse(
        "${baseURL.Urls().baseURL}case/advocate/${widget.advocateDetailsModel.id}",
      ),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return decoded.map((e) => CaseModel.fromJson(e)).toList();
      }

      if (decoded["data"] != null) {
        var list = (decoded["data"] as List)
            .map((e) => CaseModel.fromJson(e))
            .toList();

        setState(() {
          totalCases = list.length;
        });

        return list;
      }

      return [];
    }
    return null;
  }

  Future<void> loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final data = await PostService.fetchSpecificAdvocatesPosts(
      widget.advocateDetailsModel.id,
      token,
    );
    setState(() {
      posts = data;
      posts = posts.reversed.toList();
      loading = false;
    });
  }

  /// ================= PROFILE IMAGE =================
  Future<Uint8List?> fetchProfileImage() async {
    final imageId = widget.advocateDetailsModel.profileImageId;
    if (imageId == null || imageId.isEmpty) return null;

    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}user/download/$imageId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  /// ================= CV FETCH =================
  Future<Uint8List?> fetchCv() async {
    final token = await AuthService.getToken();
    final userId = widget.advocateDetailsModel.userId;

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}advocate/cv/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

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

  void downloadPdfWeb(List<int> bytes) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "file.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> downloadPdfMobile(List<int> bytes) async {
    final dir = await getTemporaryDirectory();

    final file = File('${dir.path}/advocate_cv.pdf');

    await file.writeAsBytes(bytes, flush: true);

    await OpenFilex.open(file.path);
  }

  /// ================= OPEN CV =================
  Future<void> downloadAndOpenCV() async {
    final token = await AuthService.getToken();
    final userId = widget.advocateDetailsModel.userId;

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}advocate/cv/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No CV available")));
      return;
    }

    final bytes = response.bodyBytes;

    // 🌐 WEB
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute("download", "advocate_cv.pdf")
        ..click();

      html.Url.revokeObjectUrl(url);
      return;
    }

    // 📱 MOBILE
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/advocate_cv.pdf');

    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }

  Future<bool> isMyAdvocate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final userId = prefs.getString('userId') ?? '';

    final centerAdminResponse = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}center-admin/by-user/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (centerAdminResponse.statusCode == 200) {
      final centerAdminBody = jsonDecode(centerAdminResponse.body);
      final advocateIds = centerAdminBody["advocates"] as List<dynamic>;

      return advocateIds.contains(widget.advocateDetailsModel.id);
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Advocate Details"),
        backgroundColor: Colors.white70,
        centerTitle: true,
        actions: [
          // ✅ Bookmark icon in app bar
          IconButton(
            tooltip: _isBookmarked ? "Remove bookmark" : "Bookmark",
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color:
                  _isBookmarked ? Colors.red.shade400 : Colors.grey.shade700,
            ),
            onPressed: _bookmarkBusy ? null : _toggleBookmark,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// ================= PROFILE =================
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      FutureBuilder<Uint8List?>(
                        future: fetchProfileImage(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircleAvatar(
                              radius: 55,
                              child: Icon(Icons.person, size: 55),
                            );
                          }

                          return CircleAvatar(
                            radius: 55,
                            backgroundImage: MemoryImage(snapshot.data!),
                          );
                        },
                      ),

                      // ✅ Floating bookmark button on the profile image
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 3,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _bookmarkBusy ? null : _toggleBookmark,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                _isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: _isBookmarked
                                    ? Colors.red.shade400
                                    : Colors.grey.shade700,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    widget.advocateDetailsModel.name ?? "Unknown Advocate",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "${widget.advocateDetailsModel.experience ?? 0} years experience",
                    style: TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    "$totalCases cases is fighting by ${widget.advocateDetailsModel.name} now",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            _section("Contact Information", [
              _row(Icons.email, widget.advocateDetailsModel.email),
              _row(Icons.phone, widget.advocateDetailsModel.phone),
            ]),

            _section("Location", [
              _row(Icons.location_on, widget.advocateDetailsModel.locationName),
              _row(Icons.map, "Lat: ${widget.advocateDetailsModel.lattitude}"),
              _row(
                Icons.map_outlined,
                "Lng: ${widget.advocateDetailsModel.longitude}",
              ),
            ]),

            _section("District", [
              _row(Icons.location_on, widget.advocateDetailsModel.district),
              //_row(Icons.map, "Lat: ${widget.advocateDetailsModel.lattitude}"),
              /*_row(
                Icons.map_outlined,
                "Lng: ${widget.advocateDetailsModel.longitude}",
              ),*/
            ]),

            _section("Professional Info", [
              _row(
                Icons.badge,
                "License: ${widget.advocateDetailsModel.licenseKey}",
              ),
            ]),

            _listSection(
              "Specialities",
              (widget.advocateDetailsModel.advocateSpeciality).cast<String>(),
            ),

            _listSection(
              "Degrees",
              (widget.advocateDetailsModel.degrees).cast<String>(),
            ),

            _listSection(
              "Working Experience",
              (widget.advocateDetailsModel.workingExperiences).cast<String>(),
            ),

            const SizedBox(height: 20),

            if (posts.isNotEmpty)
              SizedBox(
                height: 360,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: 300,
                      child: Card(
                        child: SingleChildScrollView(
                          child: PostCard(post: posts[index], canReact: false),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  buildStarRating(averageRating),

                  const SizedBox(height: 6),

                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  Text(
                    "$totalRatings ratings",
                    style: const TextStyle(color: Colors.black),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Highest rating: $highestRating",
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
            ),

            /// ================= CV BUTTON =================
            ElevatedButton.icon(
              onPressed: downloadAndOpenCV,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("View CV"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// ================= CASE REQUEST BUTTON =================
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                final token = prefs.getString('jwt_token') ?? '';
                final userId = prefs.getString('userId') ?? '';

                Navigator.push(
                  context,
                  NavigatorPageRoute.MaterialPageRoute(
                    builder: (context) => AddCaseRequestPage(
                      userId: userId,
                      specialRequestedAdvocate:
                          widget.advocateDetailsModel.id,
                    ),
                  ),
                );
              },
              child: const Text(
                "Send Case request",
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// ================= CHAT BUTTON =================
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                final token = prefs.getString('jwt_token') ?? '';
                final userId = prefs.getString('userId') ?? '';
                final myName = await getNameFromUser(userId);

                Navigator.push(
                  context,
                  NavigatorPageRoute.MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      otherUser: widget.advocateDetailsModel.userId ?? '',
                      othersName: widget.advocateDetailsModel.name ?? '',
                      currentUser: userId,
                      myName: myName ?? '',
                    ),
                  ),
                );
              },
              child: Text(
                "Chat with ${widget.advocateDetailsModel.name}",
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// ================= BOOKMARK BUTTON =================
            // ✅ NEW: same as user panel — full-width outlined button.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isBookmarked
                      ? Colors.red.shade600
                      : Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  side: BorderSide(
                    color: _isBookmarked
                        ? Colors.red.shade300
                        : Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
                onPressed: _bookmarkBusy ? null : _toggleBookmark,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isBookmarked
                          ? "Bookmarked"
                          : "Bookmark this Advocate",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// ================= REMOVE ADVOCATE BUTTON =================
            FutureBuilder<bool>(
              future: isMyAdvocate(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final isMyAdvocate = snapshot.data ?? false;

                if (isMyAdvocate) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () async {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      final token = prefs.getString('jwt_token') ?? '';
                      final userId = prefs.getString('userId') ?? '';

                      final advocateDeleteResponse = await http.delete(
                        Uri.parse(
                          "${baseURL.Urls().baseURL}advocate/delete/${widget.advocateDetailsModel.id}/$userId",
                        ),
                        headers: {
                          "Authorization": "Bearer $token",
                          "Content-Type": "application/json",
                        },
                      );

                      if (advocateDeleteResponse.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Advocate Removed")),
                        );

                        setState(() {
                          Navigator.pop(context);
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Advocate not removed...."),
                          ),
                        );
                      }
                    },
                    child: Text(
                      "Remove ${widget.advocateDetailsModel.name}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ================= UI HELPERS =================
  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value ?? "Not available",
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listSection(String title, List<String> items) {
    return _section(
      title,
      items.isEmpty
          ? [
              const Text(
                "No data available",
                style: TextStyle(color: Colors.red),
              ),
            ]
          : items.map((e) => _row(Icons.check_circle, e)).toList(),
    );
  }

  Widget buildStarRating(double rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 22);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 22);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 22);
        }
      }),
    );
  }
}
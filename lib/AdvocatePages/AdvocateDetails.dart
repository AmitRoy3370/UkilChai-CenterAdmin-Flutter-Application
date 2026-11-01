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
import '../CaseRelatedPages/AttachmentViewer.dart';
import 'advocate_additional_info_model.dart';
import 'advocate_working_experience_model.dart';
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

  // ========== অ্যাপবার ==========
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        "Advocate Profile",
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: _isBookmarked ? "Remove bookmark" : "Bookmark",
          icon: Icon(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: _isBookmarked ? Colors.red.shade400 : Colors.grey.shade700,
          ),
          onPressed: _bookmarkBusy ? null : _toggleBookmark,
        ),
      ],
    );
  }

  // ========== প্রোফাইল হেডার ==========
  Widget _buildProfileHeader() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade600, Colors.purple.shade600],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              children: [
                FutureBuilder<Uint8List?>(
                  future: fetchProfileImage(),
                  builder: (context, snapshot) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: snapshot.hasData
                            ? MemoryImage(snapshot.data!)
                            : null,
                        child: !snapshot.hasData
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey.shade400,
                              )
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  widget.advocateDetailsModel.fullName ??
                      widget.advocateDetailsModel.name ??
                      "Unknown Advocate",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.advocateDetailsModel.advocateSpeciality.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.advocateDetailsModel.advocateSpeciality.first,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildInfoChip(
                      icon: Icons.work_outline,
                      label:
                          "${widget.advocateDetailsModel.experience ?? 0} Years Experience",
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.cases,
                      label: "$totalCases Cases",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.white.withOpacity(0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _bookmarkBusy ? null : _toggleBookmark,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ========== স্ট্যাটাস কার্ড ==========
  Widget _buildStatsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.people_outline,
              value: totalCases.toString(),
              label: "Total Cases",
              color: Colors.blue,
            ),
            _buildStatItem(
              icon: Icons.star_outline,
              value: averageRating.toStringAsFixed(1),
              label: "Rating",
              color: Colors.amber,
            ),
            _buildStatItem(
              icon: Icons.work_outline,
              value: "${widget.advocateDetailsModel.experience ?? 0}y",
              label: "Experience",
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ========== ইনফো সেকশন ==========
  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required List<String> items,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty ||
              (items.length == 1 && items.first == "Not available"))
            Text(
              "No data available",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (title == 'Attachments') ...[
            _buildSectionTitle("Uploaded Documents"),
            _buildCard([
              for (var doc in items)
                InkWell(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString("jwt_token");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            title: const Text("Document Viewer"),
                          ),
                          body: CaseAttachmentView(
                            attachmentId: doc,
                            jwtToken: token ?? '',
                          ),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            doc,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
          ] else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: color.withOpacity(0.4), size: 6),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildWorkingExperienceInfoSection({
    required IconData icon,
    required String title,
    required AdvocateWorkingExperience advocateWorkingExperience,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (advocateWorkingExperience == null)
            Text(
              "No data available",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bar Association :- ${advocateWorkingExperience.barAssociation ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bar Controll enrollment :- ${advocateWorkingExperience.barControllEnrolment ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enrollment date :- ${advocateWorkingExperience.enrollmentDate ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Practicing court :- ${advocateWorkingExperience.practicingCoat ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Primary Practice :- ${advocateWorkingExperience.primaryPractice ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Legal Practice :- ${advocateWorkingExperience.yearOfLegalPractice ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Current chember :- ${advocateWorkingExperience.currentChemberName ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Professional experience :- ${advocateWorkingExperience.professionalExperience ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection({
    required IconData icon,
    required String title,
    required AdvocateAdditionalInfo advocateAdditionalInfo,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (advocateAdditionalInfo == null)
            Text(
              "No data available",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parmanent Adress :- ${advocateAdditionalInfo.parmanentAdress ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'City :- ${advocateAdditionalInfo.cityOfUpozila ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'nid :- ${advocateAdditionalInfo.nidNumber ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'DOB :- ${advocateAdditionalInfo.dateOfBirth ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Whatsapp :- ${advocateAdditionalInfo.whatsAppNumber ?? 'N/A'}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ========== পোস্ট সেকশন ==========
  Widget _buildPostsSection() {
    final ScrollController scrollController = ScrollController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.article_outlined,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Posts",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${posts.length} posts",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 400,
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 8,
            radius: const Radius.circular(10),
            interactive: true,
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 12),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      height: 370,
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PostCard(post: posts[index], canReact: false),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ========== রেটিং সেকশন ==========
  Widget _buildRatingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.amber.shade50, Colors.orange.shade50],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.amber.shade200.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                if (index < averageRating.floor()) {
                  return const Icon(Icons.star, color: Colors.amber, size: 28);
                } else if (index < averageRating) {
                  return const Icon(
                    Icons.star_half,
                    color: Colors.amber,
                    size: 28,
                  );
                } else {
                  return const Icon(
                    Icons.star_border,
                    color: Colors.amber,
                    size: 28,
                  );
                }
              }),
            ),
            const SizedBox(height: 8),
            Text(
              averageRating.toStringAsFixed(1),
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              "$totalRatings ratings • Highest: $highestRating",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== অ্যাকশন বাটন ==========
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // কেস রিকোয়েস্ট বাটন
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                shadowColor: Colors.green.shade300.withOpacity(0.4),
              ),
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                final userId = prefs.getString('userId') ?? '';

                Navigator.push(
                  context,
                  NavigatorPageRoute.MaterialPageRoute(
                    builder: (context) => AddCaseRequestPage(
                      userId: userId,
                      specialRequestedAdvocate: widget.advocateDetailsModel.id,
                    ),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    "Send Case Request",
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

          const SizedBox(height: 12),

          // Bookmark button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _isBookmarked
                    ? Colors.red.shade600
                    : Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                    _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isBookmarked ? "Bookmarked" : "Bookmark this Advocate",
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

          const SizedBox(height: 12),

          // CV button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(color: Colors.blue.shade300, width: 1.5),
              ),
              onPressed: downloadAndOpenCV,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    "View CV",
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

          const SizedBox(height: 12),

          // চ্যাট বাটন
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(color: Colors.purple.shade300, width: 1.5),
              ),
              onPressed: () async {
                SharedPreferences prefs =
                    await SharedPreferences.getInstance();
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    "Chat with ${widget.advocateDetailsModel.name?.split(' ').first ?? 'Advocate'}",
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

          const SizedBox(height: 12),

          // Remove advocate (only if my advocate)
          FutureBuilder<bool>(
            future: isMyAdvocate(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              if (snapshot.hasError) return const SizedBox.shrink();

              final isMyAdv = snapshot.data ?? false;
              if (!isMyAdv) return const SizedBox.shrink();

              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.red.shade200, width: 1.5),
                    ),
                    elevation: 0,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_remove, size: 22, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Text(
                        "Remove ${widget.advocateDetailsModel.name ?? 'Advocate'}",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildStatsCard(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildInfoSection(
                    icon: Icons.work_history,
                    title: "Working Experience",
                    items: widget.advocateDetailsModel.workingExperiences ?? const <String>[],
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),

                  if (widget.advocateDetailsModel.workingExperience != null) ...[
                    _buildWorkingExperienceInfoSection(
                      icon: Icons.work_history,
                      title: "Working Experience",
                      advocateWorkingExperience: widget.advocateDetailsModel.workingExperience!,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (widget.advocateDetailsModel.additionalInfo != null) ...[
                    _buildAdditionalInfoSection(
                      icon: Icons.info_outline,
                      title: "Additional information",
                      advocateAdditionalInfo: widget.advocateDetailsModel.additionalInfo!,
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (widget.advocateDetailsModel.advocateDocuments?.attachments != null &&
                      widget.advocateDetailsModel.advocateDocuments!.attachments!.isNotEmpty) ...[
                    _buildInfoSection(
                      icon: Icons.attach_file,
                      title: "Attachments",
                      items: widget.advocateDetailsModel.advocateDocuments!.attachments!
                          .map((e) => e.toString())
                          .toList(),
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                  ],

                  _buildInfoSection(
                    icon: Icons.location_on,
                    title: "Location",
                    items: [
                      widget.advocateDetailsModel.locationName ?? "Not available",
                    ],
                    color: Colors.green,
                  ),

                  const SizedBox(height: 16),

                  _buildInfoSection(
                    icon: Icons.place,
                    title: "District",
                    items: [
                      widget.advocateDetailsModel.district ?? "Not available",
                    ],
                    color: Colors.purple,
                  ),

                  const SizedBox(height: 16),

                  _buildInfoSection(
                    icon: Icons.star,
                    title: "Specialities",
                    items: widget.advocateDetailsModel.advocateSpeciality ?? const <String>[],
                    color: Colors.orange,
                  ),

                  const SizedBox(height: 16),

                  _buildInfoSection(
                    icon: Icons.school,
                    title: "Degrees",
                    items: widget.advocateDetailsModel.degrees ?? const <String>[],
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (posts.isNotEmpty) _buildPostsSection(),
            const SizedBox(height: 20),
            _buildRatingSection(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 30),
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
// lib/QuickConnect/QuickConnect.dart
// Center Admin — QuickConnect, layout matched to Admin panel.
// Click destinations preserved:
//   • Admin Dashboard (AdminDashboardPage)
//   • Chat with Expert (CenterAdminChatListScreen)
//   • Ask Question (AskQuestionPage)
//   • Cases (CaseHomePage)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/BaseURL.dart' as BASE_URL;

import 'QuickCard.dart';
import '../AdminsPage/AdminDashboardPage.dart';
import '../ChatRelatedPages/CenterAdminChatListScreen.dart';
import '../QuestionPages/AskQuestionPage.dart';
import '../CaseRelatedPages/CaseHomePage.dart';
import '../PageTransition.dart';

class QuickConnect extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;

  /// When true, the section tries to fill the remaining viewport space
  /// given by the parent via [remainingViewportHeight].
  final bool fillHeight;

  /// Explicit height to fill (in logical pixels). Used only when
  /// [fillHeight] is true.
  final double? remainingViewportHeight;

  const QuickConnect({
    super.key,
    required this.isDesktop,
    required this.isTablet,
    this.fillHeight = false,
    this.remainingViewportHeight,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenW = size.width;
    final screenH = size.height;

    // Grid config — same as admin panel
    const int columns = 2;
    const int rows = 2;

    final double crossSpacing = (screenW * 0.02).clamp(6, 12);
    final double mainSpacing  = (screenW * 0.015).clamp(5, 10);

    // Header metrics
    final double headerBarHeight  = (screenW * 0.055).clamp(20, 26);
    final double titleFontSize    = (screenW * 0.05).clamp(18, 24);
    final double subtitleFontSize = (screenW * 0.032).clamp(11, 14);
    final double titleRowHeight   = titleFontSize * 1.3;
    final double subtitleRowHeight = subtitleFontSize * 1.3;
    final double gapAfterTitle    = (screenW * 0.01).clamp(4, 8);
    final double gapBeforeGrid    = (screenW * 0.02).clamp(10, 16);

    final double effectiveHeaderHeight =
        titleRowHeight > headerBarHeight ? titleRowHeight : headerBarHeight;

    final double headerBlock = effectiveHeaderHeight +
        gapAfterTitle +
        subtitleRowHeight +
        gapBeforeGrid;

    // Card height decision
    late final double cardHeight;
    if (fillHeight && remainingViewportHeight != null) {
      final double gridArea = remainingViewportHeight! - headerBlock;
      cardHeight = ((gridArea - mainSpacing) / rows).clamp(160.0, 260.0);
    } else {
      cardHeight = (screenH * 0.20).clamp(160.0, 200.0);
    }

    final double? sectionHeight = fillHeight
        ? headerBlock + (cardHeight * rows) + mainSpacing
        : null;

    return SizedBox(
      height: sectionHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 4,
                height: headerBarHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: (screenW * 0.03).clamp(10, 14)),
              Text(
                "Quick Connect",
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: gapAfterTitle),
          Padding(
            padding: EdgeInsets.only(left: (screenW * 0.04).clamp(14, 18)),
            child: Text(
              "Get instant administrative assistance",
              style: GoogleFonts.inter(
                fontSize: subtitleFontSize,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          SizedBox(height: gapBeforeGrid),

          // Grid
          if (fillHeight)
            Expanded(
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: crossSpacing,
                  mainAxisSpacing: mainSpacing,
                  mainAxisExtent: cardHeight,
                ),
                children: _buildCards(context),
              ),
            )
          else
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: crossSpacing,
                mainAxisSpacing: mainSpacing,
                mainAxisExtent: cardHeight,
              ),
              children: _buildCards(context),
            ),
        ],
      ),
    );
  }

  // ── Card list — CENTER ADMIN destinations ──
  List<Widget> _buildCards(BuildContext context) => [
        QuickCard(
          icon: Icons.admin_panel_settings,
          title: "Admins",
          subtitle: "Manage admin dashboard",
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)], // Deep Navy
          ),
          onTap: () => _navigateWithTransition(
              context, const AdminDashboardPage()),
        ),
        QuickCard(
          icon: Icons.chat_bubble_outline,
          title: "Chat with Expert",
          subtitle: "15-min free consultation",
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)], // Royal Blue
          ),
          onTap: () async => _handleChatWithExpert(context),
        ),
        QuickCard(
          icon: Icons.help_outline_rounded,
          title: "Ask Question",
          subtitle: "Public Q&A with advocates",
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)], // Green
          ),
          onTap: () async => _handleAskQuestion(context),
        ),
        QuickCard(
          icon: Icons.calendar_month,
          title: "Cases",
          subtitle: "Schedule consultation",
          gradient: const LinearGradient(
            colors: [Color(0xFF4A148C), Color(0xFF311B92)], // Deep Purple
          ),
          onTap: () async => _handleCases(context),
        ),
      ];

  // ── Handlers — same logic as before ──
  Future<void> _navigateWithTransition(
      BuildContext context, Widget page) async {
    NavigationHelper.push(
      context,
      page,
      transitionType: await AnimatedRoute.getRandomSafeAnimation(),
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _handleChatWithExpert(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString("userId") ?? "";
    String token = prefs.getString("jwt_token") ?? "";

    if (userId.isEmpty || token.isEmpty) {
      _showLoginRequired(context);
      return;
    }

    final response = await http.get(
      Uri.parse('${BASE_URL.Urls().baseURL}user/search?userId=$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _navigateWithTransition(
        context,
        CenterAdminChatListScreen(
          currentUserId: userId,
          currentUserName: data['name'] ?? "User",
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to fetch user data."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleAskQuestion(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString("userId") ?? "";

    if (userId.isEmpty) {
      _showLoginRequired(context);
      return;
    }

    _navigateWithTransition(context, AskQuestionPage(userId: userId));
  }

  Future<void> _handleCases(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString("userId") ?? "";

    if (userId.isEmpty) {
      _showLoginRequired(context);
      return;
    }

    _navigateWithTransition(context, const CaseHomePage());
  }

  void _showLoginRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please log in to continue"),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
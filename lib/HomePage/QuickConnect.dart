// QuickConnect.dart - Center Admin (Redesigned)
import 'dart:convert';
import 'package:advocatechaicenteradmin/AdminsPage/AdminDashboardPage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../AdminsPage/SeeAllAdminJoinRequest.dart';
import '../Auth/AuthService.dart';
import '../CaseRelatedPages/CaseHomePage.dart';
import '../ChatRelatedPages/CenterAdminChatListScreen.dart';
import '../QuestionPages/AskQuestionPage.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import 'QuickCard.dart';

class QuickConnect extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;

  const QuickConnect({
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = isDesktop ? 1.1 : 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row with Gradient Bar
        Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Quick Connect",
              style: GoogleFonts.poppins(
                fontSize: isDesktop ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A237E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            "Get instant administrative assistance",
            style: GoogleFonts.inter(
              fontSize: isDesktop ? 16 : 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Animated Grid
        GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: isDesktop ? 24 : 16,
          mainAxisSpacing: isDesktop ? 24 : 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: [
            QuickCard(
              icon: Icons.admin_panel_settings,
              title: "Admins",
              subtitle: "Manage admin dashboard",
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF283593)], // Deep Navy
              ),
              onTap: () {
                print("Find Expert");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                );
              },
            ),
            QuickCard(
              icon: Icons.chat_bubble_outline,
              title: "Chat with Expert",
              subtitle: "15-min free consultation",
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)], // Royal Blue
              ),
              onTap: () async {
                print("Free Consult");
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String userId = prefs.getString("userId") ?? "";
                String token = prefs.getString("jwt_token") ?? "";

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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CenterAdminChatListScreen(
                        currentUserId: userId,
                        currentUserName: data['name'],
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('You need to log in first to fetch the data....'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            QuickCard(
              icon: Icons.help_outline_rounded,
              title: "Ask Question",
              subtitle: "Public Q&A with advocates",
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)], // Professional Green
              ),
              onTap: () async {
                print("Ask Question");
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String userId = prefs.getString("userId") ?? "";
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AskQuestionPage(userId: userId),
                  ),
                );
              },
            ),
            QuickCard(
              icon: Icons.calendar_month,
              title: "Cases",
              subtitle: "Schedule consultation",
              gradient: const LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF311B92)], // Deep Purple
              ),
              onTap: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String userId = prefs.getString("userId") ?? "";
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CaseHomePage()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
import 'package:advocatechaicenteradmin/HomePage/AdvocateList.dart';
import 'package:advocatechaicenteradmin/HomePage/QuickConnect.dart';
import 'package:advocatechaicenteradmin/PostRelatedPages/post_feed_page_home_page.dart';
import 'package:advocatechaicenteradmin/PostRelatedPages/post_feed_page.dart';
import 'package:advocatechaicenteradmin/AdvocatePages/AdvocateHomePage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'LifeCycles/PresenceSocketService.dart';
import 'package:http/http.dart' as http;
import '../Utils/BaseURL.dart' as BASE_URL;
import '../Auth/AuthService.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<StatefulWidget> createState() {
    return HomeScreenState();
  }
}

class HomeScreenState extends State<Homepage> {


  Timer? _heartbeatTimer;


  @override
  void initState() {
    super.initState();
    heartbit();

  }

  Future<void> heartbit() async {

      final userId = await AuthService.getUserId();

      if(userId != null) {

         _startHeartbeat(userId!);

      }

  }

  void _startHeartbeat(String userId) {
    _heartbeatTimer = Timer.periodic(
    const Duration(seconds: 20),
    (timer) async {
       try {
      // ✅ Direct heartbeat by userId
      final url = Uri.parse("${BASE_URL.Urls().baseURL}user-active/heartbeat/$userId");
      
      final token = await AuthService.getToken();

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        //_lastHeartbeatTime = DateTime.now();
        //print("💓 Heartbeat sent at ${_lastHeartbeatTime?.toLocal()}");
      } else {
        print("❌ Heartbeat failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Heartbeat error: $e");
    }
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final isTablet = screenWidth > 600 && screenWidth <= 800;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A237E).withOpacity(0.05), // Navy tint
            Colors.white,
            const Color(0xFF1A237E).withOpacity(0.05),
          ],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        color: const Color(0xFF1A237E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
              vertical: 20,
            ),
            child: Column(
              children: [
                _buildWelcomeBanner(context, isDesktop, isTablet),
                const SizedBox(height: 24),
                QuickConnect(
                  key: UniqueKey(),
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("Recent Legal Updates", Icons.newspaper),
                const SizedBox(height: 16),
                PostFeedPageHomePage(key: UniqueKey()),
                const SizedBox(height: 32),
                _buildSectionHeader("Featured Advocates", Icons.star),
                const SizedBox(height: 16),
                AdvocateList(key: UniqueKey()),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 24,
        vertical: isDesktop ? 32 : 24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A237E), // Deep Navy
            Color(0xFF283593), // Indigo
            Color(0xFF3949AB), // Lighter Indigo
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Welcome to Center Admin",
                  style: GoogleFonts.poppins(
                    fontSize: isDesktop ? 28 : (isTablet ? 24 : 20),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Manage and oversee all legal activities from a centralized dashboard. Connect with advocates, track cases, and ensure smooth operations.",
            style: GoogleFonts.inter(
              fontSize: isDesktop ? 16 : 14,
              color: Colors.white.withOpacity(0.95),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1A237E),
                Color(0xFF283593),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A237E),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            if (title == 'Featured Advocates') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvocateHomePage()),
              );
            } else if (title == 'Recent Legal Updates') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostFeedPage()),
              );
            }
          },
          child: Text(
            "See All",
            style: GoogleFonts.inter(
              color: const Color(0xFF1A237E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
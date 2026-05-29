import 'package:advocatechaicenteradmin/Auth/AuthService.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../CaseRelatedPages/AddCaseRequestPage.dart';
import 'MyCasesPage.dart';
import 'SeeAllCases.dart';
import 'SeeMyCaseRequest.dart';
import 'case_request_list_page.dart';
import '../PageTransition.dart';

class CaseHomePage extends StatelessWidget {
  const CaseHomePage({super.key});

  // Get random transition type
  Future<PageTransitionType> _getRandomTransition() async {
    return await AnimatedRoute.getRandomSafeAnimation();
  }

  // Navigate with random transition
  Future<void> _navigateWithRandomTransition(BuildContext context, Widget page) async {
    NavigationHelper.push(
      context,
      page,
      transitionType: await _getRandomTransition(),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          "Legal Cases",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E), // Deep Navy
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A237E), // Deep Navy
                Color(0xFF283593), // Indigo
                Color(0xFF3949AB), // Lighter Indigo
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A237E).withOpacity(0.05),
              Colors.white,
              const Color(0xFF1A237E).withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Welcome Card
                _buildWelcomeCard(),
                const SizedBox(height: 24),

                // Case Options Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildAnimatedCaseCard(
                        context,
                        title: "Add Case Request",
                        icon: Icons.add_circle_outline,
                        color: Colors.blue,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)], // Royal Blue
                        ),
                        onTap: () {
                          SharedPreferences.getInstance().then((prefs) {
                            String userId = prefs.getString('userId') ?? '';
                            _navigateWithRandomTransition(
                              context,
                              AddCaseRequestPage(userId: userId),
                            );
                          });
                        },
                      ),
                      _buildAnimatedCaseCard(
                        context,
                        title: "All Requests",
                        icon: Icons.list_alt,
                        color: Colors.green,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)], // Professional Green
                        ),
                        onTap: () {
                          _navigateWithRandomTransition(
                            context,
                            const CaseRequestListPage(),
                          );
                        },
                      ),
                      _buildAnimatedCaseCard(
                        context,
                        title: "My Requests",
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE65100), Color(0xFFBF360C)], // Deep Orange
                        ),
                        onTap: () {
                          _navigateWithRandomTransition(
                            context,
                            const SeeMyCaseRequestsPage(),
                          );
                        },
                      ),
                      _buildAnimatedCaseCard(
                        context,
                        title: "My Cases",
                        icon: Icons.gavel,
                        color: Colors.purple,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A148C), Color(0xFF311B92)], // Deep Purple
                        ),
                        onTap: () {
                          SharedPreferences.getInstance().then((prefs) {
                            String userId = prefs.getString('userId') ?? '';
                            _navigateWithRandomTransition(
                              context,
                              MyCasesPage(userId: userId),
                            );
                          });
                        },
                      ),
                      _buildAnimatedCaseCard(
                        context,
                        title: "All Cases",
                        icon: Icons.folder_open,
                        color: Colors.teal,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00695C), Color(0xFF004D40)], // Deep Teal
                        ),
                        onTap: () {
                          _navigateWithRandomTransition(
                            context,
                            const SeeAllCasesPage(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A237E), // Deep Navy
            Color(0xFF283593), // Indigo
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Center Admin Case Management",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage and oversee all legal cases",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCaseCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Click",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// main.dart - Center Admin (structure matched to Admin panel)

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'AdvocatePages/AdvocateFilterPage.dart';
import 'AdvocatePages/AdvocateHomePage.dart';
import 'ChatRelatedPages/AllUserChatListScreen.dart';
import 'ChatRelatedPages/user_active_service.dart';
import 'GroupChat/GroupChatListScreen.dart';
import 'HomePage.dart';
import 'LifeCycles/LifecycleManager.dart';
import 'LogInPage/LogIn.dart';
import 'NotificationPages/notification_page.dart';
import 'NotificationPages/notification_service.dart';
import 'NotificationPages/notification_socket_service.dart';
import 'PostRelatedPages/post_feed_page.dart';
import 'ProfilePage/ProfileAvatar.dart';
import 'ProfilePage/ProfileImageWidget.dart';
import 'ProfilePage/ProfileMenuPage.dart';
import 'Utils/BaseURL.dart' as BASE_URL;
import 'TermsAndPrivacyScreen.dart';
import 'AboutUkilScreen.dart';
import 'PageTransition.dart';
import 'splash_screen.dart';
import 'welcome_popup.dart';
import 'package:provider/provider.dart';


// ── Director / Shareholder / Company pages ──
import 'DirectorsPages/director_list_page.dart';
import 'ShareholderPages/shareholder_list_page.dart';
import 'CompanyPages/company_registration_screen.dart';
import 'CompanyPages/my_company_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: LifecycleManager(child: MyApp()),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'উকিল - Center Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'উকিল Center Admin'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String? userId, userName, directorId, shareHolderId;
  final String title;

  const MyHomePage({
    super.key,
    required this.title,
    this.userId,
    this.userName,
    this.directorId,
    this.shareHolderId,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late List<Widget> bottomPages = [];
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  Timer? _heartbeatTimer;

  String? _userId;
  String? _userName;
  String? _directorId;
  String? _shareHolderId;
  int unreadCount = 0;
  bool _isOnline = false;
  final NotificationSocketService socketService = NotificationSocketService();

  // Welcome popup state
  bool _hasCheckedWelcomePopup = false;
  static const String _welcomeShownKey = 'welcome_popup_shown';

  // ============================================================
  // Public — refresh user data (used by logout handlers, etc.)
  // ============================================================
  Future<void> refreshUserData() async {
    print("Refreshing center admin user data...");
    await _loadUserData();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (!mounted) return;

    setState(() {
      if (userId == null || userId.isEmpty) {
        _userId = null;
        _userName = null;
        _isOnline = false;

        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;

        bottomPages = _buildPages(isLoggedIn: false);
        _selectedIndex = 0;
      } else {
        bottomPages = _buildPages(isLoggedIn: true);
      }
    });
  }

  // ============================================================
  // Page list
  // ============================================================
  List<Widget> _buildPages({required bool isLoggedIn}) {
    return [
      HomePage(key: UniqueKey()),
      PostFeedPage(key: UniqueKey()),
      AdvocateFilterPage(key: UniqueKey()),
      AllUserChatListScreen(
        key: UniqueKey(),
        currentUserId: _userId,
        currentUserName: _userName,
      ),
      LogIn(key: UniqueKey()),
    ];
  }

  // ============================================================
  // Load user data
  // ============================================================
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final token = prefs.getString('jwt_token');
    final directorId = prefs.getString('directorId');
    final shareHolderId = prefs.getString('shareHolderId');

    if (userId != null && token != null && userId.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse("${BASE_URL.Urls().baseURL}user/search?userId=$userId"),
          headers: {
            'content-type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (!mounted) return;
          setState(() {
            _userId = userId;
            _userName = (data['fullName'] ?? data['name']) ?? "Center Admin";
            _directorId = directorId;
            _shareHolderId = shareHolderId;
          });
        }
      } catch (e) {
        print('Error loading user: $e');
      }
    }
  }

  // ============================================================
  // Presence + heartbeat
  // ============================================================
  void _startPresence() {
    if (_userId != null && _userId!.isNotEmpty) {
      _startHeartbeat(_userId!);
      if (mounted) {
        setState(() {
          _isOnline = true;
        });
      }
      print('🟢 Center Admin is now ONLINE');
    }
  }

  void _startHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 20),
      (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        try {
          final url = Uri.parse(
              "${BASE_URL.Urls().baseURL}user-active/heartbeat/$userId");
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token');

          final response = await http.put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode != 200) {
            print("❌ Heartbeat failed: ${response.statusCode}");
          }
        } catch (e) {
          print("❌ Heartbeat error: $e");
        }
      },
    );
  }

  void setUserActive(bool active) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      String? userId = prefs.getString('userId');
      if (userId != null) {
        final response = await http.get(
          Uri.parse("${BASE_URL.Urls().baseURL}user-active/user/$userId"),
          headers: {
            'content-type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          await UserActiveService.updateUserActive(
            body["id"],
            userId,
            active,
            token,
          );
        } else {
          await UserActiveService.addUserActive(userId, active, token);
        }
      }
    } catch (e) {
      print(e);
    }
  }

  // ============================================================
  // Notification socket
  // ============================================================
  Future<void> initNotificationSocket() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('userId');

    if (id != null && id.isNotEmpty) {
      socketService.connect(id, (data) {
        showNotificationSnack(data["message"]);
      });

      String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}notifications/unread/$id"),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          unreadCount = jsonDecode(response.body).length;
        });
      }
    }
  }

  void showNotificationSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // ============================================================
  // Init
  // ============================================================
  @override
  void initState() {
    super.initState();
    if (widget.userId != null) _userId = widget.userId;
    if (widget.userName != null) _userName = widget.userName;
    if (widget.directorId != null) _directorId = widget.directorId;
    if (widget.shareHolderId != null) _shareHolderId = widget.shareHolderId;

    _initializeData();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final splashStart = DateTime.now();

    await Future.wait([
      _loadUserData().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('⚠️ _loadUserData timeout');
        },
      ),
      initNotificationSocket().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('⚠️ initNotificationSocket timeout');
        },
      ),
    ]);

    final elapsed = DateTime.now().difference(splashStart);
    const minDuration = Duration(seconds: 2);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    if (!mounted) return;

    setState(() {
      bottomPages = _buildPages(isLoggedIn: _userId != null);
      isLoading = false;
    });

    if (_userId != null && _userId!.isNotEmpty) {
      _startPresence();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomePopupIfFirstTime();
    });
  }

  // ============================================================
  // Welcome popup
  // ============================================================
  Future<void> _showWelcomePopupIfFirstTime() async {
    if (_hasCheckedWelcomePopup) return;
    _hasCheckedWelcomePopup = true;

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool(_welcomeShownKey) ?? false;

      if (alreadyShown) {
        if (kDebugMode) {
          print('ℹ️ Welcome popup already shown — skipping');
        }
        return;
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WelcomePopup(
          onContinue: () async {
            final p = await SharedPreferences.getInstance();
            await p.setBool(_welcomeShownKey, true);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          onSkip: () async {
            final p = await SharedPreferences.getInstance();
            await p.setBool(_welcomeShownKey, true);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Welcome popup error: $e');
      }
    }
  }

  // ============================================================
  // Drawer action helpers
  // ============================================================
  Future<void> _openAllDirectors() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LogIn()),
      );
      if (result == true && mounted) await refreshUserData();
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DirectorListPage()),
    );
  }

  Future<void> _openAllShareholders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LogIn()),
      );
      if (result == true && mounted) await refreshUserData();
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShareholderListPage()),
    );
  }

  Future<void> _openCompanyRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LogIn()),
      );
      if (result == true && mounted) await refreshUserData();
      return;
    }

    final userId = prefs.getString('userId');
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyRegistrationScreen(userId: userId),
      ),
    );
  }

  Future<void> _openMyCompanies() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LogIn()),
      );
      if (result == true && mounted) await refreshUserData();
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyCompanyPage()),
    );
  }

  Future<void> _openGroupChats() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LogIn()),
      );
      if (result == true && mounted) await refreshUserData();
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GroupChatListScreen()),
    );
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          "Center Admin",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A237E),
                Color(0xFF283593),
                Color(0xFF3949AB),
              ],
            ),
          ),
        ),
        actions: [
          // Notification bell with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  setState(() {
                    unreadCount = 0;
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationPage()),
                  );
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Profile avatar (only when logged in)
          if (_userId != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileMenuPage()),
                  );
                  if (result == true) {
                    await refreshUserData();
                  }
                },
                child: ProfileImageWidget(
                  key: ValueKey(_userId),
                ),
              ),
            ),
        ],
      ),

      // ============================================================
      // DRAWER
      // ============================================================
      drawer: Drawer(
        width: 280,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A237E),
                Color(0xFF283593),
                Color(0xFF3949AB),
              ],
            ),
          ),
          child: Column(
            children: [
              _buildModernDrawerHeader(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ── MAIN TABS ──
                    _buildModernDrawerItem(
                      icon: Icons.home,
                      title: "Home",
                      index: 0,
                    ),
                    _buildModernDrawerItem(
                      icon: Icons.article,
                      title: "Posts",
                      index: 1,
                    ),
                    _buildModernDrawerItem(
                      icon: Icons.person,
                      title: "Advocates",
                      index: 2,
                    ),
                    _buildModernDrawerItem(
                      icon: Icons.chat,
                      title: "Chats",
                      index: 3,
                    ),

                    // ── GROUP CHATS ──
                    _buildModernDrawerItem(
                      icon: Icons.groups,
                      title: "Group Chats",
                      index: 15,
                    ),

                    const Divider(
                        color: Colors.white38, height: 20, thickness: 1),

                    // ── LIST VIEWS ──
                    _buildModernDrawerItem(
                      icon: Icons.people,
                      title: "All Directors",
                      index: 7,
                    ),
                    _buildModernDrawerItem(
                      icon: Icons.people_outline,
                      title: "All Shareholders",
                      index: 8,
                    ),

                    const Divider(
                        color: Colors.white38, height: 20, thickness: 1),

                    // ── COMPANY SECTION ──
                    _buildModernDrawerItem(
                      icon: Icons.business,
                      title: "Company Registration",
                      index: 13,
                    ),
                    _buildModernDrawerItem(
                      icon: Icons.business_center,
                      title: "My Companies",
                      index: 14,
                    ),

                    const Divider(
                        color: Colors.white38, height: 20, thickness: 1),

                    // ── ABOUT & TERMS ──
                    _buildModernDrawerItem(
                      icon: Icons.info_outline,
                      title: "About Ukil",
                      index: 11,
                    ),
                    _buildModernDrawerItem(
                      icon: Icons.description,
                      title: "Terms & Privacy",
                      index: 12,
                    ),

                    const Divider(
                        color: Colors.white38, height: 20, thickness: 1),

                    // ── PROFILE / LOGIN ──
                    _buildModernDrawerItem(
                      icon: _userId != null ? Icons.person : Icons.login,
                      title: _userId != null ? "Profile" : "Login",
                      index: 4,
                    ),
                  ],
                ),
              ),
              _buildModernFooter(),
            ],
          ),
        ),
      ),

      body: isLoading
          ? const SplashScreen()
          : (bottomPages.isNotEmpty && _selectedIndex < bottomPages.length)
              ? bottomPages[_selectedIndex]
              : const SplashScreen(),
    );
  }

  // ============================================================
  // Drawer header
  // ============================================================
  Widget _buildModernDrawerHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        children: [
          Hero(
            tag: 'profileHero',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: _userId != null
                      ? ProfileAvatar(key: ValueKey(_userId))
                      : const Icon(
                          Icons.admin_panel_settings,
                          size: 50,
                          color: Color(0xFF1A237E),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _userName ?? "Center Admin",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _userId != null
                  ? (_isOnline ? "Online" : "Administrator")
                  : "Not Logged In",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    // Special pages — never highlight as a tab
    final isSpecialPage = (index == 7 ||
        index == 8 ||
        index == 11 ||
        index == 12 ||
        index == 13 ||
        index == 14 ||
        index == 15);
    final isSelected = isSpecialPage ? false : (_selectedIndex == index);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.arrow_forward_ios,
                color: Colors.white, size: 16)
            : null,
        onTap: () {
          _onItemTapped(index);
        },
      ),
    );
  }

  Widget _buildModernFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle,
                  color: Colors.white.withOpacity(0.5), size: 8),
              const SizedBox(width: 4),
              Icon(Icons.circle,
                  color: Colors.white.withOpacity(0.5), size: 8),
              const SizedBox(width: 4),
              Icon(Icons.circle,
                  color: Colors.white.withOpacity(0.5), size: 8),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "© ${DateTime.now().year} Ukil Center Admin",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Drawer tap handler
  // ============================================================
  void _onItemTapped(int newIndex) async {
    // About Ukil
    if (newIndex == 11) {
      Navigator.pop(context);
      await NavigationHelper.push(
        context,
        const AboutUkilScreen(),
        transitionType: await AnimatedRoute.getRandomSafeAnimation(),
        duration: const Duration(milliseconds: 500),
      );
      return;
    }

    // Terms & Privacy
    if (newIndex == 12) {
      Navigator.pop(context);
      await NavigationHelper.push(
        context,
        const TermsAndPrivacyScreen(),
        transitionType: await AnimatedRoute.getRandomSafeAnimation(),
        duration: const Duration(milliseconds: 500),
      );
      return;
    }

    // All Directors
    if (newIndex == 7) {
      Navigator.pop(context);
      await _openAllDirectors();
      return;
    }

    // All Shareholders
    if (newIndex == 8) {
      Navigator.pop(context);
      await _openAllShareholders();
      return;
    }

    // Company Registration
    if (newIndex == 13) {
      Navigator.pop(context);
      await _openCompanyRegistration();
      return;
    }

    // My Companies
    if (newIndex == 14) {
      Navigator.pop(context);
      await _openMyCompanies();
      return;
    }

    // Group Chats
    if (newIndex == 15) {
      Navigator.pop(context);
      await _openGroupChats();
      return;
    }

    // Profile / Login
    if (newIndex == 4) {
      Navigator.pop(context);

      if (_userId != null && _userId!.isNotEmpty) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileMenuPage()),
        );
        if (result == true) {
          await refreshUserData();
        }
      } else {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogIn()),
        );

        if (result == true && mounted) {
          await Future.delayed(const Duration(milliseconds: 300));
          await refreshUserData();
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Welcome Center Admin! You have successfully logged in."),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      return;
    }

    // Main tab navigation (indices 0, 1, 2, 3)
    if (newIndex >= 0 && newIndex < bottomPages.length) {
      setState(() {
        _selectedIndex = newIndex;
      });
    }
    Navigator.pop(context);
  }
}
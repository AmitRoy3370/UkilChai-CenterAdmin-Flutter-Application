// lib/ProfilePage/ProfileMenuPage.dart
//
// Center Admin Profile Menu — full port of the user panel's ProfileHubPage.
// Every click opens the SAME page as the user panel.
// Districts removed; Delete Advocates / Delete Admins added for center admins.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASEURL;
import 'ProfileImageWidget.dart';
import 'SeeMyProfile.dart';
import 'UpdateProfile.dart';

// ── Exactly the same imports as the user panel ─────────────────────────────
import '../CaseRelatedPages/CaseHomePage.dart';
import '../AboutUkilScreen.dart';
import '../ChatRelatedPages/FreeConsultantPage.dart';
import '../QuestionPages/MyQuestionsPage.dart';
import '../AdvocatePages/BookmarkService.dart';
import '../AdvocatePages/SavedAdvocatesPage.dart';
import '../DirectorsPages/director_service.dart';
import '../DirectorsPages/director_response.dart';
import '../DirectorsPages/DirectorRegistrationScreen.dart';
import '../DirectorsPages/director_profile_page.dart';

// ─── Design tokens (identical to user panel) ────────────────────────────────
class _C {
  static const forest      = Color(0xFF1A3C2B);
  static const mid         = Color(0xFF2D6A4F);
  static const sage        = Color(0xFF52B788);
  static const frost       = Color(0xFFF0F7F3);
  static const ivory       = Color(0xFFFAFAF8);
  static const ink         = Color(0xFF111B17);
  static const slate       = Color(0xFF4B5563);
  static const mist        = Color(0xFF9CA3AF);
  static const line        = Color(0xFFE4EBE7);
  static const danger      = Color(0xFFDC2626);
  static const dangerPale  = Color(0xFFFEF2F2);
  static const warn        = Color(0xFF92400E);
  static const warnPale    = Color(0xFFFFFBEB);
  static const success     = Color(0xFF065F46);
  static const successPale = Color(0xFFECFDF5);
}

// ─── Safe helpers (dart2js-safe) ─────────────────────────────────────────────
String _s(dynamic v) {
  try {
    if (v == null) return '';
    if (v is String) return v;
    if (v is num) return v.toString();
    if (v is bool) return v.toString();
    if (v is Map || v is List) return jsonEncode(v);
    final s = v.toString();
    return s == 'null' ? '' : s;
  } catch (_) {
    return '';
  }
}

double? _toDouble(dynamic v) {
  try {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
  } catch (_) {}
  return null;
}

Map<String, dynamic> _asMap(dynamic v) {
  try {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
  } catch (_) {}
  return const {};
}

// ─── Current-user model ─────────────────────────────────────────────────────
class _AdminUser {
  final String id;
  final String name;
  final String fullName;
  final String profileImageId;
  final String email;
  final String phone;
  final double? lattitude;
  final double? longitude;
  final String locationName;

  _AdminUser({
    required this.id,
    required this.name,
    required this.fullName,
    required this.profileImageId,
    required this.email,
    required this.phone,
    this.lattitude,
    this.longitude,
    this.locationName = '',
  });

  factory _AdminUser.fromApis({
    Map<String, dynamic>? user,
    Map<String, dynamic>? contact,
    Map<String, dynamic>? location,
  }) {
    final u = _asMap(user);
    final c = _asMap(contact);
    final l = _asMap(location);

    return _AdminUser(
      id: _s(u['id']),
      name: _s(u['name']).trim(),
      fullName: _s(u['fullName']).trim(),
      profileImageId: _s(u['profileImageId']),
      email: _s(c['email']).trim(),
      phone: _s(c['phone']).trim(),
      lattitude: _toDouble(l['lattitude']),
      longitude: _toDouble(l['longitude']),
      locationName: _s(l['locationName']).trim(),
    );
  }

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (name.isNotEmpty) return name;
    return 'Center Admin';
  }
}

// ─── Center-admin info ──────────────────────────────────────────────────────
class _CenterAdminInfo {
  final String id;
  final String userName;
  final String fullName;
  final String profileImageId;
  final List<String> districts;
  final List<String> admins;
  final List<String> adminsName;
  final List<String> adminsFullName;
  final List<String> advocates;
  final List<String> advocatesName;
  final List<String> advocatesFullName;

  _CenterAdminInfo({
    required this.id,
    required this.userName,
    required this.fullName,
    required this.profileImageId,
    required this.districts,
    required this.admins,
    required this.adminsName,
    required this.adminsFullName,
    required this.advocates,
    required this.advocatesName,
    required this.advocatesFullName,
  });

  factory _CenterAdminInfo.fromMap(Map<String, dynamic> m) {
    List<String> safeList(dynamic v) {
      try {
        if (v is List) return v.map(_s).toList();
      } catch (_) {}
      return const <String>[];
    }

    return _CenterAdminInfo(
      id: _s(m['id']),
      userName: _s(m['userName']).trim(),
      fullName: _s(m['fullName']).trim(),
      profileImageId: _s(m['profileImageId']),
      districts: safeList(m['districts']),
      admins: safeList(m['admins']),
      adminsName: safeList(m['adminsName']),
      adminsFullName: safeList(m['adminsFullName']),
      advocates: safeList(m['advocates']),
      advocatesName: safeList(m['advocatesName']),
      advocatesFullName: safeList(m['advocatesFullName']),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Root page
// ═════════════════════════════════════════════════════════════════════════════

class ProfileMenuPage extends StatefulWidget {
  final String? userId;
  const ProfileMenuPage({super.key, this.userId});

  @override
  State<ProfileMenuPage> createState() => _ProfileMenuPageState();
}

class _ProfileMenuPageState extends State<ProfileMenuPage> {
  String _screen = "profile";

  _AdminUser? _user;
  _CenterAdminInfo? _adminInfo;
  bool _loadingUser = true;
  bool _loadingAdmin = true;
  String? _userError;

  int _savedAdvocatesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    await _loadUser();
    await _loadCenterAdmin();
    await _loadSavedAdvocatesCount();
  }

  Future<void> _loadSavedAdvocatesCount() async {
    try {
      final me = await AuthService.getUserId();
      BookmarkService.setCurrentUser(me);
      final count = await BookmarkService.count();
      if (!mounted) return;
      setState(() => _savedAdvocatesCount = count);
    } catch (_) {}
  }

  // ── Load user basics / contact / location ────────────────────────────────
  Future<void> _loadUser() async {
    setState(() {
      _loadingUser = true;
      _userError = null;
    });

    try {
      final token = await AuthService.getToken();
      final userId = widget.userId ?? await AuthService.getUserId();

      if (token == null || userId == null || userId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingUser = false;
          _userError = 'Please log in to view your profile';
        });
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      Map<String, dynamic> userJson = const {};
      try {
        final res = await http.get(
          Uri.parse('${BASEURL.Urls().baseURL}user/search?userId=$userId'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          userJson = _asMap(jsonDecode(res.body));
        } else {
          if (!mounted) return;
          setState(() {
            _loadingUser = false;
            _userError = 'Failed to load profile (${res.statusCode})';
          });
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loadingUser = false;
          _userError = 'Failed to load profile';
        });
        return;
      }

      Map<String, dynamic> contactJson = const {};
      try {
        final res = await http.get(
          Uri.parse(
              '${BASEURL.Urls().baseURL}user/contact-info/user?userId=$userId'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          contactJson = _asMap(jsonDecode(res.body));
        }
      } catch (_) {}

      Map<String, dynamic> locationJson = const {};
      try {
        final res = await http.get(
          Uri.parse(
              '${BASEURL.Urls().baseURL}userLocation/findByUserId/$userId'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          locationJson = _asMap(jsonDecode(res.body));
        }
      } catch (_) {}

      final profile = _AdminUser.fromApis(
        user: userJson,
        contact: contactJson,
        location: locationJson,
      );

      if (!mounted) return;
      setState(() {
        _user = profile;
        _loadingUser = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUser = false;
        _userError = 'Error loading profile: $e';
      });
    }
  }

  // ── Load center-admin ───────────────────────────────────────────────────
  Future<void> _loadCenterAdmin() async {
    setState(() => _loadingAdmin = true);

    try {
      final token = await AuthService.getToken();
      final userId = widget.userId ?? await AuthService.getUserId();
      if (token == null || userId == null || userId.isEmpty) {
        if (mounted) setState(() => _loadingAdmin = false);
        return;
      }

      final res = await http.get(
        Uri.parse('${BASEURL.Urls().baseURL}center-admin/by-user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final map = _asMap(jsonDecode(res.body));
        if (!mounted) return;
        setState(() {
          _adminInfo = _CenterAdminInfo.fromMap(map);
          _loadingAdmin = false;
        });
      } else {
        if (mounted) setState(() => _loadingAdmin = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAdmin = false);
    }
  }

  // ── Navigation helpers — SAME AS USER PANEL ─────────────────────────────
  void _setScreen(String s) => setState(() => _screen = s);

  Future<void> _openSeeMyProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SeeMyProfile()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
    await _loadUser();
  }

  Future<void> _openUpdateProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UpdateProfile()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
    await _loadEverything();
  }

  Future<void> _openCaseHomePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaseHomePage()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
  }

  Future<void> _openAboutUkil() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutUkilScreen()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
  }

  Future<void> _openFreeConsultant() async {
    final user = _user;

    if (user == null || user.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User information not available. Please try again."),
          backgroundColor: Colors.orange,
        ),
      );
      if (!mounted) return;
      setState(() => _screen = "profile");
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FreeConsultantPage(
          currentUserId: user.id,
          currentUserName: user.displayName,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _screen = "profile");
  }

  Future<void> _openMyQuestions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyQuestionsPage()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
  }

  Future<void> _openSavedAdvocates() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SavedAdvocatesPage()),
    );
    if (!mounted) return;

    try {
      final count = await BookmarkService.count();
      if (!mounted) return;
      setState(() {
        _savedAdvocatesCount = count;
        _screen = "profile";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _screen = "profile");
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ── Delete account ──────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("This action is permanent. Are you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");
    final token = prefs.getString("jwt_token");

    if (userId == null) return;

    try {
      if (_adminInfo != null && _adminInfo!.id.isNotEmpty) {
        await http.delete(
          Uri.parse(
              "${BASEURL.Urls().baseURL}center-admin/delete/${_adminInfo!.id}/$userId"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        );
      }
    } catch (_) {}

    final url = Uri.parse(
        "${BASEURL.Urls().baseURL}user/delete/$userId?tryingToDelete=$userId");

    try {
      final response = await http.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(response.body)));
        await AuthService.logout();
        if (mounted) Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account deletion failed")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Delete error: $e")));
    }
  }

  // ── Delete advocate (center-admin only) ─────────────────────────────────
  Future<void> _deleteAdvocate(String advocateId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Advocate"),
        content: Text(
          "Remove \"$label\" from your center-admin advocate list?\n\n"
          "This deletes the advocate record entirely.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");
    final token = prefs.getString("jwt_token");

    if (userId == null || token == null) return;

    try {
      final res = await http.delete(
        Uri.parse(
            "${BASEURL.Urls().baseURL}advocate/delete/$advocateId/$userId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Advocate deleted successfully"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadCenterAdmin();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${res.body}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Delete failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Delete admin (center-admin only) ────────────────────────────────────
  Future<void> _deleteAdmin(String adminId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Admin"),
        content: Text(
          "Remove \"$label\" from your center-admin admin list?\n\n"
          "This deletes the admin record entirely.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");
    final token = prefs.getString("jwt_token");

    if (userId == null || token == null) return;

    try {
      final res = await http.delete(
        Uri.parse("${BASEURL.Urls().baseURL}admin/delete/$adminId/$userId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Admin deleted successfully"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadCenterAdmin();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${res.body}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Delete failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.ivory,
      body: SafeArea(child: _buildScreen()),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case "profile":
        return _buildProfileMain();

      // ── Account ────────────────────────────────────────────────────
      case "personalInfo":
        return _buildPersonalInfo();
      case "contactInfo":
        return _buildContactInfo();
      case "identity":
        return _buildIdentity();

      // ── Center Admin ───────────────────────────────────────────────
      case "adminDetails":
        return _buildAdminDetailsScreen();
      case "deleteAdvocates":
        return _buildDeleteAdvocates();
      case "deleteAdmins":
        return _buildDeleteAdmins();

      // ── Legal Activity — SAME PAGES as user panel ──────────────────
      case "myCases":
      case "caseHistory":
        return _buildRedirect(
          title: "My Cases",
          onBack: () => _setScreen("profile"),
          onOpen: _openCaseHomePage,
        );
      case "savedAdvocates":
        return _buildRedirect(
          title: "Saved Advocates",
          onBack: () => _setScreen("profile"),
          onOpen: _openSavedAdvocates,
        );
      case "myQuestions":
        return _buildRedirect(
          title: "My Questions",
          onBack: () => _setScreen("profile"),
          onOpen: _openMyQuestions,
        );

      // ── Support — SAME PAGES as user panel ─────────────────────────
      case "help":
        return _buildRedirect(
          title: "Help & Support",
          onBack: () => _setScreen("profile"),
          onOpen: _openFreeConsultant,
        );
      case "about":
        return _buildRedirect(
          title: "About Ukil",
          onBack: () => _setScreen("profile"),
          onOpen: _openAboutUkil,
        );

      // ── Direct pages ───────────────────────────────────────────────
      case "myProfile":
        return _buildRedirect(
          title: "My Profile",
          onBack: () => _setScreen("profile"),
          onOpen: _openSeeMyProfile,
        );

      case "deleteAccount":
        return _buildSimplePlaceholder("Delete Account", "🗑️");
      default:
        return _buildProfileMain();
    }
  }

  // ── Redirect helper (SAME as user panel) ────────────────────────────────
  Widget _buildRedirect({
    required String title,
    required VoidCallback onBack,
    required Future<void> Function() onOpen,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onOpen());
    return Column(
      children: [
        _BackHeader(title: title, onBack: onBack),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(color: _C.mid),
          ),
        ),
      ],
    );
  }

  // ── Main profile screen ─────────────────────────────────────────────────
  Widget _buildProfileMain() {
    if (_loadingUser) {
      return const Center(
        child: CircularProgressIndicator(color: _C.mid),
      );
    }

    if (_userError != null && _user == null) {
      return _buildErrorState(_userError!, _loadUser);
    }

    final user = _user!;

    return RefreshIndicator(
      color: _C.mid,
      onRefresh: _loadEverything,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 60),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_C.forest, _C.mid],
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    "My Account",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openUpdateProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "✏️ Edit",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Avatar card
            Transform.translate(
              offset: const Offset(0, -46),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x211A3C2B),
                      blurRadius: 30,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const ProfileImageWidget(radius: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: _C.ink,
                            ),
                          ),
                          if (user.locationName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              "📍 ${user.locationName}",
                              style: const TextStyle(
                                  fontSize: 12, color: _C.mid),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (user.email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              "📧 ${user.email}",
                              style: const TextStyle(
                                  fontSize: 11, color: _C.mist),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Account
            _sectionLabel("Account"),
            _menuGroup([
              _MenuRow(
                icon: "👤",
                label: "Personal Information",
                sub: "Name, Email, Phone",
                onTap: () => _setScreen("personalInfo"),
              ),
              _MenuRow(
                icon: "📱",
                label: "Contact Details",
                sub: "Phone, Email, Location",
                onTap: () => _setScreen("contactInfo"),
              ),
              _MenuRow(
                icon: "🪪",
                label: "Identity & Verification",
                sub: _loadingAdmin
                    ? "Loading…"
                    : (_adminInfo == null
                        ? "Not registered as center admin"
                        : "Verified center admin"),
                onTap: () => _setScreen("identity"),
              ),
            ]),

            // Center Admin
            if (_adminInfo != null) ...[
              _sectionLabel("Center Admin"),
              _menuGroup([
                _MenuRow(
                  icon: "👥",
                  label: "Admins",
                  sub: _adminInfo!.admins.isEmpty
                      ? "No admins"
                      : "${_adminInfo!.admins.length} admins",
                  onTap: () => _setScreen("adminDetails"),
                ),
                _MenuRow(
                  icon: "⚖️",
                  label: "Advocates",
                  sub: _adminInfo!.advocates.isEmpty
                      ? "No advocates"
                      : "${_adminInfo!.advocates.length} advocates",
                  onTap: () => _setScreen("adminDetails"),
                ),
                _MenuRow(
                  icon: "🗑️",
                  label: "Delete Advocates",
                  sub: _adminInfo!.advocates.isEmpty
                      ? "No advocates to delete"
                      : "Remove advocates from your list",
                  danger: true,
                  onTap: () => _setScreen("deleteAdvocates"),
                ),
                _MenuRow(
                  icon: "❌",
                  label: "Delete Admins",
                  sub: _adminInfo!.admins.isEmpty
                      ? "No admins to delete"
                      : "Remove admins from your list",
                  danger: true,
                  onTap: () => _setScreen("deleteAdmins"),
                ),
              ]),
            ],

            // Legal Activity
            _sectionLabel("Legal Activity"),
            _menuGroup([
              _MenuRow(
                icon: "⚖️",
                label: "My Cases",
                sub: "View and manage your legal cases",
                onTap: () => _setScreen("myCases"),
              ),
              _MenuRow(
                icon: "❤️",
                label: "Saved Advocates",
                sub: _savedAdvocatesCount == 0
                    ? "None saved"
                    : "$_savedAdvocatesCount advocates bookmarked",
                onTap: () => _setScreen("savedAdvocates"),
              ),
              _MenuRow(
                icon: "💬",
                label: "My Questions",
                sub: "None posted",
                onTap: () => _setScreen("myQuestions"),
              ),
              _MenuRow(
                icon: "📋",
                label: "Case History",
                sub: "Complete legal record",
                onTap: () => _setScreen("caseHistory"),
              ),
            ]),

            // Support
            _sectionLabel("Support"),
            _menuGroup([
              _MenuRow(
                icon: "❓",
                label: "Help & Support",
                sub: "FAQs, contact, report issue",
                onTap: () => _setScreen("help"),
              ),
              _MenuRow(
                icon: "ℹ️",
                label: "About Ukil",
                sub: "Version info · Terms · Privacy",
                onTap: () => _setScreen("about"),
              ),
            ]),

            // Danger zone
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.line),
                ),
                child: Column(
                  children: [
                    _MenuRow(
                      icon: "🚪",
                      label: "Logout",
                      danger: true,
                      onTap: _logout,
                    ),
                    _MenuRow(
                      icon: "🗑️",
                      label: "Delete Account",
                      sub: "Permanently remove your account",
                      danger: true,
                      onTap: _deleteAccount,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _C.mist,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _menuGroup(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.line),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  // ── Personal Info ───────────────────────────────────────────────────────
  Widget _buildPersonalInfo() {
    final u = _user;
    if (u == null) {
      return const Center(child: CircularProgressIndicator(color: _C.mid));
    }

    return Column(
      children: [
        _BackHeader(
          title: "Personal Information",
          onBack: () => _setScreen("profile"),
          action: GestureDetector(
            onTap: _openUpdateProfile,
            child: const Text(
              "Edit",
              style: TextStyle(
                color: _C.mid,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _infoCard("Basic Information", [
                  _InfoRow(
                    label: "Full Name",
                    value: u.displayName,
                    icon: "👤",
                  ),
                  _InfoRow(label: "Username", value: u.name, icon: "🏷"),
                  _InfoRow(label: "Email", value: u.email, icon: "📧"),
                  _InfoRow(label: "Phone", value: u.phone, icon: "📱"),
                  _InfoRow(
                      label: "Location", value: u.locationName, icon: "📍"),
                ]),
                const SizedBox(height: 14),
                _infoCard("Account Status", [
                  _InfoRow(
                      label: "Account Type",
                      value: "Center Admin",
                      icon: "🎫"),
                  _InfoRow(
                    label: "Verification",
                    value: _adminInfo == null
                        ? "Not verified"
                        : "Verified center admin",
                    icon: "🛡",
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openUpdateProfile,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("Edit Personal Information"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Contact Info ────────────────────────────────────────────────────────
  Widget _buildContactInfo() {
    final u = _user;
    if (u == null) {
      return const Center(child: CircularProgressIndicator(color: _C.mid));
    }

    final lat = u.lattitude != null ? u.lattitude!.toStringAsFixed(5) : '';
    final lng = u.longitude != null ? u.longitude!.toStringAsFixed(5) : '';

    return Column(
      children: [
        _BackHeader(
          title: "Contact Details",
          onBack: () => _setScreen("profile"),
          action: GestureDetector(
            onTap: _openUpdateProfile,
            child: const Text(
              "Edit",
              style: TextStyle(
                color: _C.mid,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _infoCard("Contact Information", [
                  _InfoRow(label: "Email", value: u.email, icon: "📧"),
                  _InfoRow(label: "Phone", value: u.phone, icon: "📱"),
                  _InfoRow(
                      label: "Location",
                      value: u.locationName,
                      icon: "📍"),
                  _InfoRow(label: "Latitude", value: lat, icon: "🗺"),
                  _InfoRow(label: "Longitude", value: lng, icon: "🗺"),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Identity → SAME as user panel: always uses _IdentityRouter
  // (director registration / director profile flow).
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildIdentity() {
    return _IdentityRouter(
      userId: _user?.id ?? widget.userId ?? '',
      onBack: () => _setScreen("profile"),
      onAfterRegister: _loadUser,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Admin / Advocate / District list screen — shown when tapping
  // "Admins" or "Advocates" in the Center Admin group.
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildAdminDetailsScreen() {
    return Column(
      children: [
        _BackHeader(
          title: "Center Admin Details",
          onBack: () => _setScreen("profile"),
        ),
        Expanded(
          child: _loadingAdmin
              ? const Center(
                  child: CircularProgressIndicator(color: _C.mid))
              : (_adminInfo == null
                  ? _buildEmptyDeleteState(
                      "You are not a center admin",
                      "Register as a center admin first to view your districts, admins and advocates.",
                    )
                  : _buildAdminDetailsView(_adminInfo!)),
        ),
      ],
    );
  }

  // ── Districts / Admins / Advocates lists (verified center admin card) ──
  Widget _buildAdminDetailsView(_CenterAdminInfo info) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Verified Center Admin header card ───────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.forest, _C.mid],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text("🛡", style: TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Verified Center Admin",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.userName.isNotEmpty
                            ? info.userName
                            : info.fullName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Districts (NEW) ─────────────────────────────────────────
          _listCard(
            title: "Districts",
            icon: "🗺️",
            items: info.districts,
            emptyText: "No districts assigned",
          ),
          const SizedBox(height: 14),

          // ── Admins ──────────────────────────────────────────────────
          _listCard(
            title: "Admins",
            icon: "👥",
            items: info.adminsFullName.isNotEmpty
                ? info.adminsFullName
                : info.adminsName.isNotEmpty
                    ? info.adminsName
                    : info.admins,
            emptyText: "No admins assigned",
          ),
          const SizedBox(height: 14),

          // ── Advocates ───────────────────────────────────────────────
          _listCard(
            title: "Advocates",
            icon: "⚖️",
            items: info.advocatesFullName.isNotEmpty
                ? info.advocatesFullName
                : info.advocatesName.isNotEmpty
                    ? info.advocatesName
                    : info.advocates,
            emptyText: "No advocates assigned",
          ),
        ],
      ),
    );
  }

  // ── Delete Advocates screen ─────────────────────────────────────────────
  Widget _buildDeleteAdvocates() {
    final info = _adminInfo;
    if (info == null) {
      return Column(
        children: [
          _BackHeader(
            title: "Delete Advocates",
            onBack: () => _setScreen("profile"),
          ),
          Expanded(
            child: _loadingAdmin
                ? const Center(
                    child: CircularProgressIndicator(color: _C.mid))
                : _buildEmptyDeleteState(
                    "You are not a center admin",
                    "Register as a center admin first to manage advocates.",
                  ),
          ),
        ],
      );
    }

    final List<_DeleteTarget> targets = [];
    for (int i = 0; i < info.advocates.length; i++) {
      final id = info.advocates[i];
      String label = id;
      if (i < info.advocatesFullName.length &&
          info.advocatesFullName[i].isNotEmpty) {
        label = info.advocatesFullName[i];
      } else if (i < info.advocatesName.length &&
          info.advocatesName[i].isNotEmpty) {
        label = info.advocatesName[i];
      }
      targets.add(_DeleteTarget(id: id, label: label));
    }

    return Column(
      children: [
        _BackHeader(
          title: "Delete Advocates",
          onBack: () => _setScreen("profile"),
        ),
        Expanded(
          child: targets.isEmpty
              ? _buildEmptyDeleteState(
                  "No advocates",
                  "You don't have any advocates in your list.",
                )
              : RefreshIndicator(
                  color: _C.mid,
                  onRefresh: _loadCenterAdmin,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(18),
                    itemCount: targets.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = targets[i];
                      return _DeleteTargetTile(
                        label: t.label,
                        sub: t.id,
                        onDelete: () => _deleteAdvocate(t.id, t.label),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ── Delete Admins screen ────────────────────────────────────────────────
  Widget _buildDeleteAdmins() {
    final info = _adminInfo;
    if (info == null) {
      return Column(
        children: [
          _BackHeader(
            title: "Delete Admins",
            onBack: () => _setScreen("profile"),
          ),
          Expanded(
            child: _loadingAdmin
                ? const Center(
                    child: CircularProgressIndicator(color: _C.mid))
                : _buildEmptyDeleteState(
                    "You are not a center admin",
                    "Register as a center admin first to manage admins.",
                  ),
          ),
        ],
      );
    }

    final List<_DeleteTarget> targets = [];
    for (int i = 0; i < info.admins.length; i++) {
      final id = info.admins[i];
      String label = id;
      if (i < info.adminsFullName.length &&
          info.adminsFullName[i].isNotEmpty) {
        label = info.adminsFullName[i];
      } else if (i < info.adminsName.length &&
          info.adminsName[i].isNotEmpty) {
        label = info.adminsName[i];
      }
      targets.add(_DeleteTarget(id: id, label: label));
    }

    return Column(
      children: [
        _BackHeader(
          title: "Delete Admins",
          onBack: () => _setScreen("profile"),
        ),
        Expanded(
          child: targets.isEmpty
              ? _buildEmptyDeleteState(
                  "No admins",
                  "You don't have any admins in your list.",
                )
              : RefreshIndicator(
                  color: _C.mid,
                  onRefresh: _loadCenterAdmin,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(18),
                    itemCount: targets.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = targets[i];
                      return _DeleteTargetTile(
                        label: t.label,
                        sub: t.id,
                        onDelete: () => _deleteAdmin(t.id, t.label),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyDeleteState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off, size: 64, color: _C.mist),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _C.mist),
            ),
          ],
        ),
      ),
    );
  }

  // ── List card ───────────────────────────────────────────────────────────
  Widget _listCard({
    required String title,
    required String icon,
    required List<String> items,
    required String emptyText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _C.frost,
              border: Border(bottom: BorderSide(color: _C.line)),
            ),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _C.ink,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _C.mid.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${items.length}",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _C.mid,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                emptyText,
                style: const TextStyle(fontSize: 13, color: _C.mist),
              ),
            )
          else
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _C.frost,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _C.line),
                          ),
                          child: Text(
                            e,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _C.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _buildSimplePlaceholder(String title, String emoji) {
    return Column(
      children: [
        _BackHeader(title: title, onBack: () => _setScreen("profile")),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 14),
                  Text(
                    "$title — coming soon",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _C.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _C.frost,
              border: Border(bottom: BorderSide(color: _C.line)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _C.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: _C.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.slate, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.forest,
                foregroundColor: Colors.white,
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _IdentityRouter — SAME as user panel (director flow)
// ═════════════════════════════════════════════════════════════════════════════

class _IdentityRouter extends StatefulWidget {
  final String userId;
  final VoidCallback onBack;
  final Future<void> Function() onAfterRegister;

  const _IdentityRouter({
    required this.userId,
    required this.onBack,
    required this.onAfterRegister,
  });

  @override
  State<_IdentityRouter> createState() => _IdentityRouterState();
}

class _IdentityRouterState extends State<_IdentityRouter> {
  final DirectorService _directorService = DirectorService();

  bool _loading = true;
  String? _error;
  List<DirectorResponse> _directors = [];

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'User not logged in';
      });
      return;
    }

    try {
      final list = await _directorService.getDirectorByUserId(widget.userId);
      if (!mounted) return;
      setState(() {
        _directors = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openRegistration() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectorRegistrationScreen(userId: widget.userId),
      ),
    );
    if (!mounted) return;
    await _check();
    await widget.onAfterRegister();
  }

  Future<void> _openProfile(DirectorResponse d) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectorProfilePage(
          directorId: d.id,
          userId: widget.userId,
        ),
      ),
    );
    if (!mounted) return;
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.arrow_back,
                      size: 22, color: _C.forest),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Identity & Verification",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.mid),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: _C.danger),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.slate, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _check,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.forest,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_directors.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.forest, _C.mid],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text("🛡", style: TextStyle(fontSize: 40)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Verification Pending",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Register as a director to unlock all features.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _identityInfoCard("Director Status", [
              _identityInfoRow("Status", "Not registered", "✅"),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openRegistration,
                icon: const Icon(Icons.app_registration, size: 18),
                label: const Text("Register as Director"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.forest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final primary = _directors.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.forest, _C.mid],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text("🛡", style: TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Verified Director",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        primary.position.isNotEmpty
                            ? primary.position
                            : "Director",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _identityInfoCard("Director Information", [
            _identityInfoRow("Full Name", primary.fullName ?? "—", "👤"),
            _identityInfoRow("Position", primary.position, "💼"),
            _identityInfoRow("NID Number",
                primary.nidNumber ?? "—", "🪪"),
            _identityInfoRow("Mobile",
                primary.mobileNumber ?? primary.phone ?? "—", "📱"),
            _identityInfoRow("Email",
                primary.email ?? primary.directorEmail ?? "—", "📧"),
            _identityInfoRow("Location",
                primary.locationName ?? "—", "📍"),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openProfile(primary),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text("Open Director Profile"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityInfoCard(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _C.frost,
              border: Border(bottom: BorderSide(color: _C.line)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _C.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _identityInfoRow(String label, String value, String icon) {
    final raw = value.trim();
    final display = raw.isEmpty ? '—' : raw;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: _C.mist)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Delete target widgets
// ═════════════════════════════════════════════════════════════════════════════

class _DeleteTarget {
  final String id;
  final String label;
  const _DeleteTarget({required this.id, required this.label});
}

class _DeleteTargetTile extends StatelessWidget {
  final String label;
  final String sub;
  final VoidCallback onDelete;

  const _DeleteTargetTile({
    required this.label,
    required this.sub,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.dangerPale,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: _C.danger, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _C.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub.isNotEmpty && sub != label) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 11, color: _C.mist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                color: _C.danger, size: 16),
            label: const Text(
              "Delete",
              style: TextStyle(
                color: _C.danger,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _C.danger),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Reusable widgets
// ═════════════════════════════════════════════════════════════════════════════

class _BackHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? action;
  const _BackHeader({
    required this.title,
    required this.onBack,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.arrow_back, size: 22, color: _C.forest),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _C.ink)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final String? icon;
  const _InfoRow({required this.label, this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final raw = (value ?? '').trim();
    final displayValue = raw.isEmpty ? '—' : raw;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Text(icon!, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: _C.mist)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String icon;
  final String label;
  final String? sub;
  final String? badge;
  final bool danger;
  final bool chevron;
  final VoidCallback? onTap;
  const _MenuRow({
    required this.icon,
    required this.label,
    this.sub,
    this.badge,
    this.danger = false,
    this.chevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _C.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: danger ? _C.dangerPale : _C.frost,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: danger ? _C.danger : _C.ink,
                      )),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub!,
                        style: const TextStyle(
                            fontSize: 11, color: _C.mist)),
                  ],
                ],
              ),
            ),
            if (badge != null && badge!.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: _C.danger,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
            ],
            if (chevron)
              const Icon(Icons.chevron_right, size: 18, color: _C.mist),
          ],
        ),
      ),
    );
  }
}
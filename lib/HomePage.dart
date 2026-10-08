// lib/HomePage/HomePage.dart — Center Admin, structured EXACTLY like admin panel.
// Click destinations preserved.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import '../Utils/AdvocateSpeciality.dart';
import '../Farayez/farayez_calculator.dart';
import '../HomePage/corporate_banner.dart';
import '../CompanyPages/company_service.dart';
import '../CompanyPages/company_response.dart';
import '../CompanyPages/company_details_page.dart';
import '../CompanyPages/all_companies_page.dart';
import '../HomePage/AdvocateFilter.dart';
import '../HomePage/AdvocateFilterBar.dart';
import '../HomePage/AdvocateListView.dart';
import '../PostRelatedPages/post_feed_page.dart';
import '../PostRelatedPages/post_feed_page_home_page.dart';
import '../AdvocatePages/AdvocateHomePage.dart';
import '../QuestionPages/QuestionListPage.dart';
import '../RegistrationPage/gender.dart';
import '../LogInPage/LogIn.dart';
import '../HomePage/QuickConnect.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _heartbeatTimer;
  String? token;
  String? userId;

  String? _selectedPostType, _selectedQuestionType;
  AdvocateFilter _filter = AdvocateFilter();

  List<CompanyResponse> _companies = [];
  bool _isLoadingCompanies = true;
  String? _companyError;

  final List<String> allLocations = [
    'Bagerhat', 'Bandarban', 'Barguna', 'Barisal', 'Bhola', 'Bogra',
    'Brahmanbaria', 'Chandpur', 'Chapai Nawabganj', 'Chittagong', 'Chuadanga',
    'Comilla', "Cox's Bazar", 'Dhaka', 'Dinajpur', 'Faridpur', 'Feni',
    'Gaibandha', 'Gazipur', 'Gopalganj', 'Habiganj', 'Jamalpur', 'Jessore',
    'Jhalokati', 'Jhenaidah', 'Joypurhat', 'Khagrachari', 'Khulna',
    'Kishoreganj', 'Kurigram', 'Kushtia', 'Lakshmipur', 'Lalmonirhat',
    'Madaripur', 'Magura', 'Manikganj', 'Meherpur', 'Moulvibazar',
    'Munshiganj', 'Mymensingh', 'Naogaon', 'Narail', 'Narayanganj',
    'Narsingdi', 'Natore', 'Netrokona', 'Nilphamari', 'Noakhali', 'Pabna',
    'Panchagarh', 'Patuakhali', 'Pirojpur', 'Rajbari', 'Rajshahi',
    'Rangamati', 'Rangpur', 'Satkhira', 'Shariatpur', 'Sherpur',
    'Sirajganj', 'Sunamganj', 'Sylhet', 'Tangail', 'Thakurgaon'
  ];

  bool _isWelcomeBannerVisible = true;

  @override
  void initState() {
    super.initState();
    heartbit();
    _loadSavedFilter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanies();
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // Heartbeat
  // ============================================================
  Future<void> heartbit() async {
    token = await AuthService.getToken();
    final id = await AuthService.getUserId();
    if (id != null) {
      _startHeartbeat(id);
    }
  }

  void _startHeartbeat(String userId) {
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 20),
      (timer) async {
        try {
          final url = Uri.parse(
              "${BASE_URL.Urls().baseURL}user-active/heartbeat/$userId");
          final token = await AuthService.getToken();
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

  // ============================================================
  // Companies
  // ============================================================
  Future<void> _loadCompanies() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('cached_companies');

    List<CompanyResponse> filterRegistered(List<CompanyResponse> companies) {
      return companies.where((company) {
        final hasRegistryId = company.officeRegistryId != null &&
            company.officeRegistryId!.isNotEmpty;
        final isRegistered = company.registrationProcess != null &&
            company.registrationProcess!.status == true;
        return hasRegistryId && isRegistered;
      }).toList();
    }

    if (cachedJson != null) {
      try {
        final allCached = (jsonDecode(cachedJson) as List)
            .map((e) => CompanyResponse.fromJson(e))
            .toList();
        final cached = filterRegistered(allCached);

        if (!mounted) return;
        setState(() {
          _companies = cached;
          _isLoadingCompanies = false;
        });
      } catch (e) {
        print('⚠️ Cache parse error: $e');
      }
    }

    try {
      final allCompanies = await CompanyService().getAllCompanies();
      final registeredCompanies = filterRegistered(allCompanies);

      await prefs.setString(
        'cached_companies',
        jsonEncode(allCompanies.map((c) => c.toJson()).toList()),
      );

      if (!mounted) return;
      setState(() {
        _companies = registeredCompanies;
        _isLoadingCompanies = false;
        _companyError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _companyError = e.toString();
        _isLoadingCompanies = false;
      });
    }
  }

  // ============================================================
  // Filter persistence
  // ============================================================
  void _onFilterChanged(AdvocateFilter newFilter) {
    setState(() {
      _filter = newFilter;
    });
    _saveFilter(newFilter);
  }

  void _saveFilter(AdvocateFilter filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (filter.speciality != null && filter.speciality!.isNotEmpty) {
        await prefs.setString('filter_speciality', filter.speciality!);
      } else {
        await prefs.remove('filter_speciality');
      }
      if (filter.location != null && filter.location!.isNotEmpty) {
        await prefs.setString('filter_location', filter.location!);
      } else {
        await prefs.remove('filter_location');
      }
      if (filter.gender != null) {
        await prefs.setString('filter_gender', filter.gender!.name);
      } else {
        await prefs.remove('filter_gender');
      }
    } catch (e) {
      print("⚠️ Error saving filter: $e");
    }
  }

  void _loadSavedFilter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final speciality = prefs.getString('filter_speciality');
      if (prefs.getString('userId') != null) {
        userId = prefs.getString('userId');
      }
      final location = prefs.getString('filter_location');
      final genderStr = prefs.getString('filter_gender');

      Gender? gender;
      if (genderStr != null) {
        try {
          gender = Gender.values.firstWhere((g) => g.name == genderStr);
        } catch (e) {
          gender = null;
        }
      }

      setState(() {
        _filter = AdvocateFilter(
          speciality: speciality,
          location: location,
          gender: gender,
        );
      });
    } catch (e) {
      setState(() {
        _filter = AdvocateFilter();
      });
    }
  }

  // ============================================================
  // Navigation
  // ============================================================
  void _navigateWithRandomAnimation(Widget page) async {
    final tk = await AuthService.getToken();
    if (tk != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LogIn()));
    }
  }

  void _navigateToPostFeed(String? postType) async {
    final tk = await AuthService.getToken();
    if (tk != null) {
      _navigateWithRandomAnimation(
        PostFeedPageHomePage(initialPostType: postType),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LogIn()));
    }
  }

  void _navigateToQuestionFeed(String? postType) async {
    final tk = await AuthService.getToken();
    if (tk != null) {
      _navigateWithRandomAnimation(
        QuestionListPage(type: postType),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LogIn()));
    }
  }

  void _navigateToAllQuestions() async {
    final tk = await AuthService.getToken();
    if (tk != null) {
      _navigateWithRandomAnimation(QuestionListPage());
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LogIn()));
    }
  }

  void _navigateToAllPosts() async {
    final tk = await AuthService.getToken();
    if (tk != null) {
      _navigateWithRandomAnimation(const PostFeedPage());
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LogIn()));
    }
  }

  void _navigateToFeaturedAdvocates() async {
    final tk = await AuthService.getToken();
    if (tk != null) {
      _navigateWithRandomAnimation(const AdvocateHomePage());
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LogIn()));
    }
  }

  void _navigateToCompanyDetail(String companyId) async {
    final tk = await AuthService.getToken();
    if (tk == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LogIn()));
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CompanyDetailsPage(companyId: companyId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToAllCompanies() async {
    final tk = await AuthService.getToken();
    if (tk == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LogIn()));
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AllCompaniesPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ============================================================
  // BUILD — EXACT structure of admin panel home page
  // ============================================================
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
          colors: [Colors.green.shade50, Colors.white, Colors.green.shade50],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadCompanies();
          setState(() {});
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double viewportHeight = constraints.maxHeight;

            final double topPadding = 20;
            final double welcomeBannerHeight = _isWelcomeBannerVisible
                ? (isDesktop ? 220 : 200)
                : 60;
            final double gapAfterBanner = 24;

            final double aboveQuickConnect =
                topPadding + welcomeBannerHeight + gapAfterBanner;

            final double remainingForQuickConnect =
                (viewportHeight - aboveQuickConnect - 16).clamp(260.0, 640.0);

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                  vertical: topPadding,
                ),
                child: Column(
                  children: [
                    // ── 1. Welcome banner ──
                    _buildWelcomeBanner(context, isDesktop, isTablet),
                    SizedBox(height: gapAfterBanner),

                    // ── 2. Quick Connect (fills remaining viewport) ──
                    QuickConnect(
                      key: UniqueKey(),
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      fillHeight: true,
                      remainingViewportHeight: remainingForQuickConnect,
                    ),

                    const SizedBox(height: 32),

                    // ── 3. Post type selector ──
                    _buildPostTypeSelector(),

                    const SizedBox(height: 16),

                    // ── 4. Question type selector ──
                    _buildQuestionTypeSelector(),

                    const SizedBox(height: 32),

                    // ── 5. Featured Advocates header ──
                    _buildFeaturedAdvocatesHeader(),

                    const SizedBox(height: 16),

                    // ── 6. Advocate list ──
                    AdvocateListView(
                      key: ValueKey(
                          '${_filter.speciality}_${_filter.location}_${_filter.gender}'),
                      filter: _filter,
                      crossAxisCount: 2,
                      showAll: true,
                    ),

                    const SizedBox(height: 20),

                    // ── 7. Companies ──
                    _buildCompaniesSection(isDesktop, isTablet),

                    const SizedBox(height: 20),

                    // ── 8. Corporate banner ──
                    const CorporateBanner(),

                    const SizedBox(height: 20),

                    // ── 9. Farayez calculator ──
                    const FarayezCalculator(),

                    const SizedBox(height: 20),

                    // ── 10. Advocate promotion card ──
                    _buildAdvocatePromotionCard(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // Welcome Banner
  // ============================================================
  Widget _buildWelcomeBanner(
      BuildContext context, bool isDesktop, bool isTablet) {
    if (!_isWelcomeBannerVisible) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isWelcomeBannerVisible = true;
                });
              },
              icon: const Icon(Icons.expand_more, color: Colors.green, size: 20),
              label: Text(
                "Show Welcome Message",
                style: GoogleFonts.inter(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.green.shade50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.green.shade200, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final double logoSize = isDesktop ? 64 : (isTablet ? 56 : 48);
    final double logoRingPadding = isDesktop ? 4 : 3;
    final double logoInnerPadding = isDesktop ? 6 : 5;

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
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.15),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.9),
                        width: logoRingPadding,
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFFFFF), Color(0xFFF1F8E9)],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(logoInnerPadding),
                      child: ClipOval(
                        child: Container(
                          color: Colors.white,
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.gavel_rounded,
                              color: Color(0xFF1B5E20),
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Welcome to উকিল",
                      style: GoogleFonts.poppins(
                        fontSize: isDesktop ? 28 : (isTablet ? 24 : 20),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Your trusted legal partner. Connect with expert advocates, get legal advice, and manage your cases efficiently.",
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 16 : 14,
                  color: Colors.white.withOpacity(0.95),
                  height: 1.5,
                ),
              ),
            ],
          ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              onPressed: () {
                setState(() {
                  _isWelcomeBannerVisible = false;
                });
              },
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Featured Advocates Header
  // ============================================================
  Widget _buildFeaturedAdvocatesHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    final double logoSize = isSmallScreen ? 40 : 46;
    final double logoRingPadding = isSmallScreen ? 2.5 : 3;
    final double logoInnerPadding = isSmallScreen ? 3.5 : 4;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade700.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white,
                        width: logoRingPadding,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade600,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(logoInnerPadding),
                      child: ClipOval(
                        child: Container(
                          color: Colors.white,
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.gavel_rounded,
                              color: Colors.green.shade700,
                              size: isSmallScreen ? 18 : 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Featured Advocates",
                    style: GoogleFonts.poppins(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextButton(
                  onPressed: _navigateToFeaturedAdvocates,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    foregroundColor: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        "See All",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 11 : 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (token != null)
            AdvocateFilterBar(
              filter: _filter,
              onFilterChanged: _onFilterChanged,
              locations: allLocations,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // Question Type Selector (Recent QNA)
  // ============================================================
  Widget _buildQuestionTypeSelector() {
    final allTypes = AdvocateSpeciality.values;
    final totalTypes = allTypes.length;
    final int midPoint = (totalTypes / 2).ceil();
    final List<AdvocateSpeciality> firstHalf = allTypes.sublist(0, midPoint);
    final List<AdvocateSpeciality> secondHalf = allTypes.sublist(midPoint);

    const double logoSize = 36;
    const double logoRingPadding = 2.5;
    const double logoInnerPadding = 3.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade700.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 5,
                        spreadRadius: 0.5,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: logoRingPadding,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade600,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(logoInnerPadding),
                    child: ClipOval(
                      child: Container(
                        color: Colors.white,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.gavel_rounded,
                            color: Colors.green.shade700,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Recent QNA",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _navigateToAllQuestions,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.post_add,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "See All",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            _buildQuestionSpecialityRow(firstHalf, 'first'),
            const SizedBox(height: 10),
            _buildQuestionSpecialityRow(secondHalf, 'second'),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // Post Type Selector (Recent Legal Updates)
  // ============================================================
  Widget _buildPostTypeSelector() {
    final allTypes = AdvocateSpeciality.values;
    final totalTypes = allTypes.length;
    final int midPoint = (totalTypes / 2).ceil();
    final List<AdvocateSpeciality> firstHalf = allTypes.sublist(0, midPoint);
    final List<AdvocateSpeciality> secondHalf = allTypes.sublist(midPoint);

    const double logoSize = 36;
    const double logoRingPadding = 2.5;
    const double logoInnerPadding = 3.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade700.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 5,
                        spreadRadius: 0.5,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: logoRingPadding,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade600,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(logoInnerPadding),
                    child: ClipOval(
                      child: Container(
                        color: Colors.white,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.gavel_rounded,
                            color: Colors.green.shade700,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Recent Legal Updates",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _navigateToAllPosts,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.post_add,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "See All",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            _buildSpecialityRow(firstHalf, 'first'),
            const SizedBox(height: 10),
            _buildSpecialityRow(secondHalf, 'second'),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecialityRow(List<AdvocateSpeciality> items, String rowId) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final type = items[index];
          final isSelected = _selectedPostType == type.apiValue;
          return Container(
            width: 100,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildTypeChip(type, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildQuestionSpecialityRow(
      List<AdvocateSpeciality> items, String rowId) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final type = items[index];
          final isSelected = _selectedQuestionType == type.apiValue;
          return Container(
            width: 100,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildQuestionTypeChip(type, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildTypeChip(AdvocateSpeciality type, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        final tk = await AuthService.getToken();
        if (tk == null) {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LogIn()));
        } else {
          if (isSelected) {
            setState(() {
              _selectedPostType = null;
            });
          } else {
            _navigateToPostFeed(type.apiValue);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green.shade600 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              type.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTypeChip(AdvocateSpeciality type, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        final tk = await AuthService.getToken();
        if (tk == null) {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LogIn()));
        } else {
          if (isSelected) {
            setState(() {
              _selectedQuestionType = null;
            });
          } else {
            _navigateToQuestionFeed(type.apiValue);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green.shade600 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              type.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Companies Section
  // ============================================================
  Widget _buildCompaniesSection(bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 2);
    final cardHeight = isDesktop ? 200.0 : 180.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business,
                          color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Companies",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_companies.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_companies.isNotEmpty)
                  TextButton(
                    onPressed: _navigateToAllCompanies,
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    child: const Text('See All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingCompanies)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_companyError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade300, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load companies',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadCompanies,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_companies.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.business, color: Colors.grey, size: 40),
                      SizedBox(height: 8),
                      Text('No companies found',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  mainAxisExtent: cardHeight,
                ),
                itemCount: _companies.length > 6 ? 6 : _companies.length,
                itemBuilder: (context, index) {
                  return _buildCompanyCard(_companies[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(CompanyResponse company) {
    return GestureDetector(
      onTap: () => _navigateToCompanyDetail(company.id!),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.business,
                    color: Colors.blue.shade700, size: 30),
              ),
              const SizedBox(height: 8),
              Text(
                company.companyName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                company.type ?? 'N/A',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  _buildTag(company.category ?? 'N/A'),
                  if (company.directorsName != null &&
                      company.directorsName!.isNotEmpty)
                    _buildTag('${company.directorsName!.length} Directors'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
      ),
    );
  }

  // ============================================================
  // Advocate Promotion Card
  // ============================================================
  Widget _buildAdvocatePromotionCard() {
    const double logoSize = 72;
    const double logoRingPadding = 3.5;
    const double logoInnerPadding = 5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(color: Colors.white, width: logoRingPadding),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF1F8E9)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(logoInnerPadding),
              child: ClipOval(
                child: Container(
                  color: Colors.white,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.gavel_rounded,
                      color: Color(0xFF1B5E20),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Want to be an Advocate?",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Join our User platform and connect with clients across Bangladesh.",
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('https://ukil.com.bd');
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Visit User App"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B5E20),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// lib/AdvocatePages/advocate_home_page_pageview.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../AdvocatePages/AdvocateFilterPage.dart';
import '../LiveLocations/live_location_screen.dart';
import '../LiveLocations/live_location_provider.dart';
import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class AdvocateHomePage extends StatelessWidget {
  final bool? isShow;
  
  const AdvocateHomePage({super.key, this.isShow});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LiveLocationProvider(),
      child: _AdvocateHomePageContent(
        showBackButton: isShow ?? true, // Default to true if not provided
      ),
    );
  }
}

class _AdvocateHomePageContent extends StatefulWidget {
  final bool showBackButton;
  
  const _AdvocateHomePageContent({
    super.key,
    required this.showBackButton,
  });

  @override
  State<_AdvocateHomePageContent> createState() => _AdvocateHomePageContentState();
}

class _AdvocateHomePageContentState extends State<_AdvocateHomePageContent> {
  int _selectedIndex = 0;
  String? userId;
  String? userName, fullName;
  bool _isLoading = true;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    getUserInfo();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> getUserInfo() async {
    try {
      final id = await AuthService.getUserId();
      
      if (id != null && id.isNotEmpty) {
        String? token = await AuthService.getToken();
        
        final response = await http.get(
          Uri.parse('${BASE_URL.Urls().baseURL}user/search?userId=$id'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            userId = data['id'] ?? id;
            userName = data['name'] ?? 'User';
            fullName = data['fullName'];
            _isLoading = false;
          });
        } else {
          setState(() {
            userId = id;
            userName = 'User';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error getting user info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? "Find Advocate" : "Live Location",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        // Only show back button if showBackButton is true
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              )
            : null, // Use null instead of Text() for no leading widget
        // Add this to properly align title when no back button
        automaticallyImplyLeading: widget.showBackButton,
        actions: [
          if (_selectedIndex == 1)
            Consumer<LiveLocationProvider>(
              builder: (context, locationProvider, child) {
                return IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.grey),
                  onPressed: () {
                    locationProvider.refreshLocations();
                  },
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 16),
                  Text('Loading...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: [
                const AdvocateFilterPage(),
                if (userId != null && userId!.isNotEmpty)
                  LiveLocationScreen(
                    userId: userId!,
                    advocateId: null,
                    userName: userName ?? 'User',
                    fullName: fullName ?? userName,
                  )
                else
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Please login to see live location',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Advocates',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Live Location',
          ),
        ],
      ),
    );
  }
}
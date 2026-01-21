import 'package:flutter/material.dart';

import './AdminListPage.dart';
import 'SeeAllAdminJoinRequest.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int currentIndex = 0;

  // Pages without `const` to avoid web runtime errors
  final List<Widget> pages = [
    AdminJoinRequestPage(),
    AdminListPage(),
  ];

  final List<String> titles = [
    "Admin Join Requests",
    "All Admins",
  ];

  void onTabTapped(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(titles[currentIndex]),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: pages[currentIndex],
        // Use a key to help Flutter Web identify the widget
        key: ValueKey<int>(currentIndex),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTabTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: "Join Requests",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: "Admins",
          ),
        ],
      ),
    );
  }
}

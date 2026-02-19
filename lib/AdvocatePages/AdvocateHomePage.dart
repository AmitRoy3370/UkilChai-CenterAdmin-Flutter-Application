import 'dart:convert';
import 'package:advocatechaicenteradmin/AdvocatePages/AdvocateFilterPage.dart';
import 'package:advocatechaicenteradmin/AdvocatePages/advocate_join_request_filter_pages.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/AuthService.dart';

import '../ChatRelatedPages/user_active_service.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import '../Utils/AdvocateSpeciality.dart';

class AdvocateHomePage extends StatefulWidget {
  const AdvocateHomePage({super.key});

  @override
  State<AdvocateHomePage> createState() => _AdvocateHomePage();
}

class _AdvocateHomePage extends State<AdvocateHomePage> {
  List<Widget> pages = [AdvocateFilterPage(), AdvocateJoinRequestFilterPage()];
  int index = 0;


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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Advocate Home Page",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green,
      ),
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: " All Advocate",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: " Advocate request",
          ),
        ],
        currentIndex: index,
        onTap: (value) {
          setState(() {
            index = value;
          });
        },
      ),
    );
  }
}

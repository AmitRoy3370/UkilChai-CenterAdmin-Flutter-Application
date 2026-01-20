import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/AuthService.dart';
import '../RegistrationPage/RegistrationPage.dart';
import 'package:advocatechaicenteradmin/Utils/BaseURL.dart' as baseURL;
import 'dart:io';
import 'dart:typed_data';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<StatefulWidget> createState() {
    return LogInState();
  }
}

class LogInState extends State<LogIn> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool isVisible = false;

  bool _isPasswordVisible = false; // 👈 Password visibility controller

  Future<bool> doesItVisible() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";

    //print("token :- $token");

    if (token.isEmpty) {
      return false;
    }

    String allAthleteURL = "${baseURL.Urls().baseURL}advocate/all";

    Uri uri = Uri.parse(allAthleteURL);

    var response = await http.get(
      uri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    //print("response status code :- ${response.statusCode}");

    if (response.statusCode == 403) {
      return false;
    }

    isVisible = true;

    setState(() {
      isVisible = true;
    });

    return true;
  }

  Future<void> _submitForm() async {
    String email = emailController.text;
    String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
    } else {
      String loginURL = "${baseURL.Urls().baseURL}auth/login";

      Uri uri = Uri.parse(loginURL);

      var logInResponse = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userName": email, "password": password}),
      );

      if (logInResponse.statusCode == 200 || logInResponse.statusCode == 201) {

        print("logIn response :- ${logInResponse.body}");

        final centerAdminUrl =
            "${baseURL.Urls().baseURL}center-admin/by-user/${jsonDecode(logInResponse.body)["userId"]}";

        Uri centerAdminUri = Uri.parse(centerAdminUrl);

        final centerAdminResponse = await http.get(
          centerAdminUri,
          headers: {
            "Authorization":
                "Bearer ${jsonDecode(logInResponse.body)["token"]}",
            "Content-Type": "application/json",
          },
        );

        print("center admin response :- ${centerAdminResponse.statusCode}");

        if (centerAdminResponse.statusCode == 200 ||
            centerAdminResponse.statusCode == 201) {
          final decoded = jsonDecode(logInResponse.body);

          final userId = decoded["userId"];
          final String token = decoded["token"];

          //print("received token :- $token");

          // -------- Save token (App + Web) ----------
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("jwt_token", token);
          await prefs.setString("userId", userId);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Logged in successfully...")),
          );

          setState(() {
            isVisible = true;
            AuthService.saveToken(token);
            AuthService.saveUserId(userId);
          });
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Only center admin can logged in at here....", style: TextStyle(color: Colors.red,))));
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(logInResponse.body)));
      }
    }
  }

  initState() {
    super.initState();
    doesItVisible();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          TextField(
            decoration: InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(25.0)),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.all(10),
              hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            controller: emailController,
            maxLines: 1,
          ),

          const SizedBox(height: 20),

          // ============================
          // 🔥 Password TextField (with Show/Hide)
          // ============================
          TextField(
            controller: passwordController,
            obscureText: !_isPasswordVisible, // 👈 toggles text visibility
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(25.0)),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.all(10),

              // 👇 Suffix icon to toggle visibility
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              _submitForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              "Log In",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RegistrationPage()),
              );
            },
            child: Text(
              "Don't have account? Please register",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Visibility(
            visible: (isVisible),

            child: Text(
              "You are logged in...",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

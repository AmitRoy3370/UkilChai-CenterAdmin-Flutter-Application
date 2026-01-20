import 'package:advocatechaicenteradmin/ProfilePage/ProfileAvatar.dart';
import 'package:advocatechaicenteradmin/ProfilePage/ProfileImageWidget.dart';
import 'package:flutter/material.dart';

import 'HomePage.dart';
import 'LogInPage/LogIn.dart';
import 'ProfilePage/ProfileMenuPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'উকিল',
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'উকিল চাই'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

int index = 0;

class _MyHomePageState extends State<MyHomePage> {

  static final List<Widget> bottomPages = [
    Homepage(),
    Homepage(),
    Homepage(),
    Homepage(),
    LogIn()

  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      appBar: AppBar(
        title: Text("উকিল"),
        centerTitle: true,
        backgroundColor: Colors.green,
        titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold
        ),
        actions: [
          Padding(
              padding: EdgeInsets.only(right: 20),
              child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileMenuPage()),
                    );
                  },
                  child: ProfileImageWidget()
              )
          )
        ],

      ),
      body: bottomPages[index],
      bottomNavigationBar: BottomNavigationBar(
        items: const [

          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
            backgroundColor: Colors.black,
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.article),
              label: "Articles",
              backgroundColor: Colors.black
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Advocate",
              backgroundColor: Colors.black
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.pages),
              label: "Pages",
              backgroundColor: Colors.black
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.login),
              label: "LogIn",
              backgroundColor: Colors.black
          ),

        ],
        currentIndex: index,
        onTap: (value) {
          setState(() {

            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("clicked Index: $value and previous index : $index"),
                  duration: Duration(seconds: 2),
                )
            );

            index = value;
          });
        },

      ),

    );
  }
}

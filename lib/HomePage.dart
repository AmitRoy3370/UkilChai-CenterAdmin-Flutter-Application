
import 'package:advocatechaicenteradmin/HomePage/AdvocateList.dart';
import 'package:advocatechaicenteradmin/HomePage/ArticleList.dart';
import 'package:advocatechaicenteradmin/HomePage/QuickConnect.dart';
import 'package:flutter/cupertino.dart';

import 'HomePage/SearchScreen.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<StatefulWidget> createState() {

    return HomeScreenState();

  }

}

class HomeScreenState extends State<Homepage> {
  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      child: Column(
          children: [

            const SizedBox(height: 20),
            SearchScreen(),
            const SizedBox(height: 20),
            QuickConnect(),
            ArticleList(),
            const SizedBox(height: 20),
            AdvocateList(),
            const SizedBox(height: 20),

          ]
      ),
    );

  }

}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../AdminsPage/SeeAllAdminJoinRequest.dart';
import '../Auth/AuthService.dart';
import '../QuestionPages/AskQuestionPage.dart';
import 'QuickCard.dart';

class QuickConnect extends StatelessWidget {
  const QuickConnect({super.key});

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Title Row
        Row(
          children: const [
            Icon(Icons.rocket_launch, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              "Quick Connect",
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),

        // 2x2 Grid of Cards
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: [

            // 1st Tile
            QuickCard(
              icon: Icons.person_search,
              title: "Admin Request",
              subtitle: "Connect with specialized admins",
              onTap : () {
                print("Find Expert");

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_)  => AdminJoinRequestPage(),
                  ),
                );

              }

            ),

            // 2nd Tile
            QuickCard(
              icon: Icons.chat_bubble_outline,
              title: "Chat with Expert",
              subtitle: "15-min free consultation",
              onTap:() {
                print("Free Consult");
              }
            ),

            // 3rd Tile
            QuickCard(
              icon: Icons.help_outline_rounded,
              title: "Ask Question",
              subtitle: "Public Q&A with advocates",
              onTap : () async {
                print("Ask Question");

                SharedPreferences prefs = await SharedPreferences.getInstance();
                String userId = prefs.getString("userId") ?? "";

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_)  => AskQuestionPage(userId: userId),
                  ),
                );

              }
            ),

            // 4th Tile
            QuickCard(
              icon: Icons.calendar_month,
              title: "Book Meeting",
              subtitle: "Schedule consultation",
              onTap: () {
                print("Book Meeting");
              },
            ),
          ],
        ),
      ],
    );

  }

}
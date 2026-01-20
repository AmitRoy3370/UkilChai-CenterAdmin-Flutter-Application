import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ArticleList extends StatelessWidget {
  const ArticleList({super.key});

  @override
  Widget build(BuildContext context) {
    return MyArtileList();
  }
}

class MyArtileList extends StatelessWidget {
  const MyArtileList({super.key});

  @override
  Widget build(BuildContext context) {
    List<String> articles = ["article1", "article2", "article3", "article4"];

    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          "Top articles list...",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        ListView.separated(
          itemCount: articles.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          scrollDirection: Axis.vertical,
          padding: EdgeInsets.all(10),
          separatorBuilder: (context, index) {
            return Divider(
              color: Colors.red,
              thickness: 1,
              indent: 10,
              endIndent: 10,
              height: 20,
            );
          },

          itemBuilder: (context, index) {
            return InkWell(
              // Or GestureDetector
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Clicked on ${articles[index]}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                // Perform actions like navigating to a detail page
                // Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(item: items[index])));
              },
              child: ListTile(
                title: Text(
                  articles[index],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  'Details for ${articles[index]}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

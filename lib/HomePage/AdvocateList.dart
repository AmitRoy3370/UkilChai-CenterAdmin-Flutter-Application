import 'dart:convert';
import 'package:advocatechaicenteradmin/AdvocatePages/AdvocateDetailsModel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:advocatechaicenteradmin/Utils/BaseURL.dart' as baseURL;
import 'package:advocatechaicenteradmin/Auth/AuthService.dart';

import '../AdvocatePages/AdvocateDetails.dart';

class AdvocateList extends StatelessWidget {
  const AdvocateList({super.key});

  Future<List<AdvocateDetailsModel>> getAdvocateList() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse("${baseURL.Urls().baseURL}advocate/all");

    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to load advocates");
    }

    final List responseData = jsonDecode(response.body);
    List<AdvocateDetailsModel> list = [];

    for (var item in responseData) {
      Map<String, dynamic> advocateDecoded = item;

      String userId = advocateDecoded["userId"];

      print("getting userId :- $userId");

      final userResponse = await http.get(
        Uri.parse("${baseURL.Urls().baseURL}user/search?userId=$userId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (userResponse.statusCode == 200) {
        final user = jsonDecode(userResponse.body);

        final contactResponse = await http.get(
          Uri.parse(
            "${baseURL.Urls().baseURL}user/contact-info/user?userId=$userId",
          ),
          headers: {"Authorization": "Bearer $token"},
        );

        var advocateDetailsModel = AdvocateDetailsModel.defaultConstructor();

        advocateDetailsModel.name = user["name"];
        advocateDetailsModel.profileImageId = user["profileImageId"];
        advocateDetailsModel.userId = userId;

        advocateDetailsModel.id = advocateDecoded["id"];
        advocateDetailsModel.experience = advocateDecoded["experience"];
        advocateDetailsModel.licenseKey = advocateDecoded["licenseKey"];
        advocateDetailsModel.advocateSpeciality =
            advocateDecoded["advocateSpeciality"];
        advocateDetailsModel.degrees = advocateDecoded["degrees"];
        advocateDetailsModel.workingExperiences =
            advocateDecoded["workingExperiences"];
        advocateDetailsModel.password = user["password"];

        if (contactResponse.statusCode == 200) {
          final contact = jsonDecode(contactResponse.body);

          final locationResponse = await http.get(
            Uri.parse(
              "${baseURL.Urls().baseURL}userLocation/findByUserId/$userId",
            ),
            headers: {"Authorization": "Bearer $token"},
          );

          advocateDetailsModel.email = contact["email"];
          advocateDetailsModel.phone = contact["phone"];

          if (locationResponse.statusCode == 200) {
            final location = jsonDecode(locationResponse.body);

            advocateDetailsModel.locationName = location["locationName"];
            advocateDetailsModel.lattitude = location["lattitude"];
            advocateDetailsModel.longitude = location["longitude"];

            /*list.add(
              AdvocateDetailsModel(
                advocateDecoded["id"],
                user["name"],
                contact["email"],
                contact["phone"],
                user["profileImageId"],
                location["locationName"],
                location["lattitude"],
                location["longitude"],
                user["password"],
                advocateDecoded["experience"],
                advocateDecoded["licenseKey"],
                advocateDecoded["advocateSpeciality"],
                advocateDecoded["degrees"],
                advocateDecoded["workingExperiences"],
                userId
              ),
            );*/
          }
        }

        if (advocateDetailsModel.name != null &&
            advocateDetailsModel.userId != null &&
            advocateDetailsModel.id != null) {
          list.add(advocateDetailsModel);
        }
      }
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: getAdvocateList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              snapshot.error.toString(),
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final advocates = snapshot.data!;

        if (kDebugMode) {
          print("advocates :- $advocates");
        }

        if (advocates.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No advocates found",
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              "Top advocates list...",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: advocates.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.red),
              itemBuilder: (context, index) {
                final AdvocateDetailsModel advocate = advocates[index];

                return ListTile(
                  title: Text(
                    advocate.name ?? "Unknown Advocate",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdvocateDetails(advocateDetailsModel: advocate),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

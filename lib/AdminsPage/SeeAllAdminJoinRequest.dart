import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/AuthService.dart';
import './AdminJoinRequest.dart';
import './AdminJoinRequestService.dart';
import './AdvocateSpeciality.dart';
import '../Utils/BaseURL.dart' as BASE_URL;

class AdminJoinRequestPage extends StatefulWidget {
  const AdminJoinRequestPage({super.key});

  @override
  State<AdminJoinRequestPage> createState() => _AdminJoinRequestPageState();
}

class _AdminJoinRequestPageState extends State<AdminJoinRequestPage> {
  final service = AdminJoinRequestService();
  List<AdminJoinRequest> list = [];
  bool loading = true;

  AdvocateSpeciality? selectedSpeciality;
  final TextEditingController userIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    list = await service.getAll();
    setState(() => loading = false);
  }

  Future<void> searchByUser() async {
    if (userIdCtrl.text.isEmpty) return;
    setState(() => loading = true);
    final result = await service.findByUserId(userIdCtrl.text.trim());
    list = [result];
    setState(() => loading = false);
  }

  Future<void> searchBySpeciality(String speciality) async {
    setState(() => loading = true);
    list = await service.searchBySpeciality(speciality);
    setState(() => loading = false);
  }

  Future<String?> getName(String userId) async {

    print("userId in getName :- $userId");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";


    final nameResponse = await http.get(
      Uri.parse("${BASE_URL.Urls().baseURL}user/search?userId=$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("name status :- ${nameResponse.statusCode}");

    if (nameResponse.statusCode == 200) {
      final name = jsonDecode(nameResponse.body)["name"];

      print("name :- $name");

      return name;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Admin Join Requests"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadAll),
        ],
      ),
      body: Column(
        children: [
          // -------- USER ID SEARCH --------
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: userIdCtrl,
                    decoration: const InputDecoration(
                      labelText: "Search by User ID",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: searchByUser,
                ),
              ],
            ),
          ),

          // -------- SPECIALITY DROPDOWN --------
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButtonFormField<AdvocateSpeciality>(
              hint: const Text("Search by Speciality", style: TextStyle(color: Colors.red, fontSize: 15, fontStyle: FontStyle.normal),),
              value: selectedSpeciality,
              items: AdvocateSpeciality.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(specialityLabel(s.name), style: TextStyle(color: Colors.red, fontSize: 15, fontStyle: FontStyle.normal),),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedSpeciality = value;
                  searchBySpeciality(value.name);
                }
              },
            ),
          ),

          // -------- LIST --------
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? const Center(child: Text("No data found"))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final r = list[index];

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: FutureBuilder<String?>(
                            future: getName(r.userId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Text("Loading name...");
                              }
                              if (!snapshot.hasData || snapshot.data == null) {
                                return const Text("User name: N/A");
                              }
                              return Text("User name: ${snapshot.data}");
                            },
                          ),
                          subtitle: Wrap(
                            spacing: 6,
                            children: r.advocateSpeciality
                                .map((e) => Chip(label: Text(specialityLabel(e))))
                                .toList(),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              // -------- ACCEPT --------
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                tooltip: "Accept",
                                onPressed: () async {
                                  await service.handleJoinRequest(
                                    r.id,
                                    r.userId,
                                    "ACCEPT",
                                  );
                                  loadAll();
                                },
                              ),

                              // -------- REJECT --------
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.orange),
                                tooltip: "Reject",
                                onPressed: () async {
                                  await service.handleJoinRequest(
                                    r.id,
                                    r.userId,
                                    "REJECT",
                                  );
                                  loadAll();
                                },
                              ),

                              // -------- DELETE --------
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: "Delete",
                                onPressed: () async {
                                  await service.delete(r.id, r.userId);
                                  loadAll();
                                },
                              ),
                            ],
                          ),

                        ),
                      );

                    },
                  ),
          ),
        ],
      ),
    );
  }
}

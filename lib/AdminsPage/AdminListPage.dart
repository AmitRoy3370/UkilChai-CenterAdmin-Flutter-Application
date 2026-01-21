import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Utils/BaseURL.dart' as BASE_URL;
import './Admin.dart';
import './AdminService.dart';
import './AdvocateSpeciality.dart';

class AdminListPage extends StatefulWidget {
  const AdminListPage({super.key});

  @override
  State<AdminListPage> createState() => _AdminListPageState();
}

class _AdminListPageState extends State<AdminListPage> {
  final service = AdminService();

  List<Admin> list = [];
  bool loading = true;

  final TextEditingController userIdCtrl = TextEditingController();
  AdvocateSpeciality? selectedSpeciality;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  // ================= LOAD ALL =================
  Future<void> loadAll() async {
    setState(() => loading = true);
    list = await service.getAll();
    selectedSpeciality = null;
    userIdCtrl.clear();
    setState(() => loading = false);
  }

  // ================= SEARCH BY USER ID =================
  Future<void> searchByUserId() async {
    if (userIdCtrl.text.trim().isEmpty) return;

    String name = userIdCtrl.text.trim();

    final uri = Uri.parse("${BASE_URL.Urls().baseURL}user/find/name/$name");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";

    final response = await http.get(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      setState(() => loading = true);
      final admin = await service.findByUserId(decoded["id"]);
      list = [admin];
      setState(() => loading = false);
    } else {
      setState(() => loading = true);
      list = [];
      setState(() => loading = false);
    }
  }

  // ================= SEARCH BY SPECIALITY =================
  Future<void> searchBySpeciality(AdvocateSpeciality speciality) async {
    setState(() => loading = true);
    list = await service.findBySpeciality(speciality.name);
    setState(() => loading = false);
  }

  // ================= GET USER NAME =================
  Future<String?> getName(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString("jwt_token") ?? "";

    final res = await http.get(
      Uri.parse("${BASE_URL.Urls().baseURL}user/search?userId=$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body)["name"];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("All Admins"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadAll),
        ],
      ),
      body: Column(
        children: [
          // ================= USER ID SEARCH =================
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: userIdCtrl,
                    decoration: const InputDecoration(
                      labelText: "Search by User Name",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: searchByUserId,
                ),
              ],
            ),
          ),

          // ================= SPECIALITY DROPDOWN =================
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButtonFormField<AdvocateSpeciality>(
              value: selectedSpeciality,
              hint: const Text("Search by Speciality"),
              items: AdvocateSpeciality.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(specialityLabel(s.name)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedSpeciality = value;
                  searchBySpeciality(value);
                }
              },
            ),
          ),

          // ================= LIST =================
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? const Center(child: Text("No admin found"))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final admin = list[index];

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: FutureBuilder<String?>(
                            future: getName(admin.userId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
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
                            children: admin.advocateSpeciality
                                .map(
                                  (e) => Chip(label: Text(specialityLabel(e))),
                                )
                                .toList(),
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

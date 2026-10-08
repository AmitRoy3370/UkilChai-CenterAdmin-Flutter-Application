// lib/ChatRelatedPages/AllUserChatListScreen.dart
// Auto-reloads on every entry and every return from a pushed screen.
// No changes to main.dart required.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Utils/BaseURL.dart' as BASE_URL;
import 'chat_screen.dart';
import 'chat_list_item.dart';
import 'chat_response.dart';
import 'sender_info.dart';
import 'receiver_info.dart';

class AllUserChatListScreen extends StatefulWidget {
  final String? currentUserId;
  final String? currentUserName;

  const AllUserChatListScreen({
    Key? key,
    required this.currentUserId,
    required this.currentUserName,
  }) : super(key: key);

  @override
  _AllUserChatListScreenState createState() => _AllUserChatListScreenState();
}

class _AllUserChatListScreenState extends State<AllUserChatListScreen>
    with WidgetsBindingObserver {
  List<ChatListItem> _chatList = [];
  List<ChatListItem> _filteredChatList = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  List<ChatResponse> chatResponses = [];

  List<dynamic> _centerAdmins = [];
  Map<String, dynamic> _userDetails = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fresh load every time this screen is created
    _loadChatList();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  /// Called when the app is resumed from background.
  /// Refresh the list so it's fresh when the user comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadChatList();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data loading
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadChatList() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      final String? userId = prefs.getString('userId');

      if (token == null) {
        throw Exception('Need to login first to load chat list');
      }

      final centerAdminResponse = await http.get(
        Uri.parse('${BASE_URL.Urls().baseURL}chat/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (centerAdminResponse.statusCode == 200) {
        final decodedResponse = jsonDecode(centerAdminResponse.body);

        chatResponses = List<ChatResponse>.from(
          decodedResponse.map((item) => ChatResponse.fromJson(item)),
        );

        await _buildChatList(token);
      } else {
        throw Exception(
          'Failed to load center admins: ${centerAdminResponse.statusCode}',
        );
      }
    } catch (e) {
      print('Error loading chat list: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserDetails(String token) async {
    try {
      for (var admin in _centerAdmins) {
        String userId = admin['id'];
        if (userId != widget.currentUserId) {
          final userResponse = await http.get(
            Uri.parse('${BASE_URL.Urls().baseURL}user/search?userId=$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (userResponse.statusCode == 200) {
            _userDetails[userId] = jsonDecode(userResponse.body);
          }
        }
      }
    } catch (e) {
      print('Error loading user details: $e');
    }
  }

  Future<bool> isActive(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse("${BASE_URL.Urls().baseURL}user-active/user/$userId"),
      headers: {
        'content-type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  Future<void> _buildChatList(String token) async {
    List<ChatListItem> tempList = [];

    final activeResponse = await http.get(
      Uri.parse('${BASE_URL.Urls().baseURL}user-active/status?active=${true}'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    Map<String, bool> activeness = {};

    if (activeResponse.statusCode == 200) {
      List<dynamic> activeUsers = jsonDecode(activeResponse.body);
      for (var user in activeUsers) {
        String userId = user['userId'];
        bool active = user['active'];
        activeness[userId] = active;
      }
    }

    try {
      for (var admin in chatResponses) {
        try {
          DateTime? timeStamp = admin.timeStamp;

          SenderInfo? senderInfo = admin.senderInfo;
          ReceiverInfo? receiverInfo = admin.receiverInfo;

          String? lateMessage;
          String? otherUserId, otherUserName;

          if (senderInfo != null && senderInfo.receiverId != null) {
            lateMessage = senderInfo.message;
            otherUserId = senderInfo.receiverId;
            otherUserName = senderInfo.receiverName;
          } else if (receiverInfo != null && receiverInfo.senderId != null) {
            lateMessage = receiverInfo.message;
            otherUserId = receiverInfo.senderId;
            otherUserName = receiverInfo.senderName;
          } else {
            continue;
          }

          if (otherUserId == null || otherUserName == null) continue;

          String userAvatar = otherUserName[0].toString();

          bool? isOnline =
              activeness.isNotEmpty && activeness.containsKey(otherUserId);
          bool? isUnread = senderInfo != null
              ? senderInfo.readChat
              : receiverInfo?.readChat;

          try {
            ChatListItem listItem = ChatListItem(
              userId: otherUserId,
              userName: otherUserName,
              userAvatar: userAvatar,
              lastMessage: lateMessage,
              lastMessageTime: timeStamp,
              unreadCount: (isUnread != null && !isUnread) ? 1 : 0,
              isOnline: isOnline == true,
            );
            tempList.add(listItem);
          } catch (e) {
            print("error :- $e");
          }
        } catch (e) {
          print("error :- $e");
        }
      }

      try {
        tempList.sort((a, b) {
          if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
          if (a.lastMessageTime == null) return 1;
          if (b.lastMessageTime == null) return -1;
          return b.lastMessageTime!.compareTo(a.lastMessageTime!);
        });
      } catch (e) {
        print('Error sorting chat list: $e');
      }

      if (!mounted) return;
      setState(() {
        _chatList = tempList;
        _filteredChatList = List.from(_chatList);
        _isLoading = false;
      });
    } catch (e) {
      print('Error building chat list: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Error building chat list: $e';
        _isLoading = false;
      });
    }
  }

  void _filterChatList(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredChatList = List.from(_chatList);
      });
      return;
    }

    final filtered = _chatList.where((chat) {
      return chat.userName.toLowerCase().contains(query.toLowerCase()) ||
          (chat.lastMessage?.toLowerCase().contains(query.toLowerCase()) ??
              false);
    }).toList();

    setState(() {
      _filteredChatList = filtered;
    });
  }

  Future<void> _refreshChatList() async {
    await _loadChatList();
  }

  Future<void> _markChatAsRead(String otherUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      final historyResponse = await http.get(
        Uri.parse(
          '${BASE_URL.Urls().baseURL}chat/history/${widget.currentUserId}/$otherUserId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (historyResponse.statusCode == 200) {
        List<dynamic> messages = jsonDecode(historyResponse.body);
        for (var msg in messages) {
          if (msg['receiver'] == widget.currentUserId) {
            await http.put(
              Uri.parse(
                '${BASE_URL.Urls().baseURL}readable-chat/update/${msg['id']}/${widget.currentUserId}',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({"chatId": msg['id'], "isRead": true}),
            );
          }
        }
      }
    } catch (e) {
      print("Error marking chat read: $e");
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Navigation — refresh after return (no observer needed)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _navigateToChat(String userId, String userName) async {
    await _markChatAsRead(userId);

    if (!mounted) return;

    // Await the push so we can refresh the moment the user comes back.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          currentUser: widget.currentUserId,
          otherUser: userId,
          othersName: userName,
          myName: widget.currentUserName,
        ),
      ),
    );

    // Auto-reload on return from ChatScreen.
    if (mounted) {
      await _loadChatList();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildChatListItem(ChatListItem chat) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            chat.userName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  FutureBuilder<bool>(
                    future: isActive(chat.userId),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          snapshot.data! ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: snapshot.data!
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      } else {
                        return const Text(
                          'Offline',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            if (chat.unreadCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  chat.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chat.lastMessage != null)
              Text(
                chat.lastMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            const SizedBox(height: 4),
            if (chat.lastMessageTime != null)
              Text(
                _formatTime(chat.lastMessageTime!),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        onTap: () => _navigateToChat(chat.userId, chat.userName),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return DateFormat('hh:mm a').format(time);
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Loading chats...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 20),
          const Text(
            'Error loading chats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshChatList,
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start a conversation with other Users',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshChatList,
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshChatList,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
              onChanged: _filterChatList,
            ),
          ),
          const Divider(height: 1),

          // Chat list
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                    ? _buildErrorState()
                    : _filteredChatList.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () async {
                              await _loadChatList();
                            },
                            child: ListView.builder(
                              itemCount: _filteredChatList.length,
                              itemBuilder: (context, index) {
                                return _buildChatListItem(
                                    _filteredChatList[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
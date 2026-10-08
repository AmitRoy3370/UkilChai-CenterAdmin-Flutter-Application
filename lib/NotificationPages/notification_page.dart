// notification_page.dart
//
// Self-contained NotificationPage — owns its own NotificationService
// instance. Does NOT require a Provider/ChangeNotifierProvider in main.dart.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'notification_model.dart';
import '../ProfilePage/SeeMyProfile.dart';
import '../ChatRelatedPages/chat_screen.dart';
import '../GroupChat/GroupChatScreen.dart';
import '../CaseRelatedPages/case_tracking.dart';
import '../CaseRelatedPages/CaseDetailsPage.dart';
import '../CaseRelatedPages/case_service.dart';
import '../CaseRelatedPages/case_model.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  // ── Self-owned service (no Provider required) ────────────────────────────
  final NotificationService _service = NotificationService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(_animationController);
    _animationController.forward();

    // Initialize the service with context and load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.setContext(context);
      _service.loadUnreadNotifications();
      _service.connectWebSocket();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _service.dispose();
    super.dispose();
  }

  // ── Deep-link handler (shared between trailing check icon and onTap) ─────
  Future<void> _handleNotificationTap(NotificationModel notification) async {
    // Mark as read
    await _service.markAsRead(notification.id);

    final List<String> destinations = notification.destinations;
    final Map<String, String> params = notification.params;

    if (destinations.isEmpty) return;

    final String className = destinations.last;

    if (!mounted) return;

    if (className == 'SeeMyProfile' || className == 'ProfilePage') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeeMyProfile()),
      );
    } else if (className == 'CaseDetailsPage') {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');
      final String? caseId = params["caseId"];
      if (token == null || caseId == null) return;
      final CaseModel caseModel = await CaseService(token).findById(caseId);
      final String? userId = caseModel.userId;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaseDetailsPage(
            caseModel: caseModel,
            userId: userId,
            onDeleted: () {
              if (mounted) setState(() {});
            },
          ),
        ),
      );
    } else if (className == 'ChatScreen') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUser: params["currentUser"],
            otherUser: params["otherUser"],
            othersName: params["othersName"],
            myName: params["myName"],
          ),
        ),
      );
    } else if (className == 'GroupChatScreen') {
      final groupId = params["groupId"] ?? '';
      final groupName = params["groupName"] ?? '';
      final currentUserId = params["currentUserId"] ?? '';
      final currentUserName = params["currentUserName"] ?? '';
      const bool isAdmin = false;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: groupId,
            groupName: groupName,
            currentUserId: currentUserId,
            currentUserName: currentUserName,
            isAdmin: isAdmin,
          ),
        ),
      );
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 7) {
      return '${diff.inDays ~/ 7} সপ্তাহ আগে';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} দিন আগে';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ঘন্টা আগে';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} মিনিট আগে';
    } else {
      return 'এখনই';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("নোটিফিকেশন"),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Connection status indicator (ListenableBuilder — no Provider)
          ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _service.isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _service.isConnected ? "লাইভ" : "অফলাইন",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          // Loading state
          if (_service.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 16),
                  Text("নোটিফিকেশন লোড হচ্ছে..."),
                ],
              ),
            );
          }

          // Empty state
          if (_service.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "কোনো নোটিফিকেশন নেই",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "নতুন নোটিফিকেশন এখানে দেখাবে",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          // Notification list
          return RefreshIndicator(
            onRefresh: () => _service.loadUnreadNotifications(),
            color: Colors.green,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _service.notifications.length,
              itemBuilder: (context, index) {
                final notification = _service.notifications[index];

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        index * 0.05,
                        1.0,
                        curve: Curves.easeOut,
                      ),
                    )),
                    child: Dismissible(
                      key: Key(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      onDismissed: (_) =>
                          _service.deleteNotification(notification.id),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: notification.isRead
                                ? Colors.grey.shade200
                                : Colors.green.shade100,
                            child: Icon(
                              Icons.notifications_active,
                              color: notification.isRead
                                  ? Colors.grey.shade600
                                  : Colors.green.shade700,
                            ),
                          ),
                          title: Text(
                            notification.message,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatTime(notification.timeStamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          trailing: notification.isRead
                              ? null
                              : Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        _handleNotificationTap(notification),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                          onTap: () =>
                              _handleNotificationTap(notification),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
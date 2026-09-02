import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skybridge02/CommunicationManagement/chatscreen.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';

class ChatListScreen extends StatefulWidget {
  final bool showBackButton;
  final String selectedTab;

  const ChatListScreen({
    super.key,
    this.showBackButton = true,
    this.selectedTab = 'Buyer',
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool loading = true;
  List<Map<String, dynamic>> chats = [];
  Timer? _refreshTimer;

  String get myRole => widget.selectedTab.toLowerCase() == 'buyer' ? 'buyer' : 'traveler';
  String get title => 'Messages';

  @override
  void initState() {
    super.initState();
    loadChats();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => loadChats(showLoader: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab) {
      loadChats();
    }
  }

  Future<void> loadChats({bool showLoader = true}) async {
    try {
      if (showLoader && mounted) setState(() => loading = true);

      final response = await ApiService.get('/api/messages/my');
      final items = response is List ? response : [];
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final item in items) {
        final msg = Map<String, dynamic>.from(item as Map);
        final source = (msg['source'] ?? '').toString().toLowerCase();
        final senderId = (msg['senderId'] ?? msg['userId'] ?? '').toString();
        final receiverId = (msg['receiverId'] ?? '').toString();
        final senderRole = (msg['senderRole'] ?? '').toString().toLowerCase();
        final receiverRole = (msg['receiverRole'] ?? '').toString().toLowerCase();

        // Messages tab is only for buyer <-> traveler peer messages.
        // CRS/support/dispute/admin chats stay in the Support menu only.
        if (source != 'peer') continue;
        if (senderId == 'admin' || receiverId == 'admin') continue;
        if (senderId.isEmpty || receiverId.isEmpty) continue;

        final bool iSent = currentUid.isNotEmpty && senderId == currentUid;
        final bool iReceived = currentUid.isNotEmpty && receiverId == currentUid;
        if (!iSent && !iReceived) continue;

        final otherRole = iSent ? receiverRole : senderRole;
        final otherUserId = iSent ? receiverId : senderId;
        final otherName = iSent
            ? _pick(msg, ['receiverName', 'otherUserName'], fallback: 'User')
            : _pick(msg, ['senderName', 'name', 'userName'], fallback: 'User');
        final otherImage = iSent
            ? _pick(msg, ['receiverImage', 'otherUserImage'], fallback: '')
            : _pick(msg, ['senderImage', 'profilePicUrl', 'userImage'], fallback: '');

        final createdAt = _safeDate(msg['updatedAt'] ?? msg['createdAt']);
        final key = 'peer-$otherUserId';
        final current = grouped[key];
        final currentDate = _safeDate(current?['createdAt']);

        if (current == null || createdAt.isAfter(currentDate)) {
          grouped[key] = {
            'chatId': key,
            'otherUserId': otherUserId,
            'title': otherName,
            'image': otherImage,
            'role': _roleLabel(otherRole),
            'createdAt': createdAt.toIso8601String(),
          };
        }
      }

      final loaded = grouped.values.toList()
        ..sort((a, b) => _safeDate(b['createdAt']).compareTo(_safeDate(a['createdAt'])));

      if (mounted) {
        setState(() {
          chats = loaded;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load chats error: $e');
      if (mounted) {
        setState(() {
          chats = [];
          loading = false;
        });
      }
    }
  }

  String _pick(Map<String, dynamic> map, List<String> keys, {required String fallback}) {
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  String _roleLabel(String role) {
    if (role == 'traveler') return 'Traveler';
    if (role == 'buyer') return 'Buyer';
    return 'User';
  }

  DateTime _safeDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget? get _leading {
    if (!widget.showBackButton) return null;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
      ),
      child: IconButton(
        iconSize: 20,
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: title,
        leading: _leading,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => loadChats(),
              child: chats.isEmpty
                  ? emptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No Messages Yet',
                      subtitle: 'Your newest buyer and traveler conversations will appear here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final image = chat['image']?.toString() ?? '';
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                              child: image.isEmpty ? const Icon(Icons.person_outline) : null,
                            ),
                            title: Text(
                              chat['title']?.toString() ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              chat['role']?.toString() ?? 'User',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatId: chat['chatId']?.toString() ?? '',
                                    otherUserId: chat['otherUserId']?.toString() ?? '',
                                    otherUserName: chat['title']?.toString() ?? 'User',
                                    otherUserImage: image,
                                    source: 'peer',
                                    senderRole: myRole,
                                    receiverRole: chat['role']?.toString().toLowerCase() ?? '',
                                  ),
                                ),
                              );
                              loadChats();
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

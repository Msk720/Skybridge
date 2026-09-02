import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'package:skybridge02/Theme/app_color.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = true;
  bool updating = false;
  bool refreshing = false;
  int unreadCount = 0;
  Timer? _refreshTimer;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadNotifications(showLoader: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications({bool showLoader = true}) async {
    if (refreshing) return;

    refreshing = true;

    if (showLoader && mounted) {
      setState(() => loading = true);
    }

    try {
      final res = await ApiService.get('/getNotifications?limit=80');
      final List data = res['data'] ?? [];

      await ApiService.post('/markNotificationRead', {'all': true});

      if (!mounted) return;

      setState(() {
        notifications = List<Map<String, dynamic>>.from(data)
            .map((notification) => {
                  ...notification,
                  'isRead': true,
                })
            .toList();
        unreadCount = 0;
        loading = false;
      });
    } catch (e) {
      debugPrint('Load notifications error: $e');
      if (!mounted) return;
      if (showLoader) {
        setState(() => loading = false);
      }
    } finally {
      refreshing = false;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'OFFER_RECEIVED':
        return Icons.local_offer_rounded;
      case 'OFFER_ACCEPTED':
        return Icons.verified_rounded;
      case 'OFFER_REJECTED':
        return Icons.cancel_rounded;
      case 'ORDER_CANCELLED':
        return Icons.event_busy_rounded;
      case 'ORDER_PICKED':
        return Icons.local_shipping_rounded;
      case 'ORDER_RECEIVED':
        return Icons.done_all_rounded;
      case 'ORDER_PLACED':
        return Icons.shopping_bag_rounded;
      case 'RATING_RECEIVED':
        return Icons.star_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'OFFER_ACCEPTED':
      case 'ORDER_RECEIVED':
        return const Color(0xFF16A34A);
      case 'OFFER_REJECTED':
      case 'ORDER_CANCELLED':
        return const Color(0xFFDC2626);
      case 'ORDER_PICKED':
        return const Color(0xFF0F766E);
      case 'RATING_RECEIVED':
        return const Color(0xFFF59E0B);
      case 'OFFER_RECEIVED':
      case 'ORDER_PLACED':
      default:
        return AppColors.primary;
    }
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';

    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: dashboardAppBar(
        title: 'Notifications',
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        showNotifications: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
                ? emptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No Notifications Yet',
                    subtitle: 'Updates about offers and orders will appear here.',
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      const Text(
                        'Recent notifications',
                        style: TextStyle(
                          color: AppColors.textgray,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...notifications.map(_notificationCard),
                    ],
                  ),
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] == true;
    final type = notification['type']?.toString() ?? '';
    final color = _colorForType(type);

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isRead ? AppColors.border : color.withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isRead ? 0.09 : 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _iconForType(type),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification['title']?.toString() ?? 'Notification',
                          style: TextStyle(
                            color: AppColors.textprimary,
                            fontSize: 15,
                            fontWeight:
                                isRead ? FontWeight.w700 : FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(top: 5, left: 6),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification['message']?.toString() ?? '',
                    style: const TextStyle(
                      color: AppColors.textgray,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: AppColors.icon.withValues(alpha: 0.75),
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatTime(notification['createdAt']),
                        style: const TextStyle(
                          color: AppColors.textgray,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

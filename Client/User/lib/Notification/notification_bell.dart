import 'package:flutter/material.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Theme/app_color.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int unreadCount = 0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final res = await ApiService.get('/getNotifications?unreadOnly=true&limit=1');

      if (!mounted) return;

      setState(() {
        unreadCount = res['unreadCount'] is int ? res['unreadCount'] : 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => unreadCount = 0);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, '/notifications');
    if (mounted) {
      await _loadUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openNotifications,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

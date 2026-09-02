import 'package:skybridge02/DisputeManagement/dispute_dashboard.dart';
import 'package:skybridge02/Services/Chat/chat_service.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/app_imports.dart';

class CustomDrawer extends StatefulWidget {
  final String selectedTab;

  const CustomDrawer({
    super.key,
    this.selectedTab = 'Buyer',
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool loading = true;

  String name = 'User';
  String email = '';
  String image = '';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final raw = await ApiService.get('/getProfile');

      final profile = raw is Map<String, dynamic> ? raw : <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        name = profile['name']?.toString().trim().isNotEmpty == true
            ? profile['name']
            : 'User';

        email = profile['email']?.toString() ??
            FirebaseAuth.instance.currentUser?.email ??
            '';

        image = profile['profilePicUrl']?.toString() ?? '';

        loading = false;
      });
    } catch (e) {
      debugPrint('Drawer profile error: $e');

      if (!mounted) return;

      setState(() {
        email = FirebaseAuth.instance.currentUser?.email ?? '';
        loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.90,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            /// HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                16,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        image.isNotEmpty ? NetworkImage(image) : null,
                    child: image.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 46,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  loading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : Column(
                          children: [
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              email,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 11),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 1.25,
                      ),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/profile',
                        arguments: {'edit': true},
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text("Edit Profile",
                        style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _drawerTile(
                      context,
                      icon: Icons.person_outline,
                      title: "My Profile",
                      subtitle: "View & manage your information",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/profile',
                        );
                      },
                    ),
                    _drawerTile(
                      context,
                      icon: Icons.notifications_none_rounded,
                      title: "Notifications",
                      subtitle: "Alerts & updates",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/notifications',
                        );
                      },
                    ),
                    _drawerTile(
                      context,
                      icon: Icons.chat_bubble_outline,
                      title: "Messages",
                      subtitle: "Message buyers & travelers",
                      iconColor: Colors.green,
                      iconBackground: Colors.green.withValues(alpha: 0.10),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/messages',
                        );
                      },
                    ),
                    _drawerTile(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      title: "Stripe Connect",
                      subtitle: "Connect Stripe account",
                      iconColor: Colors.purple,
                      iconBackground: Colors.purple.withValues(alpha: 0.10),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/stripeConnect',
                        );
                      },
                    ),
                    _drawerTile(
                      context,
                      icon: Icons.headset_mic_outlined,
                      title: "Customer Support",
                      subtitle: "We're here to help",
                      iconColor: Colors.orange,
                      iconBackground: Colors.orange.withValues(alpha: 0.10),
                      onTap: () {
                        Navigator.pop(context);
                        ChatService.openChat(
                          context: context,
                          otherUserId: 'admin',
                          otherUserName: 'Customer Support',
                          source: 'support',
                        );
                      },
                    ),
                    _drawerTile(
                      context,
                      icon: Icons.gavel_outlined,
                      title: "Open Dispute",
                      subtitle: "Report an issue securely",
                      iconColor: Colors.red,
                      iconBackground: Colors.red.withValues(alpha: 0.10),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DisputeDashboard(
                              role: widget.selectedTab.toLowerCase() == 'traveler'
                                  ? 'traveler'
                                  : 'buyer',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  splashColor: Colors.red.withValues(alpha: 0.12),
                  highlightColor: Colors.red.withValues(alpha: 0.06),
                  onTap: _logout,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        244,
                        214,
                        219,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Colors.red.shade600,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            "Log Out",
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                28,
                8,
                28,
                20,
              ),
              child: Column(
                children: const [
                  Text(
                    "✈️ Bring the World Closer",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Shop globally. Deliver confidently.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = AppColors.primary,
    Color? iconBackground,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        tileColor: const Color.fromARGB(255, 235, 233, 233),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBackground ?? AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}

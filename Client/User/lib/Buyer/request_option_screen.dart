// lib/shopping_request_options_screen.dart
import 'package:flutter/material.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Theme/app_color.dart';

class RequestOptionsScreen extends StatelessWidget {
  const RequestOptionsScreen({super.key});

  Widget _optionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.08),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(width: 12),

            /// TEXT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8F8D8D),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.chevron_right,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: "Request Options",
        leading: Container(
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
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            _optionCard(
              context: context,
              icon: Icons.apps_outlined,
              title: 'Explore Market Place',
              subtitle:
                  'Not sure what you need? Explore some famous marketplaces.',
              onTap: () {
                Navigator.pushNamed(context, '/explore');
              },
            ),
            _optionCard(
              context: context,
              icon: Icons.edit,
              title: 'Add Information',
              subtitle:
                  'Know everything about what you need? Add information for your shopping request.',
              onTap: () {
                Navigator.pushNamed(context, '/add_request_info');
              },
            ),
            _optionCard(
              context: context,
              icon: Icons.lightbulb,
              title: 'Get Recommendations',
              subtitle:
                  'Need suggestions and ideas? Get personalized recommendations based on your preferences.',
              onTap: () {
                Navigator.pushNamed(context, '/ProductDashboard');
              },
            ),
          ],
        ),
      ),
    );
  }
}

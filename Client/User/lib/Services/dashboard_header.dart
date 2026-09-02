import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';

PreferredSizeWidget dashboardAppBar({
  required String title,
  List<String>? tabs,
  String? selectedTab,
  Function(String)? onTabChanged,
  Widget? leading,
  bool showNotifications = false,
}) {
  final hasTabs = tabs?.isNotEmpty ?? false;
  final hasleading = leading != null;

  return PreferredSize(
    preferredSize: Size.fromHeight(
      hasTabs ? 115 : (hasleading ? 80 : 70),
    ),
    child: Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, hasleading ? 10 : 14),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (leading != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: leading,
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 0,
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasTabs) const SizedBox(height: 9),

              if (hasTabs)
                Row(
                  children: [
                    for (final tab in tabs!)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onTabChanged?.call(tab),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: tab == selectedTab
                                  ? Colors.white10
                                  : Colors.transparent,
                            ),
                            child: Text(
                              tab,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: tab == selectedTab
                                    ? Colors.white
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

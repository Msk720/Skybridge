import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';

Widget buildTab(
  String tab,
  String selectedTab,
  Function(String) onChanged,
) {
  final active = tab == selectedTab;

  return Expanded(
    child: GestureDetector(
      onTap: () => onChanged(tab),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: active ? 20 : 0,
            vertical: active ? 4 : 0,
          ),
          decoration: active
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white30)
              : null,
          child: Text(
            tab,
            style: TextStyle(
              color: active ? Colors.white : AppColors.tabtext,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

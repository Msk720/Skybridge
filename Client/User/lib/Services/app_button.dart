import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';

Widget appPrimaryButton({
  required String text,
  required VoidCallback onPressed,
  bool loading = false,
  bool rounded = true,
  bool primaryColor = true,
  bool small = false,
  double? height,
}) {
  final radius = BorderRadius.circular(rounded ? 18 : 14);
  final double buttonHeight = height ?? (small ? 40 : 50);

  return Container(
    height: buttonHeight,
    decoration: BoxDecoration(
      color: primaryColor ? AppColors.primary : AppColors.buttonSecondary,
      borderRadius: radius,
    ),
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
        ),
      ),
      child: loading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              text,
              style: TextStyle(
                color: primaryColor ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    ),
  );
}

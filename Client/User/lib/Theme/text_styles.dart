import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle label = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.6,
      color: AppColors.textgray);

  static const TextStyle value = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.bold,
    color: AppColors.textprimary,
  );

  // City names
  static const TextStyle city = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  // Country text
  static const TextStyle country = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 17,
    height: 1.1,
  );

  // Reward old
  static const TextStyle rewardOld = TextStyle(
    decoration: TextDecoration.lineThrough,
    color: AppColors.textSecondary,
    fontSize: 15,
  );

  // Reward new
  static const TextStyle reward = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // Name
  static const TextStyle name = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 15.5,
  );

  // Role
  static const TextStyle role = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textrole,
    letterSpacing: 0.6,
  );

  // Rating
  static const TextStyle rating = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textprimary,
  );

  static const TextStyle price = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
}

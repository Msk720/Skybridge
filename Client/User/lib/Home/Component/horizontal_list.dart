import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';

Widget horizontalList({
  required int itemCount,
  required Widget Function(int index) itemBuilder,
  double spacing = 15,
  double horizontalPadding = 12,
  bool useCard = true,
  double cardWidth = 145,
  void Function(int index)? onItemTap,
}) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
    child: Row(
      children: List.generate(itemCount, (index) {
        final child = itemBuilder(index);

        Widget item = useCard
            ? Container(
                width: cardWidth,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: child,
              )
            : child;

        if (onItemTap != null) {
          item = GestureDetector(
            onTap: () => onItemTap(index),
            child: item,
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            right: index == itemCount - 1 ? 0 : spacing,
          ),
          child: item,
        );
      }),
    ),
  );
}

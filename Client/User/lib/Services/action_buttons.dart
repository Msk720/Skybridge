import 'package:flutter/material.dart';
import 'package:skybridge02/Services/app_button.dart';

class ActionButtonsRow extends StatelessWidget {
  final String leftText;
  final String rightText;
  final VoidCallback? onLeftPressed;
  final VoidCallback? onRightPressed;
  final double? height;

  const ActionButtonsRow({
    super.key,
    required this.leftText,
    required this.rightText,
    this.onLeftPressed,
    this.onRightPressed,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Row(
        children: [
          Expanded(
            child: appPrimaryButton(
              text: leftText,
              onPressed: onLeftPressed ?? () {},
              primaryColor: false,
              height: height,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: appPrimaryButton(
              text: rightText,
              onPressed: onRightPressed ?? () {},
              height: height,
            ),
          )
        ],
      ),
    );
  }
}

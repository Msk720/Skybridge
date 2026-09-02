import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';

class RequestFAB extends StatefulWidget {
  final String? routeName;
  final VoidCallback? onReturn;
  final Future<bool> Function()? beforeNavigate;
  final FutureOr<void> Function()? onPressed;
  final IconData icon;
  final String label;
  final double? width;
  final double bottomPadding;

  const RequestFAB({
    super.key,
    this.routeName,
    this.onReturn,
    this.beforeNavigate,
    this.onPressed,
    this.icon = Icons.add_rounded,
    this.label = 'Add',
    this.width,
    this.bottomPadding = 84,
  });

  @override
  State<RequestFAB> createState() => _RequestFABState();
}

class _RequestFABState extends State<RequestFAB> {
  bool _navigating = false;

  Future<void> _handleTap() async {
    if (_navigating) return;

    setState(() => _navigating = true);

    try {
      if (widget.beforeNavigate != null) {
        final allowed = await widget.beforeNavigate!();

        if (!mounted || !allowed) return;
      }

      if (widget.onPressed != null) {
        await widget.onPressed!();
        return;
      }

      final routeName = widget.routeName;
      if (routeName == null || routeName.isEmpty) return;

      final result = await Navigator.of(context).pushNamed(routeName);

      if (!mounted) return;

      if (result == true && widget.onReturn != null) {
        widget.onReturn!();
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonWidth = widget.width ?? (widget.label.length > 4 ? 152.0 : 84.0);

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: _navigating ? null : _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: buttonWidth,
            height: 44,
            decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
            child: Center(
              child: _navigating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 22, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

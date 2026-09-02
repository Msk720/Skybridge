import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skybridge02/Theme/app_color.dart';

class CustomNavBar extends StatefulWidget {
  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.selectedTab,
    required this.onTap,
  });

  final int currentIndex;
  final String selectedTab;
  final Function(int) onTap;

  @override
  State<CustomNavBar> createState() => _CustomNavBarState();
}

class _CustomNavBarState extends State<CustomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _oldVisualIndex;

  static const Color inactiveColor = Color(0xFF435B63);
  static const Color borderColor = Color(0xFFC8CCCF);

  static const double navSidePadding = 26;

  IconData get _firstIcon => widget.selectedTab == 'Buyer'
      ? Symbols.package_2
      : Symbols.plane_contrails_rounded;

  String get _firstLabel =>
      widget.selectedTab == 'Buyer' ? 'Shipments' : 'Trips';

  List<_NavItem> get _items => [
        _NavItem(index: 1, label: _firstLabel, icon: _firstIcon),
        const _NavItem(index: 2, label: 'Orders', icon: Symbols.local_mall),
        const _NavItem(index: 0, label: 'Home', icon: Icons.home_rounded),
        const _NavItem(
          index: 3,
          label: 'Offers',
          icon: Icons.local_offer_outlined,
        ),
        const _NavItem(
          index: 4,
          label: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
        ),
      ];

  int get _activeVisualIndex {
    final index = _items.indexWhere(
      (item) => item.index == widget.currentIndex,
    );

    return index < 0 ? 2 : index;
  }

  _NavItem get _activeItem => _items[_activeVisualIndex];

  @override
  void initState() {
    super.initState();

    _oldVisualIndex = _activeVisualIndex;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant CustomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.selectedTab != widget.selectedTab) {
      _oldVisualIndex = _items.indexWhere(
        (item) => item.index == oldWidget.currentIndex,
      );

      if (_oldVisualIndex < 0) {
        _oldVisualIndex = 2;
      }

      _controller.forward(from: 0);
    }
  }

  void _handleTap(int index) {
    if (index == widget.currentIndex) return;
    widget.onTap(index);
  }

  double _itemCenter(double width, int visualIndex) {
    final usableWidth = width - (navSidePadding * 2);
    final itemWidth = usableWidth / _items.length;

    return navSidePadding + (itemWidth * visualIndex) + (itemWidth / 2);
  }

  @override
  Widget build(BuildContext context) {
    const double navHeight = 92;
    const double activeCircleSize = 52;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: navHeight,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final usableWidth = width - (navSidePadding * 2);
            final itemWidth = usableWidth / _items.length;

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final value = Curves.easeOutCubic.transform(_controller.value);

                final startCenter = _itemCenter(width, _oldVisualIndex);
                final endCenter = _itemCenter(width, _activeVisualIndex);

                final activeCenter = lerpDouble(
                  startCenter,
                  endCenter,
                  value,
                )!
                    .clamp(62.0, width - 62.0)
                    .toDouble();

                final jump = -1.8 * math.sin(_controller.value * math.pi);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _NavBackgroundPainter(
                          activeCenter: activeCenter,
                          borderColor: borderColor,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: 30,
                      left: navSidePadding,
                      right: navSidePadding,
                      child: Row(
                        children: List.generate(_items.length, (visualIndex) {
                          final item = _items[visualIndex];
                          final isActive = item.index == widget.currentIndex;

                          return SizedBox(
                            width: itemWidth,
                            child: InkWell(
                              onTap: () => _handleTap(item.index),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 160),
                                    opacity: isActive ? 0 : 1,
                                    child: Icon(
                                      item.icon,
                                      size: 23,
                                      color: inactiveColor,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 160),
                                    opacity: isActive ? 0 : 1,
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.2,
                                        height: 1,
                                        fontWeight: FontWeight.w500,
                                        color: inactiveColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Positioned(
                      left: activeCenter - activeCircleSize / 2,
                      top: 18 + jump,
                      child: Container(
                        width: activeCircleSize,
                        height: activeCircleSize,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x20000000),
                              blurRadius: 9,
                              spreadRadius: 0.5,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _activeItem.icon,
                          size: _activeItem.index == 0 ? 27 : 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _NavItem {
  final int index;
  final String label;
  final IconData icon;

  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
  });
}

class _NavBackgroundPainter extends CustomPainter {
  final double activeCenter;
  final Color borderColor;

  _NavBackgroundPainter({
    required this.activeCenter,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double top = 22;
    const double cornerRadius = 11;

    const double notchWidth = 94;
    const double notchDepth = 34;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.035)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final notchLeft = activeCenter - notchWidth / 2;
    final notchRight = activeCenter + notchWidth / 2;

    final path = Path();

    path.moveTo(cornerRadius, top);

    path.lineTo(notchLeft - 7, top);

    path.cubicTo(
      notchLeft + 16,
      top,
      notchLeft + 11,
      top + notchDepth,
      activeCenter,
      top + notchDepth,
    );

    path.cubicTo(
      notchRight - 11,
      top + notchDepth,
      notchRight - 16,
      top,
      notchRight + 7,
      top,
    );

    path.lineTo(size.width - cornerRadius, top);

    path.quadraticBezierTo(
      size.width,
      top,
      size.width,
      top + cornerRadius,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, top + cornerRadius);

    path.quadraticBezierTo(
      0,
      top,
      cornerRadius,
      top,
    );

    path.close();

    canvas.drawPath(path.shift(const Offset(0, 1)), shadowPaint);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NavBackgroundPainter oldDelegate) {
    return oldDelegate.activeCenter != activeCenter ||
        oldDelegate.borderColor != borderColor;
  }
}

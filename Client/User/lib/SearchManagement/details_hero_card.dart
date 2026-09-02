import 'package:flutter/material.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Theme/app_color.dart';

class DetailsHeroCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final IconData fallbackIcon;
  final List<DetailsHeroRow> rows;
  final bool showVisual;

  const DetailsHeroCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.fallbackIcon = Icons.image_outlined,
    required this.rows,
    this.showVisual = true,
  });

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return infoCard([
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showVisual) ...[
              _HeroVisual(
                imageUrl: _hasImage ? imageUrl!.trim() : null,
                fallbackIcon: fallbackIcon,
              ),
              const SizedBox(height: 14),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => detailsInfoRow(row.label, row.value),
            ),
          ],
        ),
      ),
    ]);
  }
}

class DetailsHeroRow {
  final String label;
  final String value;

  const DetailsHeroRow(this.label, this.value);
}

class _HeroVisual extends StatelessWidget {
  final String? imageUrl;
  final IconData fallbackIcon;

  const _HeroVisual({
    required this.imageUrl,
    required this.fallbackIcon,
  });

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 190,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            Colors.white,
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _hasImage
            ? Image.network(
                imageUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _IconHero(icon: fallbackIcon),
              )
            : _IconHero(icon: fallbackIcon),
      ),
    );
  }
}

class _IconHero extends StatelessWidget {
  final IconData icon;

  const _IconHero({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.70),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              icon,
              size: 46,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 96,
            child: Row(
              children: [
                _RouteDot(size: 8),
                Expanded(
                  child: Container(
                    height: 2,
                    color: AppColors.primary.withValues(alpha: 0.30),
                  ),
                ),
                _RouteDot(size: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  final double size;

  const _RouteDot({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}


Widget detailsMessageButton({required VoidCallback onPressed}) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
    ),
    onPressed: onPressed,
    child: const Text(
      'Message',
      style: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

Widget detailsInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    ),
  );
}

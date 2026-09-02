import 'package:skybridge02/Services/app_imports.dart';

class InfoSlide {
  final String title;
  final String description;
  final String? iconName;

  InfoSlide({
    required this.title,
    required this.description,
    this.iconName,
  });
}

class InfoSlider extends StatefulWidget {
  final List<InfoSlide> slides;

  const InfoSlider({
    required this.slides,
    super.key,
  });

  @override
  State<InfoSlider> createState() => _InfoSliderState();
}

class _InfoSliderState extends State<InfoSlider> {
  late final PageController _pageController;
  int _currentIndex = 0;

  final Map<String, IconData> iconMap = {
    'shopping-bag': Icons.shopping_bag_outlined,
    'support': Icons.support_agent,
    'flight': Icons.flight_takeoff,
  };

  @override
  void initState() {
    super.initState();

    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildSlide(InfoSlide s) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          height: 105,
          color: AppColors.primary,
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -25,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B86C5).withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 35,
                bottom: -30,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E568C).withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 22, right: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34538A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          iconMap[(s.iconName ?? '').toLowerCase()] ??
                              Icons.shopping_bag_outlined,
                          color: AppColors.secondary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                fontSize: 18,
                                letterSpacing: 0.2,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.description,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.3,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.slides.length,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _currentIndex ? 16 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == _currentIndex ? AppColors.primary : AppColors.dotcolor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 115,
          width: double.infinity,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.slides.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return _buildSlide(widget.slides[index]);
            },
          ),
        ),
        const SizedBox(height: 14),
        _buildDots(),
      ],
    );
  }
}

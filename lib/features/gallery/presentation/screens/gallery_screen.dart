import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _activeCategory = 'All';

  static const _categories = [
    'All',
    'Campus',
    'Events',
    'Reunions',
    'Milestones',
  ];

  static const _galleryItems = [
    {
      'image': 'assets/images/gallery/pic1.png',
      'title': 'Golden Horizon',
      'category': 'Campus',
      'year': '2024',
      'description':
          'A breathtaking sunset over the serene campus grounds, capturing nature\'s golden embrace.',
    },
    {
      'image': 'assets/images/gallery/pic2.jpg',
      'title': 'Urban Elegance',
      'category': 'Campus',
      'year': '2023',
      'description':
          'Modern architecture illuminated by twilight, blending steel and glass in perfect harmony.',
    },
    {
      'image': 'assets/images/gallery/pic3.jpg',
      'title': 'Forest Whisper',
      'category': 'Events',
      'year': '2023',
      'description':
          'Ancient trees standing tall amidst morning mist, revealing nature\'s quiet majesty.',
    },
    {
      'image': 'assets/images/gallery/building.jpg',
      'title': 'The Grand Hall',
      'category': 'Campus',
      'year': '2022',
      'description':
          'The iconic St. Cecilia\'s main building standing proudly as a symbol of tradition and excellence.',
    },
    {
      'image': 'assets/images/gallery/pic1.png',
      'title': 'Homecoming 2024',
      'category': 'Reunions',
      'year': '2024',
      'description':
          'Alumni gathered from across the country to celebrate the annual grand homecoming.',
    },
    {
      'image': 'assets/images/gallery/pic2.jpg',
      'title': 'Recognition Night',
      'category': 'Milestones',
      'year': '2023',
      'description':
          'Honoring the achievements of outstanding alumni across various industries.',
    },
  ];

  List<Map<String, String>> get _filtered {
    if (_activeCategory == 'All') {
      return _galleryItems.map((e) => e.cast<String, String>()).toList();
    }
    return _galleryItems
        .where((e) => e['category'] == _activeCategory)
        .map((e) => e.cast<String, String>())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 640;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: CustomScrollView(
        slivers: [
          // ─── Hero app bar ───
          SliverAppBar(
            expandedHeight: isMobile ? 280 : 420,
            pinned: true,
            backgroundColor: const Color(0xFF0C0C0C),
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/gallery/building.jpg',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.4),
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFF1A1A1A)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0C0C0C).withOpacity(0.6),
                          const Color(0xFF0C0C0C),
                        ],
                        stops: const [0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 24 : 48,
                        0,
                        isMobile ? 24 : 48,
                        32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                                width: 20,
                                height: 1,
                                color: AppColors.brandRed),
                            const SizedBox(width: 10),
                            Text(
                              'ST. CECILIA\'S  ·  ARCHIVE',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                letterSpacing: 3,
                                color: AppColors.brandRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Text(
                            'The Archive.',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: isMobile ? 42 : 60,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'A quiet collection of light, memory, and legacy.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.3,
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

          // ─── Category filter ───
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF0C0C0C),
              padding: EdgeInsets.fromLTRB(
                isMobile ? 24 : 48,
                8,
                isMobile ? 24 : 48,
                24,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isActive = _activeCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _activeCategory = cat),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.brandRed
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.brandRed
                                  : Colors.white.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            cat.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // ─── Stats strip ───
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF111111),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 48,
                vertical: 16,
              ),
              child: Row(children: [
                _stripStat('${_filtered.length}', 'PHOTOS'),
                _stripDivider(),
                _stripStat(
                  _filtered.map((e) => e['year']).toSet().length.toString(),
                  'YEARS',
                ),
                _stripDivider(),
                _stripStat(_categories.length.toString(), 'CATEGORIES'),
              ]),
            ),
          ),

          // ─── Grid ───
          _filtered.isEmpty
              ? SliverToBoxAdapter(
                  child: Container(
                    color: const Color(0xFF0C0C0C),
                    padding:
                        const EdgeInsets.symmetric(vertical: 100),
                    child: Center(
                      child: Column(children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 48,
                          color: Colors.white12,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No photos in this category',
                          style: GoogleFonts.inter(
                            color: Colors.white24,
                            fontSize: 14,
                          ),
                        ),
                      ]),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 48,
                    24,
                    isMobile ? 16 : 48,
                    0,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : 2,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: isMobile ? 1.2 : 1.1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (!isMobile && index == 0) {
                          return _GalleryCard(
                            item: _filtered[index],
                            isFeature: true,
                          );
                        }
                        return _GalleryCard(
                          item: _filtered[index],
                        );
                      },
                      childCount: _filtered.length,
                    ),
                  ),
                ),

          // ─── Bottom padding ───
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 80,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stripStat(String value, String label) {
    return Row(children: [
      Text(
        value,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 24,
          fontWeight: FontWeight.w300,
          color: Colors.white,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          letterSpacing: 2,
          color: Colors.white.withOpacity(0.3),
          fontWeight: FontWeight.w600,
        ),
      ),
    ]);
  }

  Widget _stripDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: 0.5,
      height: 20,
      color: Colors.white.withOpacity(0.1),
    );
  }
}

class _GalleryCard extends StatefulWidget {
  final Map<String, String> item;
  final bool isFeature;

  const _GalleryCard({
    required this.item,
    this.isFeature = false,
  });

  @override
  State<_GalleryCard> createState() => _GalleryCardState();
}

class _GalleryCardState extends State<_GalleryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openDetail(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            border: Border.all(
              color: _hovered
                  ? AppColors.brandRed.withOpacity(0.4)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              AnimatedScale(
                scale: _hovered ? 1.03 : 1.0,
                duration: const Duration(milliseconds: 400),
                child: Image.asset(
                  widget.item['image']!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1A1A1A),
                    child: const Center(
                      child: Icon(
                        Icons.hide_image_outlined,
                        color: Colors.white12,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),

              // Gradient
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _hovered ? 0.85 : 0.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.2, 0.7, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.95),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Category badge
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _hovered
                        ? AppColors.brandRed
                        : Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    widget.item['category']!.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      letterSpacing: 1.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Year badge
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    widget.item['year']!,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      letterSpacing: 1,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Bottom content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 16,
                            height: 1,
                            color: AppColors.brandRed),
                        const SizedBox(width: 8),
                        Text(
                          widget.item['category']!.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            letterSpacing: 2,
                            color: AppColors.brandRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        widget.item['title']!,
                        style: GoogleFonts.cormorantGaramond(
                          color: Colors.white,
                          fontSize: widget.isFeature ? 28 : 22,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: _hovered
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.item['description']!,
                                    style: GoogleFonts.inter(
                                      color:
                                          Colors.white.withOpacity(0.7),
                                      fontSize: 11,
                                      height: 1.5,
                                      fontWeight: FontWeight.w300,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Text(
                                      'VIEW',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        letterSpacing: 2,
                                        color: Colors.white.withOpacity(0.6),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 10,
                                      color: Colors.white60,
                                    ),
                                  ]),
                                ],
                              )
                            : const SizedBox.shrink(),
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

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _FullScreenView(item: widget.item),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

class _FullScreenView extends StatefulWidget {
  final Map<String, String> item;

  const _FullScreenView({required this.item});

  @override
  State<_FullScreenView> createState() => _FullScreenViewState();
}

class _FullScreenViewState extends State<_FullScreenView> {
  bool _showInfo = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showInfo = !_showInfo),
        child: Stack(
          children: [
            // Zoomable image
            InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(80),
              minScale: 0.75,
              maxScale: 5.0,
              child: Center(
                child: Image.asset(
                  widget.item['image']!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(
                        Icons.hide_image_outlined,
                        color: Colors.white12,
                        size: 120,
                      ),
                ),
              ),
            ),

            // Top bar
            AnimatedOpacity(
              opacity: _showInfo ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              color: AppColors.brandRed,
                              child: Text(
                                widget.item['category']!.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  letterSpacing: 1.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.item['year']!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom info
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              bottom: _showInfo ? 0 : -200,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.98),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Container(
                          width: 20,
                          height: 1,
                          color: AppColors.brandRed),
                      const SizedBox(width: 10),
                      Text(
                        'ST. CECILIA\'S ARCHIVE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          letterSpacing: 3,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      widget.item['title']!,
                      style: GoogleFonts.cormorantGaramond(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.item['description']!,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TAP ANYWHERE TO TOGGLE INFO',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        letterSpacing: 2,
                        color: Colors.white.withOpacity(0.25),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

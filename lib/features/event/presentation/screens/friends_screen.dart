import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Safe color fallbacks
    final backgroundColor = isDark
        ? (AppColors.borderMedium ?? const Color(0xFF121212))
        : (AppColors.softWhite ?? const Color(0xFFF9FAFB));

    final surfaceColor = isDark
        ? (AppColors.cardWhite ?? const Color(0xFF1E1E1E))
        : (AppColors.cardWhite ?? Colors.white);

    final textColor = isDark
        ? Colors.white
        : (AppColors.darkText ?? const Color(0xFF1A1A1A));

    final mutedColor = isDark
        ? (Colors.grey[400] ?? Colors.grey.shade400)
        : (AppColors.mutedText ?? Colors.grey.shade600);

    final accentColor = AppColors.brandRed ?? const Color(0xFF9B1D1D);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Text(
          'Friends & Connections',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add friends',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add friends – coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search alumni',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search – coming soon')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon / illustration
                Icon(
                  Icons.people_alt_outlined,
                  size: 110,
                  color: mutedColor.withOpacity(0.7),
                ),
                const SizedBox(height: 40),

                Text(
                  'Your Network',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Coming Soon',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 28),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Connect with fellow alumni, build your professional network, '
                    'reconnect with batchmates, and grow meaningful relationships within the community.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      height: 1.5,
                      color: mutedColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 48),

                // Feature teaser cards
                _FeatureTeaserCard(
                  icon: Icons.group_outlined,
                  title: 'Friend Requests',
                  description: 'See who wants to connect with you',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                _FeatureTeaserCard(
                  icon: Icons.people_outline,
                  title: 'Suggested Connections',
                  description: 'Alumni from your batch, course, or location',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                _FeatureTeaserCard(
                  icon: Icons.star_border,
                  title: 'Favorites & Close Network',
                  description: 'Keep your most important contacts at the top',
                  isDark: isDark,
                ),

                const SizedBox(height: 60),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.grey[800] : Colors.grey[100])!.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'Your alumni network hub — launching soon!',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Small reusable teaser card
class _FeatureTeaserCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDark;

  const _FeatureTeaserCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.brandRed ?? const Color(0xFF9B1D1D);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 32,
            color: accentColor,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart'; // ← adjust path if needed

class DiscussionsScreen extends StatelessWidget {
  const DiscussionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.borderMedium : AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardWhite : AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Discussions',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white : AppColors.darkText,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.darkText,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Placeholder icon / illustration area
                Icon(
                  Icons.forum_outlined,
                  size: 120,
                  color: (isDark ? Colors.grey[600] : Colors.grey[400])?.withOpacity(0.6),
                ),
                const SizedBox(height: 32),

                Text(
                  'Discussion Forum',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.darkText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  'Coming Soon',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandRed,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'We’re working on a full-featured discussion space where alumni can connect, '
                  'share experiences, ask questions, and build meaningful conversations.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.5,
                    color: isDark ? Colors.grey[300] : AppColors.mutedText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Optional: subtle call-to-action or teaser
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.grey[800] : Colors.grey[100])?.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.brandRed.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'Stay tuned — launching soon!',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : AppColors.darkText,
                    ),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
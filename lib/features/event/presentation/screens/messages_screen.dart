import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Safe fallback colors in case AppColors is incomplete
    final backgroundColor = isDark
        ? (AppColors.borderMedium ?? const Color(0xFF121212))
        : (AppColors.softWhite ?? const Color(0xFFF9FAFB));

    final textColor = isDark
        ? Colors.white
        : (AppColors.darkText ?? const Color(0xFF1A1A1A));

    final mutedColor = isDark
        ? (Colors.grey[400] ?? Colors.grey.shade400)
        : (AppColors.mutedText ?? Colors.grey.shade600);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? (AppColors.cardWhite ?? const Color(0xFF1E1E1E))
            : (AppColors.cardWhite ?? Colors.white),
        elevation: 0,
        title: Text(
          'Messages',
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
            icon: const Icon(Icons.search),
            tooltip: 'Search messages',
            onPressed: () {
              // TODO: implement search
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 100,
                color: mutedColor.withOpacity(0.7),
              ),
              const SizedBox(height: 32),

              Text(
                'Your Messages',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Coming Soon',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandRed ?? const Color(0xFF9B1D1D),
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Private messaging between alumni will be available soon. '
                  'Connect, collaborate, and stay in touch with your network.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.5,
                    color: mutedColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),

              // Teaser box
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.grey[800] : Colors.grey[100])!.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (AppColors.brandRed ?? const Color(0xFF9B1D1D)).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  'Private chats, group discussions & more — launching soon!',
                  style: GoogleFonts.inter(
                    fontSize: 15,
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brandRed ?? const Color(0xFF9B1D1D),
        foregroundColor: Colors.white,
        onPressed: () {
          // TODO: implement new message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New message – coming soon')),
          );
        },
        child: const Icon(Icons.edit),
        tooltip: 'New Message',
      ),
    );
  }
}
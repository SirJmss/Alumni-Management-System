import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alumni/core/constants/app_colors.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final String title;
  final String content;
  final String dateStr;
  final bool important;

  const AnnouncementDetailScreen({
    super.key,
    required this.title,
    required this.content,
    required this.dateStr,
    required this.important,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        title: Text('Announcement',
            style: GoogleFonts.cormorantGaramond(fontSize: 22)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (important)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'IMPORTANT',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            Text(
              title,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.access_time,
                  size: 14, color: AppColors.mutedText),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedText,
                    fontStyle: FontStyle.italic),
              ),
            ]),
            const SizedBox(height: 20),
            const Divider(color: AppColors.borderSubtle),
            const SizedBox(height: 20),
            Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.7,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
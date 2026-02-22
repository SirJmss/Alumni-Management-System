import 'package:flutter/material.dart';

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
      backgroundColor: const Color(0xFFE6D3AE),
      appBar: AppBar(
        title: const Text(
          'Announcement Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFFE64646),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ),
                if (important)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE64646),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Important',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[800]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
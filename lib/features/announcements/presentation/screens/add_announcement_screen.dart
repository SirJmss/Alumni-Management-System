import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/notification/notification_service.dart';

class AddAnnouncementScreen extends StatefulWidget {
  const AddAnnouncementScreen({super.key});

  @override
  State<AddAnnouncementScreen> createState() =>
      _AddAnnouncementScreenState();
}

class _AddAnnouncementScreenState
    extends State<AddAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isImportant = false;
  bool _isLoading = false;
  String? _userRole;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole =
              doc.data()?['role'] as String? ?? 'alumni';
          _currentUid = user.uid;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading role: $e', isError: true);
      }
    }
  }

  bool get _canPost =>
      _userRole == 'admin' ||
      _userRole == 'registrar' ||
      _userRole == 'staff' ||
      _userRole == 'moderator';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final ref = await FirebaseFirestore.instance
          .collection('announcements')
          .add({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'publishedAt': FieldValue.serverTimestamp(),
        'important': _isImportant,
        'createdBy': _currentUid,
        'createdByRole': _userRole,
      });

      // ─── Notify all users ───
      await NotificationService.sendAnnouncementNotificationToAll(
        announcementTitle: _titleController.text.trim(),
        announcementId: ref.id,
      );

      if (mounted) {
        _showSnackBar('Announcement posted!', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to post: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(
                color: AppColors.brandRed)),
      );
    }

    if (!_canPost) {
      return Scaffold(
        backgroundColor: AppColors.softWhite,
        appBar: AppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
          iconTheme:
              const IconThemeData(color: AppColors.darkText),
          title: Text('Post Announcement',
              style:
                  GoogleFonts.cormorantGaramond(fontSize: 22)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline,
                    size: 64, color: AppColors.mutedText),
                const SizedBox(height: 16),
                Text('Access Restricted',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 24,
                        color: AppColors.darkText)),
                const SizedBox(height: 8),
                Text(
                  'Only administrators, staff, and moderators can post announcements.',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.mutedText),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        iconTheme:
            const IconThemeData(color: AppColors.darkText),
        title: Text('New Announcement',
            style: GoogleFonts.cormorantGaramond(fontSize: 22)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: Text(
              _isLoading ? 'Posting...' : 'Publish',
              style: GoogleFonts.inter(
                color: AppColors.brandRed,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ─── Title ───
            TextFormField(
              controller: _titleController,
              style: GoogleFonts.inter(fontSize: 15),
              decoration: _inputDecoration('Title',
                  'e.g. Enrollment Reminder for AY 2026'),
              validator: (v) => v?.trim().isEmpty == true
                  ? 'Title is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // ─── Content ───
            TextFormField(
              controller: _contentController,
              maxLines: 10,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: _inputDecoration(
                  'Content', 'Write your announcement here...',
                  alignHint: true),
              validator: (v) => v?.trim().isEmpty == true
                  ? 'Content is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // ─── Important toggle ───
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.borderSubtle),
              ),
              child: SwitchListTile(
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        AppColors.brandRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.star_outline,
                      color: AppColors.brandRed, size: 20),
                ),
                title: Text('Mark as Important',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Highlighted for all alumni',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedText)),
                value: _isImportant,
                activeColor: AppColors.brandRed,
                onChanged: (v) =>
                    setState(() => _isImportant = v),
              ),
            ),

            const SizedBox(height: 32),

            // ─── Submit ───
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Icon(Icons.campaign_outlined),
                label: Text(
                  _isLoading
                      ? 'Publishing...'
                      : 'Publish Announcement',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint,
      {bool alignHint = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignHint,
      labelStyle: GoogleFonts.inter(
          color: AppColors.brandRed, fontWeight: FontWeight.w500),
      hintStyle: GoogleFonts.inter(
          color: AppColors.mutedText, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: AppColors.brandRed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: AppColors.cardWhite,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
    );
  }
}
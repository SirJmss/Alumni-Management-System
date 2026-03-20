import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alumni/core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '';
  String _email = '';
  String _role = '';
  String _avatarUrl = '';
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _messageNotifications = true;
  bool _eventNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _name = data['name'] ??
              data['fullName'] ??
              user.displayName ??
              'User';
          _email = user.email ?? '';
          _role = data['role'] ?? 'Alumni';
          _avatarUrl = data['profilePictureUrl'] ?? '';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _email = user.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Log out ───
  Future<void> _logout() async {
    final confirm = await _showConfirmDialog(
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      confirmText: 'Log Out',
      confirmColor: AppColors.brandRed,
    );
    if (confirm != true) return;
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (route) => false);
    }
  }

  // ─── Change password via email ───
  Future<void> _changePassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showSnackBar('No email associated with this account', isError: true);
      return;
    }

    final confirm = await _showConfirmDialog(
      title: 'Change Password',
      message:
          'A password reset link will be sent to:\n\n$email\n\nCheck your inbox and follow the instructions.',
      confirmText: 'Send Link',
      confirmColor: AppColors.brandRed,
    );
    if (confirm != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackBar('Reset link sent to $email', isError: false);
    } catch (e) {
      _showSnackBar('Failed to send reset email: $e', isError: true);
    }
  }

  // ─── Change email ───
  Future<void> _changeEmail() async {
    final controller = TextEditingController();
    final newEmail = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Change Email',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your new email address:',
                style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'new@email.com',
                hintStyle: GoogleFonts.inter(color: AppColors.mutedText),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.brandRed),
                ),
              ),
              style: GoogleFonts.inter(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Update',
                style: GoogleFonts.inter(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (newEmail == null || newEmail.isEmpty) return;

    try {
      await FirebaseAuth.instance.currentUser
          ?.verifyBeforeUpdateEmail(newEmail);
      _showSnackBar(
          'Verification sent to $newEmail. Verify to complete change.',
          isError: false);
    } catch (e) {
      _showSnackBar('Failed to update email: $e', isError: true);
    }
  }

  // ─── Delete account ───
  Future<void> _deleteAccount() async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Account',
      message:
          'This is permanent and cannot be undone.\n\nAll your data, connections, and messages will be deleted forever.',
      confirmText: 'Delete Forever',
      confirmColor: Colors.red.shade700,
    );
    if (confirm != true) return;

    // Second confirmation
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Are you absolutely sure?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.red.shade700)),
        content: Text(
            'Type DELETE to confirm account deletion.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, delete my account',
                style: GoogleFonts.inter(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (secondConfirm != true) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .delete();
      }
      await FirebaseAuth.instance.currentUser?.delete();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnackBar(
            'Please log out and log back in before deleting your account.',
            isError: true);
      } else {
        _showSnackBar('Error: ${e.message}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // ─── Contact support via email ───
  Future<void> _contactSupport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@stceciliasalumni.com',
      queryParameters: {
        'subject': 'Alumni App Support Request',
        'body':
            'Hi Support Team,\n\nI need help with:\n\n[Describe your issue here]\n\nAccount: $_email\nRole: $_role',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      _showSnackBar('Could not open email app', isError: true);
    }
  }

  // ─── Help & FAQ ───
  Future<void> _openHelp() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Text('Help & FAQ',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _faqItem(
                      'How do I connect with other alumni?',
                      'Go to Friends & Network from the dashboard or drawer. Search for alumni by name and send a friend request. Alumni can accept or decline requests.',
                    ),
                    _faqItem(
                      'How do I update my profile?',
                      'Tap Settings → Edit Profile, or go to My Profile from the drawer and tap the edit button.',
                    ),
                    _faqItem(
                      'How do I send a message?',
                      'Visit an alumni\'s profile and tap Message, or go to the Messages section from the drawer.',
                    ),
                    _faqItem(
                      'Why can\'t I send a friend request to an admin?',
                      'Friend requests are only available between alumni. Admins and registrars manage the platform and do not receive connection requests.',
                    ),
                    _faqItem(
                      'How do I change my password?',
                      'Go to Settings → Change Password. A reset link will be sent to your registered email address.',
                    ),
                    _faqItem(
                      'How do I report a problem?',
                      'Tap Contact Support in Settings to send us an email. We typically respond within 24 hours.',
                    ),
                    _faqItem(
                      'Can I delete my account?',
                      'Yes. Go to Settings → Delete Account. This action is permanent and cannot be undone.',
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton.icon(
                        onPressed: _contactSupport,
                        icon: const Icon(Icons.email_outlined,
                            color: AppColors.brandRed),
                        label: Text('Still need help? Contact us',
                            style: GoogleFonts.inter(
                                color: AppColors.brandRed,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqItem(String question, String answer) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      iconColor: AppColors.brandRed,
      collapsedIconColor: AppColors.mutedText,
      title: Text(question,
          style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600)),
      children: [
        Text(answer,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.5)),
      ],
    );
  }

  // ─── Privacy policy ───
  Future<void> _openPrivacyPolicy() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Text('Privacy Policy',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Last updated: January 2026\n\n'
                      'Your privacy is important to us. This policy explains how we collect, use, and protect your information.\n\n'
                      '1. INFORMATION WE COLLECT\n'
                      'We collect information you provide when registering, including your name, email, batch year, and course. We also collect profile information you voluntarily add such as work experience and education.\n\n'
                      '2. HOW WE USE YOUR INFORMATION\n'
                      'Your information is used to:\n'
                      '• Display your profile to other alumni\n'
                      '• Send you relevant notifications\n'
                      '• Connect you with fellow alumni\n'
                      '• Improve our services\n\n'
                      '3. DATA SHARING\n'
                      'We do not sell your personal data to third parties. Your profile is visible only to verified alumni and administrators.\n\n'
                      '4. DATA SECURITY\n'
                      'We use Firebase (Google) infrastructure with industry-standard security measures to protect your data.\n\n'
                      '5. YOUR RIGHTS\n'
                      'You may edit or delete your account at any time through Settings. For data export requests, contact our support team.\n\n'
                      '6. CONTACT\n'
                      'For privacy concerns, email us at privacy@stceciliasalumni.com',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.darkText,
                          height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Copy UID ───
  void _copyUserId() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    Clipboard.setData(ClipboardData(text: uid));
    _showSnackBar('User ID copied to clipboard', isError: false);
  }

  // ─── Helpers ───
  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content:
            Text(message, style: GoogleFonts.inter(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style:
                    GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText,
                style: GoogleFonts.inter(
                    color: confirmColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text('Settings',
            style: GoogleFonts.cormorantGaramond(fontSize: 26)),
        centerTitle: true,
        iconTheme:
            const IconThemeData(color: AppColors.darkText),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed))
          : ListView(
              children: [
                // ─── Profile card ───
                _buildProfileCard(),
                const SizedBox(height: 8),

                // ─── Account ───
                _buildSectionLabel('ACCOUNT'),
                _buildCard(children: [
                  _buildTile(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    subtitle: 'Name, photo, headline, about',
                    onTap: () => Navigator.pushNamed(
                        context, '/edit_profile'),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.email_outlined,
                    title: 'Change Email',
                    subtitle: _email,
                    onTap: _changeEmail,
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle: 'Send reset link to your email',
                    onTap: _changePassword,
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.badge_outlined,
                    title: 'Role',
                    subtitle: _role,
                    showArrow: false,
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.fingerprint,
                    title: 'Copy User ID',
                    subtitle: 'For support reference',
                    onTap: _copyUserId,
                    showArrow: false,
                    trailingIcon: Icons.copy,
                  ),
                ]),

                const SizedBox(height: 8),

                // ─── Notifications ───
                _buildSectionLabel('NOTIFICATIONS'),
                _buildCard(children: [
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    subtitle: 'All in-app alerts',
                    value: _notificationsEnabled,
                    onChanged: (val) => setState(
                        () => _notificationsEnabled = val),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Email Notifications',
                    subtitle: 'Receive alerts via email',
                    value: _emailNotifications,
                    onChanged: _notificationsEnabled
                        ? (val) => setState(
                            () => _emailNotifications = val)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Message Notifications',
                    subtitle: 'New messages',
                    value: _messageNotifications,
                    onChanged: _notificationsEnabled
                        ? (val) => setState(
                            () => _messageNotifications = val)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.event_outlined,
                    title: 'Event Notifications',
                    subtitle: 'Upcoming events and announcements',
                    value: _eventNotifications,
                    onChanged: _notificationsEnabled
                        ? (val) => setState(
                            () => _eventNotifications = val)
                        : null,
                  ),
                ]),

                const SizedBox(height: 8),

                // ─── Support ───
                _buildSectionLabel('SUPPORT'),
                _buildCard(children: [
                  _buildTile(
                    icon: Icons.help_outline,
                    title: 'Help & FAQ',
                    subtitle: 'Common questions answered',
                    onTap: _openHelp,
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.contact_support_outlined,
                    title: 'Contact Support',
                    subtitle: 'support@stceciliasalumni.com',
                    onTap: _contactSupport,
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: _openPrivacyPolicy,
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'Alumni Nexus Portal v1.0.0',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Alumni Nexus Portal',
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          '© 2026 St. Cecilia\'s Alumni',
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Connecting the past, present, and future of St. Cecilia\'s.',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 8),

                // ─── Danger zone ───
                _buildSectionLabel('ACCOUNT ACTIONS'),
                _buildCard(children: [
                  _buildTile(
                    icon: Icons.logout,
                    title: 'Log Out',
                    titleColor: AppColors.brandRed,
                    iconColor: AppColors.brandRed,
                    onTap: _logout,
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete Account',
                    subtitle: 'Permanently remove your account',
                    titleColor: Colors.red.shade700,
                    iconColor: Colors.red.shade700,
                    onTap: _deleteAccount,
                  ),
                ]),

                const SizedBox(height: 60),
              ],
            ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.borderSubtle,
            child: _avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _avatarUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _avatarFallback(),
                    ),
                  )
                : _avatarFallback(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name,
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_email,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.mutedText)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        AppColors.brandRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _role.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandRed,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.brandRed, size: 20),
            onPressed: () =>
                Navigator.pushNamed(context, '/edit_profile'),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Text(
      _name.isNotEmpty ? _name[0].toUpperCase() : '?',
      style: GoogleFonts.cormorantGaramond(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.brandRed,
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.mutedText,
          )),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
    bool showArrow = true,
    IconData? trailingIcon,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.brandRed).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            color: iconColor ?? AppColors.brandRed, size: 20),
      ),
      title: Text(title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: titleColor ?? AppColors.darkText,
          )),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.mutedText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: trailingIcon != null
          ? Icon(trailingIcon,
              color: AppColors.mutedText, size: 18)
          : (onTap != null && showArrow
              ? const Icon(Icons.chevron_right,
                  color: AppColors.mutedText, size: 20)
              : null),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.brandRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.brandRed, size: 20),
      ),
      title: Text(title,
          style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.mutedText))
          : null,
      value: value,
      activeColor: AppColors.brandRed,
      onChanged: onChanged,
    );
  }

  Widget _buildDivider() {
    return const Divider(
        height: 1,
        color: AppColors.borderSubtle,
        indent: 68,
        endIndent: 0);
  }
}
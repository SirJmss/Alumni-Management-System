import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Safe color fallbacks in case some AppColors are missing
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
          'Settings',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 28,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Profile header
          _SettingsHeader(
            name: 'Kami', // ← you can replace with real name later
            email: 'kami@example.com',
            avatarUrl: null, // ← add real URL or asset later
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // Sections
          _buildSectionHeader(context, 'Account', isDark),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Edit name, photo, batch, course',
            onTap: () {
              // TODO: navigate to profile edit screen
              _showComingSoon(context);
            },
          ),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            title: 'Verification Status',
            subtitle: 'Pending / Verified / Rejected',
            trailing: Text(
              'Pending',
              style: GoogleFonts.inter(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _showComingSoon(context),
          ),

          const Divider(height: 32),

          _buildSectionHeader(context, 'Preferences', isDark),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Push, email, in-app alerts',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Appearance',
            subtitle: 'Light / Dark / System',
            trailing: Text(
              isDark ? 'Dark' : 'Light',
              style: GoogleFonts.inter(color: mutedColor),
            ),
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'English (default)',
            onTap: () => _showComingSoon(context),
          ),

          const Divider(height: 32),

          _buildSectionHeader(context, 'Privacy & Security', isDark),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Privacy Settings',
            subtitle: 'Who can see your profile, posts',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.security,
            title: 'Security',
            subtitle: 'Change password, 2FA',
            onTap: () => _showComingSoon(context),
          ),

          const Divider(height: 32),

          _buildSectionHeader(context, 'Support', isDark),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Help & FAQ',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.contact_support_outlined,
            title: 'Contact Support',
            onTap: () => _showComingSoon(context),
          ),

          const SizedBox(height: 40),

          // Logout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: show confirmation dialog + sign out
                _showComingSoon(context);
              },
              icon: Icon(Icons.logout, color: accentColor),
              label: Text(
                'Log Out',
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: isDark ? Colors.grey[500] : Colors.grey[700],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feature coming soon')),
    );
  }
}

// Profile header card
class _SettingsHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isDark;

  const _SettingsHeader({
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.brandRed ?? const Color(0xFF9B1D1D);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Card(
        elevation: isDark ? 2 : 1,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: accentColor.withOpacity(0.15),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, color: accentColor),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit profile – coming soon')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable settings tile
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.brandRed ?? const Color(0xFF9B1D1D)),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
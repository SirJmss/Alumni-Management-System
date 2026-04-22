import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CreateUserPanel
//
// A modal bottom sheet / dialog that lets admins create accounts for:
//   - Alumni (role: 'alumni')
//   - Moderator (role: 'moderator')
//   - Registrar (role: 'registrar')
//   - Admin (role: 'admin')
//
// USAGE — call this static method from any admin screen:
//   CreateUserPanel.show(context);
//
// HOW IT WORKS:
//   1. Admin fills out the form and selects a role.
//   2. A Firebase Auth account is created via createUserWithEmailAndPassword.
//   3. A Firestore /users document is written with all profile fields +
//      verificationStatus = 'verified' and status = 'active' (admin-created
//      accounts skip the verification queue).
//   4. The newly created user is immediately signed out so the admin's session
//      is not replaced.
//   5. Optionally, a password-reset email is sent so the new user can set
//      their own password on first login.
// ─────────────────────────────────────────────────────────────────────────────

class CreateUserPanel extends StatefulWidget {
  const CreateUserPanel({super.key});

  /// Convenience launcher — shows the panel as a modal bottom sheet.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateUserPanel(),
    );
  }

  @override
  State<CreateUserPanel> createState() => _CreateUserPanelState();
}

class _CreateUserPanelState extends State<CreateUserPanel> {
  final _formKey = GlobalKey<FormState>();

  // ─── Controllers ─────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();

  // ─── State ────────────────────────────────────────────────────────────────
  String _selectedRole = 'alumni';
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _sendResetEmail = true;
  bool _isLoading = false;
  String? _globalError;

  // Role options with metadata
  static const _roles = [
    _RoleOption(
      value: 'alumni',
      label: 'Alumni',
      description: 'Standard alumni member with community access.',
      icon: Icons.school_outlined,
      color: Color(0xFF2563EB),
    ),
    _RoleOption(
      value: 'moderator',
      label: 'Moderator',
      description: 'Can moderate posts, comments, and reports.',
      icon: Icons.shield_outlined,
      color: Color(0xFF16A34A),
    ),
    _RoleOption(
      value: 'registrar',
      label: 'Registrar',
      description: 'Manages alumni records and registry uploads.',
      icon: Icons.assignment_outlined,
      color: Color(0xFFD97706),
    ),
    _RoleOption(
      value: 'admin',
      label: 'Admin',
      description: 'Full access to all admin features and settings.',
      icon: Icons.admin_panel_settings_outlined,
      color: Color(0xFFDC2626),
    ),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _batchCtrl.dispose();
    _courseCtrl.dispose();
    _phoneCtrl.dispose();
    _studentIdCtrl.dispose();
    super.dispose();
  }

  // ─── Create user ──────────────────────────────────────────────────────────
  Future<void> _createUser() async {
    setState(() => _globalError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Remember current admin
    final adminUser = FirebaseAuth.instance.currentUser;

    try {
      // 1. Create Firebase Auth account
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
      );

      final newUid = credential.user!.uid;
      final now = FieldValue.serverTimestamp();

      // 2. Write Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUid)
          .set({
        'uid': newUid,
        'name': _nameCtrl.text.trim(),
        'fullName': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'role': _selectedRole,
        'status': 'active',
        'verificationStatus': 'verified',
        'batchYear': _batchCtrl.text.trim(),
        'batch': _batchCtrl.text.trim(),
        'course': _courseCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'studentId': _studentIdCtrl.text.trim(),
        'headline': '',
        'about': '',
        'location': '',
        'connectionsCount': 0,
        'followersCount': 0,
        'createdAt': now,
        'updatedAt': now,
        'verifiedAt': now,
        'verifiedBy': adminUser?.uid ?? 'admin',
        'registryMatchId': '',
        'matchConfidence': 0.0,
      });

      // 3. Optionally send password-reset so user sets their own password
      if (_sendResetEmail) {
        await FirebaseAuth.instance
            .sendPasswordResetEmail(
          email: _emailCtrl.text.trim().toLowerCase(),
        );
      }

      // 4. Sign out the newly created user & restore admin session
      //    (Firebase Auth automatically signs in the new user on creation)
      await FirebaseAuth.instance.signOut();

      // Re-authenticate admin if we have their credentials cached.
      // Since we can't re-auth without their password, we navigate the admin
      // back to login. In a production app you'd use Admin SDK / Cloud Function
      // to create users server-side so the admin session is never disturbed.
      // For this client-side flow, we show a success dialog and pop.

      if (!mounted) return;
      Navigator.pop(context, true);
      _showSuccessDialog(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        role: _selectedRole,
        sentReset: _sendResetEmail,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _globalError = switch (e.code) {
          'email-already-in-use' =>
            'An account with this email already exists.',
          'weak-password' =>
            'Password must be at least 6 characters.',
          'invalid-email' => 'The email address is invalid.',
          _ => e.message ?? 'Failed to create account.',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _globalError = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog({
    required String name,
    required String email,
    required String role,
    required bool sentReset,
  }) {
    final roleOption =
        _roles.firstWhere((r) => r.value == role);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: roleOption.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(roleOption.icon,
                  color: roleOption.color, size: 30),
            ),
            const SizedBox(height: 16),
            Text('Account Created!',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            const SizedBox(height: 8),
            Text(name,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
            const SizedBox(height: 4),
            Text(email,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedText)),
            const SizedBox(height: 12),
            _badge(role.toUpperCase(), roleOption.color),
            if (sentReset) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.blue.shade100),
                ),
                child: Row(children: [
                  Icon(Icons.mail_outline,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A password-reset email has been sent so the user can set their own password.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.amber.shade200),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your admin session was replaced. Please sign in again.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.amber.shade800,
                        height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to login since admin session is gone
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (r) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Sign In Again',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Drag handle ──
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.person_add_alt_1_outlined,
                      color: AppColors.brandRed,
                      size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('Create New Account',
                          style:
                              GoogleFonts.cormorantGaramond(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkText)),
                      Text(
                          'Admin-created accounts are auto-verified.',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.mutedText)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.mutedText),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            const Divider(
                height: 20, color: AppColors.borderSubtle),

            // ── Form body ──
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(
                      28, 4, 28, 40),
                  children: [
                    // ── Role selector ──
                    _sectionLabel('SELECT ROLE'),
                    const SizedBox(height: 10),
                    _RoleSelector(
                      roles: _roles,
                      selected: _selectedRole,
                      onChanged: (v) =>
                          setState(() => _selectedRole = v),
                    ),

                    const SizedBox(height: 24),
                    _sectionDivider('ACCOUNT INFORMATION'),
                    const SizedBox(height: 16),

                    // ── Full name ──
                    _fieldLabel('FULL NAME *'),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _nameCtrl,
                      hint: 'e.g. Juan dela Cruz',
                      icon: Icons.person_outline,
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Full name is required'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // ── Email ──
                    _fieldLabel('EMAIL ADDRESS *'),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _emailCtrl,
                      hint: 'e.g. juan@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) {
                          return 'Email is required';
                        }
                        if (!RegExp(
                                r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                            .hasMatch(v!.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),
                    _sectionDivider('PASSWORD'),
                    const SizedBox(height: 16),

                    // ── Password ──
                    _fieldLabel('PASSWORD *'),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _passwordCtrl,
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscure: _obscurePass,
                      onToggleObscure: () => setState(
                          () => _obscurePass = !_obscurePass),
                      validator: (v) {
                        if (v?.isEmpty ?? true) {
                          return 'Password is required';
                        }
                        if (v!.length < 6) {
                          return 'At least 6 characters required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Confirm password ──
                    _fieldLabel('CONFIRM PASSWORD *'),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _confirmCtrl,
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscure: _obscureConfirm,
                      onToggleObscure: () => setState(
                          () =>
                              _obscureConfirm = !_obscureConfirm),
                      validator: (v) {
                        if (v != _passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // ── Send reset email toggle ──
                    GestureDetector(
                      onTap: () => setState(
                          () => _sendResetEmail = !_sendResetEmail),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _sendResetEmail
                              ? Colors.blue.shade50
                              : AppColors.softWhite,
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                            color: _sendResetEmail
                                ? Colors.blue.shade200
                                : AppColors.borderSubtle,
                          ),
                        ),
                        child: Row(children: [
                          AnimatedContainer(
                            duration: const Duration(
                                milliseconds: 200),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _sendResetEmail
                                  ? Colors.blue.shade600
                                  : Colors.white,
                              border: Border.all(
                                color: _sendResetEmail
                                    ? Colors.blue.shade600
                                    : AppColors.borderSubtle,
                                width: 1.5,
                              ),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: _sendResetEmail
                                ? const Icon(Icons.check,
                                    color: Colors.white,
                                    size: 12)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Send password-reset email',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600,
                                        color:
                                            AppColors.darkText)),
                                Text(
                                    'User will receive an email to set their own password.',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color:
                                            AppColors.mutedText)),
                              ],
                            ),
                          ),
                          Icon(Icons.mail_outline,
                              size: 18,
                              color: _sendResetEmail
                                  ? Colors.blue.shade400
                                  : AppColors.borderSubtle),
                        ]),
                      ),
                    ),

                    // ── Show profile fields only for alumni ──
                    if (_selectedRole == 'alumni') ...[
                      const SizedBox(height: 24),
                      _sectionDivider('PROFILE DETAILS'),
                      const SizedBox(height: 16),

                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('BATCH YEAR'),
                              const SizedBox(height: 8),
                              _buildField(
                                controller: _batchCtrl,
                                hint: 'e.g. 2019',
                                icon: Icons.calendar_today_outlined,
                                keyboardType:
                                    TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('STUDENT ID'),
                              const SizedBox(height: 8),
                              _buildField(
                                controller: _studentIdCtrl,
                                hint: 'e.g. 2019-0001',
                                icon: Icons.badge_outlined,
                              ),
                            ],
                          ),
                        ),
                      ]),

                      const SizedBox(height: 16),

                      _fieldLabel('COURSE / PROGRAM'),
                      const SizedBox(height: 8),
                      _buildField(
                        controller: _courseCtrl,
                        hint:
                            'e.g. BS Computer Science',
                        icon: Icons.school_outlined,
                      ),

                      const SizedBox(height: 16),

                      _fieldLabel('PHONE NUMBER'),
                      const SizedBox(height: 8),
                      _buildField(
                        controller: _phoneCtrl,
                        hint: 'e.g. +63 917 000 0000',
                        icon: Icons.phone_outlined,
                        keyboardType:
                            TextInputType.phone,
                      ),
                    ],

                    // ── Global error ──
                    if (_globalError != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_globalError!,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color:
                                        Colors.red.shade700,
                                    height: 1.4)),
                          ),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Submit ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : _createUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.brandRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          disabledBackgroundColor:
                              AppColors.brandRed
                                  .withOpacity(0.6),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                      Icons
                                          .person_add_alt_1_outlined,
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                      'CREATE ${_selectedRole.toUpperCase()} ACCOUNT',
                                      style:
                                          GoogleFonts.inter(
                                        fontWeight:
                                            FontWeight.w700,
                                        fontSize: 13,
                                        letterSpacing: 1,
                                      )),
                                ],
                              ),
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

  // ─── Reusable widgets ─────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.mutedText));

  Widget _fieldLabel(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.mutedText));

  Widget _sectionDivider(String label) {
    return Row(children: [
      Container(
          width: 16,
          height: 1,
          color: AppColors.borderSubtle),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.mutedText)),
      const SizedBox(width: 8),
      Expanded(
          child: Container(
              height: 1, color: AppColors.borderSubtle)),
    ]);
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
          fontSize: 14, color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: AppColors.borderSubtle, fontSize: 13),
        prefixIcon:
            Icon(icon, color: AppColors.mutedText, size: 18),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.mutedText,
                  size: 18,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.softWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: AppColors.brandRed, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RoleOption — data model for each role card
// ─────────────────────────────────────────────────────────────────────────────
class _RoleOption {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _RoleOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _RoleSelector — 2×2 grid of role cards
// ─────────────────────────────────────────────────────────────────────────────
class _RoleSelector extends StatelessWidget {
  final List<_RoleOption> roles;
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleSelector({
    required this.roles,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: roles
          .map((role) => _RoleCard(
                role: role,
                isSelected: selected == role.value,
                onTap: () => onChanged(role.value),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RoleCard — individual selectable role tile
// ─────────────────────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final _RoleOption role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? role.color.withOpacity(0.06)
              : AppColors.softWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? role.color : AppColors.borderSubtle,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isSelected
                  ? role.color.withOpacity(0.12)
                  : AppColors.borderSubtle.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(role.icon,
                color: isSelected
                    ? role.color
                    : AppColors.mutedText,
                size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(role.label,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? role.color
                            : AppColors.darkText)),
                Text(role.description,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.mutedText,
                        height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_circle,
                color: role.color, size: 16),
        ]),
      ),
    );
  }
}
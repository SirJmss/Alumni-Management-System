import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';

class EditEventScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> event;

  const EditEventScreen(
      {super.key, required this.eventId, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _typeController;

  DateTime? _startDateTime;
  DateTime? _endDateTime;

  File? _newImageFile;
  String? _currentImageUrl;
  bool _removeImage = false;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isVirtual = false;
  bool _isImportant = false;

  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
        text: widget.event['title'] ?? '');
    _descriptionController = TextEditingController(
        text: widget.event['description'] ?? '');
    _locationController = TextEditingController(
        text: widget.event['location'] ?? '');
    _typeController = TextEditingController(
        text: widget.event['type'] ?? '');

    final startTs = widget.event['startDate'] as Timestamp?;
    if (startTs != null) _startDateTime = startTs.toDate();

    final endTs = widget.event['endDate'] as Timestamp?;
    if (endTs != null) _endDateTime = endTs.toDate();

    _currentImageUrl =
        widget.event['heroImageUrl'] as String?;
    _isVirtual = widget.event['isVirtual'] as bool? ?? false;
    _isImportant =
        widget.event['isImportant'] as bool? ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Select Image Source',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.brandRed),
              title: Text('Gallery',
                  style: GoogleFonts.inter()),
              onTap: () =>
                  Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.brandRed),
              title: Text('Camera',
                  style: GoogleFonts.inter()),
              onTap: () =>
                  Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 800,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _newImageFile = File(pickedFile.path);
        _removeImage = false;
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      setState(() => _isUploading = true);
      final userId =
          FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final fileName =
          'event_images/$userId/edit_${widget.eventId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Image upload failed: $e', isError: true);
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initial = isStart
        ? (_startDateTime ?? DateTime.now())
        : (_endDateTime ?? _startDateTime ?? DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.brandRed),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.brandRed),
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.brandRed),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.brandRed),
          ),
        ),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startDateTime = combined;
        if (_endDateTime != null &&
            _endDateTime!.isBefore(combined)) {
          _endDateTime = null;
        }
      } else {
        _endDateTime = combined;
      }
    });
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Tap to set';
    return DateFormat('EEE, MMM dd yyyy • hh:mm a').format(dt);
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDateTime == null) {
      _showSnackBar('Start date & time is required',
          isError: true);
      return;
    }
    if (_endDateTime != null &&
        _endDateTime!.isBefore(_startDateTime!)) {
      _showSnackBar('End cannot be before start', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? newImageUrl;
      if (_removeImage) {
        newImageUrl = null;
      } else if (_newImageFile != null) {
        newImageUrl = await _uploadImage(_newImageFile!);
        newImageUrl ??= _currentImageUrl;
      } else {
        newImageUrl = _currentImageUrl;
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'type': _typeController.text.trim().isEmpty
            ? 'Campus Event'
            : _typeController.text.trim(),
        'startDate': Timestamp.fromDate(_startDateTime!),
        'endDate': _endDateTime != null
            ? Timestamp.fromDate(_endDateTime!)
            : null,
        'heroImageUrl': newImageUrl,
        'isVirtual': _isVirtual,
        'isImportant': _isImportant,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackBar('Event updated successfully!',
            isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
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
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        iconTheme:
            const IconThemeData(color: AppColors.darkText),
        title: Text('Edit Event',
            style: GoogleFonts.cormorantGaramond(fontSize: 22)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateEvent,
            child: Text(
              _isLoading ? 'Saving...' : 'Save',
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
            // ─── Image ───
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppColors.borderSubtle),
                ),
                child: _newImageFile != null
                    ? Stack(children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(16),
                          child: Image.file(_newImageFile!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200),
                        ),
                        _removeButton(),
                        if (_isUploading)
                          const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white)),
                      ])
                    : (_currentImageUrl != null &&
                            !_removeImage)
                        ? Stack(children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: _currentImageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
                                placeholder: (_, __) =>
                                    const Center(
                                        child:
                                            CircularProgressIndicator(
                                                color: AppColors
                                                    .brandRed)),
                                errorWidget: (_, __, ___) =>
                                    const Icon(
                                        Icons.broken_image,
                                        color:
                                            AppColors.mutedText),
                              ),
                            ),
                            _removeButton(),
                          ])
                        : Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                  Icons
                                      .add_photo_alternate_outlined,
                                  size: 48,
                                  color: AppColors.mutedText),
                              const SizedBox(height: 8),
                              Text('Tap to add event image',
                                  style: GoogleFonts.inter(
                                      color: AppColors.mutedText,
                                      fontSize: 14)),
                            ],
                          ),
              ),
            ),

            const SizedBox(height: 20),

            _buildField(
              controller: _titleController,
              label: 'Event Title',
              hint: 'What is this event called?',
              validator: (v) => v?.trim().isEmpty == true
                  ? 'Title is required'
                  : null,
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _typeController,
              label: 'Event Type',
              hint: 'e.g. Campus Event, Webinar, Reunion',
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe the event...',
              maxLines: 5,
              validator: (v) => v?.trim().isEmpty == true
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _locationController,
              label: 'Location',
              hint: 'Venue, address, or online link',
              prefixIcon: Icons.location_on_outlined,
            ),

            const SizedBox(height: 20),

            _buildToggleCard(
              icon: Icons.videocam_outlined,
              title: 'Virtual Event',
              subtitle: 'This event will be held online',
              value: _isVirtual,
              onChanged: (v) => setState(() => _isVirtual = v),
            ),
            const SizedBox(height: 10),
            _buildToggleCard(
              icon: Icons.star_outline,
              title: 'Mark as Important',
              subtitle: 'Highlight this event for all alumni',
              value: _isImportant,
              onChanged: (v) =>
                  setState(() => _isImportant = v),
            ),

            const SizedBox(height: 20),

            Text('Schedule',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            const SizedBox(height: 12),

            _buildDateTimeTile(
              label: 'Start Date & Time',
              value: _startDateTime,
              isStart: true,
              required: true,
            ),
            const SizedBox(height: 10),
            _buildDateTimeTile(
              label: 'End Date & Time',
              value: _endDateTime,
              isStart: false,
              required: false,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateEvent,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isLoading ? 'Saving...' : 'Save Changes',
                  style: GoogleFonts.inter(
                      fontSize: 16,
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

  Widget _removeButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: () => setState(() {
          _newImageFile = null;
          _removeImage = true;
        }),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.close,
              color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
            color: AppColors.brandRed,
            fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.inter(
            color: AppColors.mutedText, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon,
                color: AppColors.mutedText, size: 20)
            : null,
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
      ),
      validator: validator,
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
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
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText)),
        value: value,
        activeColor: AppColors.brandRed,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateTimeTile({
    required String label,
    required DateTime? value,
    required bool isStart,
    required bool required,
  }) {
    return GestureDetector(
      onTap: () => _pickDateTime(isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null
                ? AppColors.brandRed.withOpacity(0.4)
                : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.brandRed, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label${required ? ' *' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(value),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: value != null
                          ? AppColors.darkText
                          : AppColors.mutedText,
                      fontWeight: value != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              value != null
                  ? Icons.edit_outlined
                  : Icons.add_circle_outline,
              color: AppColors.brandRed,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
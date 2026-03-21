import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class EventPlanningScreen extends StatefulWidget {
  const EventPlanningScreen({super.key});

  @override
  State<EventPlanningScreen> createState() => _EventPlanningScreenState();
}

class _EventPlanningScreenState extends State<EventPlanningScreen> {
  // Helper to get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.blue;
      case 'ongoing':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'draft':
      default:
        return AppColors.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      // ================= APPBAR UPDATED FOR ADMIN PORTAL =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.dashboard_outlined, color: AppColors.darkText),
          onPressed: () {
            // Navigator.pop(context) or navigate to a specific route
            Navigator.of(context).pop(); 
          },
        ),
        title: Text(
          'Admin Portal / Dashboard',
          style: GoogleFonts.inter(
            color: AppColors.darkText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= 1. HERO OVERVIEW SECTION (Photo Preserved) =================
            Container(
              height: 300,
              width: double.infinity,
              child: Stack(
                children: [
                  // Background Image
                  Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                            'https://images.unsplash.com/photo-1511578314322-379afb476865?q=80&w=2069&auto=format&fit=crop'),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.4), BlendMode.darken),
                      ),
                    ),
                  ),
                  // Text Overlay
                  Positioned(
                    bottom: 40,
                    left: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Planning Overview',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Coordinate and track all St. Cecilia’s alumni gatherings.',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ================= 2. DASHBOARD CONTENT =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Schedule',
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('Create New Event',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showEventForm(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Event List (Functionality Preserved)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .orderBy('startDate', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const Center(child: CircularProgressIndicator());
                      if (snapshot.hasError)
                        return Center(
                            child: Text('Error loading events',
                                style: GoogleFonts.inter()));
                      final events = snapshot.data?.docs ?? [];
                      if (events.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 100),
                            child: Text('No events created yet.',
                                style: GoogleFonts.inter(
                                    fontSize: 17, color: AppColors.mutedText)),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final doc = events[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final start =
                              (data['startDate'] as Timestamp?)?.toDate();
                          final status = data['status'] ?? 'DRAFT';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                    radius: 28,
                                    backgroundColor:
                                        AppColors.brandRed.withOpacity(0.1),
                                    child: const Icon(Icons.event,
                                        color: AppColors.brandRed)),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['title'] ?? 'No title',
                                          style: GoogleFonts.inter(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.darkText)),
                                      const SizedBox(height: 8),
                                      Text(data['description'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: AppColors.mutedText)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_month,
                                              size: 14, color: AppColors.brandRed),
                                          const SizedBox(width: 6),
                                          Text(
                                              start != null
                                                  ? "${DateFormat('MMM dd, yyyy').format(start)} - ${data['endTime'] ?? 'TBD'}"
                                                  : "TBD",
                                              style: GoogleFonts.inter(
                                                  fontSize: 13)),
                                          const SizedBox(width: 20),
                                          const Icon(Icons.people_outline,
                                              size: 14, color: AppColors.brandRed),
                                          const SizedBox(width: 6),
                                          Text(
                                              "Capacity: ${data['capacity'] ?? 0}",
                                              style: GoogleFonts.inter(
                                                  fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: _getStatusColor(status)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: Text(
                                            status.toString().toUpperCase(),
                                            style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _getStatusColor(status))),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _showEventForm(
                                            eventId: doc.id, initialData: data)),
                                    IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () => _confirmDelete(doc.id,
                                            data['title'] ?? 'event')),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= CRUD FUNCTIONALITY (Preserved) =================

  void _showEventForm({String? eventId, Map<String, dynamic>? initialData}) {
    final isEdit = eventId != null;
    final formKey = GlobalKey<FormState>();

    final titleCtrl = TextEditingController(text: initialData?['title'] ?? '');
    final descCtrl = TextEditingController(text: initialData?['description'] ?? '');
    final locationCtrl = TextEditingController(text: initialData?['location'] ?? '');
    final capacityCtrl = TextEditingController(text: initialData?['capacity']?.toString() ?? '');
    DateTime? selectedDate = (initialData?['startDate'] as Timestamp?)?.toDate();
    String? endTimeStr = initialData?['endTime'];
    String status = initialData?['status'] ?? 'DRAFT';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Event' : 'Create Event', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      style: GoogleFonts.inter(),
                      decoration: InputDecoration(labelText: 'Event Title*', hintText: 'e.g., Grand Alumni Homecoming', labelStyle: GoogleFonts.inter()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descCtrl,
                      style: GoogleFonts.inter(),
                      decoration: InputDecoration(labelText: 'Description*', hintText: 'What is this event about?', labelStyle: GoogleFonts.inter()),
                      maxLines: 3,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: locationCtrl,
                      style: GoogleFonts.inter(),
                      decoration: InputDecoration(labelText: 'Location*', hintText: 'e.g., College Gym', labelStyle: GoogleFonts.inter()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Location is required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: capacityCtrl,
                      style: GoogleFonts.inter(),
                      decoration: InputDecoration(labelText: 'Capacity*', hintText: 'Total attendees', labelStyle: GoogleFonts.inter()),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Capacity is required';
                        if (int.tryParse(v) == null) return 'Must be a number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                      tileColor: Colors.grey[50],
                      title: Text(
                        selectedDate == null ? "Select Date*" : DateFormat('yyyy-MM-dd').format(selectedDate!),
                        style: GoogleFonts.inter(color: selectedDate == null ? Colors.red.shade700 : Colors.black),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                      tileColor: Colors.grey[50],
                      title: Text(endTimeStr ?? "Select End Time*", style: GoogleFonts.inter()),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) setDialogState(() => endTimeStr = picked.format(context));
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(labelText: 'Status', labelStyle: GoogleFonts.inter()),
                      items: ['DRAFT', 'PUBLISHED', 'ONGOING', 'COMPLETED', 'CANCELLED']
                          .map((val) => DropdownMenuItem(value: val, child: Text(val, style: GoogleFonts.inter())))
                          .toList(),
                      onChanged: (val) => setDialogState(() => status = val!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('Cancel', style: GoogleFonts.inter())
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                if (selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an event date')));
                  return;
                }

                final data = {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'capacity': int.tryParse(capacityCtrl.text) ?? 0,
                  'startDate': Timestamp.fromDate(selectedDate!),
                  'endTime': endTimeStr ?? 'TBD',
                  'status': status,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                try {
                  if (isEdit) {
                    await FirebaseFirestore.instance.collection('events').doc(eventId).update(data);
                  } else {
                    await FirebaseFirestore.instance.collection('events').add(data);
                  }
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(isEdit ? 'Update' : 'Create', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String eventId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Event', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$title"? This cannot be undone.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}
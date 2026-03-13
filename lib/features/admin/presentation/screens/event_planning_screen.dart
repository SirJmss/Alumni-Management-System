import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart'; // ← adjust import if needed

class EventPlanningScreen extends StatefulWidget {
  const EventPlanningScreen({super.key});

  @override
  State<EventPlanningScreen> createState() => _EventPlanningScreenState();
}

class _EventPlanningScreenState extends State<EventPlanningScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Event Planning',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Event'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => _showEventForm(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Events',
              style: GoogleFonts.cormorantGaramond(fontSize: 24, color: AppColors.darkText),
            ),
            const SizedBox(height: 8),
            Text(
              'Create, edit and manage alumni events',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .orderBy('startDate', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading events\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final events = snapshot.data?.docs ?? [];

                  if (events.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No events yet',
                            style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click "New Event" to create one',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final doc = events[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final start = (data['startDate'] as Timestamp?)?.toDate();
                      final end = (data['endDate'] as Timestamp?)?.toDate();
                      final status = data['status'] as String? ?? 'draft';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: _getStatusColor(status).withOpacity(0.15),
                            child: Icon(
                              Icons.event,
                              color: _getStatusColor(status),
                            ),
                          ),
                          title: Text(
                            data['title'] ?? 'No title',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (start != null)
                                Text(
                                  DateFormat('MMM dd, yyyy • h:mm a').format(start) +
                                      (end != null ? ' – ${DateFormat('h:mm a').format(end)}' : ''),
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${data['registeredCount'] ?? 0} registered',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.success),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 22),
                                tooltip: 'Edit',
                                onPressed: () => _showEventForm(eventId: doc.id, initialData: data),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(doc.id, data['title'] ?? 'this event'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'ongoing':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _showEventForm({String? eventId, Map<String, dynamic>? initialData}) {
    final isEdit = eventId != null;
    final titleCtrl = TextEditingController(text: initialData?['title'] ?? '');
    final descCtrl = TextEditingController(text: initialData?['description'] ?? '');
    final locationCtrl = TextEditingController(text: initialData?['location'] ?? '');
    final capacityCtrl = TextEditingController(text: initialData?['capacity']?.toString() ?? '');

    DateTime? startDate = (initialData?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (initialData?['endDate'] as Timestamp?)?.toDate();

    String status = initialData?['status'] ?? 'draft';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Event' : 'Create New Event'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Event Title *'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'Location / Link'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Capacity (optional)'),
                ),
                const SizedBox(height: 24),

                // Date & Time pickers
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          startDate == null ? 'Start Date & Time' : DateFormat('MMM dd, yyyy • hh:mm a').format(startDate!),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(startDate ?? DateTime.now()),
                              );
                              if (time != null) {
                                setState(() {
                                  startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          endDate == null ? 'End Date & Time (optional)' : DateFormat('MMM dd, yyyy • hh:mm a').format(endDate!),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now().add(const Duration(hours: 2)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(endDate ?? DateTime.now()),
                              );
                              if (time != null) {
                                setState(() {
                                  endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Status dropdown
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'published', child: Text('Published')),
                    DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => status = val);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || startDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and start date are required')),
                );
                return;
              }

              final data = {
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'location': locationCtrl.text.trim(),
                'capacity': int.tryParse(capacityCtrl.text.trim()),
                'startDate': Timestamp.fromDate(startDate!),
                if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
                'status': status,
                'updatedAt': FieldValue.serverTimestamp(),
                if (!isEdit) ...{
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser?.uid,
                  'registeredCount': 0,
                },
              };

              try {
                if (isEdit) {
                  await FirebaseFirestore.instance.collection('events').doc(eventId).update(data);
                } else {
                  await FirebaseFirestore.instance.collection('events').add(data);
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Event updated' : 'Event created'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    ).then((_) => setState(() {})); // refresh list after dialog closes
  }

  Future<void> _confirmDelete(String eventId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "$title"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting event: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
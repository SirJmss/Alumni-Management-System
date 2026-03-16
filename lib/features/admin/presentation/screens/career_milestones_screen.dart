import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class CareerMilestonesScreen extends StatefulWidget {
  const CareerMilestonesScreen({super.key});

  @override
  State<CareerMilestonesScreen> createState() => _CareerMilestonesScreenState();
}

class _CareerMilestonesScreenState extends State<CareerMilestonesScreen> {
  String? selectedStatusFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Career Milestones',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String?>(
              value: selectedStatusFilter,
              hint: Text('All Statuses', style: GoogleFonts.inter(color: AppColors.mutedText)),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) => setState(() => selectedStatusFilter = value),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Career Milestones Moderation',
              style: GoogleFonts.cormorantGaramond(fontSize: 36, fontWeight: FontWeight.w300, color: AppColors.darkText),
            ),
            const SizedBox(height: 8),
            Text(
              'Review and moderate alumni-submitted career achievements and updates',
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.mutedText),
            ),
            const SizedBox(height: 32),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getFilteredMilestones(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading milestones:\n${snapshot.error}',
                        style: GoogleFonts.inter(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final milestones = snapshot.data?.docs ?? [];

                  if (milestones.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_history_outlined, size: 90, color: Colors.grey[350]),
                          const SizedBox(height: 32),
                          Text(
                            'No career milestones to review',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.darkText),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedStatusFilter != null
                                ? 'No milestones with status: ${selectedStatusFilter!.toUpperCase()}'
                                : 'Alumni can submit career updates from their profile page',
                            style: GoogleFonts.inter(fontSize: 15, color: AppColors.mutedText),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: milestones.length,
                    itemBuilder: (context, index) {
                      final doc = milestones[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
                      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
                      final milestoneDate = (data['date'] as Timestamp?)?.toDate();
                      final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';
                      final userName = data['userName'] ?? data['submittedByName'] ?? 'Unknown Alumni';
                      final avatarUrl = data['userPhotoUrl'] as String?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: _getStatusColor(status).withOpacity(0.15),
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? Icon(Icons.workspace_premium, color: _getStatusColor(status), size: 32)
                                    : null,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['title'] ?? 'Untitled Milestone',
                                            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$userName • ${data['company'] ?? 'No company'}',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    if (milestoneDate != null)
                                      Text(
                                        'Milestone date: ${DateFormat('MMM dd, yyyy').format(milestoneDate)}',
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          'Submitted by $userName • ${submittedAt != null ? DateFormat('MMM dd, yyyy').format(submittedAt) : '—'}',
                                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                                        ),
                                        if (updatedAt != null && updatedAt.isAfter(submittedAt ?? DateTime(2000))) ...[
                                          const SizedBox(width: 12),
                                          Text(
                                            '(Updated: ${DateFormat('MMM dd, yyyy').format(updatedAt)})',
                                            style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Column(
                                children: [
                                  if (status == 'pending') ...[
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                      tooltip: 'Approve this milestone',
                                      onPressed: () => _updateStatus(doc.id, 'approved'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
                                      tooltip: 'Reject this milestone',
                                      onPressed: () => _updateStatus(doc.id, 'rejected'),
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 24),
                                    tooltip: 'Edit milestone',
                                    onPressed: () => _showEditForm(doc.id, data),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                                    tooltip: 'Delete milestone',
                                    onPressed: () => _confirmDelete(doc.id, data['title'] ?? 'this milestone'),
                                  ),
                                ],
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

  Stream<QuerySnapshot> _getFilteredMilestones() {
    Query query = FirebaseFirestore.instance
        .collection('career_milestones')
        .orderBy('submittedAt', descending: true);

    if (selectedStatusFilter != null) {
      query = query.where('status', isEqualTo: selectedStatusFilter);
    }

    return query.snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'pending':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Future<void> _updateStatus(String milestoneId, String newStatus) async {
    final action = newStatus == 'approved' ? 'Approve' : 'Reject';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Milestone'),
        content: Text('Are you sure you want to $action this career update?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: newStatus == 'approved' ? Colors.green : Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('career_milestones').doc(milestoneId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'approved') ...{
          'approvedBy': FirebaseAuth.instance.currentUser?.uid,
          'approvedAt': FieldValue.serverTimestamp(),
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Milestone ${newStatus == 'approved' ? 'approved' : 'rejected'}'),
          backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEditForm(String milestoneId, Map<String, dynamic> initialData) {
    final titleCtrl = TextEditingController(text: initialData['title'] ?? '');
    final companyCtrl = TextEditingController(text: initialData['company'] ?? '');
    final descCtrl = TextEditingController(text: initialData['description'] ?? '');
    String selectedType = initialData['type'] ?? 'promotion';
    DateTime? milestoneDate = (initialData['date'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Career Milestone'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Milestone Title *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: companyCtrl,
                    decoration: const InputDecoration(labelText: 'Company / Organization', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Milestone Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'promotion', child: Text('Promotion')),
                      DropdownMenuItem(value: 'new_job', child: Text('New Job')),
                      DropdownMenuItem(value: 'award', child: Text('Award / Recognition')),
                      DropdownMenuItem(value: 'certification', child: Text('Certification / Degree')),
                      DropdownMenuItem(value: 'retirement', child: Text('Retirement')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      milestoneDate == null ? 'Milestone Date *' : 'Date: ${DateFormat('MMM dd, yyyy').format(milestoneDate!)}',
                      style: GoogleFonts.inter(fontSize: 14.5),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today, color: AppColors.brandRed),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: milestoneDate ?? DateTime.now(),
                          firstDate: DateTime(1990),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) {
                          setDialogState(() => milestoneDate = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty || milestoneDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title and date are required')),
                  );
                  return;
                }

                final data = {
                  'title': title,
                  'company': companyCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'type': selectedType,
                  'date': Timestamp.fromDate(milestoneDate!),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                try {
                  await FirebaseFirestore.instance.collection('career_milestones').doc(milestoneId).update(data);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Milestone updated'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String milestoneId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Milestone'),
        content: Text('Delete "$title"?\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('career_milestones').doc(milestoneId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone deleted'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return isEmpty ? this : "${this[0].toUpperCase()}${substring(1)}";
  }
}
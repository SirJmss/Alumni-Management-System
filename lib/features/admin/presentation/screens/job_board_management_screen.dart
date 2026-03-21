import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class JobBoardManagementScreen extends StatefulWidget {
  const JobBoardManagementScreen({super.key});

  @override
  State<JobBoardManagementScreen> createState() => _JobBoardManagementScreenState();
}

class _JobBoardManagementScreenState extends State<JobBoardManagementScreen> {
  String? selectedStatusFilter;
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      // ================= 1. APPBAR (Updated Navigation) =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.dashboard_outlined, color: AppColors.darkText),
          onPressed: () {
            // Explicitly navigating to your Admin Dashboard route
            Navigator.pushReplacementNamed(context, '/admin_dashboard');
          },
        ),
        title: Text(
          'Admin Portal / Job Management',
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
            // ================= 2. HERO SECTION =================
            Container(
              height: 300,
              width: double.infinity,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: const NetworkImage(
                            'https://images.unsplash.com/photo-1486312338219-ce68d2c6f44d?q=80&w=2072&auto=format&fit=crop'),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.5), BlendMode.darken),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Job Board Management',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Post and monitor career opportunities for the alumni network.',
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

            // ================= 3. MAIN CONTENT AREA =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Career Listings',
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText),
                      ),
                      _buildFilterMenu(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSearchBar(),
                  const SizedBox(height: 32),

                  StreamBuilder<QuerySnapshot>(
                    stream: _buildJobQuery(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text("Error: Check Firebase connection."));
                      }

                      final jobs = snapshot.data?.docs ?? [];
                      final filteredJobs = jobs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final title = (data['title'] ?? '').toString().toLowerCase();
                        final company = (data['company'] ?? '').toString().toLowerCase();
                        return title.contains(searchQuery) || company.contains(searchQuery);
                      }).toList();

                      if (filteredJobs.isEmpty) return _buildEmptyState();

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredJobs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredJobs[index];
                          return _jobCard(doc.id, doc.data() as Map<String, dynamic>);
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

  // ================= UI HELPERS =================

  Widget _buildFilterMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list, color: AppColors.mutedText),
      onSelected: (value) => setState(() => selectedStatusFilter = value == 'all' ? null : value),
      itemBuilder: (context) => [
        _buildPopupItem('all', 'Show All'),
        _buildPopupItem('pending', 'Pending'),
        _buildPopupItem('approved', 'Approved'),
        _buildPopupItem('rejected', 'Rejected'),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String label) {
    bool isSelected = (selectedStatusFilter == value) || (value == 'all' && selectedStatusFilter == null);
    return PopupMenuItem(
      value: value,
      child: Text(label, style: GoogleFonts.inter(
          color: isSelected ? AppColors.brandRed : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search job title, company...",
          hintStyle: GoogleFonts.inter(color: AppColors.mutedText, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _jobCard(String id, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final postedAt = (data['postedAt'] as Timestamp?)?.toDate();

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
          Container(
            height: 60, width: 60,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1), 
              borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(Icons.business_center_outlined, color: _getStatusColor(status)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['title'] ?? 'Job Title', 
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                    Text(data['salary'] ?? 'N/A', 
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(data['company'] ?? 'Company Name', 
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.brandRed, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniTag(data['location'] ?? 'Remote', const Color(0xFFEEE5FF), const Color(0xFF6236FF)),
                    const SizedBox(width: 8),
                    _miniTag(status.toUpperCase(), _getStatusColor(status).withOpacity(0.1), _getStatusColor(status)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  data['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText, height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  postedAt != null ? "Posted on ${DateFormat('MMM dd, yyyy').format(postedAt)}" : "",
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              if (status == 'pending') ...[
                IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.green), onPressed: () => _updateJobStatus(id, 'approved')),
                IconButton(icon: const Icon(Icons.highlight_off, color: Colors.red), onPressed: () => _updateJobStatus(id, 'rejected')),
              ],
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditJobDialog(id, data)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmDeleteJob(id)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(Icons.work_outline, size: 64, color: AppColors.mutedText.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No job postings found.', style: GoogleFonts.inter(color: AppColors.mutedText)),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _buildJobQuery() {
    Query query = FirebaseFirestore.instance.collection('job_posting').orderBy('postedAt', descending: true);
    if (selectedStatusFilter != null) {
      query = query.where('status', isEqualTo: selectedStatusFilter);
    }
    return query.snapshots();
  }

  Color _getStatusColor(String status) {
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.orange;
  }

  void _showEditJobDialog(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6EAE8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => EditJobDialog(id: id, data: data),
    );
  }

  Future<void> _updateJobStatus(String id, String status) async => await FirebaseFirestore.instance.collection('job_posting').doc(id).update({'status': status});
  Future<void> _confirmDeleteJob(String id) async => await FirebaseFirestore.instance.collection('job_posting').doc(id).delete();
}

// --- EDIT DIALOG (DESIGN MAINTAINED) ---
class EditJobDialog extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  const EditJobDialog({super.key, required this.id, required this.data});
  @override State<EditJobDialog> createState() => _EditJobDialogState();
}

class _EditJobDialogState extends State<EditJobDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController title, company, location, salary, desc;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.data['title']);
    company = TextEditingController(text: widget.data['company']);
    location = TextEditingController(text: widget.data['location'] ?? '');
    salary = TextEditingController(text: widget.data['salary'] ?? '');
    desc = TextEditingController(text: widget.data['description']);
  }

  @override
  void dispose() {
    title.dispose(); company.dispose(); location.dispose(); salary.dispose(); desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 24, right: 24, top: 30),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Edit Job Posting", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w500)),
              const SizedBox(height: 30),
              _field("Job Title *", title),
              _field("Company *", company),
              _field("Location / Remote *", location),
              _field("Salary Range (optional)", salary, req: false),
              _field("Job Description *", desc, isMulti: true),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8D4F46),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await FirebaseFirestore.instance.collection('job_posting').doc(widget.id).update({
                          'title': title.text.trim(),
                          'company': company.text.trim(),
                          'location': location.text.trim(),
                          'salary': salary.text.trim(),
                          'description': desc.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Text("Save Changes", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool req = true, bool isMulti = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: Colors.black54)),
          TextFormField(
            controller: ctrl,
            maxLines: isMulti ? null : 1,
            decoration: const InputDecoration(
              isDense: true,
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 1.5)),
            ),
            validator: (v) => (req && (v == null || v.trim().isEmpty)) ? "Required" : null,
          ),
        ],
      ),
    );
  }
}
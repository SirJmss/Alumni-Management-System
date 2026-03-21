import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart'; // Ensure this exists

class GrowthMetricsScreen extends StatefulWidget {
  const GrowthMetricsScreen({super.key});

  @override
  State<GrowthMetricsScreen> createState() => _GrowthMetricsScreenState();
}

class _GrowthMetricsScreenState extends State<GrowthMetricsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Data State
  int totalAlumni = 0;
  int activeUsers = 0;
  int totalEvents = 0;
  int totalChapters = 0;
  List<Map<String, dynamic>> monthlyGrowth = [];
  bool isLoading = true;
  StreamSubscription? _metricsSubscription;

  @override
  void initState() {
    super.initState();
    _listenToLiveMetrics();
    _load12MonthGrowth();
  }

  @override
  void dispose() {
    _metricsSubscription?.cancel();
    super.dispose();
  }

  int get inactiveUsers => (totalAlumni - activeUsers).clamp(0, totalAlumni);

  // --- 1. Platform Snapshot: Live Firestore Sync ---
  void _listenToLiveMetrics() {
    final firestore = FirebaseFirestore.instance;
    _metricsSubscription = firestore.collection('users').snapshots().listen((_) async {
      try {
        final results = await Future.wait([
          firestore.collection('users').count().get(),
          firestore.collection('users').where('status', isEqualTo: 'active').count().get(),
          firestore.collection('events').count().get(),
          firestore.collection('chapters').count().get(),
        ]).timeout(const Duration(seconds: 5));

        if (!mounted) return;
        setState(() {
          totalAlumni = results[0].count ?? 0;
          activeUsers = results[1].count ?? 0;
          totalEvents = results[2].count ?? 0;
          totalChapters = results[3].count ?? 0;
          isLoading = false;
        });
      } catch (e) {
        if (mounted) setState(() => isLoading = false);
      }
    });
  }

  // --- 2. Growth: 12 Months Logic ---
  Future<void> _load12MonthGrowth() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('monthly_metrics')
          .orderBy('timestamp', descending: false)
          .limit(12) // Fetches the full year
          .get();

      if (mounted && snap.docs.isNotEmpty) {
        setState(() {
          monthlyGrowth = snap.docs.map((doc) => {
            'month': DateFormat('MMM').format((doc.data()['timestamp'] as Timestamp).toDate()),
            'value': (doc.data()['totalAlumni'] as num?)?.toDouble() ?? 0.0,
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("12-Month Chart Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: _buildAppBar(),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : _buildWebLayout(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
        onPressed: () => Navigator.pushReplacementNamed(context, '/admin_dashboard'),
      ),
      title: Text('Growth Metrics', 
        style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      centerTitle: false,
    );
  }

  Widget _buildWebLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLiveCounterGrid(),
              const SizedBox(height: 24),
              _buildChartCard("12-Month Growth", _buildLineChart()),
              const SizedBox(height: 24),
              _buildChartCard("Member Activity Status (Active vs Inactive)", _buildBarChart()),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI: LIVE SNAPSHOT CARDS ---
  Widget _buildLiveCounterGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _snapshotCard("Total Alumni", totalAlumni.toString(), Icons.groups_rounded, Colors.blue),
        _snapshotCard("Active Users", activeUsers.toString(), Icons.bolt_rounded, Colors.orange),
        _snapshotCard("Total Events", totalEvents.toString(), Icons.event_available_rounded, Colors.purple),
        _snapshotCard("Chapters", totalChapters.toString(), Icons.map_rounded, Colors.green),
      ],
    );
  }

  Widget _snapshotCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // --- UI: CHART WRAPPERS ---
  Widget _buildChartCard(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SizedBox(height: 300, child: chart),
        ],
      ),
    );
  }

  // --- 12 MONTH LINE CHART ---
  Widget _buildLineChart() {
    if (monthlyGrowth.isEmpty) return const Center(child: Text("Fetching 12-month data..."));
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(), topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
            int i = v.toInt();
            if (i < 0 || i >= monthlyGrowth.length) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(monthlyGrowth[i]['month'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
            );
          })),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: monthlyGrowth.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['value'])).toList(),
            isCurved: true,
            color: AppColors.brandRed,
            barWidth: 4,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(show: true, color: AppColors.brandRed.withOpacity(0.05)),
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  // --- ACTIVE VS INACTIVE BAR CHART ---
  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: totalAlumni.toDouble() + (totalAlumni * 0.1),
        barTouchData: BarTouchData(enabled: true),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
            return Text(v == 0 ? "Active" : "Inactive", style: const TextStyle(fontWeight: FontWeight.bold));
          })),
          topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
        ),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: activeUsers.toDouble(), color: Colors.greenAccent[700], width: 50, borderRadius: BorderRadius.circular(6))
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: inactiveUsers.toDouble(), color: AppColors.brandRed, width: 50, borderRadius: BorderRadius.circular(6))
          ]),
        ],
      ),
    );
  }
}
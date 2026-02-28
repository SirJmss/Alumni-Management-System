import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class GrowthMetricsScreen extends StatefulWidget {
  const GrowthMetricsScreen({super.key});

  @override
  State<GrowthMetricsScreen> createState() => _GrowthMetricsScreenState();
}

class _GrowthMetricsScreenState extends State<GrowthMetricsScreen> {
  int totalAlumni = 0;
  int activeUsers = 0;
  int totalEvents = 0;
  int totalChapters = 0;
  List<Map<String, dynamic>> monthlyGrowth = [];
  bool isLoading = true;
  String? errorMessage;
  StreamSubscription? _usersSubscription;

  @override
  void initState() {
    super.initState();
    _listenToLiveMetrics();
    _loadHistoricalGrowth();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    super.dispose();
  }

  int get inactiveUsers => (totalAlumni - activeUsers).clamp(0, totalAlumni);

  void _listenToLiveMetrics() {
    final firestore = FirebaseFirestore.instance;
    _usersSubscription = firestore.collection('users').snapshots().listen((_) async {
      if (!mounted) return;
      try {
        final results = await Future.wait([
          firestore.collection('users').count().get(),
          firestore.collection('users').where('status', isEqualTo: 'active').count().get(),
          firestore.collection('events').count().get(),
          firestore.collection('chapters').count().get(),
        ]);
        if (!mounted) return;
        setState(() {
          totalAlumni = results[0].count ?? 0;
          activeUsers = results[1].count ?? 0;
          totalEvents = results[2].count ?? 0;
          totalChapters = results[3].count ?? 0;
          isLoading = false;
          errorMessage = null;
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            errorMessage = 'Failed to load metrics';
            isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _loadHistoricalGrowth() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final start = DateTime(now.year - 1, now.month + 1, 1);
      final snap = await firestore
          .collection('monthly_metrics')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy('timestamp')
          .limit(12)
          .get();

      if (mounted) {
        setState(() {
          monthlyGrowth = snap.docs.map((doc) {
            final data = doc.data();
            final ts = data['timestamp'] as Timestamp?;
            return {
              'month': ts != null ? DateFormat('MMM yy').format(ts.toDate()) : 'N/A',
              'alumni': data['totalAlumni'] as int? ?? 0,
              'active': data['activeUsers'] as int? ?? 0,
            };
          }).toList();
        });
      }
    } catch (_) {
      // silent fail – live numbers still shown
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Growth',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandRed))
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      errorMessage!,
                      style: GoogleFonts.inter(color: AppColors.error, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Platform Snapshot',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LIVE • Firestore',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Compact metrics cards
                      Expanded(
                        flex: 3,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cross = constraints.maxWidth > 600 ? 4 : 2;
                            return GridView.count(
                              crossAxisCount: cross,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.4,
                              children: [
                                _buildCompactCard('TOTAL ALUMNI', totalAlumni.toString(), 'members'),
                                _buildCompactCard('ACTIVE', activeUsers.toString(), 'now', AppColors.success),
                                _buildCompactCard('EVENTS', totalEvents.toString(), 'total'),
                                _buildCompactCard('CHAPTERS', totalChapters.toString(), 'active'),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Compact line chart
                      Text(
                        'Growth – 12 months',
                        style: GoogleFonts.cormorantGaramond(fontSize: 20, color: AppColors.darkText),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 160,
                        child: monthlyGrowth.isEmpty
                            ? const Center(child: Text('no historical data', style: TextStyle(fontSize: 13, color: Colors.grey)))
                            : LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 22,
                                        interval: 2,
                                        getTitlesWidget: (value, meta) {
                                          final i = value.toInt();
                                          if (i % 2 == 0 && i < monthlyGrowth.length) {
                                            return Text(monthlyGrowth[i]['month'], style: const TextStyle(fontSize: 9));
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 28,
                                        interval: 5000,
                                        getTitlesWidget: (v, m) => Text(
                                          '${(v / 1000).toStringAsFixed(0)}k',
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  minX: 0,
                                  maxX: (monthlyGrowth.length - 1).toDouble(),
                                  minY: 0,
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: monthlyGrowth.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['alumni'] as num?)?.toDouble() ?? 0)).toList(),
                                      isCurved: true,
                                      color: AppColors.brandRed,
                                      barWidth: 2,
                                      dotData: const FlDotData(show: false),
                                    ),
                                    LineChartBarData(
                                      spots: monthlyGrowth.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['active'] as num?)?.toDouble() ?? 0)).toList(),
                                      isCurved: true,
                                      color: AppColors.success,
                                      barWidth: 2,
                                      dotData: const FlDotData(show: false),
                                    ),
                                  ],
                                  lineTouchData: const LineTouchData(enabled: false),
                                ),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Compact donut chart
                      Text(
                        'Active vs Inactive',
                        style: GoogleFonts.cormorantGaramond(fontSize: 20, color: AppColors.darkText),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140,
                        child: totalAlumni == 0
                            ? const Center(child: Text('no data', style: TextStyle(fontSize: 13, color: Colors.grey)))
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 38,
                                      startDegreeOffset: -90,
                                      sections: [
                                        PieChartSectionData(
                                          value: activeUsers.toDouble(),
                                          color: AppColors.success,
                                          radius: 52,
                                          title: activeUsers > 5 ? '${((activeUsers / totalAlumni) * 100).toStringAsFixed(0)}%' : '',
                                          titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        PieChartSectionData(
                                          value: inactiveUsers.toDouble(),
                                          color: AppColors.borderSubtle,
                                          radius: 52,
                                          title: inactiveUsers > 5 ? '${((inactiveUsers / totalAlumni) * 100).toStringAsFixed(0)}%' : '',
                                          titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        totalAlumni.toString(),
                                        style: GoogleFonts.cormorantGaramond(fontSize: 26, fontWeight: FontWeight.w300),
                                      ),
                                      const Text('total', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 12),

                      // Tiny legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTinyLegend(AppColors.success, 'Active'),
                          const SizedBox(width: 24),
                          _buildTinyLegend(AppColors.borderSubtle, 'Inactive'),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCompactCard(String title, String value, String subtitle, [Color? color]) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 9, letterSpacing: 0.8, color: AppColors.mutedText, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 34,
                fontWeight: FontWeight.w300,
                color: color ?? AppColors.darkText,
              ),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
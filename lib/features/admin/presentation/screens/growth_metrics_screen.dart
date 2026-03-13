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

  // ── Your data loading methods (unchanged) ──
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
      // silent fail
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
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      errorMessage!,
                      style: GoogleFonts.inter(color: AppColors.error, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final isNarrow = width < 700;

                    final horizontalPad = (width * 0.05).clamp(16.0, 48.0);
                    final verticalPad = (constraints.maxHeight * 0.02).clamp(12.0, 32.0);

                    int gridColumns = isNarrow ? 2 : 4;
                    double cardAspect = isNarrow ? 1.35 : 1.55;

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(horizontalPad, verticalPad, horizontalPad, verticalPad + 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform Snapshot',
                            style: GoogleFonts.cormorantGaramond(fontSize: 28, fontWeight: FontWeight.w400, color: AppColors.darkText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'LIVE • Firestore',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedText),
                          ),
                          const SizedBox(height: 24),

                          // Stats cards
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: gridColumns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: cardAspect,
                            children: [
                              _buildCompactCard('TOTAL ALUMNI', totalAlumni.toString(), 'members'),
                              _buildCompactCard('ACTIVE', activeUsers.toString(), 'now', AppColors.success),
                              _buildCompactCard('EVENTS', totalEvents.toString(), 'total'),
                              _buildCompactCard('CHAPTERS', totalChapters.toString(), 'active'),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Growth chart section
                          Text(
                            'Growth – 12 months',
                            style: GoogleFonts.cormorantGaramond(fontSize: 22, color: AppColors.darkText),
                          ),
                          const SizedBox(height: 12),
                          AspectRatio(
                            aspectRatio: isNarrow ? 1.6 : 2.2,
                            child: monthlyGrowth.isEmpty
                                ? const Center(child: Text('No historical data yet', style: TextStyle(fontSize: 14, color: Colors.grey)))
                                : LineChart(
                                    LineChartData(
                                      gridData: const FlGridData(show: false),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 24,
                                            interval: 2,
                                            getTitlesWidget: (value, meta) {
                                              final i = value.toInt();
                                              if (i % 2 == 0 && i < monthlyGrowth.length) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 6),
                                                  child: Text(
                                                    monthlyGrowth[i]['month'],
                                                    style: const TextStyle(fontSize: 10),
                                                  ),
                                                );
                                              }
                                              return const Text('');
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 32,
                                            interval: 5000,
                                            getTitlesWidget: (v, m) => Text(
                                              '${(v / 1000).toStringAsFixed(0)}k',
                                              style: const TextStyle(fontSize: 10),
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
                                          barWidth: 2.2,
                                          dotData: const FlDotData(show: false),
                                        ),
                                        LineChartBarData(
                                          spots: monthlyGrowth.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['active'] as num?)?.toDouble() ?? 0)).toList(),
                                          isCurved: true,
                                          color: AppColors.success,
                                          barWidth: 2.2,
                                          dotData: const FlDotData(show: false),
                                        ),
                                      ],
                                      lineTouchData: const LineTouchData(enabled: false),
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 32),

                          // Donut chart section
                          Text(
                            'Active vs Inactive Members',
                            style: GoogleFonts.cormorantGaramond(fontSize: 22, color: AppColors.darkText),
                          ),
                          const SizedBox(height: 12),
                          AspectRatio(
                            aspectRatio: isNarrow ? 1.3 : 1.6,
                            child: totalAlumni == 0
                                ? const Center(child: Text('No data available', style: TextStyle(fontSize: 14, color: Colors.grey)))
                                : Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      PieChart(
                                        PieChartData(
                                          sectionsSpace: 3,
                                          centerSpaceRadius: 48,
                                          startDegreeOffset: -90,
                                          sections: [
                                            PieChartSectionData(
                                              value: activeUsers.toDouble(),
                                              color: AppColors.success,
                                              radius: 60,
                                              title: activeUsers > 5 ? '${((activeUsers / totalAlumni) * 100).toStringAsFixed(0)}%' : '',
                                              titleStyle: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                            PieChartSectionData(
                                              value: inactiveUsers.toDouble(),
                                              color: AppColors.borderSubtle,
                                              radius: 60,
                                              title: inactiveUsers > 5 ? '${((inactiveUsers / totalAlumni) * 100).toStringAsFixed(0)}%' : '',
                                              titleStyle: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              totalAlumni.toString(),
                                              style: GoogleFonts.cormorantGaramond(fontSize: 36, fontWeight: FontWeight.w300),
                                            ),
                                          ),
                                          const Text('total members', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),

                          const SizedBox(height: 16),

                          // Legend
                          Center(
                            child: Wrap(
                              spacing: 32,
                              runSpacing: 12,
                              children: [
                                _buildTinyLegend(AppColors.success, 'Active'),
                                _buildTinyLegend(AppColors.borderSubtle, 'Inactive'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildCompactCard(String title, String value, String subtitle, [Color? accentColor]) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 10, letterSpacing: 0.8, color: AppColors.mutedText, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: accentColor ?? AppColors.darkText,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedText),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}
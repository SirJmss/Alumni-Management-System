import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GrowthMetricsScreen extends StatefulWidget {
  const GrowthMetricsScreen({super.key});

  @override
  State<GrowthMetricsScreen> createState() =>
      _GrowthMetricsScreenState();
}

class _GrowthMetricsScreenState
    extends State<GrowthMetricsScreen> {
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

  int get inactiveUsers =>
      (totalAlumni - activeUsers).clamp(0, totalAlumni);

  void _listenToLiveMetrics() {
    final firestore = FirebaseFirestore.instance;
    _metricsSubscription = firestore
        .collection('users')
        .snapshots()
        .listen((_) async {
      try {
        final results = await Future.wait([
          firestore.collection('users').count().get(),
          firestore
              .collection('users')
              .where('status', isEqualTo: 'active')
              .count()
              .get(),
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

  Future<void> _load12MonthGrowth() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('monthly_metrics')
          .orderBy('timestamp', descending: false)
          .limit(12)
          .get();

      if (mounted && snap.docs.isNotEmpty) {
        setState(() {
          monthlyGrowth = snap.docs
              .map((doc) => {
                    'month': DateFormat('MMM').format(
                        (doc.data()['timestamp'] as Timestamp)
                            .toDate()),
                    'value': (doc.data()['totalAlumni']
                                as num?)
                            ?.toDouble() ??
                        0.0,
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('12-Month Chart Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Sidebar ───
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  right: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ─── Logo ───
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALUMNI',
                        style:
                            GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          letterSpacing: 6,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ARCHIVE PORTAL',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Nav ───
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _sidebarSection('NETWORK', [
                          _sidebarItem('Overview',
                              route: '/admin_dashboard'),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection('ENGAGEMENT', [
                          _sidebarItem(
                              'Career Milestones',
                              route: '/career_milestones'),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection(
                            'ADMIN FEATURES', [
                          _sidebarItem(
                              'User Verification & Moderation',
                              route:
                                  '/user_verification_moderation'),
                          _sidebarItem('Event Planning',
                              route: '/event_planning'),
                          _sidebarItem(
                              'Job Board Management',
                              route:
                                  '/job_board_management'),
                          _sidebarItem('Growth Metrics',
                              route: '/growth_metrics',
                              isActive: true),
                          _sidebarItem(
                              'Announcement Management',
                              route:
                                  '/announcement_management'),
                        ]),
                      ],
                    ),
                  ),
                ),

                // ─── Footer ───
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: AppColors.borderSubtle
                                .withOpacity(0.3))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppColors.brandRed,
                            child: Text(
                              'A',
                              style: GoogleFonts
                                  .cormorantGaramond(
                                      color: Colors.white,
                                      fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Registrar Admin',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.bold)),
                              Text('NETWORK OVERSEER',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: AppColors
                                          .mutedText)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance
                              .signOut();
                          if (mounted) {
                            Navigator.pushReplacementNamed(
                                context, '/login');
                          }
                        },
                        child: Text(
                          'DISCONNECT',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Main content ───
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandRed))
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // ─── Header ───
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Growth Metrics',
                                  style: GoogleFonts
                                      .cormorantGaramond(
                                    fontSize: 36,
                                    fontWeight:
                                        FontWeight.w400,
                                    color:
                                        AppColors.darkText,
                                  ),
                                ),
                                Text(
                                  'LIVE PLATFORM OVERVIEW',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    color:
                                        AppColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green
                                    .withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(
                                        20),
                                border: Border.all(
                                    color: Colors.green
                                        .withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration:
                                      const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('Live',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight:
                                            FontWeight.w600)),
                              ]),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ─── Stat cards ───
                        Row(
                          children: [
                            _statCard(
                                'Total Alumni',
                                totalAlumni.toString(),
                                Icons.groups_rounded,
                                Colors.blue),
                            const SizedBox(width: 16),
                            _statCard(
                                'Active Users',
                                activeUsers.toString(),
                                Icons.bolt_rounded,
                                Colors.orange),
                            const SizedBox(width: 16),
                            _statCard(
                                'Total Events',
                                totalEvents.toString(),
                                Icons.event_available_rounded,
                                Colors.purple),
                            const SizedBox(width: 16),
                            _statCard(
                                'Chapters',
                                totalChapters.toString(),
                                Icons.map_rounded,
                                Colors.green),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ─── Charts row ───
                        Expanded(
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              // ─── Line chart ───
                              Expanded(
                                flex: 3,
                                child: _chartCard(
                                  '12-Month Alumni Growth',
                                  monthlyGrowth.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                            children: [
                                              const Icon(
                                                  Icons
                                                      .bar_chart_outlined,
                                                  size: 48,
                                                  color: AppColors
                                                      .borderSubtle),
                                              const SizedBox(
                                                  height: 12),
                                              Text(
                                                  'No monthly data yet',
                                                  style: GoogleFonts.inter(
                                                      color: AppColors
                                                          .mutedText)),
                                              const SizedBox(
                                                  height: 6),
                                              Text(
                                                'Add documents to\nmonthly_metrics collection',
                                                style: GoogleFonts.inter(
                                                    fontSize:
                                                        11,
                                                    color: AppColors
                                                        .mutedText),
                                                textAlign:
                                                    TextAlign
                                                        .center,
                                              ),
                                            ],
                                          ),
                                        )
                                      : _buildLineChart(),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // ─── Bar chart ───
                              Expanded(
                                flex: 2,
                                child: _chartCard(
                                  'Active vs Inactive',
                                  totalAlumni == 0
                                      ? Center(
                                          child: Text(
                                              'No data yet',
                                              style: GoogleFonts.inter(
                                                  color: AppColors
                                                      .mutedText)))
                                      : _buildBarChart(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText),
          ),
          const SizedBox(height: 4),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(
            color: AppColors.borderSubtle,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.mutedText),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= monthlyGrowth.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    monthlyGrowth[i]['month'],
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.mutedText),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: monthlyGrowth
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(),
                    e.value['value']))
                .toList(),
            isCurved: true,
            color: AppColors.brandRed,
            barWidth: 3,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.brandRed.withOpacity(0.06),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) =>
                  FlDotCirclePainter(
                radius: 3,
                color: AppColors.brandRed,
                strokeWidth: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: totalAlumni.toDouble() +
            (totalAlumni * 0.15),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod,
                    rodIndex) =>
                BarTooltipItem(
              rod.toY.toInt().toString(),
              GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(
            color: AppColors.borderSubtle,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, m) => Text(
                v.toInt().toString(),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.mutedText),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final labels = ['Active', 'Inactive'];
                final i = v.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[i],
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(
              toY: activeUsers.toDouble(),
              color: Colors.green,
              width: 40,
              borderRadius: BorderRadius.circular(6),
            ),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(
              toY: inactiveUsers.toDouble(),
              color: AppColors.brandRed,
              width: 40,
              borderRadius: BorderRadius.circular(6),
            ),
          ]),
        ],
      ),
    );
  }

  // ─── Sidebar helpers ───
  Widget _sidebarSection(
      String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: AppColors.mutedText.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _sidebarItem(String label,
      {String? route, bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: route != null && !isActive
            ? () => Navigator.pushNamed(context, route)
            : null,
        child: MouseRegion(
          cursor: route != null && !isActive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: isActive
                  ? AppColors.brandRed
                  : AppColors.darkText,
              fontWeight: isActive
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
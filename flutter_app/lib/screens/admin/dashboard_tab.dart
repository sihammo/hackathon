import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/wilayas.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  int _activeView = 0; // 0: Adoption & Ventes, 1: Alertes & Secours, 2: Wilayas
  int _days = 30;
  bool _includeTests = true;

  @override
  Widget build(BuildContext context) {
    final db = context.read<Db>();
    final isArabic = context.watch<LocaleController>().lang == 'ar';

    return StreamBuilder<List<AppUser>>(
      stream: db.allUsers(),
      builder: (context, usersSnap) => StreamBuilder<List<DeviceInfo>>(
        stream: db.allDevices(),
        builder: (context, devSnap) => StreamBuilder<List<AlertModel>>(
          stream: db.allAlerts(),
          builder: (context, alertSnap) {
            if (usersSnap.hasError || devSnap.hasError || alertSnap.hasError) {
              return EmptyState(Icons.error_outline, context.tr('err_generic'));
            }
            if (!usersSnap.hasData || !devSnap.hasData || !alertSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final rawUsers = usersSnap.data!.where((u) => !u.isAdmin).toList();
            final devices = devSnap.data!;
            final alerts = alertSnap.data!.where((a) => _includeTests || !a.testMode).toList();

            // Real dynamic counts from database
            final totalUsersCount = rawUsers.length;
            final totalCarsCount = rawUsers.where((u) => u.vehicleType == VehicleType.car).length;
            final totalMotosCount = rawUsers.where((u) => u.vehicleType == VehicleType.motorcycle).length;
            final onlineCount = devices.where((d) => d.connected).length;
            final coveredWilayas = rawUsers
                .map((u) => u.wilayaCode)
                .where((c) => c > 0 && c <= 58)
                .toSet();

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Top Status Header & Filter View Switcher
                  _viewSwitcher(context, isArabic),
                  const SizedBox(height: 14),

                  if (_activeView == 0) ...[
                    // HERO ADOPTION CARD: Showcase how many users bought & use this tool
                    _heroAdoptionCard(
                      context,
                      totalUsersCount: totalUsersCount,
                      carsCount: totalCarsCount,
                      motosCount: totalMotosCount,
                      onlineCount: onlineCount,
                      coveredWilayasCount: coveredWilayas.length,
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 16),

                    // Sales Growth Chart: month over month adoption curve
                    _salesGrowthCard(context, rawUsers, isArabic),
                    const SizedBox(height: 16),

                    // Live Feed of Recent Buyers / Box Activations
                    _recentActivationsCard(context, rawUsers, devices, isArabic),
                    const SizedBox(height: 16),

                    // Top Wilayas by Users / Tool Adoption
                    _wilayasAdoptionCard(context, rawUsers, isArabic),
                  ] else if (_activeView == 1) ...[
                    // Emergency & Lives Saved Impact View
                    _safetyImpactSummary(context, alerts, isArabic),
                    const SizedBox(height: 16),
                    _alertsSection(context, alerts),
                    const SizedBox(height: 16),
                    _chartSection(context, alerts),
                    const SizedBox(height: 16),
                    _responseSection(context, alerts),
                  ] else ...[
                    // Geographic Wilaya Fleet Details
                    _wilayasAdoptionCard(context, rawUsers, isArabic),
                    const SizedBox(height: 16),
                    _wilayaAlertsSection(context, alerts),
                  ],

                  const SizedBox(height: 12),
                  // Compact Test Mode Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.science_outlined, size: 18, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('include_test_alerts'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Switch(
                          value: _includeTests,
                          onChanged: (v) => setState(() => _includeTests = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ View Switcher
  Widget _viewSwitcher(BuildContext context, bool isArabic) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _switcherTab(0, isArabic ? 'المستخدمون والمبيعات' : 'Utilisateurs & Ventes', Icons.groups_outlined),
          _switcherTab(1, isArabic ? 'التنبيهات والإنقاذ' : 'Alertes & Secours', Icons.emergency_outlined),
          _switcherTab(2, isArabic ? 'الولايات' : 'Wilayas', Icons.map_outlined),
        ],
      ),
    );
  }

  Widget _switcherTab(int index, String title, IconData icon) {
    final active = _activeView == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeView = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? AppColors.brand : Colors.blueGrey),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Hero Adoption Card
  Widget _heroAdoptionCard(
    BuildContext context, {
    required int totalUsersCount,
    required int carsCount,
    required int motosCount,
    required int onlineCount,
    required int coveredWilayasCount,
    required bool isArabic,
  }) {
    final vehicleTotal = carsCount + motosCount;
    final carPercent = vehicleTotal > 0 ? ((carsCount / vehicleTotal) * 100).round() : 0;
    final motoPercent = vehicleTotal > 0 ? ((motosCount / vehicleTotal) * 100).round() : 0;
    final onlinePercent = totalUsersCount > 0 ? ((onlineCount / totalUsersCount) * 100).round() : 0;
    final coveragePercent = ((coveredWilayasCount / 58.0) * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Tag Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isArabic ? 'شبكة سلامتك المباشرة' : 'PARC SLAMTEK EN DIRECT',
                      style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Color(0xFF0284C7), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? 'بيانات حقيقية مباشرة' : 'Base de données réelle',
                      style: const TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Main Big Number Counter
          Text(
            isArabic ? 'إجمالي الأجهزة والمستخدمين المسجلين' : 'CONDUCTEURS PROTÉGÉS PAR LE BOÎTIER',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$totalUsersCount',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                ),
                child: Text(
                  isArabic ? 'مستخدم مسجل' : 'Actifs Réels',
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'عدد المستخدمين المسجلين في النظام والذين يستعملون جهاز إنذار الحوادث سلامتك.'
                : 'Utilisateurs enregistrés équipés du boîtier connecté Slamtek.',
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),

          // Fleet Split Cards (Cars vs Motos vs Live)
          Row(
            children: [
              Expanded(
                child: _fleetPill(
                  icon: Icons.directions_car_rounded,
                  count: '$carsCount',
                  label: isArabic ? 'سيارات ($carPercent%)' : 'Voitures ($carPercent%)',
                  accentColor: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _fleetPill(
                  icon: Icons.two_wheeler_rounded,
                  count: '$motosCount',
                  label: isArabic ? 'دراجات ($motoPercent%)' : 'Motos ($motoPercent%)',
                  accentColor: const Color(0xFFE11D48),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _fleetPill(
                  icon: Icons.wifi_tethering,
                  count: '$onlineCount',
                  label: isArabic ? 'متصل ($onlinePercent%)' : 'En ligne ($onlinePercent%)',
                  accentColor: const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Territory Progress Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF0284C7), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isArabic ? 'تغطية الولايات الوطنية' : 'Couverture du Territoire',
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$coveredWilayasCount / 58 Wilayas ($coveragePercent%)',
                            style: const TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (coveredWilayasCount / 58.0).clamp(0.0, 1.0),
                          minHeight: 6,
                          color: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fleetPill({
    required IconData icon,
    required String count,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Sales Growth Card
  Widget _salesGrowthCard(BuildContext context, List<AppUser> users, bool isArabic) {
    final now = DateTime.now();
    final monthsFr = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'];
    final monthsAr = ['جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان', 'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

    final monthLabels = <String>[];
    final salesCounts = <int>[];

    for (int i = 5; i >= 0; i--) {
      int targetMonth = now.month - i;
      int targetYear = now.year;
      while (targetMonth <= 0) {
        targetMonth += 12;
        targetYear -= 1;
      }
      final endOfMonth = DateTime(targetYear, targetMonth + 1, 1);
      final label = isArabic ? monthsAr[targetMonth - 1] : monthsFr[targetMonth - 1];
      monthLabels.add(label);

      final count = users.where((u) => u.createdAt == null || u.createdAt!.isBefore(endOfMonth)).length;
      salesCounts.add(count);
    }

    final maxVal = salesCounts.fold<int>(0, (m, c) => c > m ? c : m);
    final chartMaxY = maxVal > 0 ? (maxVal * 1.35).ceilToDouble() : 10.0;
    final firstCount = salesCounts.first;
    final lastCount = salesCounts.last;
    final growthStr = firstCount > 0 && lastCount >= firstCount
        ? '+${(((lastCount - firstCount) / firstCount) * 100).round()}%'
        : '+$lastCount';

    return SectionCard(
      title: isArabic ? 'نمو مبيعات الجهاز والمستخدمين' : 'Croissance des Ventes du Boîtier Slamtek',
      icon: Icons.auto_graph,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'تطور عدد الأجهزة المباعة شهرياً' : 'Évolution cumulée des boîtiers vendus',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  growthStr,
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: BarChart(
                BarChartData(
                  maxY: chartMaxY,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (v, meta) {
                          if (v == 0 || v == (chartMaxY / 2).round() || v == chartMaxY.round()) {
                            return Text('${v.toInt()}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i >= 0 && i < monthLabels.length) {
                            return Text(monthLabels[i],
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < salesCounts.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: salesCounts[i].toDouble(),
                            width: 22,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            gradient: LinearGradient(
                              colors: i == salesCounts.length - 1
                                  ? [const Color(0xFF0284C7), const Color(0xFF38BDF8)]
                                  : [const Color(0xFF334155), const Color(0xFF64748B)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'إجمالي المستخدمين المسجلين في النظام: ${users.length} مستخدم.'
                : 'Total réel de ${users.length} conducteurs enregistrés dans la base de données.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Recent Buyers Feed
  Widget _recentActivationsCard(
    BuildContext context,
    List<AppUser> users,
    List<DeviceInfo> devices,
    bool isArabic,
  ) {
    final sortedUsers = List<AppUser>.from(users)
      ..sort((a, b) => (b.createdAt ?? DateTime(2020)).compareTo(a.createdAt ?? DateTime(2020)));
    final displayUsers = sortedUsers.take(6).toList();

    return SectionCard(
      title: isArabic ? 'آخر المستخدمين الذين اشتروا وفعلوا الجهاز' : 'Derniers Utilisateurs Ayant Activé le Boîtier',
      icon: Icons.history_edu_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (displayUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  isArabic ? 'لا يوجد مستخدمون مسجلون حالياً' : 'Aucun utilisateur enregistré pour le moment',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            for (final u in displayUsers) ...[
              Builder(
                builder: (context) {
                  final dev = devices.where((d) => d.userId == u.uid).firstOrNull;
                  final wilaya = Wilayas.byCode(u.wilayaCode);
                  final wilayaName = isArabic ? (wilaya?.nameAr ?? '') : (wilaya?.nameFr ?? '');
                  final wilayaLabel = '${u.wilayaCode.toString().padLeft(2, '0')} - $wilayaName';
                  final isMoto = u.vehicleType == VehicleType.motorcycle;
                  final vehicleName = isMoto
                      ? (isArabic ? 'دراجة نارية' : 'Moto')
                      : (isArabic ? 'سيارة' : 'Voiture');
                  final devId = dev?.id ?? 'SOLVEX-${u.uid.substring(0, u.uid.length.clamp(0, 4)).toUpperCase()}';
                  final isOnline = dev?.connected ?? false;

                  String timeAgo = '';
                  if (u.createdAt != null) {
                    final diff = DateTime.now().difference(u.createdAt!);
                    if (diff.inMinutes < 60) {
                      timeAgo = isArabic ? 'منذ ${diff.inMinutes} د' : 'Il y a ${diff.inMinutes} min';
                    } else if (diff.inHours < 24) {
                      timeAgo = isArabic ? 'منذ ${diff.inHours} سا' : 'Il y a ${diff.inHours}h';
                    } else {
                      timeAgo = isArabic ? 'منذ ${diff.inDays} يوم' : 'Il y a ${diff.inDays}j';
                    }
                  } else {
                    timeAgo = isArabic ? 'حديثاً' : 'Récemment';
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF0F172A),
                          child: Icon(
                            isMoto ? Icons.two_wheeler : Icons.directions_car,
                            color: const Color(0xFF38BDF8),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    u.fullName.isNotEmpty ? u.fullName : u.username,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: (isOnline ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isOnline
                                          ? (isArabic ? 'متصل' : 'Actif')
                                          : (isArabic ? 'غير متصل' : 'Veille'),
                                      style: TextStyle(
                                        color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$wilayaLabel • $vehicleName',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              devId,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeAgo,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (u != displayUsers.last) const Divider(height: 12),
            ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Wilayas Adoption Card
  Widget _wilayasAdoptionCard(BuildContext context, List<AppUser> users, bool isArabic) {
    final counts = <int, int>{};
    for (final u in users) {
      if (u.wilayaCode > 0 && u.wilayaCode <= 58) {
        counts[u.wilayaCode] = (counts[u.wilayaCode] ?? 0) + 1;
      }
    }

    final total = users.isNotEmpty ? users.length : 1;
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topWilayas = sortedEntries.take(8).map((e) {
      final w = Wilayas.byCode(e.key);
      final codeStr = e.key.toString().padLeft(2, '0');
      final name = isArabic ? (w?.nameAr ?? '') : (w?.nameFr ?? '');
      final ratio = e.value / total;
      return ('$codeStr - $name', e.value, ratio);
    }).toList();

    if (sortedEntries.length > 8) {
      final otherCount = sortedEntries.skip(8).fold<int>(0, (sum, e) => sum + e.value);
      topWilayas.add((
        isArabic ? 'ولايات أخرى (${sortedEntries.length - 8})' : 'Autres (${sortedEntries.length - 8} Wilayas)',
        otherCount,
        otherCount / total,
      ));
    }

    return SectionCard(
      title: isArabic ? 'توزيع المستخدمين حسب الولايات' : 'Top Wilayas par Nombre d\'Utilisateurs',
      icon: Icons.pin_drop_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topWilayas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  isArabic ? 'لا توجد بيانات ولايات حالياً' : 'Aucune donnée de wilaya disponible',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            for (final w in topWilayas) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        w.$1,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: w.$3.clamp(0.0, 1.0),
                          minHeight: 10,
                          color: AppColors.brand,
                          backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 58,
                      child: Text(
                        '${w.$2} (${(w.$3 * 100).toInt()}%)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Safety & Lives Saved Summary
  Widget _safetyImpactSummary(BuildContext context, List<AlertModel> alerts, bool isArabic) {
    final totalAlerts = alerts.length;
    final resolvedCount = alerts.where((a) => a.status == AlertStatus.resolved).length;

    int arrivedCount = 0;
    int totalArrivalSeconds = 0;
    for (final a in alerts) {
      final sent = a.statusTimestamps[AlertStatus.sent] ?? a.createdAt;
      final arrived = a.statusTimestamps[AlertStatus.arrived];
      if (sent != null && arrived != null && arrived.isAfter(sent)) {
        arrivedCount++;
        totalArrivalSeconds += arrived.difference(sent).inSeconds;
      }
    }

    String arrivalDelayStr;
    if (arrivedCount > 0) {
      final avgSec = totalArrivalSeconds ~/ arrivedCount;
      final mins = avgSec ~/ 60;
      final secs = avgSec % 60;
      arrivalDelayStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    } else {
      arrivalDelayStr = isArabic ? 'فوري' : '< 5 min';
    }

    final resolutionRateStr = totalAlerts > 0
        ? '${((resolvedCount / totalAlerts) * 100).round()}%'
        : '100%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.health_and_safety, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'الحصيلة المباشرة لحماية الأرواح' : 'IMPACT SÉCURITÉ ROUTIÈRE SLAMTEK',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic
                          ? '$totalAlerts تنبيهاً مسجلاً في النظام'
                          : '$totalAlerts alertes enregistrées dans le système',
                      style: TextStyle(color: Colors.red.shade900, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricTile(
                '$totalAlerts',
                isArabic ? 'تنبيهات مسجلة' : 'Secours Alertés',
                const Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              _metricTile(
                arrivalDelayStr,
                isArabic ? 'متوسط التدخل' : 'Délai d\'arrivée',
                const Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              _metricTile(
                resolutionRateStr,
                isArabic ? 'نسبة المعالجة' : 'Résolution',
                const Color(0xFF2563EB),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)), maxLines: 1),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Alerts & Existing Charts
  Widget _alertsSection(BuildContext context, List<AlertModel> alerts) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    int since(Duration d) =>
        alerts.where((a) => a.createdAt != null && now.difference(a.createdAt!) < d).length;
    final today = alerts.where((a) => a.createdAt != null && a.createdAt!.isAfter(midnight)).length;
    final cancelled = alerts.where((a) => a.isCancelled).length;
    final byStatus = <String, int>{};
    for (final a in alerts) {
      byStatus[a.status] = (byStatus[a.status] ?? 0) + 1;
    }
    return SectionCard(
      title: context.tr('alerts'),
      icon: Icons.notifications_active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatGrid([
            _Stat(context.tr('today'), '$today', Icons.today, color: AppColors.brand),
            _Stat(context.tr('last_7d'), '${since(const Duration(days: 7))}', Icons.date_range),
            _Stat(context.tr('last_30d'), '${since(const Duration(days: 30))}', Icons.calendar_month),
            _Stat(context.tr('total'), '${alerts.length}', Icons.all_inclusive),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in AlertStatus.all)
                Chip(
                  avatar: CircleAvatar(backgroundColor: AppColors.forStatus(s), radius: 6),
                  label: Text('${context.tr('status_$s')}: ${byStatus[s] ?? 0}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${context.tr('cancelled_by_user')}: $cancelled',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _chartSection(BuildContext context, List<AlertModel> alerts) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: _days - 1));
    final sent = List<int>.filled(_days, 0);
    final cancelled = List<int>.filled(_days, 0);
    for (final a in alerts) {
      final d = a.createdAt;
      if (d == null || d.isBefore(start)) continue;
      final i = DateTime(d.year, d.month, d.day).difference(start).inDays;
      if (i < 0 || i >= _days) continue;
      if (a.isCancelled) {
        cancelled[i]++;
      } else {
        sent[i]++;
      }
    }
    var maxY = 0;
    for (var i = 0; i < _days; i++) {
      if (sent[i] + cancelled[i] > maxY) maxY = sent[i] + cancelled[i];
    }
    final labelEvery = _days <= 7 ? 1 : (_days <= 30 ? 5 : 15);

    return SectionCard(
      title: context.tr('alerts_over_time'),
      icon: Icons.bar_chart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 7, label: Text('7 ${context.tr('days')}')),
              ButtonSegment(value: 30, label: Text('30 ${context.tr('days')}')),
              ButtonSegment(value: 90, label: Text('90 ${context.tr('days')}')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: BarChart(
                BarChartData(
                  maxY: (maxY < 4 ? 4 : maxY + 1).toDouble(),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, meta) => v == v.roundToDouble()
                            ? Text(v.toInt().toString(), style: const TextStyle(fontSize: 10))
                            : const SizedBox.shrink(),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i % labelEvery != 0 && i != _days - 1) return const SizedBox.shrink();
                          return Text(formatDate(start.add(Duration(days: i))),
                              style: const TextStyle(fontSize: 9));
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < _days; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (sent[i] + cancelled[i]).toDouble(),
                            width: _days <= 7 ? 18 : (_days <= 30 ? 6 : 2.5),
                            borderRadius: BorderRadius.circular(2),
                            color: AppColors.brand,
                            rodStackItems: [
                              BarChartRodStackItem(0, sent[i].toDouble(), AppColors.brand),
                              BarChartRodStackItem(sent[i].toDouble(),
                                  (sent[i] + cancelled[i]).toDouble(), Colors.grey),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppColors.brand, context.tr('status_sent')),
              const SizedBox(width: 16),
              _legend(Colors.grey, context.tr('status_cancelled')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wilayaAlertsSection(BuildContext context, List<AlertModel> alerts) {
    final counts = <int, int>{};
    for (final a in alerts.where((a) => !a.isCancelled)) {
      counts[a.wilayaCode] = (counts[a.wilayaCode] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final shown = entries.take(10).toList();
    final max = entries.isEmpty ? 1 : entries.first.value;
    final lang = context.lang;

    return SectionCard(
      title: context.tr('alerts_by_wilaya'),
      icon: Icons.location_city,
      child: entries.isEmpty
          ? Text(context.tr('no_alerts'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(Wilayas.byCode(e.key)?.label(lang) ?? '${e.key}',
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: e.value / max,
                              minHeight: 12,
                              color: AppColors.brand,
                              backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        SizedBox(width: 36, child: Text(' ${e.value}', textAlign: TextAlign.end)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _responseSection(BuildContext context, List<AlertModel> alerts) {
    final global = {for (final s in EmergencyServiceType.all) s: <Duration>[]};
    final perWilaya = <int, Map<String, List<Duration>>>{};
    for (final a in alerts.where((a) => !a.isCancelled)) {
      for (final s in EmergencyServiceType.all) {
        final rt = a.response(s).responseTime(a.createdAt);
        if (rt == null) continue;
        global[s]!.add(rt);
        perWilaya
            .putIfAbsent(a.wilayaCode, () => {for (final x in EmergencyServiceType.all) x: <Duration>[]})[s]!
            .add(rt);
      }
    }
    Duration? avg(List<Duration> l) => l.isEmpty
        ? null
        : Duration(seconds: l.map((d) => d.inSeconds).reduce((a, b) => a + b) ~/ l.length);

    final lang = context.lang;
    final rows = perWilaya.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return SectionCard(
      title: context.tr('response_times'),
      icon: Icons.timer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatGrid([
            _Stat(context.tr('police'), formatDuration(avg(global[EmergencyServiceType.police]!)),
                Icons.local_police),
            _Stat(context.tr('civil_protection'),
                formatDuration(avg(global[EmergencyServiceType.civil]!)), Icons.fire_truck),
          ]),
          const SizedBox(height: 4),
          Text(context.tr('response_time_desc'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(context.tr('no_response_data'))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: [
                  DataColumn(label: Text(context.tr('wilaya'))),
                  DataColumn(label: Text(context.tr('police'))),
                  DataColumn(label: Text(context.tr('civil_protection'))),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(Text(Wilayas.byCode(r.key)?.label(lang) ?? '${r.key}')),
                      DataCell(Text(formatDuration(avg(r.value[EmergencyServiceType.police]!)))),
                      DataCell(Text(formatDuration(avg(r.value[EmergencyServiceType.civil]!)))),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, color: c),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _Stat(this.label, this.value, this.icon, {this.color});
}

class _StatGrid extends StatelessWidget {
  final List<_Stat> stats;
  const _StatGrid(this.stats);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 600 ? 4 : 2;
      final w = (c.maxWidth - (perRow - 1) * 8) / perRow;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in stats)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(s.icon, color: s.color ?? Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.value,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(s.label,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

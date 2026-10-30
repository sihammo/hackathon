import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/wilayas.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/ble_service.dart';
import '../../services/db.dart';
import '../../services/emergency_service.dart';
import '../../services/location_service.dart';
import '../../services/safe_route_service.dart';
import '../../services/voice_service.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/common.dart';
import '../common/hotspot_map.dart';
import 'device_scan_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool? _permsOk;
  Wilaya? _detected;
  bool _detectDismissed = false;
  late final MapController _dashboardMapController = MapController();
  SafeDestination _selectedDestination = SafeRouteService.destinations.first;

  void _selectDestination(SafeDestination dest, bool isArabic) {
    setState(() => _selectedDestination = dest);
    final target = dest.targetLocation;
    try {
      _dashboardMapController.move(
        LatLng((36.7510 + target.latitude) / 2, (3.0555 + target.longitude) / 2),
        12.2,
      );
    } catch (_) {}
    VoiceService.speakSafeRouteSelected(
      destination: isArabic ? dest.nameAr : dest.name,
      blackPointsAvoided: dest.safeRoute.blackPointsAvoided,
      isArabic: isArabic,
    );
  }

  @override
  void initState() {
    super.initState();
    _checkPerms();
    _detectWilaya();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final hotspots = await context.read<Db>().allHotspots().first;
        if (mounted) {
          final isAr = context.read<LocaleController>().lang == 'ar';
          context.read<LocationService>().checkProximity(hotspots, isArabic: isAr);
        }
      } catch (_) {}
    });
  }

  /// Auto-detects the wilaya from GPS and suggests it if it differs.
  Future<void> _detectWilaya() async {
    final w = await context.read<LocationService>().detectWilaya();
    if (mounted && w != null) setState(() => _detected = w);
  }

  Future<void> _checkPerms() async {
    final ok = await context.read<EmergencyService>().hasAllPermissions();
    if (mounted) setState(() => _permsOk = ok);
  }

  Future<void> _requestPerms() async {
    await context.read<EmergencyService>().requestPermissions();
    await _checkPerms();
  }

  Future<void> _setVehicle(AppUser user, VehicleType v) async {
    final session = context.read<SessionController>();
    final ble = context.read<BleService>();
    ble.vehicleType = v;
    await session.updateUser({'vehicleType': v.id});
    final sent = await ble.sendVehicleType(v);
    if (mounted) {
      if (ble.isConnected) {
        showSnack(context, context.tr(sent ? 'vehicle_sent' : 'vehicle_not_sent'));
      } else {
        final isAr = context.read<LocaleController>().lang == 'ar';
        showSnack(
          context,
          isAr
              ? 'تم ضبط وضع: ${v == VehicleType.car ? "سيارة" : "دراجة نارية 🏍️"}'
              : 'Mode activé: ${v == VehicleType.car ? "Voiture 🚗" : "Moto 🏍️"}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user!;
    final ble = context.watch<BleService>();
    final db = context.read<Db>();
    final locService = context.watch<LocationService>();
    final isArabic = context.watch<LocaleController>().lang == 'ar';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Row(
          children: [
            Tooltip(
              message: isArabic ? 'اضغط لتغيير صورتك' : 'Cliquer pour changer votre photo',
              child: InkWell(
                onTap: () => showAvatarPicker(context),
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.6), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: getUserAvatarProvider(user.effectiveAvatar),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.ok,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${context.tr('hello')} 👋',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.ok.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Actif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ok,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<AppConfig>(
        stream: db.config(),
        builder: (context, cfgSnap) {
          final cfg = cfgSnap.data ?? AppConfig.defaults;
          final testMode = EmergencyService.isTestMode(user, cfg);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (testMode) ...[
                InfoBanner(
                  context.tr('test_mode_banner'),
                  icon: Icons.science_outlined,
                ),
                const SizedBox(height: 12),
              ],
              if (_permsOk == false) ...[
                SectionCard(
                  title: context.tr('permissions_needed'),
                  icon: Icons.privacy_tip_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.tr('permissions_desc')),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _requestPerms,
                        child: Text(context.tr('grant_permissions')),
                      ),
                    ],
                  ),
                ),
              ],
              if (_detected != null && _detected!.code != user.wilayaCode && !_detectDismissed)
                SectionCard(
                  title: context.tr('wilaya_detected'),
                  icon: Icons.my_location,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context
                          .tr('wilaya_detected_desc')
                          .replaceAll('{w}', _detected!.label(context.lang))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () async {
                                await db.updateUser(user.uid, {'wilayaCode': _detected!.code});
                              },
                              child: Text(context.tr('use_this_wilaya')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _detectDismissed = true),
                            child: Text(context.tr('ignore')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              _blackPointAlertBanner(context, locService, isArabic),
              _deviceCard(context, ble),
              _vehicleCard(context, user),
              _trikSureCard(context, isArabic),
              _dashboardMapCard(context, locService, db, isArabic),
              _wilayaCard(context, user, db, testMode, cfg),
              if (testMode)
                SectionCard(
                  title: context.tr('test_tools'),
                  icon: Icons.science_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                        onPressed: () => ble.simulateAccident(),
                        icon: const Icon(Icons.car_crash),
                        label: Text(context.tr('simulate_accident')),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: ble.isConnected
                            ? () async {
                                final ok = await ble.sendTestAlert();
                                if (context.mounted && !ok) {
                                  showSnack(context, context.tr('device_not_connected'));
                                }
                              }
                            : null,
                        icon: const Icon(Icons.bluetooth),
                        label: Text(context.tr('device_test_alert')),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Photo 1: Trik Sûre Safe Route Card placed directly under Photo 2 (Vehicle Card).
  Widget _trikSureCard(BuildContext context, bool isArabic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF044E36), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF044E36).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: shield icon in circle + title & description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isArabic
                                ? 'تريك سورة : مسار بدون حوادث'
                                : 'TRIK SÛRE : ITINÉRAIRE SANS ACCIDENTS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic
                          ? 'تطبيق SolveX يرسم لك مساراً يتفادى مناطق الحوادث المتكررة'
                          : 'SolveX vous guide sur la route évitant les zones d\'accidents récurrents',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sub-heading
          Text(
            isArabic
                ? 'مسارات جاهزة لتفادي النقاط السوداء :'
                : 'Itinéraires pré-calculés sans points noirs :',
            style: const TextStyle(
              color: Color(0xFFF1F5F9),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          // Horizontal scroll of pre-calculated destination chips matching Photo 1
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final d in SafeRouteService.destinations) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          VoiceService.speakSafeRouteSelected(
                            destination: isArabic ? d.nameAr : d.name,
                            blackPointsAvoided: d.safeRoute.blackPointsAvoided,
                            isArabic: isArabic,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HotspotMapPage(
                                title: context.tr('nav_map'),
                                initialDestinationId: d.id,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(d.icon, size: 17, color: const Color(0xFF047857)),
                              const SizedBox(width: 8),
                              Text(
                                isArabic
                                    ? d.nameAr.split('(').first.trim()
                                    : (d.id == 'aeroport'
                                        ? "Aéroport d'Alger Houari Boumediene"
                                        : d.name.split('(').first.trim()),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Primary Button matching Photo 1 exactly
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF064E3B),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                VoiceService.speakSafeRouteSelected(
                  destination: isArabic ? 'مطار هواري بومدين' : 'Aéroport d\'Alger',
                  blackPointsAvoided: 3,
                  isArabic: isArabic,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HotspotMapPage(
                      title: context.tr('nav_map'),
                      initialDestinationId: 'aeroport',
                    ),
                  ),
                );
              },
              child: Text(
                isArabic ? 'فتح الخريطة والإرشاد الآمن' : 'Ouvrir la Carte & Guidage Sécurisé',
                style: const TextStyle(
                  color: Color(0xFF064E3B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardMapCard(
      BuildContext context, LocationService locService, Db db, bool isArabic) {
    final near = locService.isNearBlackPoint;
    final dist = locService.distanceMeters.toInt();
    final userLoc = LatLng(locService.userLocation.lat, locService.userLocation.lng);
    final safe = _selectedDestination.safeRoute;

    final polylines = [
      Polyline(
        points: safe.points,
        strokeWidth: 9.0,
        color: const Color(0xFF10B981).withValues(alpha: 0.35),
      ),
      Polyline(
        points: safe.points,
        strokeWidth: 5.0,
        color: const Color(0xFF10B981),
      ),
    ];

    final destMarker = Marker(
      point: _selectedDestination.targetLocation,
      width: 38,
      height: 38,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF10B981), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
      ),
    );

    return StreamBuilder<List<Hotspot>>(
      stream: db.allHotspots(),
      builder: (context, snap) {
        final hotspots = snap.data ?? const <Hotspot>[];
        final pts = hotspots.map((h) => LatLng(h.lat, h.lng)).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: near ? Colors.redAccent : const Color(0xFFE2E8F0),
              width: near ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (near ? Colors.red : Colors.black).withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (near ? Colors.red : const Color(0xFF10B981)).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        near ? Icons.warning_amber_rounded : Icons.shield_rounded,
                        color: near ? Colors.red : const Color(0xFF059669),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'خريطة النقاط السوداء والمسار الآمن' : 'Carte & Itinéraire Sécurisé (Trik Sûre)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            near
                                ? (isArabic ? '⚠️ تنبيه: اقتراب من نقطة حوادث سابقة ($dist م)' : '⚠️ Point noir à proximité ($dist m)')
                                : (isArabic ? '🛡️ مسار آمن يتفادى الحوادث (98% أمان)' : '🛡️ Trajet optimisé sans points noirs'),
                            style: TextStyle(
                              fontSize: 11,
                              color: near ? Colors.red : const Color(0xFF059669),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isArabic ? 'تكبير الخريطة' : 'Agrandir la carte',
                      icon: const Icon(Icons.open_in_full, size: 18),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HotspotMapPage(
                              title: context.tr('nav_map'),
                              initialDestinationId: _selectedDestination.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Embedded Live Map
              Container(
                height: 250,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      AccidentMap(
                        mapController: _dashboardMapController,
                        points: pts,
                        userLocation: userLoc,
                        isNearBlackPoint: near,
                        center: userLoc,
                        zoom: 12.5,
                        polylines: polylines,
                        additionalMarkers: [destMarker],
                      ),
                      // Top Left Safe Route pill
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isArabic
                                    ? 'مسار آمن: ${_selectedDestination.safeRoute.blackPointsAvoided} نقاط متفاداة'
                                    : 'Trik Sûre: ${_selectedDestination.safeRoute.blackPointsAvoided} évités',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Recenter button
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: FloatingActionButton.small(
                          heroTag: 'recenter_dash_map',
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          tooltip: isArabic ? 'موقعي' : 'Ma position',
                          child: const Icon(Icons.my_location, size: 18),
                          onPressed: () {
                            _dashboardMapController.move(userLoc, 13.5);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Destination selector chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'اختر الوجهة لعرض المسار الآمن :' : 'Choisissez une destination sécurisée :',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final d in SafeRouteService.destinations) ...[
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                avatar: Icon(
                                  d.icon,
                                  size: 15,
                                  color: _selectedDestination.id == d.id ? Colors.white : const Color(0xFF047857),
                                ),
                                label: Text(
                                  isArabic ? d.nameAr.split('(').first.trim() : d.name.split('(').first.trim(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _selectedDestination.id == d.id ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                selected: _selectedDestination.id == d.id,
                                selectedColor: const Color(0xFF047857),
                                labelStyle: TextStyle(
                                  color: _selectedDestination.id == d.id ? Colors.white : const Color(0xFF0F172A),
                                ),
                                onSelected: (sel) {
                                  if (sel) _selectDestination(d, isArabic);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Simulation testing buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: near ? Colors.red : Colors.black87,
                          side: BorderSide(
                            color: near ? Colors.red : const Color(0xFFCBD5E1),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.car_crash, size: 15),
                        label: Text(
                          isArabic ? 'اقتراب من نقطة سوداء' : 'Simuler Point Noir',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          locService.simulateMoveNearBlackPoint(hotspots, isArabic: isArabic);
                          try {
                            _dashboardMapController.move(
                              LatLng(locService.userLocation.lat, locService.userLocation.lng),
                              14.5,
                            );
                          } catch (_) {}
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal.shade800,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.shield_outlined, size: 15),
                        label: Text(
                          isArabic ? 'منطقة آمنة' : 'Zone Sûre',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          locService.simulateMoveToSafeZone(hotspots);
                          try {
                            _dashboardMapController.move(
                              LatLng(locService.userLocation.lat, locService.userLocation.lng),
                              12.5,
                            );
                          } catch (_) {}
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Action buttons (Open full map + Voice guidance test)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.navigation_outlined, size: 17),
                        label: Text(
                          isArabic ? 'فتح الخريطة الكاملة وتفاصيل المسار' : 'Ouvrir la Carte Plein Écran',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HotspotMapPage(
                                title: context.tr('nav_map'),
                                initialDestinationId: _selectedDestination.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: isArabic ? 'استماع للتنبيه الصوتي' : 'Écouter l\'alerte vocale',
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(11),
                      ),
                      icon: const Icon(Icons.volume_up, size: 19),
                      onPressed: () => locService.speakCurrentWarning(isArabic: isArabic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blackPointAlertBanner(BuildContext context, LocationService locService, bool isArabic) {
    if (!locService.isNearBlackPoint) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.25),
            blurRadius: 14,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? '⚠️ تنبيه: اقتراب من منطقة حوادث سابقة' : '⚠️ ALERTE : POINT NOIR IMMINENT',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic ? 'نقطة سوداء (وقع فيها حادث سابقاً)' : 'Zone à risque élevé d\'accident',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'أنت على بعد ${locService.distanceMeters.toInt()}م من موقع وقع فيه حادث سابقاً. خفف سرعتك وكن حذراً!'
                          : 'Vous êtes à ${locService.distanceMeters.toInt()}m d\'un lieu où un accident a déjà eu lieu auparavant. Ralentissez immédiatement !',
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: Text(
                      isArabic ? 'استماع للتنبيه الصوتي' : 'Écouter l\'alerte vocale',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => locService.speakCurrentWarning(isArabic: isArabic),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.map, size: 18),
                  label: Text(isArabic ? 'الخريطة' : 'Carte'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HotspotMapPage(title: context.tr('nav_map')),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceCard(BuildContext context, BleService ble) {
    final connected = ble.link == DeviceLink.connected;
    final connecting = ble.link == DeviceLink.connecting;
    final color = connected ? AppColors.ok : (connecting ? AppColors.warn : AppColors.brand);
    final st = ble.status;

    return SectionCard(
      title: context.tr('device'),
      icon: Icons.sensors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              children: [
                Icon(
                  connected
                      ? Icons.bluetooth_connected
                      : (connecting ? Icons.bluetooth_searching : Icons.bluetooth_disabled),
                  color: color,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(connected
                            ? 'connected'
                            : (connecting ? 'connecting' : 'disconnected')),
                        style: TextStyle(
                            color: color, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (ble.pairedId != null)
                        Text(ble.pairedName,
                            style: Theme.of(context).textTheme.bodySmall),
                      if (connected && st != null)
                        Text(
                          st.gpsFix
                              ? '${context.tr('gps_fix')} (${st.satellites ?? 0} sat)'
                              : context.tr('gps_no_fix'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
                  ),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: Text(context.tr(ble.pairedId == null ? 'pair_device' : 'change_device')),
                ),
              ),
              if (ble.pairedId != null) ...[
                const SizedBox(width: 8),
                if (connected)
                  IconButton.outlined(
                    tooltip: context.tr('calibrate'),
                    onPressed: () async {
                      final ok = await ble.calibrate();
                      if (context.mounted) {
                        showSnack(context, context.tr(ok ? 'calibrated' : 'device_not_connected'));
                      }
                    },
                    icon: const Icon(Icons.straighten),
                  )
                else
                  IconButton.outlined(
                    tooltip: context.tr('reconnect'),
                    onPressed: connecting ? null : () => ble.restore(),
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleCard(BuildContext context, AppUser user) {
    final isMoto = user.vehicleType == VehicleType.motorcycle;
    return SectionCard(
      title: context.tr('vehicle_type'),
      icon: isMoto ? Icons.two_wheeler : Icons.directions_car_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<VehicleType>(
            style: const ButtonStyle(
              visualDensity: VisualDensity.comfortable,
            ),
            segments: [
              ButtonSegment(
                value: VehicleType.car,
                icon: const Icon(Icons.directions_car),
                label: Text(context.tr('car')),
              ),
              ButtonSegment(
                value: VehicleType.motorcycle,
                icon: const Icon(Icons.two_wheeler),
                label: Text(context.tr('motorcycle')),
              ),
            ],
            selected: {user.vehicleType},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) {
                _setVehicle(user, s.first);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(isMoto ? 'moto_desc' : 'car_desc'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isMoto ? AppColors.brand : null,
                ),
          ),
        ],
      ),
    );
  }

  Widget _wilayaCard(
      BuildContext context, AppUser user, Db db, bool testMode, AppConfig cfg) {
    final lang = context.lang;
    return SectionCard(
      title: context.tr('emergency_numbers'),
      icon: Icons.local_police_outlined,
      child: StreamBuilder<WilayaNumbers?>(
        stream: db.wilayaNumbersOf(user.wilayaCode),
        builder: (context, snap) {
          final n = snap.data;
          final testNum = EmergencyService.testNumber(user, cfg);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(context.tr('wilaya'), Wilayas.byCode(user.wilayaCode)?.label(lang) ?? '—',
                  icon: Icons.location_city),
              InfoRow(context.tr('police'), n?.police.isNotEmpty == true ? n!.police : '—',
                  icon: Icons.local_police),
              InfoRow(context.tr('civil_protection'),
                  n?.civilProtection.isNotEmpty == true ? n!.civilProtection : '—',
                  icon: Icons.fire_truck),
              if (testMode) ...[
                const Divider(),
                InfoRow(context.tr('test_number'), testNum.isEmpty ? context.tr('not_set') : testNum,
                    icon: Icons.science),
                Text(context.tr('test_mode_replaces'),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              if (n == null && snap.connectionState == ConnectionState.active)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(context.tr('numbers_not_configured'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 4),
              Text(context.tr('wilaya_auto_note'), style: Theme.of(context).textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}

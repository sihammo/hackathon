import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/db.dart';
import '../../services/location_service.dart';
import '../../services/safe_route_service.dart';
import '../../services/voice_service.dart';

/// Map displaying accident black points (hotspots), live user position,
/// and calculated Safe Routes ("Trik Sûre") avoiding accident-prone areas.
class AccidentMap extends StatelessWidget {
  final List<LatLng> points;
  final LatLng? center;
  final double zoom;
  final LatLng? highlight;
  final LatLng? userLocation;
  final bool isNearBlackPoint;
  final double dotSize;
  final MapController? mapController;
  final List<Polyline>? polylines;
  final List<Marker>? additionalMarkers;
  final void Function(TapPosition tapPosition, LatLng latLng)? onTap;

  const AccidentMap({
    super.key,
    required this.points,
    this.center,
    this.zoom = 13,
    this.highlight,
    this.userLocation,
    this.isNearBlackPoint = false,
    this.dotSize = 22,
    this.mapController,
    this.polylines,
    this.additionalMarkers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveCenter = center ??
        userLocation ??
        (points.isNotEmpty ? points.first : const LatLng(AppConstants.algeriaLat, AppConstants.algeriaLng));

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: effectiveCenter,
        initialZoom: zoom,
        onTap: onTap,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          fallbackUrl: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.solvex.solvex_alert',
        ),
        if (polylines != null && polylines!.isNotEmpty)
          PolylineLayer(polylines: polylines!),
        CircleLayer(
          circles: [
            for (final p in points)
              CircleMarker(
                point: p,
                radius: 45,
                color: Colors.red.withValues(alpha: 0.2),
                borderColor: Colors.redAccent,
                borderStrokeWidth: 2,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Accident Black Points (Points Noirs)
            for (final p in points)
              Marker(
                point: p,
                width: dotSize + 14,
                height: dotSize + 14,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                  ),
                ),
              ),

            // User Live Location Marker (Blue Pulsing Radar)
            if (userLocation != null)
              Marker(
                point: userLocation!,
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isNearBlackPoint ? Colors.red : Colors.blue).withValues(alpha: 0.25),
                        border: Border.all(
                          color: isNearBlackPoint ? Colors.redAccent : Colors.blueAccent,
                          width: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isNearBlackPoint ? Colors.red : Colors.blueAccent,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.navigation, color: Colors.white, size: 11),
                      ),
                    ),
                  ],
                ),
              ),

            // Highlighted point if specified
            if (highlight != null)
              Marker(
                point: highlight!,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, color: AppColors.brand, size: 44),
              ),

            // Additional markers (destinations, route points)
            if (additionalMarkers != null) ...additionalMarkers!,
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

/// Full interactive Map Page with Safe Route Planner ("Trik Sûre"),
/// proximity black point warning, live user location, and voice alerts.
class HotspotMapPage extends StatefulWidget {
  final String title;
  final String? initialDestinationId;

  const HotspotMapPage({super.key, required this.title, this.initialDestinationId});

  @override
  State<HotspotMapPage> createState() => _HotspotMapPageState();
}

class _HotspotMapPageState extends State<HotspotMapPage> {
  late final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  SafeDestination? _activeDestination;
  bool _useSafeRoute = true;
  bool _showBothRoutes = true;
  String _searchQuery = '';
  bool _isSearching = false;

  // Active Navigation Simulation state
  bool _isNavigating = false;
  int _navStep = 0;
  Timer? _navTimer;
  LatLng? _navVehiclePos;
  double _navSpeedKmH = 68.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialDestinationId != null) {
      _activeDestination = SafeRouteService.destinations.firstWhere(
        (d) => d.id == widget.initialDestinationId,
        orElse: () => SafeRouteService.destinations.first,
      );
      _searchCtrl.text = _activeDestination!.name;
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _selectDestination(SafeDestination dest, {bool announceVoice = true}) {
    _stopNavigation();
    setState(() {
      _activeDestination = dest;
      _useSafeRoute = true;
      _isSearching = false;
      _searchCtrl.text = dest.name;
    });

    // Center map between departure and destination
    final target = dest.targetLocation;
    _mapController.move(
      LatLng((36.7510 + target.latitude) / 2, (3.0555 + target.longitude) / 2),
      12.0,
    );

    if (announceVoice) {
      final isAr = context.read<LocaleController>().lang == 'ar';
      VoiceService.speakSafeRouteSelected(
        destination: isAr ? dest.nameAr : dest.name,
        blackPointsAvoided: dest.safeRoute.blackPointsAvoided,
        isArabic: isAr,
      );
    }
  }

  /// Calculates a route dynamically when the user taps anywhere on the map!
  void _setDestinationFromTap(LatLng tappedPoint, LatLng userLoc, bool isArabic) async {
    if (_isNavigating) return;

    // 1. Instant baseline route (zero waiting time)
    final customDest = SafeRouteService.calculateCustomDestination(
      start: userLoc,
      destination: tappedPoint,
    );
    _selectDestination(customDest, announceVoice: true);

    // 2. Asynchronously enhance with exact 100% road-following OSRM geometry
    try {
      final enhanced = await SafeRouteService.calculateCustomDestinationAsync(
        start: userLoc,
        destination: tappedPoint,
      );
      if (mounted && _activeDestination?.id == customDest.id) {
        setState(() {
          _activeDestination = enhanced;
        });
      }
    } catch (_) {}
  }

  /// Starts live turn-by-turn navigation simulation along the safe route!
  void _startNavigation() {
    if (_activeDestination == null) return;
    final points = _activeDestination!.safeRoute.points;
    if (points.isEmpty) return;

    setState(() {
      _isNavigating = true;
      _navStep = 0;
      _navVehiclePos = points.first;
      _useSafeRoute = true;
      _isSearching = false;
    });

    final isAr = context.read<LocaleController>().lang == 'ar';
    VoiceService.speak(
      isAr
          ? 'تم تفعيل إرشاد SolveX التفاعلي. أنت تسير الآن على مسار تريك سورة الآمن الذي يتفادى مناطق الحوادث.'
          : 'Guidage SolveX activé. Vous roulez sur l\'itinéraire Trik Sûre évitant toutes les zones d\'accidents.',
      lang: isAr ? 'ar-SA' : 'fr-FR',
    );

    _navTimer?.cancel();
    _navTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (!mounted || !_isNavigating || _activeDestination == null) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_navStep < points.length - 1) {
          _navStep++;
          _navVehiclePos = points[_navStep];
          _navSpeedKmH = 60.0 + (math.Random().nextDouble() * 16.0);
          _mapController.move(_navVehiclePos!, 14.5);

          if (_navStep == (points.length / 2).round()) {
            VoiceService.speak(
              isAr
                  ? 'انتبه: على يمينك الطريق القديم الذي تكثر فيه الحوادث. استمر بالسير على هذا المسار الآمن.'
                  : 'Attention : Vous longez la zone d\'accidents récurrents. Poursuivez tout droit sur la voie sécurisée.',
              lang: isAr ? 'ar-SA' : 'fr-FR',
            );
          }
        } else {
          timer.cancel();
          _isNavigating = false;
          VoiceService.speak(
            isAr
                ? 'تهانينا! لقد وصلتم إلى وجهتكم بأمان تام وبدون أي حوادث عبر مسار تريك سورة.'
                : 'Félicitations ! Vous êtes arrivés à destination en toute sécurité sans traverser aucun point noir.',
            lang: isAr ? 'ar-SA' : 'fr-FR',
          );
        }
      });
    });
  }

  void _stopNavigation() {
    _navTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _navStep = 0;
      _navVehiclePos = null;
    });
  }

  List<Polyline> _buildPolylines() {
    if (_activeDestination == null) return const [];
    final safe = _activeDestination!.safeRoute;
    final risky = _activeDestination!.riskyRoute;

    final list = <Polyline>[];

    // Risky / direct route (with accidents) in Red
    if (!_useSafeRoute || _showBothRoutes) {
      // Glow underlay red
      list.add(
        Polyline(
          points: risky.points,
          strokeWidth: !_useSafeRoute ? 10.0 : 5.0,
          color: const Color(0xFFEF4444).withValues(alpha: !_useSafeRoute ? 0.45 : 0.25),
        ),
      );
      // Main red line
      list.add(
        Polyline(
          points: risky.points,
          strokeWidth: !_useSafeRoute ? 6.0 : 3.5,
          color: const Color(0xFFEF4444),
        ),
      );
    }

    // Safe route (Trik Sûre) in glowing emerald green
    if (_useSafeRoute || _showBothRoutes) {
      // Glow underlay green
      list.add(
        Polyline(
          points: safe.points,
          strokeWidth: _useSafeRoute ? 12.0 : 6.0,
          color: const Color(0xFF10B981).withValues(alpha: _useSafeRoute ? 0.35 : 0.2),
        ),
      );
      // Main core line green
      list.add(
        Polyline(
          points: safe.points,
          strokeWidth: _useSafeRoute ? 6.5 : 4.0,
          color: const Color(0xFF10B981),
        ),
      );
    }

    return list;
  }

  List<Marker> _buildRouteMarkers(bool isArabic, VehicleType vehicleType) {
    if (_activeDestination == null) return const [];
    final dest = _activeDestination!;
    final markers = <Marker>[];

    // 1. Destination Marker (Flag & Pin)
    markers.add(
      Marker(
        point: dest.targetLocation,
        width: 140,
        height: 60,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                ],
              ),
              child: Text(
                isArabic ? dest.nameAr.split('(').first.trim() : dest.name.split('(').first.trim(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981), width: 2.5),
              ),
              child: const Center(
                child: Icon(Icons.flag_rounded, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );

    // 2. Accident Callouts on the Risky Route
    final riskyPoints = dest.riskyRoute.points;
    if (riskyPoints.length > 2) {
      for (int i = 1; i < riskyPoints.length - 1; i++) {
        final p = riskyPoints[i];
        markers.add(
          Marker(
            point: p,
            width: 155,
            height: 48,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? 'نقطة حوادث سابقة ⚠️' : 'Zone d\'accidents ⚠️',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 3. Safe Route Badge on the Green Route Midpoint
    final safePoints = dest.safeRoute.points;
    if (safePoints.length >= 3) {
      final midIdx = (safePoints.length / 2).floor();
      markers.add(
        Marker(
          point: safePoints[midIdx],
          width: 150,
          height: 36,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFF047857),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield, color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(
                  isArabic ? 'مسار تريك سورة (آمن 100%)' : 'Trik Sûre (0 point noir)',
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 4. Vehicle Navigation Marker (Moving along the route)
    if (_isNavigating && _navVehiclePos != null) {
      final isMoto = vehicleType == VehicleType.motorcycle;
      markers.add(
        Marker(
          point: _navVehiclePos!,
          width: 52,
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isMoto ? Icons.two_wheeler : Icons.directions_car,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<Db>();
    final locService = context.watch<LocationService>();
    final user = context.watch<SessionController>().user!;
    final isArabic = context.watch<LocaleController>().lang == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'خريطة وتخطيط المسارات الآمنة' : widget.title),
        actions: [
          IconButton(
            tooltip: isArabic ? 'موقعي' : 'Recentrer sur ma position',
            icon: const Icon(Icons.my_location),
            onPressed: () {
              final loc = locService.userLocation;
              _mapController.move(LatLng(loc.lat, loc.lng), 14);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Hotspot>>(
        stream: db.allHotspots(),
        builder: (context, snap) {
          final hotspots = snap.data ?? const <Hotspot>[];
          final pts = hotspots.map((h) => LatLng(h.lat, h.lng)).toList();
          final userLoc = LatLng(locService.userLocation.lat, locService.userLocation.lng);

          return Stack(
            children: [
              // Main Map with interactive onTap
              AccidentMap(
                mapController: _mapController,
                points: pts,
                userLocation: userLoc,
                isNearBlackPoint: locService.isNearBlackPoint,
                center: userLoc,
                zoom: _activeDestination != null ? 12.0 : 13.5,
                polylines: _buildPolylines(),
                additionalMarkers: _buildRouteMarkers(isArabic, user.vehicleType),
                onTap: (tapPosition, latLng) {
                  _setDestinationFromTap(latLng, userLoc, isArabic);
                },
              ),

              // TOP OVERLAY: Navigation HUD or Destination Search Bar
              if (_isNavigating)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _navigationHud(context, isArabic),
                )
              else if (locService.isNearBlackPoint)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _blackPointProximityWarning(context, locService, isArabic),
                )
              else
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _destinationSearchBar(context, userLoc, isArabic),
                ),

              // BOTTOM OVERLAY: Route Comparison or Category Chips
              if (_isNavigating)
                Positioned(
                  bottom: 16,
                  left: 12,
                  right: 12,
                  child: _navigationBottomBar(context, isArabic),
                )
              else if (_activeDestination != null)
                Positioned(
                  bottom: 14,
                  left: 12,
                  right: 12,
                  child: _routeComparisonCard(context, isArabic),
                )
              else
                Positioned(
                  bottom: 16,
                  left: 12,
                  right: 12,
                  child: _quickChipsBar(context, isArabic),
                ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ TOP SEARCH BAR
  Widget _destinationSearchBar(BuildContext context, LatLng userLoc, bool isArabic) {
    final filtered = SafeRouteService.destinations.where((d) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.name.toLowerCase().contains(q) ||
          d.nameAr.contains(q) ||
          d.city.toLowerCase().contains(q);
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF047857), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? 'إلى أين تريد الذهاب ؟ (مطار، تيبازة، شراقة...)'
                          : 'Rechercher une destination en Algérie...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _isSearching = val.isNotEmpty;
                      });
                    },
                    onTap: () {
                      setState(() => _isSearching = true);
                    },
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchCtrl.clear();
                        _searchQuery = '';
                        _isSearching = false;
                        _activeDestination = null;
                      });
                    },
                  )
                else
                  IconButton(
                    tooltip: isArabic ? 'انقر على الخريطة لتحديد موقع' : 'Toucher la carte',
                    icon: const Icon(Icons.touch_app_outlined, color: Color(0xFF047857), size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArabic
                                ? 'اضغط في أي مكان على الخريطة لحساب المسار الآمن فوراً !'
                                : 'Appuyez n\'importe où sur la carte pour tracer votre itinéraire !',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),

        // Autocomplete suggestions dropdown
        if (_isSearching)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final d in filtered)
                  ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(d.icon, color: const Color(0xFF047857), size: 18),
                    ),
                    title: Text(
                      isArabic ? d.nameAr : d.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    subtitle: Text(
                      '${d.city} • ${isArabic ? "تفادي الحوادث" : "Sans points noirs"}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669)),
                    ),
                    onTap: () => _selectDestination(d),
                  ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      isArabic
                          ? 'لم نجد وجهة بهذا الاسم. اضغط على الخريطة لتحديد الوجهة بدقة.'
                          : 'Aucune destination trouvée. Touchez la carte pour choisir ce point.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------ ROUTE COMPARISON CARD
  Widget _routeComparisonCard(BuildContext context, bool isArabic) {
    final dest = _activeDestination!;
    final safe = dest.safeRoute;
    final risky = dest.riskyRoute;

    return Card(
      elevation: 10,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF10B981), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Destination
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.alt_route_rounded, color: Color(0xFF047857), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? dest.nameAr : dest.name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isArabic
                            ? 'مقارنة مسار الحوادث مع مسار SolveX الآمن'
                            : 'Comparatif : Route à Risques vs Trik Sûre',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _activeDestination = null;
                      _searchCtrl.clear();
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Two Route Cards Comparison (Red vs Green)
            Row(
              children: [
                // 1. Red Route with Accidents
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_useSafeRoute ? Colors.red : const Color(0xFFFECACA),
                        width: !_useSafeRoute ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isArabic ? 'طريق الحوادث' : 'Route Directe',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${risky.distanceKm} km • ${risky.durationMinutes} min',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isArabic ? '⚠️ ${risky.blackPointsCount} نقاط حوادث' : '⚠️ ${risky.blackPointsCount} Points Noirs',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 2. Green Safe Route (Trik Sûre)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _useSafeRoute ? const Color(0xFF10B981) : const Color(0xFFA7F3D0),
                        width: _useSafeRoute ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_rounded, color: Color(0xFF047857), size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isArabic ? 'تريك سورة (آمن)' : 'Trik Sûre SolveX',
                                style: const TextStyle(
                                  color: Color(0xFF047857),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${safe.distanceKm} km • ${safe.durationMinutes} min',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isArabic ? '🛡️ 0 حادث (100% أمان)' : '🛡️ 0 Accident (100% Sûr)',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Explanation callout
            Text(
              _useSafeRoute ? safe.explanation : risky.explanation,
              style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // Action Buttons
            Row(
              children: [
                // Primary Start Navigation Button
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: Text(
                      isArabic ? 'بدء الإرشاد الآمن' : 'Démarrer le Guidage Sécurisé',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _startNavigation,
                  ),
                ),

                const SizedBox(width: 8),

                // Toggle views (Trik Sûre vs Risky)
                IconButton.filledTonal(
                  tooltip: isArabic ? 'تبديل عرض المسار' : 'Basculer de route',
                  icon: const Icon(Icons.swap_calls_rounded),
                  onPressed: () {
                    setState(() => _useSafeRoute = !_useSafeRoute);
                  },
                ),

                // Toggle overlay both routes
                IconButton.filledTonal(
                  tooltip: _showBothRoutes
                      ? (isArabic ? 'إخفاء المسار المقارن' : 'Masquer la comparaison')
                      : (isArabic ? 'مقارنة المسارين' : 'Comparer les deux routes'),
                  icon: Icon(_showBothRoutes ? Icons.layers_rounded : Icons.layers_outlined),
                  onPressed: () {
                    setState(() => _showBothRoutes = !_showBothRoutes);
                  },
                ),

                IconButton.filledTonal(
                  tooltip: isArabic ? 'استماع للتحذير الصوتي' : 'Écouter l\'alerte vocale',
                  icon: const Icon(Icons.volume_up_rounded),
                  onPressed: () {
                    final isAr = context.read<LocaleController>().lang == 'ar';
                    VoiceService.speakSafeRouteSelected(
                      destination: isAr ? dest.nameAr : dest.name,
                      blackPointsAvoided: dest.safeRoute.blackPointsAvoided,
                      isArabic: isAr,
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

  // ------------------------------------------------------------------ NAVIGATION HUD (Active Mode)
  Widget _navigationHud(BuildContext context, bool isArabic) {
    final dest = _activeDestination!;
    final safe = dest.safeRoute;
    final totalPoints = safe.points.length;
    final progress = totalPoints > 1 ? (_navStep / (totalPoints - 1)).clamp(0.0, 1.0) : 0.0;
    final distRemaining = safe.distanceKm * (1.0 - progress);
    final etaRemaining = (safe.durationMinutes * (1.0 - progress)).round().clamp(1, safe.durationMinutes);

    return Card(
      color: const Color(0xFF064E3B),
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'إرشاد SolveX التفاعلي نشط' : 'Guidage Sécurisé SolveX Actif',
                        style: const TextStyle(
                          color: Color(0xFFA7F3D0),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isArabic ? dest.nameAr : dest.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Text(
                    '${_navSpeedKmH.toInt()} km/h',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic
                      ? 'متبقي: ${distRemaining.toStringAsFixed(1)} كم • $etaRemaining دقيقة'
                      : 'Reste : ${distRemaining.toStringAsFixed(1)} km • $etaRemaining min',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                Text(
                  isArabic ? '🛡️ 0 حادث (مسار آمن)' : '🛡️ 3 accidents évités',
                  style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ NAVIGATION BOTTOM BAR
  Widget _navigationBottomBar(BuildContext context, bool isArabic) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(
                  isArabic ? 'إيقاف الإرشاد' : 'Quitter le Guidage',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _stopNavigation,
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: isArabic ? 'تكرار التوجيه الصوتي' : 'Répéter l\'instruction',
              icon: const Icon(Icons.volume_up),
              onPressed: () {
                final isAr = context.read<LocaleController>().lang == 'ar';
                VoiceService.speak(
                  isAr
                      ? 'واصل السير على مسار تريك سورة. الطريق آمن تماماً.'
                      : 'Continuez tout droit sur l\'itinéraire Trik Sûre. Route sécurisée.',
                  lang: isAr ? 'ar-SA' : 'fr-FR',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ QUICK DESTINATION CHIPS
  Widget _quickChipsBar(BuildContext context, bool isArabic) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.near_me_outlined, size: 16, color: Color(0xFF047857)),
                const SizedBox(width: 6),
                Text(
                  isArabic ? 'وجهات سريعة لتفادي الحوادث :' : 'Destinations sans points noirs :',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final d in SafeRouteService.destinations) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: Icon(d.icon, size: 15, color: const Color(0xFF047857)),
                        label: Text(
                          isArabic ? d.nameAr.split('(').first.trim() : d.name.split('(').first.trim(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFFECFDF5),
                        side: const BorderSide(color: Color(0xFFA7F3D0)),
                        onPressed: () => _selectDestination(d),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ PROXIMITY ALERT BANNER
  Widget _blackPointProximityWarning(BuildContext context, LocationService locService, bool isArabic) {
    return Card(
      color: const Color(0xFFFEF2F2),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? '⚠️ تحذير: منطقة حوادث سابقة' : '⚠️ ALERTE : POINT NOIR IMMINENT',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    isArabic
                        ? 'أنت على بعد ${locService.distanceMeters.toInt()} م من موقع حوادث سابقة !'
                        : 'Vous êtes à ${locService.distanceMeters.toInt()} m d\'un lieu d\'accidents.',
                    style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 11.5),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.red),
              onPressed: () => locService.speakCurrentWarning(isArabic: isArabic),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Wraps the application inside a realistic phone mockup when viewed on desktop browsers.
class PhoneFrameWrapper extends StatefulWidget {
  final Widget child;

  const PhoneFrameWrapper({super.key, required this.child});

  @override
  State<PhoneFrameWrapper> createState() => _PhoneFrameWrapperState();
}

class _PhoneFrameWrapperState extends State<PhoneFrameWrapper> {
  bool _phoneMode = true;
  int _deviceIndex = 0; // 0 = iPhone, 1 = Android / Pixel

  static const _devices = [
    _DeviceSpec(name: 'iPhone 16 Pro', width: 402, height: 874, borderRadius: 52),
    _DeviceSpec(name: 'Google Pixel 9', width: 412, height: 892, borderRadius: 48),
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width > 600;

    // If on actual mobile device or user disabled phone mode, render full screen directly.
    if (!isDesktop || !_phoneMode) {
      return Stack(
        children: [
          widget.child,
          if (isDesktop && !_phoneMode)
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(30),
                color: Colors.black87,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => setState(() => _phoneMode = true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_iphone, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Activer Vue Téléphone',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final dev = _devices[_deviceIndex];

    // Scale down slightly if browser window is shorter than device height.
    final availableHeight = media.size.height - 90;
    final scale = (availableHeight < dev.height) ? (availableHeight / dev.height) : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 22, height: 22, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  const Text(
                    'Slamtek — Rendu Mobile',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  // Device Switcher
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_devices.length, (idx) {
                        final selected = idx == _deviceIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _deviceIndex = idx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF10B981) : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _devices[idx].name,
                              style: TextStyle(
                                color: selected ? Colors.white : const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Fullscreen toggle button
                  IconButton(
                    tooltip: 'Passer en plein écran',
                    icon: const Icon(Icons.fullscreen, color: Color(0xFF64748B)),
                    onPressed: () => setState(() => _phoneMode = false),
                  ),
                ],
              ),
            ),

            // Phone Body Area
            Expanded(
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: dev.width,
                    height: dev.height,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(dev.borderRadius),
                      border: Border.all(color: const Color(0xFF334155), width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 45,
                          spreadRadius: 8,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          blurRadius: 60,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(dev.borderRadius - 10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          // App Viewport with proper Safe Area padding
                          Positioned.fill(
                            child: MediaQuery(
                              data: media.copyWith(
                                size: Size(dev.width, dev.height),
                                padding: const EdgeInsets.only(top: 54, bottom: 24),
                                viewPadding: const EdgeInsets.only(top: 54, bottom: 24),
                              ),
                              child: widget.child,
                            ),
                          ),

                          // Status Bar (Time and Battery/Wifi icons flanking the Dynamic Island)
                          Positioned(
                            top: 14,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '09:41',
                                      style: TextStyle(
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.signal_cellular_4_bar, size: 14, color: Color(0xFF1E293B)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.wifi, size: 14, color: Color(0xFF1E293B)),
                                        const SizedBox(width: 5),
                                        Container(
                                          width: 20,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                                            borderRadius: BorderRadius.circular(2.5),
                                          ),
                                          padding: const EdgeInsets.all(1),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E293B),
                                              borderRadius: BorderRadius.circular(1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Dynamic Island / Camera Notch (top center)
                          Positioned(
                            top: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 115,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white12, width: 1),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1A2E),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF0B3B60), width: 1.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Bottom Gesture Bar (Home indicator)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: IgnorePointer(
                                child: Container(
                                  width: 135,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceSpec {
  final String name;
  final double width;
  final double height;
  final double borderRadius;

  const _DeviceSpec({
    required this.name,
    required this.width,
    required this.height,
    required this.borderRadius,
  });
}

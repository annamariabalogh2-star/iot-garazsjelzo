import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const GarageAssistApp());
}

class GarageAssistApp extends StatelessWidget {
  const GarageAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Garage Assist',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05090D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF36DCA4),
          brightness: Brightness.dark,
        ),
      ),
      home: const GarageAssistScreen(),
    );
  }
}

class GarageAssistScreen extends StatefulWidget {
  const GarageAssistScreen({super.key});

  @override
  State<GarageAssistScreen> createState() => _GarageAssistScreenState();
}

class _GarageAssistScreenState extends State<GarageAssistScreen> {
  static final Uri _statusUri = Uri.parse('http://192.168.4.1/api/status');

  final http.Client _client = http.Client();

  Timer? _pollTimer;
  bool _requestInProgress = false;
  bool _isConnected = false;
  int _frontMissingReadings = 0;
  int _sideMissingReadings = 0;

  int? _frontDistance;
  int? _sideDistance;

  String _parkingState = 'OFFLINE';
  String _sideState = 'OFFLINE';

  @override
  void initState() {
    super.initState();

    _fetchStatus();

    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _fetchStatus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    if (_requestInProgress) {
      return;
    }

    _requestInProgress = true;

    try {
      final response = await _client
          .get(_statusUri)
          .timeout(const Duration(seconds: 1));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final frontDistance = _readDistance(data['frontDistance']);
      final sideDistance = _readDistance(data['sideDistance']);
      final parkingState = _readState(data['parkingState']);
      final sideState = _readState(data['sideState']);

      if (!mounted) {
        return;
      }

      setState(() {
        if (frontDistance == null) {
          _frontMissingReadings++;

          if (_frontMissingReadings >= 3) {
            _frontDistance = null;
            _parkingState = parkingState;
          }
        } else {
          _frontMissingReadings = 0;
          _frontDistance = _smoothDistance(_frontDistance, frontDistance);
          _parkingState = parkingState;
        }

        if (sideDistance == null) {
          _sideMissingReadings++;

          if (_sideMissingReadings >= 3) {
            _sideDistance = null;
            _sideState = sideState;
          }
        } else {
          _sideMissingReadings = 0;
          _sideDistance = _smoothDistance(_sideDistance, sideDistance);
          _sideState = sideState;
        }

        _isConnected = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _frontDistance = null;
        _sideDistance = null;
        _parkingState = 'OFFLINE';
        _sideState = 'OFFLINE';
        _isConnected = false;
      });
    } finally {
      _requestInProgress = false;
    }
  }

  int? _readDistance(Object? value) {
    int? parsedValue;

    if (value is int) {
      parsedValue = value;
    } else if (value is num) {
      parsedValue = value.round();
    } else {
      parsedValue = int.tryParse(value?.toString() ?? '');
    }

    if (parsedValue == null) {
      throw const FormatException('Invalid distance value');
    }

    if (parsedValue < 0) {
      return null;
    }

    return parsedValue;
  }

  String _readState(Object? value) {
    final state = value?.toString().trim().toUpperCase();

    if (state == null || state.isEmpty) {
      throw const FormatException('Invalid state value');
    }

    return state;
  }

  int _smoothDistance(int? currentValue, int newValue) {
    if (currentValue == null) {
      return newValue;
    }

    if ((currentValue - newValue).abs() >= 10) {
      return newValue;
    }

    return ((currentValue * 2 + newValue) / 3).round();
  }

  @override
  Widget build(BuildContext context) {
    final parkingColor = _isConnected
        ? stateColor(_parkingState)
        : const Color(0xFF65717C);

    final sideColor = _isConnected
        ? stateColor(_sideState)
        : const Color(0xFF65717C);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101A20), Color(0xFF05090D), Color(0xFF020406)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dashboardWidth = (constraints.maxWidth - 24).clamp(
                320.0,
                420.0,
              );
              final largeGaugeSize = math
                  .min(dashboardWidth - 125, 210)
                  .toDouble();
              final carWidth = math.min(dashboardWidth * 0.32, 120.0);
              final smallGaugeSize = math
                  .min((dashboardWidth - carWidth) / 2 + 2, 124)
                  .toDouble();

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Column(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: dashboardWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Header(isConnected: _isConnected),
                              const SizedBox(height: 4),
                              _DashboardGauge(
                                size: largeGaugeSize,
                                label: 'PARKING ASSIST',
                                headline: _parkingState,
                                subline: _frontDistance == null
                                    ? '-- CM TO STOP'
                                    : '$_frontDistance CM TO STOP',
                                color: parkingColor,
                                needlePosition: statePosition(_parkingState),
                                showNeedle: true,
                                multicolor: _isConnected,
                              ),
                              const SizedBox(height: 8),
                              const _SectionLine(),
                              SizedBox(
                                height: 332,
                                child: _VehiclePanel(
                                  parkingColor: parkingColor,
                                  sideColor: sideColor,
                                  isConnected: _isConnected,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: dashboardWidth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _DashboardGauge(
                              size: smallGaugeSize,
                              label: 'FRONT',
                              headline: _frontDistance?.toString() ?? '--',
                              subline: 'CM',
                              color: parkingColor,
                              needlePosition: statePosition(_parkingState),
                            ),
                            _DashboardGauge(
                              size: smallGaugeSize,
                              label: 'DOOR ZONE',
                              headline: _sideState,
                              subline: _sideDistance == null
                                  ? '-- CM'
                                  : '$_sideDistance CM',
                              color: sideColor,
                              needlePosition: statePosition(_sideState),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Footer(isConnected: _isConnected),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? const Color(0xFF36DCA4)
        : const Color(0xFFFF526D);

    return Row(
      children: [
        const Icon(
          Icons.directions_car_filled_rounded,
          color: Color(0xFF9FB0BA),
          size: 30,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'GARAGE ASSIST',
            style: TextStyle(
              color: Color(0xFFEAF2F5),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                isConnected ? 'LIVE' : 'OFFLINE',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLine extends StatelessWidget {
  const _SectionLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Color(0xFF44535C), Colors.transparent],
        ),
      ),
    );
  }
}

class _DashboardGauge extends StatelessWidget {
  const _DashboardGauge({
    required this.size,
    required this.label,
    required this.headline,
    required this.subline,
    required this.color,
    required this.needlePosition,
    this.showNeedle = false,
    this.multicolor = false,
  });

  final double size;
  final String label;
  final String headline;
  final String subline;
  final Color color;
  final double needlePosition;
  final bool showNeedle;
  final bool multicolor;

  @override
  Widget build(BuildContext context) {
    final headlineSize = headline.length >= 7 ? size * 0.105 : size * 0.16;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF12212B), Color(0xFF071017), Color(0xFF020608)],
          stops: [0, 0.68, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: 3,
          ),
          const BoxShadow(
            color: Colors.black,
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _GaugePainter(
          color: color,
          position: needlePosition,
          showNeedle: showNeedle,
          multicolor: multicolor,
        ),
        child: showNeedle
            ? Stack(
                children: [
                  Positioned(
                    top: size * 0.32,
                    left: size * 0.14,
                    right: size * 0.14,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF8F9AA2),
                        fontSize: size * 0.048,
                        letterSpacing: size * 0.009,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Positioned(
                    top: size * 0.64,
                    left: size * 0.14,
                    right: size * 0.14,
                    height: size * 0.16,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        headline,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          color: color,
                          fontSize: headlineSize,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: size * 0.85,
                    left: size * 0.12,
                    right: size * 0.12,
                    height: size * 0.08,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        subline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFAAB3B9),
                          fontSize: size * 0.065,
                          height: 1.2,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Padding(
                  padding: EdgeInsets.only(top: size * 0.05),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF8F9AA2),
                          fontSize: size * 0.055 + 2,
                          letterSpacing: size * 0.012,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: size * 0.055),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          color: color,
                          fontSize: headlineSize + 1,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: size * 0.04),
                      Text(
                        subline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFAAB3B9),
                          fontSize: size * 0.075 + 1,
                          height: 1.25,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.color,
    required this.position,
    required this.showNeedle,
    required this.multicolor,
  });

  final Color color;
  final double position;
  final bool showNeedle;
  final bool multicolor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - size.width * 0.055;
    final strokeWidth = size.width * 0.065;

    const startAngle = math.pi * 0.75;
    const totalSweep = math.pi * 1.5;

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = const Color(0xFF303942)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(arcRect, startAngle, totalSweep, false, trackPaint);

    if (multicolor) {
      _drawArcSection(
        canvas,
        arcRect,
        startAngle,
        totalSweep * 0.35,
        const Color(0xFF36DCA4),
        strokeWidth,
      );

      _drawArcSection(
        canvas,
        arcRect,
        startAngle + totalSweep * 0.35,
        totalSweep * 0.23,
        const Color(0xFFFFBD43),
        strokeWidth,
      );

      _drawArcSection(
        canvas,
        arcRect,
        startAngle + totalSweep * 0.58,
        totalSweep * 0.18,
        const Color(0xFFFF526D),
        strokeWidth,
      );
    } else {
      _drawArcSection(
        canvas,
        arcRect,
        startAngle,
        totalSweep * position,
        color,
        strokeWidth,
      );
    }

    for (var index = 0; index <= 24; index++) {
      final tickPosition = index / 24;
      final angle = startAngle + totalSweep * tickPosition;
      final isMainTick = index % 4 == 0;

      final outerPoint = Offset(
        center.dx + math.cos(angle) * (radius + strokeWidth / 2),
        center.dy + math.sin(angle) * (radius + strokeWidth / 2),
      );

      final innerRadius =
          radius - (isMainTick ? strokeWidth * 0.9 : strokeWidth * 0.6);

      final innerPoint = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );

      final tickPaint = Paint()
        ..color = Colors.white.withValues(alpha: isMainTick ? 0.75 : 0.38)
        ..strokeWidth = isMainTick ? 2 : 1;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }

    if (showNeedle) {
      // Keep the needle above the status and caption in every state.
      final needleAngle = startAngle + totalSweep * position.clamp(1 / 6, 5 / 6);
      final needleCenter = Offset(center.dx, size.height * 0.54);
      final needleLength = size.width * 0.38;

      final needleEnd = Offset(
        needleCenter.dx + math.cos(needleAngle) * needleLength,
        needleCenter.dy + math.sin(needleAngle) * needleLength,
      );

      final needlePaint = Paint()
        ..color = color
        ..strokeWidth = size.width * 0.018
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(needleCenter, needleEnd, needlePaint);

      canvas.drawCircle(
        needleCenter,
        size.width * 0.035,
        Paint()..color = color,
      );

      canvas.drawCircle(
        needleCenter,
        size.width * 0.014,
        Paint()..color = const Color(0xFFFFE2A2),
      );
    }
  }

  void _drawArcSection(
    Canvas canvas,
    Rect rect,
    double start,
    double sweep,
    Color sectionColor,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = sectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.position != position ||
        oldDelegate.showNeedle != showNeedle ||
        oldDelegate.multicolor != multicolor;
  }
}

class _VehiclePanel extends StatelessWidget {
  const _VehiclePanel({
    required this.parkingColor,
    required this.sideColor,
    required this.isConnected,
  });

  final Color parkingColor;
  final Color sideColor;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: CustomPaint(
        painter: _VehiclePainter(
          parkingColor: parkingColor,
          sideColor: sideColor,
          isConnected: isConnected,
        ),
      ),
    );
  }
}

class _VehiclePainter extends CustomPainter {
  const _VehiclePainter({
    required this.parkingColor,
    required this.sideColor,
    required this.isConnected,
  });

  final Color parkingColor;
  final Color sideColor;
  final bool isConnected;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF253039).withValues(alpha: 0.26)
      ..strokeWidth = 1;

    for (double y = 45; y < size.height; y += 45) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), gridPaint);
    }

    final wallPaint = Paint()
      ..color = const Color(0xFF8F9AA2)
      ..strokeWidth = 7;

    canvas.drawLine(
      Offset(size.width * 0.17, 12),
      Offset(size.width * 0.83, 12),
      wallPaint,
    );

    final centerX = size.width / 2;
    final carWidth = math.min(size.width * 0.35, 132).toDouble();
    const carHeight = 176.0;
    const carTop = 162.0;
    const radarBase = 136.0;

    final sensorPaint = Paint()
      ..color = parkingColor.withValues(alpha: isConnected ? 0.85 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    for (final radius in [42.0, 68.0, 94.0]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(centerX, radarBase),
          width: radius * 2.3,
          height: radius * 2,
        ),
        math.pi,
        math.pi,
        false,
        sensorPaint..color = parkingColor.withValues(alpha: 1 - radius / 180),
      );
    }

    canvas.save();
    canvas.translate(centerX, carTop);
    canvas.scale(1.14);
    canvas.translate(-centerX, -carTop);

    final carRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX - carWidth / 2, carTop, carWidth, carHeight),
      const Radius.circular(40),
    );

    canvas.drawRRect(
      carRect,
      Paint()
        ..color = const Color(0xFF26343C)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      carRect,
      Paint()
        ..color = const Color(0xFF91A3AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final windowPaint = Paint()
      ..color = const Color(0xFF111B21)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - carWidth * 0.34,
          carTop + 31,
          carWidth * 0.68,
          53,
        ),
        const Radius.circular(20),
      ),
      windowPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - carWidth * 0.34,
          carTop + 114,
          carWidth * 0.68,
          46,
        ),
        const Radius.circular(20),
      ),
      windowPaint,
    );

    final headlightPaint = Paint()
      ..color = parkingColor
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(centerX - carWidth * 0.28, carTop + 14),
      Offset(centerX - carWidth * 0.12, carTop + 14),
      headlightPaint,
    );

    canvas.drawLine(
      Offset(centerX + carWidth * 0.12, carTop + 14),
      Offset(centerX + carWidth * 0.28, carTop + 14),
      headlightPaint,
    );

    final sideX = math
        .min(centerX + carWidth / 2 + 20, size.width - 34)
        .toDouble();

    final sideLinePaint = Paint()
      ..color = sideColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const sideBottom = carTop + 129;

    canvas.drawLine(
      Offset(sideX, carTop + 38),
      Offset(sideX, sideBottom),
      sideLinePaint,
    );

    canvas.drawCircle(
      Offset(sideX, carTop + 38),
      5.5,
      Paint()..color = sideColor,
    );

    canvas.drawCircle(
      Offset(sideX, sideBottom),
      5.5,
      Paint()..color = sideColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter oldDelegate) {
    return oldDelegate.parkingColor != parkingColor ||
        oldDelegate.sideColor != sideColor ||
        oldDelegate.isConnected != isConnected;
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? const Color(0xFF36DCA4)
        : const Color(0xFFFF526D);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF10181E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3841)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              isConnected
                  ? 'ESP32-S3  •  LOCAL  •  LIVE 0.2s'
                  : 'CONNECTION LOST  •  192.168.4.1',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color stateColor(String state) {
  switch (state) {
    case 'GO':
    case 'CLEAR':
      return const Color(0xFF36DCA4);

    case 'SLOW':
      return const Color(0xFFFFBD43);

    case 'STOP':
      return const Color(0xFFFF405D);

    case 'BLOCKED':
      return const Color(0xFFFF405D);

    default:
      return const Color(0xFF65717C);
  }
}

double statePosition(String state) {
  switch (state) {
    case 'GO':
    case 'CLEAR':
      return 0.32;

    case 'SLOW':
      return 0.54;

    case 'STOP':
      return 0.74;

    case 'BLOCKED':
      return 0.93;

    default:
      return 0;
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_navi_sdk/flutter_navi_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'place.dart';

class TMapView extends StatefulWidget {
  const TMapView({super.key, this.departure, this.destination});

  final Place? departure;
  final Place? destination;

  @override
  State<TMapView> createState() => _TMapViewState();
}

class _TMapViewState extends State<TMapView> {
  bool _isInitializing = true;
  bool _isRefreshing = false;
  bool _isReady = false;
  bool _isSdkInitialized = false;
  String _statusMessage = 'Preparing T map...';
  Position? _currentPosition;
  String _appliedMarkerKey = 'none';
  int _markerConfigSerial = 0;
  final Map<int, String> _markerIconPaths = {};

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get _mapDataKey {
    final position = _currentPosition;

    return [
      if (position != null)
        'gps:${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}',
    ].join('|');
  }

  String get _requestedMarkerKey {
    final departure = widget.departure;
    final destination = widget.destination;

    return [
      if (departure != null)
        'dep:${departure.latitude.toStringAsFixed(6)},${departure.longitude.toStringAsFixed(6)}',
      if (destination != null)
        'dest:${destination.latitude.toStringAsFixed(6)},${destination.longitude.toStringAsFixed(6)}',
    ].join('|').ifEmpty('none');
  }

  RouteRequestData _routeRequestData() {
    return RouteRequestData();
  }

  String _mapSummaryText() {
    final departure = widget.departure;
    final destination = widget.destination;

    if (departure != null && destination != null) {
      return '${departure.name} -> ${destination.name}';
    }

    if (departure != null) {
      return '출발지 ${departure.name}';
    }

    if (destination != null) {
      return '목적지 ${destination.name}';
    }

    return 'GPS ${_currentPosition!.latitude.toStringAsFixed(6)}, '
        '${_currentPosition!.longitude.toStringAsFixed(6)}';
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(TMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isSdkInitialized && _requestedMarkerKey != _appliedMarkerKey) {
      unawaited(
        _configureSelectedPlaceMarkers(
          centerPlace: _changedPlaceFrom(oldWidget),
        ),
      );
    }
  }

  bool _isSamePlace(Place? a, Place? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    return a.id == b.id &&
        a.latitude == b.latitude &&
        a.longitude == b.longitude;
  }

  Place? _changedPlaceFrom(TMapView oldWidget) {
    if (!_isSamePlace(widget.destination, oldWidget.destination)) {
      return widget.destination;
    }
    if (!_isSamePlace(widget.departure, oldWidget.departure)) {
      return widget.departure;
    }
    return null;
  }

  Future<void> _refreshMap() async {
    if (_isInitializing || _isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      _statusMessage = 'Refreshing map...';
    });

    try {
      await _loadCurrentPosition();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _initialize() async {
    if (!_isSupportedPlatform) {
      setState(() {
        _isInitializing = false;
        _statusMessage = 'T map is only available on Android and iOS.';
      });
      return;
    }

    try {
      final isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Turn on GPS/location services and try again.';
        });
        return;
      }

      final permission = await Permission.location.request();
      if (!permission.isGranted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Location permission is required to show T map.';
        });
        return;
      }

      await _loadCurrentPosition();

      if (_isSdkInitialized) {
        return;
      }

      setState(() {
        _isInitializing = true;
        _isReady = false;
        _statusMessage = 'Initializing T map SDK...';
      });

      final tMapApiKey = dotenv.env['TMAP_API_KEY'] ?? '';
      if (tMapApiKey.isEmpty) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'TMAP_API_KEY is not configured.';
        });
        return;
      }

      final result = await TmapUISDKManager().initSDK(
        AuthData(clientApiKey: tMapApiKey, isAvailableInBackground: true),
      );

      if (!mounted) {
        return;
      }

      if (result == InitResult.granted) {
        _isSdkInitialized = true;
        await _configureSelectedPlaceMarkers(updateState: false);
        if (!mounted) {
          return;
        }

        setState(() {
          _isInitializing = false;
          _isReady = true;
          _statusMessage = 'T map ready';
        });
        return;
      }

      setState(() {
        _isInitializing = false;
        _statusMessage =
            'T map initialization failed: ${result?.text ?? "unknown"}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _statusMessage = 'T map error: $error';
      });
    }
  }

  Future<void> _configureSelectedPlaceMarkers({
    bool updateState = true,
    Place? centerPlace,
  }) async {
    final serial = ++_markerConfigSerial;
    final markerKey = _requestedMarkerKey;
    final markers = <UISDKMarker>[];

    final departure = widget.departure;
    if (departure != null) {
      markers.add(
        UISDKMarker(
          markerId: 'departure',
          imageName: await _markerIconPath(const Color(0xFF2563EB)),
          markerType: MarkerType.point,
          markerPoint: [
            UISDKMarkerPoint(
              latitude: departure.latitude,
              longitude: departure.longitude,
            ),
          ],
        ),
      );
    }

    final destination = widget.destination;
    if (destination != null) {
      markers.add(
        UISDKMarker(
          markerId: 'destination',
          imageName: await _markerIconPath(const Color(0xFFDC2626)),
          markerType: MarkerType.point,
          markerPoint: [
            UISDKMarkerPoint(
              latitude: destination.latitude,
              longitude: destination.longitude,
            ),
          ],
        ),
      );
    }

    final manager = TmapUISDKManager();
    await manager.configMarker(UISDKMarkerConfig(markers: markers));

    final selectedCenter = centerPlace ?? destination ?? departure;
    if (selectedCenter != null) {
      await manager.setMapCenter(
        selectedCenter.latitude,
        selectedCenter.longitude,
      );
    } else {
      final currentPosition = _currentPosition;
      if (currentPosition != null) {
        await manager.setMapCenter(
          currentPosition.latitude,
          currentPosition.longitude,
          animated: false,
        );
      }
    }

    if (!mounted || serial != _markerConfigSerial) {
      return;
    }

    if (updateState) {
      setState(() {
        _appliedMarkerKey = markerKey;
      });
    } else {
      _appliedMarkerKey = markerKey;
    }
  }

  Future<String> _markerIconPath(Color color) async {
    final colorKey = color.toARGB32();
    final cachedPath = _markerIconPaths[colorKey];
    if (cachedPath != null) {
      return cachedPath;
    }

    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}dangretel_tmap_marker_$colorKey.png',
    );
    if (!await file.exists()) {
      await file.writeAsBytes(await _createMarkerIconBytes(color), flush: true);
    }

    _markerIconPaths[colorKey] = file.path;
    return file.path;
  }

  Future<Uint8List> _createMarkerIconBytes(Color color) async {
    const width = 96;
    const height = 112;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..color = color;
    final shadow = ui.Paint()..color = const Color(0x33000000);

    canvas.drawCircle(const ui.Offset(50, 46), 30, shadow);
    canvas.drawCircle(const ui.Offset(48, 42), 30, paint);

    final tail = ui.Path()
      ..moveTo(48, 100)
      ..lineTo(31, 63)
      ..lineTo(65, 63)
      ..close();
    canvas.drawPath(tail, paint);

    canvas.drawCircle(
      const ui.Offset(48, 42),
      11,
      ui.Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _loadCurrentPosition() async {
    final currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _currentPosition = currentPosition;
      _isInitializing = false;
      _isReady = _isSdkInitialized;
      _statusMessage =
          'GPS ready: ${currentPosition.latitude}, ${currentPosition.longitude}';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupportedPlatform) {
      return const _MessageView(
        icon: Icons.map_outlined,
        title: 'T map is only available on Android and iOS.',
        subtitle: 'Run this app on an Android phone or emulator.',
      );
    }

    if (_isInitializing) {
      return _MessageView(
        icon: Icons.sync,
        title: _statusMessage,
        subtitle: 'Please wait a moment.',
        loading: true,
      );
    }

    if (!_isReady) {
      return _MessageView(
        icon: Icons.error_outline,
        title: 'T map is not ready.',
        subtitle: _statusMessage,
      );
    }

    return Stack(
      children: [
        KeyedSubtree(
          key: ValueKey<String>(_mapDataKey),
          child: TmapViewWidget(data: _routeRequestData()),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isRefreshing ? null : _refreshMap,
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: _isRefreshing
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1F2937),
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Color(0xFF1F2937),
                      ),
              ),
            ),
          ),
        ),
        if (_currentPosition != null ||
            widget.departure != null ||
            widget.destination != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  _mapSummaryText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F6F8),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF3056A0),
              ),
            )
          else
            Icon(icon, size: 44, color: const Color(0xFF3056A0)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

extension _StringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

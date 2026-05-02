import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_navi_sdk/flutter_navi_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

const _tMapApiKey = 'TXChrUJFjq9O4TdlVdE5U5s9GI3f8Wlt6kHC4kAP';

class TMapView extends StatefulWidget {
  const TMapView({super.key});

  @override
  State<TMapView> createState() => _TMapViewState();
}

class _TMapViewState extends State<TMapView> {
  bool _isInitializing = true;
  bool _isReady = false;
  String _statusMessage = 'Preparing T map...';
  Position? _currentPosition;

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
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

      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = currentPosition;
        _statusMessage =
            'GPS ready: ${currentPosition.latitude}, ${currentPosition.longitude}';
      });

      setState(() {
        _statusMessage = 'Initializing T map SDK...';
      });

      final result = await TmapUISDKManager().initSDK(
        AuthData(
          clientApiKey: _tMapApiKey,
          isAvailableInBackground: true,
        ),
      );

      if (!mounted) {
        return;
      }

      if (result == InitResult.granted) {
        setState(() {
          _isInitializing = false;
          _isReady = true;
          _statusMessage = 'T map ready';
        });
        return;
      }

      setState(() {
        _isInitializing = false;
        _statusMessage = 'T map initialization failed: ${result?.text ?? "unknown"}';
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
        TmapViewWidget(
          data: RouteRequestData(
            source: RoutePoint(
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
              name: 'Current Location',
            ),
            destination: RoutePoint(
              latitude: _currentPosition!.latitude + 0.01,
              longitude: _currentPosition!.longitude + 0.01,
              name: 'Nearby Destination',
            ),
            routeOption: [
              PlanningOption.recommend,
            ],
            guideWithoutPreview: false,
          ),
        ),
        if (_currentPosition != null)
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
                  'GPS ${_currentPosition!.latitude.toStringAsFixed(6)}, '
                  '${_currentPosition!.longitude.toStringAsFixed(6)}',
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
            Icon(
              icon,
              size: 44,
              color: const Color(0xFF3056A0),
            ),
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
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

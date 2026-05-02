import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_navi_sdk/config/drive_route_data.dart';
import 'package:provider/provider.dart';
import 'package:tmap_ui_sdk/event/data/driveStatus/tmap_drivestatus.dart';
import 'package:tmap_ui_sdk/event/data/driveguide/tmap_driveguide.dart';
import 'package:tmap_ui_sdk/event/data/driveguide/tmap_driveguide_sdi.dart';
import 'package:tmap_ui_sdk/event/data/sdkStatus/tmap_sdk_status.dart';
import 'package:tmap_ui_sdk/tmap_ui_sdk.dart';
import 'package:tmap_ui_sdk/tmap_ui_sdk_manager.dart';
import 'package:tmap_ui_sdk/widget/tmap_view_widget.dart';

class DrivePage extends StatefulWidget {
  const DrivePage({super.key});

  @override
  State<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  bool _isViewReady = false;

  @override
  void initState() {
    super.initState();
    _initializeSafely();
  }

  Future<void> _initializeSafely() async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    TmapUISDKManager().startTmapSDKStatusStream(onStatusListener);
    TmapUISDKManager().startTmapDriveStatusStream(onDriveStatus);
    TmapUISDKManager().startTmapDriveGuideStream(onDriveGuide);

    if (mounted) {
      setState(() {
        _isViewReady = true;
      });
    }
  }

  void onDriveGuide(TmapDriveGuide guide) {

    var lat = guide.matchedLatitude;
    var lon = guide.matchedLongitude;

    log("lat : $lat, lon : $lon");

  }

  void onDriveStatus(TmapDriveStatus status) {
    log("status ============ ${status.text}");
  }

  void onStatusListener(TmapSDKStatusMsg status) {
    switch (status.sdkStatus) {
      case TmapSDKStatus.dismissReq:
        onDismiss(); // 운행이 종료되면 화면을 닫는다.
        break;
      default:
        break;
    }
  }

  void onDismiss() {
    if (context.mounted) {
      Navigator.of(context).popUntil((route) {
        return route.settings.name == '/';
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    TmapUISDKManager().stopTmapSDKStatusStream();
    TmapUISDKManager().stopTmapDriveStatusStream();
    TmapUISDKManager().stopTmapDriveGuideStream();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: true,
        onPopInvoked: (didPop) async {
          if (didPop) {
            await TmapUISDKManager().stopDriving();
            return;
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: SafeArea(
            bottom: true,
            child: Container(
              color: Colors.white,
              child: _isViewReady
                  ? Consumer<DriveRouteData>(
                      builder: (context, drive, child) =>
                          TmapViewWidget(data: drive.getRouteRequestData()))
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),
        ));
  }
}

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_navi_sdk/config/config_car.dart';
import 'package:flutter_navi_sdk/config/drive_route_data.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:tmap_ui_sdk/auth/data/auth_data.dart';
import 'package:tmap_ui_sdk/auth/data/init_result.dart';
import 'package:tmap_ui_sdk/event/data/sdkStatus/tmap_sdk_status.dart';
import 'package:tmap_ui_sdk/tmap_ui_sdk.dart';
import 'package:tmap_ui_sdk/tmap_ui_sdk_manager.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool isInit = false;

  String platformVersion = "Unknown";
  String initStatus = "Unknown";

  final platform = const MethodChannel("flutter.android");

  @override
  void initState() {
    super.initState();

    TmapUISDKManager().startTmapSDKStatusStream(onSDKStatusStream);
    //위치 권한
    permissionLocation();
  }

  Future<void> permissionLocation() async {
    var status = await Permission.location.request();

    if (status.isGranted) {
      initTmap();
    } else {
      Fluttertoast.showToast(msg: "위치 권한을 허용해야 초기화가 완료 됩니다.");
    }
  }

  Future<void> initTmap() async {
    if (isInit) {
      // 초기화 완료됐을 때
      Fluttertoast.showToast(msg: "이미 초기화 완료");
    } else {
      var pv;
      var isInitGranted = InitResult.notGranted.text;
      try {
        pv = await TmapUiSdk().getPlatformVersion();

        AuthData authInfo = AuthData(
            clientApiKey: "",
            userKey: "",
            deviceKey: "",
            isAvailableInBackground: true);

        var result = await TmapUISDKManager().initSDK(authInfo);

        if (result != null && pv != null) {
          isInitGranted = result.text;

          if (result == InitResult.granted) {
            isInit = true;
          }
        }
      } catch (e) {
        pv = "Unknown Platform Version";
        isInitGranted = InitResult.notGranted.text;

      }

      setState(() {
        platformVersion = pv;
        initStatus = isInitGranted;
      });
    }
  }

  void onSDKStatusStream(TmapSDKStatusMsg msg) {
    switch (msg.sdkStatus) {
      case TmapSDKStatus.savedDriveInfo:
        //이어가기를 할 때
        showContinueDriveDialog(msg.extraData);
        break;
      default:
        break;
    }
  }

  Future<void> showContinueDriveDialog(String dest) async {
    showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              title: const Text("알림"),
              content: Text("$dest (으)로 경로 안내를 이어서 안내 받으시겠습니까?"),
              actions: [
                TextButton(onPressed: stopDriving, child: const Text("아니오")),
                TextButton(onPressed: continueDrive, child: const Text("네")),
              ],
            ));
  }

  Future<void> continueDrive() async {
    DriveRouteData.isSafeDriving = false;
    DriveRouteData.isContinueDriving = true;
    context.go("/drivePage");
  }

  Future<void> stopDriving() async {
    Navigator.of(context).pop();
    TmapUISDKManager().clearContinueDriveInfo();
  }

  Future<void> clickPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      openAppSettings();
    } else {
      Fluttertoast.showToast(msg: "이미 위치 권한을 허용 하였습니다.");
    }
  }

  Future<bool?> setCarConfig() async {
    ConfigCarModel model = context.read<ConfigCarModel>();

    bool? result = await TmapUISDKManager().setConfigSDK(model.nomalCar);

    Fluttertoast.showToast(
        msg: result == true ? "set car config success" : "set car config fail");

    return result;
  }

  Future<bool?> setTruckConfig() async {
    ConfigCarModel model = context.read<ConfigCarModel>();

    bool? result = await TmapUISDKManager().setConfigSDK(model.truck);

    Fluttertoast.showToast(
        msg: result == true
            ? "set truck option success"
            : "set truck option fail");

    return result;
  }

  Future<bool?> finalizeSDK() async {
    if (isInit) {
      isInit = false;

      setState(() {
        initStatus = "notGranted";
      });
    }
    return await TmapUISDKManager().finalizeSDK();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("navi sdk sample"),
        centerTitle: true,
      ),
      body: Center(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Running on : $platformVersion"),
          Text("init status : $initStatus"),
          TextButton(
            onPressed: clickPermission,
            child: const Text("위치 권한"),
          ),
          TextButton(onPressed: initTmap, child: const Text("초기화")),
          TextButton(onPressed: setCarConfig, child: const Text("차량 설정")),
          TextButton(onPressed: setTruckConfig, child: const Text("트럭 설정")),
          TextButton(
              onPressed: () {
                if (isInit) {
                  DriveRouteData.isSafeDriving = true;
                  context.go("/drivePage");
                } else {
                  Fluttertoast.showToast(msg: "초기화 실패");
                }
              },
              child: Text("안전운행")),
          TextButton(
              onPressed: () {
                if (isInit) {
                  DriveRouteData.isSafeDriving = false;
                  context.go("/drivePage");
                } else {
                  Fluttertoast.showToast(msg: "초기화 실패");
                }
              },
              child: Text("경로안내")),
          TextButton(onPressed: finalizeSDK, child: const Text("SDK 종료")),
        ],
      )),
    );
  }
}

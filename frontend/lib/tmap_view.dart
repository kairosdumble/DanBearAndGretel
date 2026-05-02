import 'package:flutter/material.dart';
import 'package:tmap_sdk/tmap_sdk.dart'; // 패키지 이름은 설치한 버전에 따라 다를 수 있음

class TMapView extends StatelessWidget {
  const TMapView({super.key});

  @override
  Widget build(BuildContext context) {
    return TMapWidget(
      onMapCreated: (controller) {
        // 지도가 생성되었을 때 할 일 (예: 현재 위치로 이동)
        controller.setTrackingMode(TrackingMode.Follow); 
      },
    );
  }
}
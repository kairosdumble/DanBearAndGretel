import 'package:tmap_ui_sdk/config/sdk_config.dart';
import 'package:tmap_ui_sdk/config/uisdk_truck_option.dart';

class ConfigCarModel {
  SDKConfig get nomalCar => SDKConfig(
        carType: UISDKCarModel.normal,
        fuelType: UISDKFuel.gas,
        showTrafficAccident: true,
        mapTextSize: UISDKMapFontSize.small,
        nightMode: UISDKAutoNightModeType.auto,
        isUseSpeedReactMapScale: false,
        isShowTrafficInRoute: false,
        isShowExitPopupWhenStopDriving: true,
        useRealTimeAutoReroute: true,
        suspendInBackground: false,
      );

  SDKConfig get truck => SDKConfig(
        carType: UISDKCarModel.truck,
        truckOption: truckOption,
        fuelType: UISDKFuel.diesel,
        showTrafficAccident: true,
        mapTextSize: UISDKMapFontSize.large,
        nightMode: UISDKAutoNightModeType.auto,
        isUseSpeedReactMapScale: true,
        isShowTrafficInRoute: true,
        isShowExitPopupWhenStopDriving: false,
        useRealTimeAutoReroute: true,
        suspendInBackground: false,
      );

  UISDKTruckOption get truckOption => UISDKTruckOption(
        truckHeight: 300,
        // cm
        truckLength: 0,
        truckLoadingWeight: 25000,
        // kg
        truckType: TruckType.constructionTruck,
        truckWidth: 0,
      );
}

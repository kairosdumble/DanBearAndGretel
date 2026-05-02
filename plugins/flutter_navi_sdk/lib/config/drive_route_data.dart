import 'package:tmap_ui_sdk/route/data/planning_option.dart';
import 'package:tmap_ui_sdk/route/data/route_point.dart';
import 'package:tmap_ui_sdk/route/data/route_request_data.dart';

class DriveRouteData {
  static bool isSafeDriving = false;
  static bool isContinueDriving = false;

  RouteRequestData getRouteRequestData() {
    if (isSafeDriving) {
      return RouteRequestData(
        safeDriving: true,
      );
    } else if (!isSafeDriving && isContinueDriving) {
      return RouteRequestData(
        continueDriving: true,
      );
    }



    List<PlanningOption> option = [
      PlanningOption.recommend,
      PlanningOption.generalRoad,
    ];

    RoutePoint start =
        RoutePoint(latitude: 37.564995, longitude: 126.987065, name: "TMOBI");

    RoutePoint dest = RoutePoint(
        latitude: 36.479709, longitude: 127.289804, name: "세종특별자치의회");

    List<RoutePoint> ways = [
      RoutePoint(latitude: 37.201164, longitude: 127.348022, name: "경유지 1"),
      RoutePoint(latitude: 37.102245, longitude: 127.152204, name: "경유지 2")
    ];



    return RouteRequestData(
        wayPoints: ways,
        routeOption: option,
        destination: dest,
        guideWithoutPreview: false);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_navi_sdk/config/config_car.dart';
import 'package:flutter_navi_sdk/config/drive_route_data.dart';
import 'package:flutter_navi_sdk/pages/drive_page.dart';
import 'package:flutter_navi_sdk/pages/root_page.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

void main() => runApp(const Home());

final GoRouter _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (context, state) => const RootPage(), routes: [
    GoRoute(path: 'drivePage', builder: (context, state) => const DrivePage()),
  ])
]);

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          Provider(create: (context) => ConfigCarModel()),
          Provider(create: (context) => DriveRouteData())
        ],
        child: MaterialApp.router(
          title: "NAVI SDK SAMPLE",
          theme: ThemeData(primarySwatch: Colors.blue),
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
        ));
  }
}

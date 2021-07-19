import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_elevation/map_elevation.dart';

import 'data.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.orange,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'map_elevation demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ElevationPoint hoverPoint;

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Stack(children: [
        FlutterMap(
          options: new MapOptions(
            center: LatLng(45.10, 5.48),
            zoom: 11.0,
          ),
          layers: [
            TileLayerOptions(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
            ),
            PolylineLayerOptions(
              // Will only render visible polylines, increasing performance
              polylines: [
                Polyline(
                  // An optional tag to distinguish polylines in callback
                  points: getPoints(),
                  color: Colors.red,
                  strokeWidth: 3.0,
                ),
              ],
            ),
            MarkerLayerOptions(markers: [
              if (hoverPoint is LatLng)
                Marker(
                    point: hoverPoint,
                    width: 8,
                    height: 8,
                    builder: (BuildContext context) => Container(
                          decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8)),
                        ))
            ]),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: Container(
            color: Colors.white.withOpacity(0.6),
            child: NotificationListener<ElevationHoverNotification>(
                onNotification: (ElevationHoverNotification notification) {
                  setState(() {
                    hoverPoint = notification.position;
                  });

                  return true;
                },
                child: Elevation(
                  getPoints(),
                  color: Colors.grey,
                  elevationGradientColors: ElevationGradientColors(
                      gt10: Colors.green,
                      gt20: Colors.orangeAccent,
                      gt30: Colors.redAccent),
                )),
          ),
        )
      ]),
    );
  }
}

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_elevation/map_elevation.dart';

import 'data.dart';

void main() {
  runApp(MyApp());
}

enum ParameterItems {
  elevation("elevation", null),
  feetPose("feetpose", 12),
  pathwidth("pathwidth", 13);

  const ParameterItems(this.label, this.value);
  final String label;
  final int? value;

  static final List<ParameterEntry> entries =
      UnmodifiableListView<ParameterEntry>(
    values.map<ParameterEntry>(
      (ParameterItems item) => ParameterEntry(value: item, label: item.label),
    ),
  );

  List<int> get subTypes {
    switch (this) {
      case ParameterItems.elevation:
        return [-5, -7, -10, -15, 15];
      case ParameterItems.feetPose:
        return [0, 1, 2, 3, 4];

      case ParameterItems.pathwidth:
        return [0, 1, 2, 3, 4];
    }
  }

  Map<int, Color> get colorValueMap {
    switch (this) {
      case ParameterItems.elevation:
        return ElevationGradientColors(
                lt5: Colors.yellow,
                lt7: Colors.orangeAccent,
                lt10: Colors.deepOrangeAccent,
                lt15: Colors.red,
                gt15: Colors.brown
                // gt10: Colors.green,
                // gt20: Colors.orangeAccent,
                // gt30: Colors.redAccent
                )
            .toMapValues();
      case ParameterItems.feetPose:
        return {
          0: Colors.grey,
          1: Colors.blue,
          2: Colors.green,
          3: Colors.orange,
          4: Colors.red
        };
      case ParameterItems.pathwidth:
        return {
          0: Colors.grey,
          1: Colors.green,
          2: Colors.yellow,
          3: Colors.orange,
          4: Colors.red
        };
    }
  }

  Map<String, Color> get colorLabelMap {
    switch (this) {
      case ParameterItems.elevation:
        return ElevationGradientColors(
                lt5: Colors.yellow,
                lt7: Colors.orangeAccent,
                lt10: Colors.deepOrangeAccent,
                lt15: Colors.red,
                gt15: Colors.brown
                // gt10: Colors.green,
                // gt20: Colors.orangeAccent,
                // gt30: Colors.redAccent
                )
            .toMapLabel();
      case ParameterItems.feetPose:
        return {
          "indéfini": Colors.grey,
          "irrégulier": Colors.blue,
          "régulier": Colors.green,
          "technique": Colors.orange,
          "très technique": Colors.red
        };
      case ParameterItems.pathwidth:
        return {
          "indéfini": Colors.grey,
          "single": Colors.green,
          "largeur > 50cm": Colors.yellow,
          "large": Colors.orange,
          "très large": Colors.red
        };
    }
  }
}

typedef ParameterEntry = DropdownMenuEntry<ParameterItems>;

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
      home: MyHomePage(
        title: 'map_elevation demo',
        key: null,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required this.title, super.key});

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
  ElevationPoint? hoverPoint;
  ParameterItems colorParameter = ParameterItems.elevation;

  @override
  Widget build(BuildContext context) {
    final points = getPoints(raw);

    //get legend second  text
    List<String> secondLegendList = [];
    if (colorParameter != ParameterItems.elevation) {
      secondLegendList = getParameterDistributionPercentageString(
          points: points,
          parameter: colorParameter.value!,
          parameterValues: colorParameter.subTypes);
    } else {
      secondLegendList = getElevationDistributionPercentageString(
          points: points, subtypes: [-5, -7, -10, -15, 15]);
    }

    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Stack(children: [
        FlutterMap(
          options: new MapOptions(
            initialCenter: LatLng(45.10, 5.48),
            initialZoom: 11.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
            ),
            PolylineLayer(
              // Will only render visible polylines, increasing performance
              polylines: [
                Polyline(
                  // An optional tag to distinguish polylines in callback
                  points: points,
                  color: Colors.red,
                  strokeWidth: 3.0,
                ),
              ],
            ),
            MarkerLayer(markers: [
              if (hoverPoint != null)
                Marker(
                    point: hoverPoint!.latLng,
                    width: 8,
                    height: 8,
                    child: Container(
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
          height: 300,
          child: Container(
            color: Colors.white.withValues(alpha: 0.6),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownMenu<ParameterItems>(
                    inputDecorationTheme: InputDecorationTheme(
                        filled: true, fillColor: Colors.white),
                    menuStyle: MenuStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.white)),
                    initialSelection: ParameterItems.elevation,
                    dropdownMenuEntries: ParameterItems.entries,
                    onSelected: ((ParameterItems? parameter) {
                      setState(() {
                        colorParameter = parameter!;
                      });
                    }),
                  ),
                ),
                SizedBox(
                  height: 120,
                  width: MediaQuery.of(context).size.width,
                  child: NotificationListener<ElevationHoverNotification>(
                      onNotification:
                          (ElevationHoverNotification notification) {
                        setState(() {
                          hoverPoint = notification.position;
                        });

                        return true;
                      },
                      child: Elevation(
                          totalDistance: 51000,
                          parameterUsedToColor: colorParameter.value,
                          points,
                          color: Color(0xFF172033),
                          parameterValuesAndColorsMap:
                              colorParameter.colorValueMap)),
                ),
                ElevationLegend(
                  columns: 2,
                  parameterLabelAndColorsMap: colorParameter.colorLabelMap,
                  secondLegendTextList: [], //secondLegendList,
                )
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

library map_elevation;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart' as lg;

/// Elevation statefull widget
class Elevation extends StatefulWidget {
  /// List of points to draw on elevation widget
  /// Lat and Long are required to emit notification on hover
  final List<ElevationPoint> points;

  /// Background color of the elevation graph
  final Color? color;

  /// Elevation gradient colors
  /// See [ElevationGradientColors] for more details
  final ElevationGradientColors? elevationGradientColors;

  /// [WidgetBuilder] like Function to add child over the graph
  final Function(BuildContext context, Size size)? child;

  Elevation(this.points,
      {this.color, this.elevationGradientColors, this.child});

  @override
  State<StatefulWidget> createState() => _ElevationState();
}

class _ElevationState extends State<Elevation> {
  double? _hoverLinePosition;
  double? _hoveredAltitude;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints bc) {
      Offset _lbPadding = Offset(35, 6);
      _ElevationPainter elevationPainter = _ElevationPainter(widget.points,
          paintColor: widget.color ?? Colors.transparent,
          elevationGradientColors: widget.elevationGradientColors,
          lbPadding: _lbPadding);
      return GestureDetector(
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            final pointFromPosition = elevationPainter
                .getPointFromPosition(details.globalPosition.dx);

            if (pointFromPosition != null) {
              ElevationHoverNotification(pointFromPosition)..dispatch(context);
              setState(() {
                _hoverLinePosition = details.globalPosition.dx;
                _hoveredAltitude = pointFromPosition.altitude;
              });
            }
          },
          onHorizontalDragEnd: (DragEndDetails details) {
            ElevationHoverNotification(null)..dispatch(context);
            setState(() {
              _hoverLinePosition = null;
            });
          },
          child: Stack(children: <Widget>[
            CustomPaint(
              painter: elevationPainter,
              size: Size(bc.maxWidth, bc.maxHeight),
            ),
            if (widget.child != null && widget.child is Function)
              Container(
                margin: EdgeInsets.only(left: _lbPadding.dx),
                width: bc.maxWidth - _lbPadding.dx,
                height: bc.maxHeight - _lbPadding.dy,
                child: Builder(
                    builder: (BuildContext context) => widget.child!(
                        context,
                        Size(bc.maxWidth - _lbPadding.dx,
                            bc.maxHeight - _lbPadding.dy))),
              ),
            if (_hoverLinePosition != null)
              Positioned(
                left: _hoverLinePosition,
                top: 0,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        height: bc.maxHeight,
                        width: 1,
                        decoration: BoxDecoration(color: Colors.black),
                      ),
                      if (_hoveredAltitude != null)
                        Text(
                          _hoveredAltitude!.round().toString(),
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        )
                    ]),
              )
          ]));
    });
  }
}

class _ElevationPainter extends CustomPainter {
  List<ElevationPoint> points;
  late List<double> _relativeAltitudes;
  Color paintColor;
  Offset lbPadding;
  late int _min, _max;
  late double widthOffset;
  ElevationGradientColors? elevationGradientColors;

  _ElevationPainter(this.points,
      {required this.paintColor,
      this.lbPadding = Offset.zero,
      this.elevationGradientColors}) {
    _min = (points.map((point) => point.altitude).toList().reduce(min) / 100)
            .floor() *
        100;
    _max = (points.map((point) => point.altitude).toList().reduce(max) / 100)
            .ceil() *
        100;

    _relativeAltitudes =
        points.map((point) => (point.altitude - _min) / (_max - _min)).toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);

    final paint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.src
      ..style = PaintingStyle.fill
      ..color = paintColor;
    final axisPaint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.src
      ..style = PaintingStyle.stroke;

    if (elevationGradientColors != null) {
      List<Color> gradientColors = [paintColor];
      for (int i = 1; i < points.length; i++) {
        double dX = lg.Distance().distance(points[i], points[i - 1]);
        double dZ = (points[i].altitude - points[i - 1].altitude);

        double gradient = 100 * dZ / dX;
        if (gradient > 30) {
          gradientColors.add(elevationGradientColors!.gt30);
        } else if (gradient > 20) {
          gradientColors.add(elevationGradientColors!.gt20);
        } else if (gradient > 10) {
          gradientColors.add(elevationGradientColors!.gt10);
        } else {
          gradientColors.add(paintColor);
        }
      }

      paint.shader = ui.Gradient.linear(
          Offset(lbPadding.dx, 0),
          Offset(size.width, 0),
          gradientColors,
          _calculateColorsStop(gradientColors));
    }

    canvas.saveLayer(rect, Paint());

    widthOffset = (size.width - lbPadding.dx) / _relativeAltitudes.length;

    final path = Path()
      ..moveTo(lbPadding.dx, _getYForAltitude(_relativeAltitudes[0], size));
    _relativeAltitudes.asMap().forEach((int index, double altitude) {
      path.lineTo(
          index * widthOffset + lbPadding.dx, _getYForAltitude(altitude, size));
    });
    path.lineTo(size.width, size.height - lbPadding.dy);
    path.lineTo(lbPadding.dx, size.height - lbPadding.dy);

    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(lbPadding.dx, 0),
        Offset(lbPadding.dx, size.height - lbPadding.dy), axisPaint);

    int roundedAltitudeDiff = _max.ceil() - _min.floor();
    int axisStep = max(100, (roundedAltitudeDiff / 5).round());

    List<double>.generate((roundedAltitudeDiff / axisStep).round(),
        (i) => (axisStep * i + _min).toDouble()).forEach((altitude) {
      double relativeAltitude = (altitude - _min) / (_max - _min);
      canvas.drawLine(
          Offset(lbPadding.dx, _getYForAltitude(relativeAltitude, size)),
          Offset(lbPadding.dx + 10, _getYForAltitude(relativeAltitude, size)),
          axisPaint);
      TextPainter(
          text: TextSpan(
              style: TextStyle(color: Colors.black, fontSize: 10),
              text: altitude.toInt().toString()),
          textDirection: TextDirection.ltr)
        ..layout()
        ..paint(
            canvas, Offset(5, _getYForAltitude(relativeAltitude, size) - 5));
    });

    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;

  double _getYForAltitude(double altitude, Size size) =>
      size.height - altitude * size.height - lbPadding.dy;

  ElevationPoint? getPointFromPosition(double position) {
    int index = ((position - lbPadding.dx) / widthOffset).round();

    if (index >= points.length || index < 0) return null;

    return points[index];
  }

  List<double> _calculateColorsStop(List gradientColors) {
    final colorsStopInterval = 1.0 / gradientColors.length;
    return List.generate(
        gradientColors.length, (index) => index * colorsStopInterval);
  }
}

/// [Notification] emitted when graph is hovered
class ElevationHoverNotification extends Notification {
  /// Hovered point coordinates
  final ElevationPoint? position;

  ElevationHoverNotification(this.position);
}

/// Elevation gradient colors
/// Not color is used when gradient is < 10% (graph background color is used [Elevation.color])
class ElevationGradientColors {
  /// Used when elevation gradient is > 10%
  final Color gt10;

  /// Used when elevation gradient is > 20%
  final Color gt20;

  /// Used when elevation gradient is > 30%
  final Color gt30;

  ElevationGradientColors(
      {required this.gt10, required this.gt20, required this.gt30});
}

/// Geographic point with elevation
class ElevationPoint extends lg.LatLng {
  /// Altitude (in meters)
  double altitude;

  ElevationPoint(double latitude, double longitude, this.altitude)
      : super(latitude, longitude);

  lg.LatLng get latLng => this;
}

library map_elevation;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as lg;
import 'package:units_converter/models/extension_converter.dart';
import 'package:units_converter/properties/length.dart';

import 'elevation_point.dart';

export 'elevation_functions.dart';
export 'elevation_legend.dart';
export 'elevation_point.dart';

/// Elevation statefull widget
class Elevation extends StatefulWidget {
  /// List of points to draw on elevation widget
  /// Lat and Long are required to emit notification on hover
  /// A Parameter argument can be added to color the graph, See [ElevationPoint.parameters]
  final List<ElevationPoint> points;

  /// Background color of the elevation graph
  final Color? color;

  /// Map of of the values the parameter can take and the color associated
  /// Note : If you just want to color your graph according to the elevation, you can simply pass :
  /// ElevationGradientColors.toMap()
  final Map<int, Color>? parameterValuesAndColorsMap;

  ///The value of the parameter used to color the graph, if null, it means the elevation is used to color the graph
  final int? parameterUsedToColor;

  /// Color of the scale
  final Color? scaleColor;

  /// Color of the dashed altitudes lines
  final Color? dashedAltitudesColor;

  /// Style of the scale items label
  final TextStyle? scaleTextStyle;

  /// Total distance of route
  final num? totalDistance;

  final double? progression;

  /// [WidgetBuilder] like Function to add child over the graph
  final Function(BuildContext context, Size size)? child;

  /// Unit used to display the altitude/distance, can be meters or feet.
  final LENGTH unit;

  final List<List<ElevationPoint>>? groupedElevationPoints;

  Elevation(this.points,
      {this.color,
      this.parameterValuesAndColorsMap,
      this.child,
      this.parameterUsedToColor,
      this.scaleColor,
      this.dashedAltitudesColor,
      this.scaleTextStyle,
      this.totalDistance,
      this.progression,
      this.unit = LENGTH.meters,
      this.groupedElevationPoints});

  @override
  State<StatefulWidget> createState() => _ElevationState();
}

class _ElevationState extends State<Elevation> {
  double? _hoverLinePosition;
  double? _hoveredAltitude;

  @override
  Widget build(BuildContext context) {
    const progressionWidth = 20.0;

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints bc) {
      Offset _lbPadding = Offset(35, 10);
      _ElevationPainter elevationPainter = _ElevationPainter(widget.points,
          unit: widget.unit,
          paintColor: widget.color ?? Colors.transparent,
          parameter: widget.parameterUsedToColor,
          parametersColors: widget.parameterValuesAndColorsMap,
          scaleTextStyle: widget.scaleTextStyle,
          scaleColor: widget.scaleColor,
          dashedAltitudesColor: widget.dashedAltitudesColor,
          totalDistance: widget.totalDistance,
          lbPadding: _lbPadding,
          groupedElevationPoints: widget.groupedElevationPoints);

      return GestureDetector(
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            final pointFromPosition = elevationPainter
                .getPointFromPosition(details.globalPosition.dx);

            if (pointFromPosition != null) {
              ElevationHoverNotification(pointFromPosition)..dispatch(context);
              setState(() {
                _hoverLinePosition = details.globalPosition.dx;
                _hoveredAltitude = pointFromPosition.altitude
                    .convertFromTo(LENGTH.meters, widget.unit);
              });
            }
          },
          onHorizontalDragEnd: (DragEndDetails details) {
            ElevationHoverNotification(null)
              ..dispatch(context); //on the local file, just one point ?
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
            if (widget.progression != null)
              Positioned(
                left: _lbPadding.dx +
                    widget.progression! * (bc.maxWidth - _lbPadding.dx) -
                    progressionWidth / 2,
                top: 0,
                width: progressionWidth,
                child: Column(
                  children: [
                    Text(
                      "${widget.progression! * 100 ~/ 1}%",
                      style: const TextStyle(
                          fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Container(
                      height: bc.maxHeight,
                      width: 2,
                      decoration: const BoxDecoration(color: Color(0xFF172033)),
                    ),
                  ],
                ),
              ),
            if (_hoverLinePosition != null)
              Builder(
                builder: (context) {
                  // Estimate tooltip width based on text length
                  final String altitudeText = _hoveredAltitude != null
                      ? _hoveredAltitude!.round().toString()
                      : "0";
                  final double estimatedWidth =
                      altitudeText.length * 8.0 + 10.0;

                  // Check if tooltip would go beyond the right edge
                  final bool isNearRightEdge =
                      _hoverLinePosition! + estimatedWidth > bc.maxWidth;

                  // Position the vertical line
                  return Stack(
                    children: [
                      // Vertical line
                      Positioned(
                        left: _hoverLinePosition,
                        top: 0,
                        child: Container(
                          height: bc.maxHeight,
                          width: 1,
                          decoration: BoxDecoration(color: Colors.black),
                        ),
                      ),
                      // Tooltip
                      if (_hoveredAltitude != null)
                        Positioned(
                          // If near right edge, position tooltip to the left of the line
                          left: isNearRightEdge
                              ? _hoverLinePosition! - estimatedWidth
                              : _hoverLinePosition,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text(
                              altitudeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ]));
    });
  }
}

class _ElevationPainter extends CustomPainter {
  /// List of points to draw on elevation widget
  List<ElevationPoint> points;
  late List<double> _relativeAltitudes;

  /// Main color used to paint under the elevation line in the graph
  Color paintColor;
  TextStyle? scaleTextStyle;
  Color? scaleColor;
  Color? dashedAltitudesColor;
  Offset lbPadding;
  late int _min, _max;
  late double widthOffset;
  num? totalDistance;
  List<List<ElevationPoint>>? groupedElevationPoints;
  LENGTH unit;

  /// Map of of the values the parameter can take and the color associated
  Map<int, Color>? parametersColors;

  /// The parameter chosen to color the graph, if null, it means the elevation is used to color the graph
  int? parameter;

  // TODO Pass this as parameters !
  bool dashedAltitudes = true;
  bool scaleAltitudesMarks = false;

  bool altitudeScaleLineVisible = false;
  bool withDistanceScale = true;

  _ElevationPainter(this.points,
      {required this.paintColor,
      required this.unit,
      this.lbPadding = Offset.zero,
      this.parametersColors,
      this.parameter,
      this.scaleTextStyle,
      this.dashedAltitudesColor,
      this.totalDistance,
      this.scaleColor,
      this.groupedElevationPoints}) {
    final allPoints =
        groupedElevationPoints?.expand((e) => e).toList() ?? points;
    final mapPointsAltitudesWithCurrentUnit = allPoints
        .map((point) => point.altitude.convertFromTo(LENGTH.meters, unit) ?? 0);

    if (mapPointsAltitudesWithCurrentUnit.isEmpty) {
      _min = 0;
      _max = 0;
      _relativeAltitudes = [];
      return;
    }
    _min = (mapPointsAltitudesWithCurrentUnit.reduce(min) / 100).floor() * 100;
    _max = (mapPointsAltitudesWithCurrentUnit.reduce(max) / 100).ceil() * 100;

    _relativeAltitudes = mapPointsAltitudesWithCurrentUnit
        .map((altitude) => (altitude - _min) / (_max - _min))
        .toList();
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

    _drawAltitudeMarks(canvas, size);
    canvas.saveLayer(rect, Paint());

    widthOffset = (size.width - lbPadding.dx) / (_relativeAltitudes.length - 1);

    // Create a list of segments to draw, whether from grouped points or a single list
    List<List<ElevationPoint>> segments = [];
    if (groupedElevationPoints != null) {
      segments = groupedElevationPoints!;
    } else {
      segments = [points];
    }

    int currentIndex = 0;
    for (final segment in segments) {
      if (segment.isEmpty) continue;

      // Get relative altitudes for this segment
      final segmentRelativeAltitudes = segment
          .map((point) =>
              (point.altitude.convertFromTo(LENGTH.meters, unit)! - _min) /
              (_max - _min))
          .toList();

      final path = Path();

      // Start the path
      path.moveTo(currentIndex * widthOffset + lbPadding.dx,
          _getYForAltitude(segmentRelativeAltitudes[0], size));

      // Draw lines for this segment
      for (var i = 0; i < segment.length; i++) {
        path.lineTo((currentIndex + i) * widthOffset + lbPadding.dx,
            _getYForAltitude(segmentRelativeAltitudes[i], size));
      }

      // Complete the path to the bottom
      final lastPointX =
          (currentIndex + segment.length - 1) * widthOffset + lbPadding.dx;

      path.lineTo(lastPointX, size.height - lbPadding.dy);
      path.lineTo(currentIndex * widthOffset + lbPadding.dx,
          size.height - lbPadding.dy);
      path.close();

      paint.shader = _createGradientShader(size, segment);
      canvas.drawPath(path, paint);

      // Only increment index if we're processing grouped points
      if (groupedElevationPoints != null) {
        currentIndex += segment.length;
      }
    }

    final scaleTextStyleOrDefault =
        scaleTextStyle ?? const TextStyle(color: Colors.black, fontSize: 10);

    if (withDistanceScale && totalDistance != null) {
      const minimumSpaceBetweenDistanceScaleSegmentKilometersMarks = 30;
      final totalDistanceInCurrentLargestUnit = (totalDistance!.convertFromTo(
              LENGTH.meters,
              unit == LENGTH.meters ? LENGTH.kilometers : LENGTH.miles) ??
          0);
      // We display the 0 so we add one segment
      final numberOfScaleSegments =
          totalDistanceInCurrentLargestUnit.floor() + 1;
      var distanceBetweenScaleSegments = size.width ~/ numberOfScaleSegments;
      var displayEveryNSegments = 1;

      while ((displayEveryNSegments * distanceBetweenScaleSegments) <=
          minimumSpaceBetweenDistanceScaleSegmentKilometersMarks) {
        displayEveryNSegments = displayEveryNSegments + 1;
      }

      // If number is round, we keep it short form, otherwise, we keep it with 1 single digit after the ,
      var largestScaleLabel =
          totalDistanceInCurrentLargestUnit.roundToDouble() ==
                  totalDistanceInCurrentLargestUnit
              ? totalDistanceInCurrentLargestUnit
              : num.parse(totalDistanceInCurrentLargestUnit.toStringAsFixed(1));

      if (numberOfScaleSegments >= 1) {
        // Should be between 0 and 1 km
        for (var i = 0;
            i <= numberOfScaleSegments;
            i += displayEveryNSegments) {
          final relativeHorizontalPosition = (i / largestScaleLabel);
          final xPosition = lbPadding.dx +
              (size.width - lbPadding.dx) * relativeHorizontalPosition;
          TextPainter(
              text:
                  TextSpan(style: scaleTextStyleOrDefault, text: i.toString()),
              textDirection: TextDirection.ltr)
            ..layout()
            ..paint(
                canvas,
                Offset(
                    // 2.5 is arbitrary here, as a 80/20 to consider "text width" and center text
                    xPosition - 2.5,
                    size.height -
                        (scaleTextStyleOrDefault.fontSize!.toDouble() * 1.2)));
        }
      }
    }

    canvas.restore();
  }

  void _drawAltitudeMarks(Canvas canvas, Size size) {
    int roundedAltitudeDiff = _max.ceil() - _min.floor();
    int axisStep = max(100, (roundedAltitudeDiff / 5).round());

    final scaleTextStyleOrDefault =
        scaleTextStyle ?? const TextStyle(color: Colors.black, fontSize: 10);

    final axisPaint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.src
      ..style = PaintingStyle.stroke;

    for (var altitude in List<double>.generate(
        (roundedAltitudeDiff / axisStep).round(),
        (i) => (axisStep * i + _min).toDouble())) {
      double relativeAltitude = (altitude - _min) / (_max - _min);
      if (dashedAltitudes) {
        double dashWidth = 4, dashSpace = 5, startX = 0;
        final paint = Paint()
          ..color = dashedAltitudesColor ?? Colors.grey
          ..strokeWidth = 1;
        // Paint
        while (startX < size.width) {
          canvas.drawLine(
              Offset(lbPadding.dx + startX,
                  _getYForAltitude(relativeAltitude, size)),
              Offset(lbPadding.dx + startX + dashWidth,
                  _getYForAltitude(relativeAltitude, size)),
              paint);
          startX += dashWidth + dashSpace;
        }
      }

      if (scaleAltitudesMarks) {
        canvas.drawLine(
            Offset(lbPadding.dx, _getYForAltitude(relativeAltitude, size)),
            Offset(lbPadding.dx + 10, _getYForAltitude(relativeAltitude, size)),
            axisPaint);
      }

      // Paint altitudes text (Eg. 2600 ft)
      TextPainter(
          text: TextSpan(
              style: scaleTextStyleOrDefault,
              text:
                  '${altitude.toInt().toString()} ${unit == LENGTH.meters ? "m" : "ft"}'),
          textDirection: TextDirection.ltr)
        ..layout()
        ..paint(
            canvas,
            Offset(
                0,
                _getYForAltitude(relativeAltitude, size) -
                    scaleTextStyleOrDefault.fontSize!.toDouble()));
    }

    if (altitudeScaleLineVisible) {
      canvas.drawLine(Offset(lbPadding.dx, 0),
          Offset(lbPadding.dx, size.height - lbPadding.dy), axisPaint);
    }
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

  ui.Gradient? _createGradientShader(
      Size size, List<ElevationPoint> groupPoints) {
    List<Color> gradientColors = [];

    //Painter when elevation is used to color the graph
    if (parametersColors != null && parameter == null) {
      gradientColors = _calculateGradientColorsForElevation(points);
    }

    //Painter when a parameter is used to color the graph
    if (parametersColors != null && parameter != null) {
      gradientColors = _calculateGradientColorsForParameter(points);
    }

    //Create the gradient
    if (gradientColors.isNotEmpty) {
      int n = gradientColors.length;
      List<Color> discreteColors = [];
      List<double> stops = [];
      for (int i = 0; i < n; i++) {
        discreteColors.add(gradientColors[i]);
        discreteColors.add(gradientColors[i]);
        stops.add(i / n);
        stops.add((i + 1) / n);
      }
      return ui.Gradient.linear(Offset(lbPadding.dx, 0), Offset(size.width, 0),
          discreteColors, stops);
    }
    return null;
  }

  List<Color> _calculateGradientColorsForElevation(
      List<ElevationPoint> groupPoints) {
    // Helper function to determine color based on gradient
    Color _getColorForGradient(double gradient) {
      if (gradient >= 30 && parametersColors!.containsKey(30)) {
        return parametersColors![30]!;
      } else if (gradient >= 20 && parametersColors!.containsKey(20)) {
        return parametersColors![20]!;
      } else if (gradient >= 15 && parametersColors!.containsKey(15)) {
        return parametersColors![15]!;
      } else if (gradient >= 10 && parametersColors!.containsKey(10)) {
        return parametersColors![10]!;
      } else if (gradient <= 5 && parametersColors!.containsKey(-5)) {
        return parametersColors![-5]!;
      } else if (gradient <= 7 && parametersColors!.containsKey(-7)) {
        return parametersColors![-7]!;
      } else if (gradient <= 10 && parametersColors!.containsKey(-10)) {
        return parametersColors![-10]!;
      } else if (gradient <= 15 && parametersColors!.containsKey(-15)) {
        return parametersColors![-15]!;
      } else {
        return paintColor;
      }
    }

    List<Color> gradientColors = [];

    // Handle empty list or single point
    if (groupPoints.isEmpty) {
      return [];
    } else if (groupPoints.length == 1) {
      return [paintColor];
    }

    // Handle the case differently - one color per segment, not per point
    for (int i = 0; i < groupPoints.length - 1; i++) {
      // Calculate gradient between this point and the next
      double dX =
          (const lg.Distance().distance(groupPoints[i + 1], groupPoints[i]))
                  .convertFromTo(LENGTH.meters, unit) ??
              0;
      double dZ = ((groupPoints[i + 1]
                  .altitude
                  .convertFromTo(LENGTH.meters, unit) ??
              0) -
          (groupPoints[i].altitude.convertFromTo(LENGTH.meters, unit) ?? 0));

      double gradient = dX > 0 ? 100 * dZ / dX : 0;
      gradientColors.add(_getColorForGradient(gradient));
    }

    // For the last point, use the same color as the last segment
    gradientColors.add(gradientColors.last);

    return gradientColors;
  }

  List<Color> _calculateGradientColorsForParameter(
      List<ElevationPoint> groupPoints) {
    List<Color> gradientColors = [];
    Color? colorTypeSet;

    // Process each point
    for (int i = 0; i < groupPoints.length; i++) {
      bool parameterFound = false;

      // Check if the point has the wanted parameter type
      if (groupPoints[i].parameters.isNotEmpty) {
        for (int j = 0; j < groupPoints[i].parameters.length; j++) {
          if (groupPoints[i].parameters[j]["type"] == parameter) {
            // Get the correct color according to the subtype
            Color pointColor =
                parametersColors![groupPoints[i].parameters[j]["sub_type"]]!;
            gradientColors.add(pointColor);
            // Save color for the next points
            colorTypeSet = pointColor;
            parameterFound = true;
            break;
          }
        }
      }

      // If no matching parameter found, use the last color set or default
      if (!parameterFound) {
        gradientColors.add(colorTypeSet ?? paintColor);
      }
    }

    return gradientColors;
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
  final Color? gt10;

  /// Used when elevation gradient is > 20%
  final Color? gt20;

  /// Used when elevation gradient is > 30%
  final Color? gt30;

  ///used when elevation gradient is < 5%
  final Color? lt5;

  ///used when elevation gradient is < 7%
  final Color? lt7;

  ///Used when elevation gradient is < 10%
  final Color? lt10;

  ///Used when elevation gradient is < 15%
  final Color? lt15;

  ///Used when elevation gradient is > 15%
  final Color? gt15;

  ElevationGradientColors(
      {this.lt5,
      this.lt7,
      this.lt10,
      this.lt15,
      this.gt15,
      this.gt10,
      this.gt20,
      this.gt30});

  Map<int, Color> toMapValues() {
    return {
      if (gt10 != null) 10: gt10!,
      if (gt20 != null) 20: gt20!,
      if (gt30 != null) 30: gt30!,
      if (lt5 != null) -5: lt5!,
      if (lt7 != null) -7: lt7!,
      if (lt10 != null) -10: lt10!,
      if (lt15 != null) -15: lt15!,
      if (gt15 != null) 15: gt15!,
    };
  }

  Map<String, Color> toMapLabel() {
    return {
      if (gt10 != null) "Pentes >10%": gt10!,
      if (gt20 != null) "Pentes >20%": gt20!,
      if (gt30 != null) "Pentes >30%": gt30!,
      if (lt5 != null) "Pentes <5%": lt5!,
      if (lt7 != null) "Pentes <7%": lt7!,
      if (lt10 != null) "Pentes <10%": lt10!,
      if (lt15 != null) "Pentes <15%": lt15!,
      if (gt15 != null) "Pentes >15%": gt15!,
    };
  }
}

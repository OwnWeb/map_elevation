library map_elevation;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as lg;
import 'package:units_converter/models/extension_converter.dart';
import 'package:units_converter/properties/length.dart';

import 'elevation_point.dart';

export 'elevation_functions.dart';
export 'elevation_legend.dart';
export 'elevation_point.dart';

/// Room kept on the left for the altitude labels.
const double _kAltitudeScaleWidth = 35;

/// The altitude scale labels every hundred, and aims for that many marks.
const int _kAltitudeScaleStep = 100;
const int _kAltitudeScaleMarkCount = 5;
const double _kAltitudeMarkLength = 10;
const double _kDashWidth = 4;
const double _kDashSpace = 5;

/// The distance labels sit in the bottom band, and need their own leading in it.
const double _kDistanceLabelLeading = 1.4;

/// Defaults for the ridge line and the markers pinned on it.
const double _kDefaultStrokeWidth = 1.4;
const double _kDefaultMarkerRadius = 2.4;
const double _kDefaultMarkerStrokeWidth = 1.3;

const TextStyle _kDefaultScaleTextStyle =
    TextStyle(color: Colors.black, fontSize: 10);

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

  /// Whether the altitude scale is drawn: the labels on the left and the dashed
  /// lines across. Hidden, the track uses the full height instead of a range
  /// rounded to hundreds, and the room kept on the left goes back to the graph.
  final bool showAltitudeScale;

  /// The line drawn on the ridge, over the filled area. None when null.
  final ElevationStroke? stroke;

  /// Round dots pinned on the ridge, at chosen points. None when null.
  final ElevationMarkers? markers;

  /// The drag line and its altitude label. Black, as before, when null.
  final Color? hoverColor;

  /// Text of the last mark of the distance scale, which carries the whole
  /// length of the track. The plugin cannot localise a decimal separator, so a
  /// caller that cares passes its own. Trimmed to one decimal when null.
  final String? totalDistanceLabel;

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
      this.groupedElevationPoints,
      this.showAltitudeScale = true,
      this.stroke,
      this.markers,
      this.hoverColor,
      this.totalDistanceLabel});

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
      final double scaleFontSize = widget.scaleTextStyle?.fontSize ??
          _kDefaultScaleTextStyle.fontSize!;
      Offset _lbPadding = Offset(
          widget.showAltitudeScale ? _kAltitudeScaleWidth : 0,
          scaleFontSize * _kDistanceLabelLeading);
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
          showAltitudeScale: widget.showAltitudeScale,
          stroke: widget.stroke,
          markers: widget.markers,
          totalDistanceLabel: widget.totalDistanceLabel,
          groupedElevationPoints: widget.groupedElevationPoints);

      return GestureDetector(
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            final pointFromPosition = elevationPainter
                .getPointFromPosition(details.localPosition.dx);

            if (pointFromPosition != null) {
              ElevationHoverNotification(pointFromPosition)..dispatch(context);
              setState(() {
                _hoverLinePosition = details.localPosition.dx;
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
                          decoration: BoxDecoration(
                              color: widget.hoverColor ?? Colors.black),
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
                                color: widget.hoverColor,
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
  late double _min, _max;
  late double widthOffset;
  num? totalDistance;
  List<List<ElevationPoint>>? groupedElevationPoints;
  LENGTH unit;

  /// Map of of the values the parameter can take and the color associated
  Map<int, Color>? parametersColors;

  /// The parameter chosen to color the graph, if null, it means the elevation is used to color the graph
  int? parameter;

  final bool showAltitudeScale;
  final ElevationStroke? stroke;
  final ElevationMarkers? markers;
  final String? totalDistanceLabel;

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
      this.groupedElevationPoints,
      this.showAltitudeScale = true,
      this.stroke,
      this.markers,
      this.totalDistanceLabel}) {
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
    final double lowest = mapPointsAltitudesWithCurrentUnit.reduce(min);
    final double highest = mapPointsAltitudesWithCurrentUnit.reduce(max);

    // The scale labels whole steps, so its range has to land on them. Without
    // it, rounding only costs the track the height it could have used.
    _min = showAltitudeScale
        ? (lowest / _kAltitudeScaleStep).floor() *
            _kAltitudeScaleStep.toDouble()
        : lowest;
    _max = showAltitudeScale
        ? (highest / _kAltitudeScaleStep).ceil() * _kAltitudeScaleStep.toDouble()
        : highest;

    // A flat track would divide by zero and paint nothing but NaN.
    if (_max == _min) _max = _min + _kAltitudeScaleStep;

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

    if (showAltitudeScale) _drawAltitudeMarks(canvas, size);
    canvas.saveLayer(rect, Paint());

    widthOffset = (size.width - lbPadding.dx) / (_relativeAltitudes.length - 1);

    // Create a list of segments to draw, whether from grouped points or a single list
    List<List<ElevationPoint>> segments = [];
    if (groupedElevationPoints != null) {
      segments = groupedElevationPoints!;
    } else {
      segments = [points];
    }

    final List<Path> ridgePaths = [];

    int currentIndex = 0;
    for (final segment in segments) {
      if (segment.isEmpty) continue;

      // Get relative altitudes for this segment
      final segmentRelativeAltitudes = segment
          .map((point) =>
              (point.altitude.convertFromTo(LENGTH.meters, unit)! - _min) /
              (_max - _min))
          .toList();

      final ridge = Path();

      // Start the path
      ridge.moveTo(currentIndex * widthOffset + lbPadding.dx,
          _getYForAltitude(segmentRelativeAltitudes[0], size));

      // Draw lines for this segment
      for (var i = 0; i < segment.length; i++) {
        ridge.lineTo((currentIndex + i) * widthOffset + lbPadding.dx,
            _getYForAltitude(segmentRelativeAltitudes[i], size));
      }

      // Complete the path to the bottom
      final lastPointX =
          (currentIndex + segment.length - 1) * widthOffset + lbPadding.dx;

      final area = Path.from(ridge)
        ..lineTo(lastPointX, size.height - lbPadding.dy)
        ..lineTo(currentIndex * widthOffset + lbPadding.dx,
            size.height - lbPadding.dy)
        ..close();

      paint.shader = _createGradientShader(size, segment);
      canvas.drawPath(area, paint);
      ridgePaths.add(ridge);

      // Only increment index if we're processing grouped points
      if (groupedElevationPoints != null) {
        currentIndex += segment.length;
      }
    }

    _drawRidgeStroke(canvas, ridgePaths);
    _drawMarkers(canvas, size);

    final scaleTextStyleOrDefault = scaleTextStyle ?? _kDefaultScaleTextStyle;

    if (withDistanceScale && totalDistance != null) {
      _drawDistanceScale(canvas, size, scaleTextStyleOrDefault);
    }

    canvas.restore();
  }

  void _drawDistanceScale(Canvas canvas, Size size, TextStyle scaleTextStyle) {
    const double minimumSpaceBetweenMarks = 30;

    final double total = (totalDistance!.convertFromTo(LENGTH.meters,
                unit == LENGTH.meters ? LENGTH.kilometers : LENGTH.miles) ??
            0)
        .toDouble();
    if (total <= 0) return;

    final int lastWholeMark = total.floor();

    // The zero counts as a mark when spacing them out.
    final int spaceBetweenMarks = size.width ~/ (lastWholeMark + 1);
    if (spaceBetweenMarks == 0) return;

    var displayEveryNMarks = 1;
    while (displayEveryNMarks * spaceBetweenMarks <= minimumSpaceBetweenMarks) {
      displayEveryNMarks++;
    }

    final double plotWidth = size.width - lbPadding.dx;
    final double y =
        size.height - scaleTextStyle.fontSize! * _kDistanceLabelLeading;
    double xOf(num value) => lbPadding.dx + plotWidth * (value / total);

    final double totalX = xOf(total);

    for (var mark = 0; mark <= lastWholeMark; mark += displayEveryNMarks) {
      final double x = xOf(mark);

      // The total always keeps its mark; a whole one crowding it is dropped.
      if (mark > 0 && totalX - x < minimumSpaceBetweenMarks) continue;

      _paintScaleLabel(canvas, size, '$mark', x, y, scaleTextStyle);
    }

    _paintScaleLabel(canvas, size, totalDistanceLabel ?? _trimmedTotal(total),
        totalX, y, scaleTextStyle);
  }

  /// One decimal, and no trailing zero on a round distance.
  String _trimmedTotal(double total) {
    final String fixed = total.toStringAsFixed(1);

    return fixed.endsWith('.0')
        ? fixed.substring(0, fixed.length - 2)
        : fixed;
  }

  void _paintScaleLabel(Canvas canvas, Size size, String label, double x,
      double y, TextStyle style) {
    final painter = TextPainter(
        text: TextSpan(style: style, text: label),
        textDirection: TextDirection.ltr)
      ..layout();

    // Centred on its own mark, but never off the canvas: with no altitude
    // scale keeping room on the left, the first mark sits on x = 0.
    final double left = (x - painter.width / 2)
        .clamp(0.0, max(0.0, size.width - painter.width));

    painter.paint(canvas, Offset(left, y));
  }

  void _drawAltitudeMarks(Canvas canvas, Size size) {
    final int roundedAltitudeDiff = _max.ceil() - _min.floor();
    final int axisStep = max(_kAltitudeScaleStep,
        (roundedAltitudeDiff / _kAltitudeScaleMarkCount).round());

    final scaleTextStyleOrDefault = scaleTextStyle ?? _kDefaultScaleTextStyle;

    final axisPaint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.src
      ..style = PaintingStyle.stroke;

    for (final altitude in List<double>.generate(
        (roundedAltitudeDiff / axisStep).round(),
        (i) => axisStep * i + _min)) {
      final double relativeAltitude = (altitude - _min) / (_max - _min);
      final double y = _getYForAltitude(relativeAltitude, size);

      if (dashedAltitudes) _drawDashedAltitudeLine(canvas, size, y);

      if (scaleAltitudesMarks) {
        canvas.drawLine(Offset(lbPadding.dx, y),
            Offset(lbPadding.dx + _kAltitudeMarkLength, y), axisPaint);
      }

      // Paint altitudes text (Eg. 2600 ft)
      TextPainter(
          text: TextSpan(
              style: scaleTextStyleOrDefault,
              text:
                  '${altitude.toInt()} ${unit == LENGTH.meters ? "m" : "ft"}'),
          textDirection: TextDirection.ltr)
        ..layout()
        ..paint(canvas, Offset(0, y - scaleTextStyleOrDefault.fontSize!));
    }

    if (altitudeScaleLineVisible) {
      canvas.drawLine(Offset(lbPadding.dx, 0),
          Offset(lbPadding.dx, size.height - lbPadding.dy), axisPaint);
    }
  }

  void _drawDashedAltitudeLine(Canvas canvas, Size size, double y) {
    final paint = Paint()
      ..color = dashedAltitudesColor ?? Colors.grey
      ..strokeWidth = 1;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(lbPadding.dx + startX, y),
          Offset(lbPadding.dx + startX + _kDashWidth, y), paint);
      startX += _kDashWidth + _kDashSpace;
    }
  }

  void _drawRidgeStroke(Canvas canvas, List<Path> ridgePaths) {
    final ElevationStroke? stroke = this.stroke;
    if (stroke == null) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final Path ridge in ridgePaths) {
      canvas.drawPath(ridge, paint);
    }
  }

  void _drawMarkers(Canvas canvas, Size size) {
    final ElevationMarkers? markers = this.markers;
    if (markers == null) return;

    final fillPaint = Paint()
      ..color = markers.fillColor
      ..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..color = markers.strokeColor
      ..strokeWidth = markers.strokeWidth
      ..style = PaintingStyle.stroke;

    for (final int pointIndex in markers.pointIndices) {
      if (pointIndex < 0 || pointIndex >= _relativeAltitudes.length) continue;

      final Offset center = Offset(pointIndex * widthOffset + lbPadding.dx,
          _getYForAltitude(_relativeAltitudes[pointIndex], size));

      canvas.drawCircle(center, markers.radius, fillPaint);
      canvas.drawCircle(center, markers.radius, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter oldDelegate) {
    return points != oldDelegate.points ||
        paintColor != oldDelegate.paintColor ||
        parameter != oldDelegate.parameter ||
        parametersColors != oldDelegate.parametersColors ||
        unit != oldDelegate.unit ||
        scaleColor != oldDelegate.scaleColor ||
        scaleTextStyle != oldDelegate.scaleTextStyle ||
        dashedAltitudesColor != oldDelegate.dashedAltitudesColor ||
        showAltitudeScale != oldDelegate.showAltitudeScale ||
        stroke != oldDelegate.stroke ||
        markers != oldDelegate.markers ||
        totalDistanceLabel != oldDelegate.totalDistanceLabel;
  }

  /// Room kept above the highest point for what is drawn on the ridge itself,
  /// which the canvas would otherwise clip in half.
  double get _topInset {
    final ElevationMarkers? markers = this.markers;
    final double strokeReach = (stroke?.width ?? 0) / 2;
    final double markerReach =
        markers == null ? 0 : markers.radius + markers.strokeWidth / 2;

    return max(strokeReach, markerReach);
  }

  /// The band the track is drawn in: under whatever sits on the ridge, above
  /// the room the distance labels need. The highest point used to land on
  /// `-lbPadding.dy`, off the canvas, and got clipped away.
  double _getYForAltitude(double altitude, Size size) {
    final double band = size.height - _topInset - lbPadding.dy;

    return _topInset + (1 - altitude) * band;
  }

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

/// The line drawn on the ridge of the elevation graph, over the filled area.
class ElevationStroke {
  const ElevationStroke({
    required this.color,
    this.width = _kDefaultStrokeWidth,
  });

  final Color color;
  final double width;

  @override
  bool operator ==(Object other) =>
      other is ElevationStroke && other.color == color && other.width == width;

  @override
  int get hashCode => Object.hash(color, width);
}

/// Round dots pinned on the ridge, at the given indexes of the point list.
/// Out of range indexes are ignored rather than thrown, so a caller may pass
/// the points of interest of a track without checking the track first.
class ElevationMarkers {
  const ElevationMarkers({
    required this.pointIndices,
    required this.fillColor,
    required this.strokeColor,
    this.radius = _kDefaultMarkerRadius,
    this.strokeWidth = _kDefaultMarkerStrokeWidth,
  });

  final List<int> pointIndices;
  final Color fillColor;
  final Color strokeColor;
  final double radius;
  final double strokeWidth;

  @override
  bool operator ==(Object other) =>
      other is ElevationMarkers &&
      listEquals(other.pointIndices, pointIndices) &&
      other.fillColor == fillColor &&
      other.strokeColor == strokeColor &&
      other.radius == radius &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(Object.hashAll(pointIndices), fillColor,
      strokeColor, radius, strokeWidth);
}

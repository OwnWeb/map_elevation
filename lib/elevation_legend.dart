// First, let's define the LegendItem and ElevationLegend classes

import 'package:flutter/material.dart';

// Enum to choose between column-first or row-first distribution
enum LegendDistribution {
  byColumn, // Fill columns first (vertically)
  byRow // Fill rows first (horizontally)
}

// Class to hold legend item data
class LegendItem {
  final String label;
  final Color color;
  final String? value;

  const LegendItem({
    required this.label,
    required this.color,
    this.value,
  });
}

class ElevationLegend extends StatelessWidget {
  /// List of legend items to display
  final List<LegendItem> legendItems;

  /// Number of columns in the legend, is set to 3 by default
  final int columns;

  /// Distribution type: by column or by row
  final LegendDistribution distribution;

  /// TextStyle of the label
  final TextStyle labelTextStyle;

  /// TextStyle of the value text
  final TextStyle valueTextStyle;

  ///Padding of one legend element
  final EdgeInsetsGeometry padding;

  const ElevationLegend(
      {super.key,
      required this.legendItems,
      this.columns = 3,
      this.distribution = LegendDistribution.byColumn,
      this.padding = const EdgeInsets.symmetric(horizontal: 4),
      this.labelTextStyle = const TextStyle(fontWeight: FontWeight.bold),
      this.valueTextStyle = const TextStyle()});

  @override
  Widget build(BuildContext context) {
    // Safety check
    if (legendItems.isEmpty) {
      return Container();
    }

    return distribution == LegendDistribution.byColumn
        ? _buildColumnFirstLayout()
        : _buildRowFirstLayout();
  }

  /// Builds a column-first layout
  Widget _buildColumnFirstLayout() {
    final int totalItems = legendItems.length;
    final int itemsPerColumn = (totalItems / columns).ceil();

    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(columns, (columnIndex) {
          // Calculate start index for this column
          final int startIndex = columnIndex * itemsPerColumn;

          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(itemsPerColumn, (itemIndex) {
              final int elementIndex = startIndex + itemIndex;

              // Only create element if the index is valid
              if (elementIndex < totalItems) {
                return _createLegendElement(elementIndex);
              } else {
                return const SizedBox.shrink(); // Empty widget for padding
              }
            }),
          );
        }),
      ),
    );
  }

  /// Builds a row-first layout
  Widget _buildRowFirstLayout() {
    final int totalItems = legendItems.length;
    final int rows = (totalItems / columns).ceil();

    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(rows, (rowIndex) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(columns, (columnIndex) {
              final int elementIndex = rowIndex * columns + columnIndex;

              // Always use Expanded to ensure equal width columns
              return Expanded(
                flex: 1,
                child: elementIndex < totalItems
                    ? _createLegendElement(elementIndex)
                    : const SizedBox(), // Empty widget with same structure
              );
            }),
          );
        }),
      ),
    );
  }

  /// Creates a legend element at the specified index
  Widget _createLegendElement(int index) {
    final LegendItem item = legendItems[index];

    return _LegendElement(
      padding: padding,
      color: item.color,
      label: item.label,
      value: item.value,
      labelTextStyle: labelTextStyle,
      valueTextStyle: valueTextStyle,
    );
  }
}

// Renamed from _legendElement to follow Dart naming conventions
class _LegendElement extends StatelessWidget {
  final Color color;
  final String label;
  final String? value;
  final TextStyle labelTextStyle;
  final TextStyle valueTextStyle;
  final EdgeInsetsGeometry padding;

  const _LegendElement(
      {required this.color,
      required this.label,
      required this.value,
      required this.padding,
      required this.labelTextStyle,
      required this.valueTextStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.all(4),
            width: 20,
            height: 20,
            color: color,
          ),
          Text(
            label,
            style: labelTextStyle,
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                value!,
                style: valueTextStyle,
              ),
            ),
        ],
      ),
    );
  }
}

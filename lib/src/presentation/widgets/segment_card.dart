import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/code_segment.dart';

/// Interactive card widget for configuring a single [CodeSegment].
///
/// Includes a draggable header bar and length controls with increment/decrement
/// buttons and numeric input validation.
class SegmentCard extends StatelessWidget {
  final CodeSegment segment;
  final int index;
  final VoidCallback onLengthChanged;

  const SegmentCard({
    super.key,
    required this.segment,
    required this.index,
    required this.onLengthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: segment.color.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: SizedBox(
        width: 230,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Reorderable Drag Header
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: segment.color.withValues(alpha: 0.12),
                    border: Border(
                      bottom: BorderSide(
                        color: segment.color.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Position badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: segment.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Label
                      Expanded(
                        child: Text(
                          segment.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Drag handle icon
                      Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: segment.color.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Card Body: Length controls & sample char indicator
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Length',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: segment.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'sample: ${segment.sampleChar}',
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: segment.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Length increment/decrement input group
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Decrease length',
                        onPressed: segment.length > 1
                            ? () {
                                segment.updateLength(segment.length - 1);
                                onLengthChanged();
                              }
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 58,
                        child: TextFormField(
                          controller: segment.controller,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null && parsed >= 1) {
                              segment.length = parsed;
                              onLengthChanged();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Increase length',
                        onPressed: () {
                          segment.updateLength(segment.length + 1);
                          onLengthChanged();
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

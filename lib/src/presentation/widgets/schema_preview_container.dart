import 'package:flutter/material.dart';
import '../../data/models/code_segment.dart';
import '../../logic/services/filename_parser_service.dart';

/// Container widget that displays a live, color-coded preview of the filename schema,
/// including total expected character count, monospace dummy string, and range legend.
class SchemaPreviewContainer extends StatelessWidget {
  final List<CodeSegment> segments;
  final String delimiter;

  const SchemaPreviewContainer({
    super.key,
    required this.segments,
    required this.delimiter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalExpectedLength = FilenameParserService.calculateExpectedLength(
      segments,
      delimiter: delimiter,
    );

    // Build RichText spans and range metadata
    final previewSpans = <InlineSpan>[];
    final legendItems = <_LegendRange>[];
    var cursor = 0;

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final start = cursor;
      final end = cursor + segment.length;

      // Dummy segment string: sampleChar repeated by segment length
      final dummyText = segment.sampleChar * segment.length;

      previewSpans.add(
        TextSpan(
          text: dummyText,
          style: TextStyle(
            color: segment.color,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );

      legendItems.add(
        _LegendRange(
          label: segment.label,
          color: segment.color,
          start: start,
          end: end,
          length: segment.length,
        ),
      );

      cursor = end;

      // Delimiter span
      if (delimiter.isNotEmpty && i < segments.length - 1) {
        previewSpans.add(
          TextSpan(
            text: delimiter,
            style: TextStyle(
              color: colorScheme.outline,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
        cursor += delimiter.length;
      }
    }

    // Append .ext in grey
    previewSpans.add(
      const TextSpan(
        text: '.ext',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.normal,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Preview title & Total Character Count badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live Filename Schema Preview',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Total Base Length: $totalExpectedLength chars'
                  '${delimiter.isNotEmpty ? " (with '$delimiter')" : ""}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Monospace dummy preview box
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF111827)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF1F2937)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText.rich(
                TextSpan(
                  children: previewSpans,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Legend mapping each color to block name and character range
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: legendItems.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.label}: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'chars ${item.start}–${item.end} (${item.length})',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: item.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LegendRange {
  final String label;
  final Color color;
  final int start;
  final int end;
  final int length;

  const _LegendRange({
    required this.label,
    required this.color,
    required this.start,
    required this.end,
    required this.length,
  });
}

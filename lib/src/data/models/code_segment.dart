import 'package:flutter/material.dart';

/// Represents a configurable segment of a filename schema.
class CodeSegment {
  final String id;
  final String label;
  int length;
  final String sampleChar;
  final Color color;
  final TextEditingController controller;

  CodeSegment({
    required this.id,
    required this.label,
    required this.length,
    required this.sampleChar,
    required this.color,
    TextEditingController? controller,
  }) : controller = controller ?? TextEditingController(text: length.toString());

  /// Updates the length of the segment, ensuring a minimum of 1.
  /// Synchronizes the [controller] text if it differs.
  void updateLength(int newLength) {
    final clampedLength = newLength < 1 ? 1 : newLength;
    length = clampedLength;
    final stringVal = clampedLength.toString();
    if (controller.text != stringVal) {
      controller.text = stringVal;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
  }

  /// Disposes the underlying [controller].
  void dispose() {
    controller.dispose();
  }

  /// Returns the default list of 4 schema blocks as specified:
  /// 1. Main Code (24 chars, Blue, 'C')
  /// 2. Index 1 (2 chars, Green, '1')
  /// 3. Index 2 (2 chars, Orange, '2')
  /// 4. Revision (3 chars, Purple, 'R')
  static List<CodeSegment> createDefaultSegments() {
    return [
      CodeSegment(
        id: 'code',
        label: 'Main Code',
        length: 24,
        sampleChar: 'C',
        color: const Color(0xFF2563EB), // Material / Tailwind Blue
      ),
      CodeSegment(
        id: 'idx1',
        label: 'Index 1',
        length: 2,
        sampleChar: '1',
        color: const Color(0xFF16A34A), // Material / Tailwind Green
      ),
      CodeSegment(
        id: 'idx2',
        label: 'Index 2',
        length: 2,
        sampleChar: '2',
        color: const Color(0xFFEA580C), // Material / Tailwind Orange
      ),
      CodeSegment(
        id: 'rev',
        label: 'Revision',
        length: 3,
        sampleChar: 'R',
        color: const Color(0xFF9333EA), // Material / Tailwind Purple
      ),
    ];
  }
}

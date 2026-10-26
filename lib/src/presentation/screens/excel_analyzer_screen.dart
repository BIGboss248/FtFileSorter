import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/widgets/animated_theme_toggle.dart';
import '../../data/models/excel_file_metadata.dart';
import '../../logic/services/excel_metadata_service.dart';

/// Screen for selecting an Excel data file, parsing its metadata,
/// and selecting the target column that holds the document code
/// with intelligent auto-detection.
class ExcelAnalyzerScreen extends StatefulWidget {
  const ExcelAnalyzerScreen({super.key});

  @override
  State<ExcelAnalyzerScreen> createState() => _ExcelAnalyzerScreenState();
}

class _ExcelAnalyzerScreenState extends State<ExcelAnalyzerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controller for the Excel file path
  final TextEditingController _filePathController = TextEditingController();

  // Excel metadata service
  final ExcelMetadataService _metadataService = const ExcelMetadataService();

  // State
  bool _isLoading = false;
  String? _errorMessage = null;
  ExcelFileMetadata? _metadata;
  int? _selectedColumnIndex;

  // Code browsing state
  final TextEditingController _browsedCodeController = TextEditingController();
  int _currentCodeIndex = 0;

  @override
  void dispose() {
    _filePathController.dispose();
    _browsedCodeController.dispose();
    super.dispose();
  }

  /// Trigger file picker for Excel files (.xlsx, .xls, .csv)
  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Excel Metadata File',
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        _filePathController.text = path;
        await _loadFileMetadata(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick Excel file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Parse the Excel file and auto-select document code column
  Future<void> _loadFileMetadata(String path, {String? sheetName}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final metadata = await _metadataService.parseExcelFile(
        path,
        sheetName: sheetName,
      );

      setState(() {
        _metadata = metadata;
        _isLoading = false;
        // Default to auto-detected column or first column
        _selectedColumnIndex = metadata.autoDetectedDocCodeColumnIndex ??
            (metadata.columns.isNotEmpty ? metadata.columns.first.index : null);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _metadata = null;
        _selectedColumnIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel Metadata & Document Code Analysis'),
        actions: const [
          AnimatedThemeToggle(),
          SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                // 1. File Picker Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Excel Data Source',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select the sample or production Excel file containing engineering document records.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _filePathController,
                                decoration: InputDecoration(
                                  labelText: 'Excel File Path',
                                  hintText: r'e.g. D:\Downloads\sample.xlsx',
                                  prefixIcon: const Icon(Icons.table_chart_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please select or enter an Excel file path.';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    _loadFileMetadata(val.trim());
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _pickExcelFile,
                                icon: const Icon(Icons.file_open_outlined),
                                label: const Text('Browse File'),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final path = _filePathController.text.trim();
                                  if (path.isNotEmpty) {
                                    _loadFileMetadata(path);
                                  }
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reload'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Loading State
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Reading Excel worksheet metadata...'),
                        ],
                      ),
                    ),
                  ),

                // 3. Error State
                if (_errorMessage != null)
                  Card(
                    color: colorScheme.errorContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: colorScheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 4. Metadata & Column Selection Section
                if (_metadata != null) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Column Configuration & Detection',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Chip(
                                avatar: const Icon(Icons.table_rows, size: 16),
                                label: Text('${_metadata!.totalRows} Rows'),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                avatar: const Icon(Icons.view_column, size: 16),
                                label: Text('${_metadata!.totalColumns} Columns'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Worksheet selector if multiple sheets exist
                          if (_metadata!.sheetNames.length > 1) ...[
                            Text(
                              'Active Worksheet',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _metadata!.selectedSheet,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              items: _metadata!.sheetNames.map((sheet) {
                                return DropdownMenuItem(
                                  value: sheet,
                                  child: Text(sheet),
                                );
                              }).toList(),
                              onChanged: (sheet) {
                                if (sheet != null && sheet != _metadata!.selectedSheet) {
                                  _loadFileMetadata(
                                    _filePathController.text.trim(),
                                    sheetName: sheet,
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Document Code Column Selector
                          Text(
                            'Document Code Column',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Specify the column containing the document codes (e.g. 18-character codes to analyze).',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),

                          DropdownButtonFormField<int>(
                            value: _selectedColumnIndex,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Select Document Code Column',
                              prefixIcon: const Icon(Icons.tag),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            items: _metadata!.columns.map((col) {
                              final isAutoDetected =
                                  col.index == _metadata!.autoDetectedDocCodeColumnIndex;
                              return DropdownMenuItem<int>(
                                value: col.index,
                                child: Row(
                                  children: [
                                    Text(
                                      col.displayName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isAutoDetected) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Auto-Detected',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedColumnIndex = val;
                              });
                            },
                          ),

                          // Detection Notice Badge
                          if (_metadata!.autoDetectedDocCodeColumnIndex != null &&
                              _selectedColumnIndex ==
                                  _metadata!.autoDetectedDocCodeColumnIndex) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: colorScheme.primary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Auto-selected based on header keyword matching and document code pattern recognition.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Data Preview Table
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.preview_outlined, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Data Preview (First 5 Rows)',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                colorScheme.surfaceContainerHighest,
                              ),
                              columns: _metadata!.columns.take(10).map((col) {
                                final isSelected = col.index == _selectedColumnIndex;
                                return DataColumn(
                                  label: Text(
                                    '${col.letter}: ${col.header}',
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected ? colorScheme.primary : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                              rows: _metadata!.previewRows.map((row) {
                                return DataRow(
                                  cells: List.generate(
                                    _metadata!.columns.take(10).length,
                                    (idx) {
                                      final text = idx < row.length ? row[idx] : '';
                                      final isSelected =
                                          _metadata!.columns[idx].index ==
                                              _selectedColumnIndex;
                                      return DataCell(
                                        Text(
                                          text,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? colorScheme.primary
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/widgets/animated_theme_toggle.dart';
import '../../data/models/code_segment.dart';
import '../../logic/services/filename_parser_service.dart';
import '../widgets/schema_preview_container.dart';
import '../widgets/segment_card.dart';
import '../widgets/test_parser_section.dart';
import 'document_analyzer_screen.dart';
import 'excel_analyzer_screen.dart';

/// Production-ready configuration screen for desktop file sorting and filename schema configuration.
class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  // Global form key for validation
  final _formKey = GlobalKey<FormState>();

  // 1. Boolean configuration toggle: Convert to PDF
  bool _convertToPdf = false;

  // 2. Source folder picker controller (input documents to analyze)
  final TextEditingController _sourceFolderController = TextEditingController();

  // 3. Destination folder picker controller (where resulting files will be saved)
  final TextEditingController _targetFolderController = TextEditingController();

  // 4. Excel metadata file picker controller
  final TextEditingController _excelFileController = TextEditingController();

  // 4. Dynamic Filename Schema Builder segments
  late final List<CodeSegment> _segments;

  // Delimiter selector state: '' (None), '_' (Underscore), '-' (Hyphen)
  String _selectedDelimiter = '';

  // 5. Test parser controller and service
  final TextEditingController _testFilenameController = TextEditingController();
  final FilenameParserService _parserService = const FilenameParserService();

  @override
  void initState() {
    super.initState();
    _segments = CodeSegment.createDefaultSegments();
    _testFilenameController.addListener(_onTestFilenameChanged);
    _generateDefaultSampleTestFilename();
  }

  void _onTestFilenameChanged() {
    setState(() {});
  }

  void _generateDefaultSampleTestFilename() {
    final buffer = StringBuffer();
    for (var i = 0; i < _segments.length; i++) {
      final segment = _segments[i];
      buffer.write(segment.sampleChar * segment.length);
      if (_selectedDelimiter.isNotEmpty && i < _segments.length - 1) {
        buffer.write(_selectedDelimiter);
      }
    }
    buffer.write('.xlsx');
    _testFilenameController.text = buffer.toString();
  }

  @override
  void dispose() {
    // Properly dispose all controllers
    _sourceFolderController.dispose();
    _targetFolderController.dispose();
    _excelFileController.dispose();
    _testFilenameController.removeListener(_onTestFilenameChanged);
    _testFilenameController.dispose();

    for (final segment in _segments) {
      segment.dispose();
    }

    super.dispose();
  }

  // File & Directory Picker Methods
  Future<void> _pickSourceFolder() async {
    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Source Documents Folder (To Analyze)',
      );

      if (directoryPath != null && directoryPath.isNotEmpty) {
        setState(() {
          _sourceFolderController.text = directoryPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick source directory: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickTargetFolder() async {
    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Destination Folder (Resulting Files)',
      );

      if (directoryPath != null && directoryPath.isNotEmpty) {
        setState(() {
          _targetFolderController.text = directoryPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick directory: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Excel or CSV Spreadsheet',
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath != null && filePath.isNotEmpty) {
          setState(() {
            _excelFileController.text = filePath;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onReorderSegments(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _segments.removeAt(oldIndex);
      _segments.insert(newIndex, item);
      _generateDefaultSampleTestFilename();
    });
  }

  void _onSegmentLengthUpdated() {
    setState(() {
      _generateDefaultSampleTestFilename();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Desktop Sorter & Filename Parser Configuration'),
        centerTitle: false,
        actions: [
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ExcelAnalyzerScreen(),
                ),
              );
            },
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const Text('Excel Analyzer'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DocumentAnalyzerScreen(),
                ),
              );
            },
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('Document Code Analyzer'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Reset to Default Schema',
            icon: const Icon(Icons.restore),
            onPressed: () {
              setState(() {
                for (final segment in _segments) {
                  segment.dispose();
                }
                _segments.clear();
                _segments.addAll(CodeSegment.createDefaultSegments());
                _selectedDelimiter = '';
                _generateDefaultSampleTestFilename();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Filename schema reset to default blocks.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const AnimatedThemeToggle(),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                // 1. Boolean Configuration Checkbox
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      'Convert to PDF',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Automatically convert processed documents to PDF format during sorting.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _convertToPdf
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: _convertToPdf
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: _convertToPdf,
                    onChanged: (value) {
                      setState(() {
                        _convertToPdf = value ?? false;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Source Documents Folder (To Analyze)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Source Documents Folder (To Analyze)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The folder containing the incoming documents and files to analyze.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _sourceFolderController,
                                decoration: InputDecoration(
                                  labelText: 'Source Folder Path',
                                  hintText: r'e.g. C:\Users\Admin\IncomingDocs',
                                  prefixIcon: const Icon(Icons.source_outlined),
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
                                    return 'Source documents directory path is required.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _pickSourceFolder,
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Browse Source'),
                                style: FilledButton.styleFrom(
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

                const SizedBox(height: 16),

                // 3. Destination Folder (Resulting Files)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destination Folder (Resulting Files)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The root directory where resulting and sorted files will be saved.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _targetFolderController,
                                decoration: InputDecoration(
                                  labelText: 'Destination Folder Path',
                                  hintText: r'e.g. C:\Users\Admin\SortedFiles',
                                  prefixIcon: const Icon(Icons.folder_outlined),
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
                                    return 'Destination directory path is required.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _pickTargetFolder,
                                icon: const Icon(Icons.drive_file_move_outlined),
                                label: const Text('Browse Destination'),
                                style: FilledButton.styleFrom(
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

                const SizedBox(height: 16),

                // 4. Excel Metadata File Picker Section
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Excel Metadata File',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select the reference metadata spreadsheet (*.xlsx, *.xls, *.csv) containing document records.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _excelFileController,
                                decoration: InputDecoration(
                                  labelText: 'Metadata Excel / CSV File Path',
                                  hintText: r'e.g. C:\Data\Metadata_Catalog.xlsx',
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
                                    return 'Reference metadata Excel/CSV file path is required.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _pickExcelFile,
                                icon: const Icon(Icons.attach_file),
                                label: const Text('Select Excel'),
                                style: FilledButton.styleFrom(
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

                const SizedBox(height: 24),

                // 4. Dynamic Filename Schema Builder
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  spacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dynamic Filename Schema Builder',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Drag header handles to reorder blocks. Adjust character length per block.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    // Delimiter Selector
                    // Row(
                    //   mainAxisSize: MainAxisSize.min,
                    //   children: [
                    //     Text(
                    //       'Delimiter:',
                    //       style: theme.textTheme.labelMedium?.copyWith(
                    //         fontWeight: FontWeight.w600,
                    //       ),
                    //     ),
                    //     const SizedBox(width: 8),
                    //     SegmentedButton<String>(
                    //       segments: const [
                    //         ButtonSegment(
                    //           value: '',
                    //           label: Text('None'),
                    //         ),
                    //         ButtonSegment(
                    //           value: '_',
                    //           label: Text('_ (Underscore)'),
                    //         ),
                    //         ButtonSegment(
                    //           value: '-',
                    //           label: Text('- (Hyphen)'),
                    //         ),
                    //       ],
                    //       selected: {_selectedDelimiter},
                    //       onSelectionChanged: (newSelection) {
                    //         setState(() {
                    //           _selectedDelimiter = newSelection.first;
                    //           _generateDefaultSampleTestFilename();
                    //         });
                    //       },
                    //     ),
                    //   ],
                    // ),
                  ],
                ),

                const SizedBox(height: 12),

                // Horizontal ReorderableListView for Segments
                SizedBox(
                  height: 155,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: _segments.length,
                    onReorder: _onReorderSegments,
                    itemBuilder: (context, index) {
                      final segment = _segments[index];
                      return Padding(
                        key: ValueKey(segment.id),
                        padding: const EdgeInsets.only(right: 12),
                        child: SegmentCard(
                          segment: segment,
                          index: index,
                          onLengthChanged: _onSegmentLengthUpdated,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // 5. Live Color-Coded Filename Preview
                SchemaPreviewContainer(
                  segments: _segments,
                  delimiter: _selectedDelimiter,
                ),

                const SizedBox(height: 24),

                // 6. Interactive Test Parser Section
                TestParserSection(
                  controller: _testFilenameController,
                  segments: _segments,
                  delimiter: _selectedDelimiter,
                  parserService: _parserService,
                  onSampleGenerated: _generateDefaultSampleTestFilename,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/widgets/animated_theme_toggle.dart';
import '../../data/models/document_code_analysis.dart';
import '../../logic/services/document_code_parser_service.dart';
import '../navigation/app_navigation_drawer.dart';

/// Screen for inputting and analyzing an 18-character document code,
/// identifying its document type (Characters 11 & 12), and specifying
/// the target save directory and matching file types.
class DocumentAnalyzerScreen extends StatefulWidget {
  const DocumentAnalyzerScreen({super.key});

  @override
  State<DocumentAnalyzerScreen> createState() => _DocumentAnalyzerScreenState();
}

class _DocumentAnalyzerScreenState extends State<DocumentAnalyzerScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Text input controller for 18-character code
  final TextEditingController _codeController = TextEditingController();

  // 2. Directory picker controller for save location
  final TextEditingController _directoryController = TextEditingController();

  // Parser service
  final DocumentCodeParserService _parserService = const DocumentCodeParserService();

  // Cached analysis state
  late DocumentCodeAnalysis _analysis;

  @override
  void initState() {
    super.initState();
    _analysis = DocumentCodeAnalysis.empty();
    _codeController.addListener(_onCodeInputChanged);
  }

  void _onCodeInputChanged() {
    final text = _codeController.text;
    setState(() {
      _analysis = _parserService.analyze(text);
    });
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeInputChanged);
    _codeController.dispose();
    _directoryController.dispose();
    super.dispose();
  }

  // Directory picker logic
  Future<void> _pickDirectory() async {
    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Target Directory to Save Matching Files',
      );

      if (directoryPath != null && directoryPath.isNotEmpty) {
        setState(() {
          _directoryController.text = directoryPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select directory: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // Clipboard paste helper
  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        final text = data.text!.trim();
        _codeController.text = text;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code pasted from clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to paste from clipboard: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // Quick sample loader
  void _loadSample(String sampleCode) {
    _codeController.text = sampleCode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text('Document Code Analyzer (18-Char)'),
        actions: [
          IconButton(
            tooltip: 'Insert Sample Drawing Code (DW)',
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () => _loadSample('PRJ1020300DW000101'),
          ),
          const AnimatedThemeToggle(),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                // Header overview card
                _buildHeaderCard(theme, colorScheme),

                const SizedBox(height: 20),

                // Card 1: The Two Required Inputs
                _buildInputsCard(theme, colorScheme),

                const SizedBox(height: 24),

                // Card 2: Analysis Section Below the Inputs
                _buildAnalysisSection(theme, colorScheme),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.analytics_outlined,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '18-Character Code Breakdown & Document Classification',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Input an 18-character document code below. Characters 11 and 12 define the Document Type, which identifies the matching file formats to save to your chosen target directory.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputsCard(ThemeData theme, ColorScheme colorScheme) {
    final currentLength = _analysis.totalLength;
    final isCodeEmpty = _codeController.text.trim().isEmpty;

    return Card(
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
                Icon(
                  Icons.input_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Input Parameters',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the document code and select the target directory.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),

            // 1. Text input for 18-character code
            Text(
              '1. 18-Character Document Code',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(18),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\-\.]')),
              ],
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 16,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. PRJ1020300DW000101',
                prefixIcon: const Icon(Icons.qr_code_2),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isCodeEmpty)
                      IconButton(
                        tooltip: 'Clear code',
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _codeController.clear();
                        },
                      ),
                    IconButton(
                      tooltip: 'Paste from clipboard',
                      icon: const Icon(Icons.content_paste_outlined, size: 20),
                      onPressed: _pasteFromClipboard,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                counterText: '$currentLength / 18 characters',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Sample code pills for instant testing
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Sample Codes:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                ActionChip(
                  label: const Text('Drawing (DW)'),
                  avatar: const Icon(Icons.architecture, size: 16),
                  onPressed: () => _loadSample('PRJ1020300DW000101'),
                ),
                ActionChip(
                  label: const Text('Specification (SP)'),
                  avatar: const Icon(Icons.article, size: 16),
                  onPressed: () => _loadSample('ENG4400100SP000201'),
                ),
                ActionChip(
                  label: const Text('Data Sheet (DS)'),
                  avatar: const Icon(Icons.table_chart, size: 16),
                  onPressed: () => _loadSample('EQUIP90000DS000301'),
                ),
                ActionChip(
                  label: const Text('Calculation (CA)'),
                  avatar: const Icon(Icons.calculate, size: 16),
                  onPressed: () => _loadSample('CIVIL80000CA000401'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. Directory picker input
            Text(
              '2. Save Target Directory',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _directoryController,
                    readOnly: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'No directory selected yet...',
                      prefixIcon: const Icon(Icons.folder_outlined),
                      suffixIcon: _directoryController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear directory',
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  _directoryController.clear();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      helperText:
                          'Selected folder where matching files will be saved (save logic will be executed here).',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton.tonalIcon(
                    onPressed: _pickDirectory,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Browse Directory'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSection(ThemeData theme, ColorScheme colorScheme) {
    if (_analysis.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.code_outlined,
                size: 52,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'Awaiting 18-Character Code',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Type or paste a code into the input above to see real-time decoding of document type (Chars 11–12), segment breakdowns, and target save file types.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Real-time status banner
        _buildStatusBanner(theme, colorScheme),

        const SizedBox(height: 16),

        // Visual segment ribbon (Chars 1-10, 11-12, 13-18)
        _buildSegmentRibbon(theme, colorScheme),

        const SizedBox(height: 16),

        // Document Type & Target File Types to Save
        _buildDocumentTypeCard(theme, colorScheme),

        const SizedBox(height: 16),

        // Deconstructed Code Segments Breakdown Table
        _buildDeconstructedCodesCard(theme, colorScheme),
      ],
    );
  }

  Widget _buildStatusBanner(ThemeData theme, ColorScheme colorScheme) {
    final isValid = _analysis.isValidLength;
    final hasDocType = _analysis.hasDocumentType;

    final Color bgColor;
    final Color fgColor;
    final IconData icon;

    if (isValid) {
      bgColor = Colors.green.withValues(alpha: 0.12);
      fgColor = Colors.green.shade800;
      icon = Icons.check_circle_outline;
    } else if (hasDocType) {
      bgColor = Colors.blue.withValues(alpha: 0.12);
      fgColor = Colors.blue.shade800;
      icon = Icons.info_outline;
    } else {
      bgColor = Colors.orange.withValues(alpha: 0.12);
      fgColor = Colors.orange.shade800;
      icon = Icons.pending_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fgColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _analysis.statusMessage ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fgColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_analysis.totalLength} / 18 chars',
              style: TextStyle(
                color: fgColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentRibbon(ThemeData theme, ColorScheme colorScheme) {
    final prefix = _analysis.prefixCode;
    final docType = _analysis.documentTypeCode;
    final suffix = _analysis.suffixCode;

    return Card(
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
            Row(
              children: [
                Icon(Icons.view_column_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Visual Code Segmentation',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildRibbonBlock(
                      label: 'Prefix / Entity (1-10)',
                      value: prefix.isNotEmpty ? prefix : '...',
                      color: const Color(0xFF2563EB), // Blue
                      charRange: 'Chars 1–10 (${prefix.length}/10)',
                    ),
                    _buildRibbonBlock(
                      label: 'Document Type (11-12)',
                      value: docType.isNotEmpty ? docType : '..',
                      color: const Color(0xFF16A34A), // Green
                      charRange: 'Chars 11–12 (${docType.length}/2)',
                      isHighlighted: true,
                    ),
                    _buildRibbonBlock(
                      label: 'Serial & Rev (13-18)',
                      value: suffix.isNotEmpty ? suffix : '......',
                      color: const Color(0xFF9333EA), // Purple
                      charRange: 'Chars 13–18 (${suffix.length}/6)',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonBlock({
    required String label,
    required String value,
    required Color color,
    required String charRange,
    bool isHighlighted = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isHighlighted ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isHighlighted ? 0.8 : 0.3),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            charRange,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTypeCard(ThemeData theme, ColorScheme colorScheme) {
    final docTypeInfo = _analysis.documentTypeInfo;
    final hasDocType = _analysis.hasDocumentType;
    final targetFolder = _directoryController.text.trim();

    return Card(
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
                Icon(
                  Icons.category_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Document Type Analysis & Target Files',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (!hasDocType)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Enter at least 12 characters to extract and decode the document type from characters 11 & 12.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              // Document Type Details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      docTypeInfo?.icon ?? Icons.description,
                      color: colorScheme.onSecondaryContainer,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              docTypeInfo?.title ?? 'Document Type (${_analysis.documentTypeCode})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _analysis.documentTypeCode,
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Consolas',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          docTypeInfo?.description ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Files to Save based on document type
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.save_as_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Identified File Types to Save (Based on Doc Type):',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _analysis.targetFileTypes.map((ext) {
                        return Chip(
                          avatar: Icon(
                            _iconForExtension(ext),
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          label: Text(
                            ext,
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: colorScheme.surface,
                          side: BorderSide(color: colorScheme.outlineVariant),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          targetFolder.isNotEmpty
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color: targetFolder.isNotEmpty
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            targetFolder.isNotEmpty
                                ? 'Save Destination: $targetFolder'
                                : 'No save directory selected yet. Pick a directory above to save matching files.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: targetFolder.isNotEmpty
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeconstructedCodesCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
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
                Icon(
                  Icons.format_list_bulleted_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Extracted Sub-Codes Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(3),
                3: FlexColumnWidth(4),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _buildTableRow(
                  theme,
                  segment: 'Prefix Code',
                  positions: '1–10 (10 chars)',
                  codeValue: _analysis.prefixCode,
                  meaning: 'Project / Plant / Unit Entity ID',
                  isHeader: false,
                ),
                _buildTableRow(
                  theme,
                  segment: 'Document Type',
                  positions: '11–12 (2 chars)',
                  codeValue: _analysis.documentTypeCode,
                  meaning: _analysis.documentTypeInfo?.title ?? 'Awaiting characters 11-12',
                  isHeader: false,
                  isHighlighted: true,
                ),
                _buildTableRow(
                  theme,
                  segment: 'Serial & Revision',
                  positions: '13–18 (6 chars)',
                  codeValue: _analysis.suffixCode,
                  meaning: 'Sheet Number & Sequential Revision',
                  isHeader: false,
                ),
                _buildTableRow(
                  theme,
                  segment: 'Complete Code',
                  positions: '1–18 (18 chars)',
                  codeValue: _analysis.sanitizedCode,
                  meaning: _analysis.isValidLength
                      ? 'Fully Formed 18-Character Code'
                      : 'Partial (${_analysis.totalLength}/18 chars)',
                  isHeader: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(
    ThemeData theme, {
    required String segment,
    required String positions,
    required String codeValue,
    required String meaning,
    required bool isHeader,
    bool isHighlighted = false,
  }) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
    );

    return TableRow(
      decoration: BoxDecoration(
        color: isHighlighted
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
            : null,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            segment,
            style: style.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(positions, style: style),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            codeValue.isNotEmpty ? codeValue : '—',
            style: style.copyWith(
              fontFamily: 'Consolas',
              fontWeight: FontWeight.bold,
              color: isHighlighted ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(meaning, style: style),
        ),
      ],
    );
  }

  IconData _iconForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.dwg':
      case '.dxf':
        return Icons.architecture_outlined;
      case '.xlsx':
      case '.xls':
      case '.csv':
        return Icons.table_view_outlined;
      case '.docx':
      case '.doc':
        return Icons.description_outlined;
      case '.mpp':
        return Icons.calendar_today_outlined;
      case '.ifc':
        return Icons.foundation_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

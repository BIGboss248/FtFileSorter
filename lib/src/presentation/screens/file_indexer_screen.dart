import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/logging/app_logger.dart';
import '../../../core/theme/widgets/animated_theme_toggle.dart';
import '../../data/models/document_type_info.dart';
import '../../data/models/duplicate_code_group.dart';
import '../../data/models/indexed_file.dart';
import '../../logic/services/file_index_service.dart';
import '../navigation/app_navigation_drawer.dart';

/// Screen that scans a folder tree and renders every discovered file together
/// with its 18-character document code and 2-character document type
/// (characters 12-13 of the file name). The result can be exported to CSV.
class FileIndexerScreen extends StatefulWidget {
  /// Service used to walk the file system. Overridable for tests.
  final FileIndexService indexService;

  /// Optional folder path used to pre-fill the input.
  final String? initialFolderPath;

  const FileIndexerScreen({
    super.key,
    this.indexService = const FileIndexService(),
    this.initialFolderPath,
  });

  @override
  State<FileIndexerScreen> createState() => _FileIndexerScreenState();
}

class _FileIndexerScreenState extends State<FileIndexerScreen> {
  static const String _allTypesFilter = '__ALL__';
  static const String _unknownTypeFilter = '__NONE__';

  static final _log = createLogger('FileIndexerScreen');

  /// Number of table rows rendered per page. Keeps large archives responsive
  /// by avoiding one giant synchronous table build.
  static const int _pageSize = 200;

  final TextEditingController _folderController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _duplicateDestinationController =
      TextEditingController();
  final ScrollController _tableScrollController = ScrollController();

  bool _recursive = true;
  bool _copyDuplicates = false;
  bool _isScanning = false;
  bool _isExporting = false;
  bool _isCopying = false;
  String? _errorMessage;
  String _typeFilter = _allTypesFilter;
  int _page = 0;
  FileIndexResult? _result;
  DuplicateCopyResult? _copyResult;

  /// Source path -> copy destination, exported in the CSV `Copied To` column.
  Map<String, String> _copiedTo = const {};

  /// 1-based position of each file in the full sorted result. Shared with the
  /// CSV export so table rows and exported rows carry the same index.
  Map<IndexedFile, int> _indexByFile = const {};

  @override
  void initState() {
    super.initState();
    final initialPath = widget.initialFolderPath;
    if (initialPath != null && initialPath.trim().isNotEmpty) {
      _folderController.text = initialPath.trim();
    }
    _log.d(
      'FileIndexerScreen initialised '
      '(initialFolderPath="${_folderController.text}", '
      'recursive=$_recursive, pageSize=$_pageSize).',
    );
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _log.t('FileIndexerScreen disposed.');
    _searchController.removeListener(_onSearchChanged);
    _folderController.dispose();
    _searchController.dispose();
    _duplicateDestinationController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _log.t('Search query changed: "${_searchController.text}".');
    setState(() => _page = 0);
    _scrollTableToTop();
  }

  void _scrollTableToTop() {
    if (_tableScrollController.hasClients) {
      _log.t('Scrolling the table back to the top.');
      _tableScrollController.jumpTo(0);
    }
  }

  void _goToPage(int page) {
    _log.d('Changing table page to ${page + 1}.');
    setState(() => _page = page);
    _scrollTableToTop();
  }

  Future<void> _pickFolder() async {
    _log.d('Opening the folder picker.');

    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Folder to Index',
      );

      if (directoryPath == null || directoryPath.isEmpty) {
        _log.d('Folder picker was cancelled.');
        return;
      }

      _log.i('Folder selected: "$directoryPath".');
      _folderController.text = directoryPath;
      await _scanFolder();
    } catch (error, stackTrace) {
      _log.e('Folder picker failed.', error: error, stackTrace: stackTrace);
      _showErrorSnapshot('Failed to pick folder: $error');
    }
  }

  Future<void> _scanFolder() async {
    if (_isScanning) {
      _log.d('Ignoring scan request: a scan is already running.');
      return;
    }

    final path = _folderController.text.trim();
    if (path.isEmpty) {
      _log.w('Scan requested with an empty folder path.');
      _showSnackBar('Choose a folder to index first.');
      return;
    }

    _log.i(
      'Scan requested: path="$path", recursive=$_recursive, pageSize=$_pageSize.',
    );

    final stopwatch = Stopwatch()..start();

    _searchController.clear();
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    // Let the frame that contains the loading indicator reach the screen
    // before any file-system work begins. Without this the scan can start in
    // the same microtask as setState, so the window looks unresponsive until
    // the first frame finally lands. The timeout keeps indexing from stalling
    // forever if the platform stops producing frames (e.g. a hidden window).
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {},
    );
    if (!mounted) {
      _log.d('Screen was disposed before the loading frame completed.');
      return;
    }

    _log.t('Loading frame painted; handing over to the index service.');

    try {
      final result = await widget.indexService.indexDirectory(
        path,
        recursive: _recursive,
      );

      stopwatch.stop();

      if (!mounted) {
        _log.d('Screen was disposed before the scan result was applied.');
        return;
      }

      _log.i(
        'Scan result applied: ${result.totalFiles} file(s), '
        '${result.scannedDirectories} folder(s), '
        '${result.warnings.length} warning(s) in '
        '${stopwatch.elapsedMilliseconds} ms.',
      );

      setState(() {
        _result = result;
        _indexByFile = {
          for (var i = 0; i < result.files.length; i++) result.files[i]: i + 1,
        };
        _isScanning = false;
        _errorMessage = null;
        _copyResult = null;
        _copiedTo = const {};
        _typeFilter = _allTypesFilter;
        _page = 0;
      });

      if (_copyDuplicates) {
        setState(_suggestDuplicateDestination);
      }

      if (result.files.isEmpty) {
        _log.w('Scan completed but no files were found in "$path".');
        _showSnackBar('No files found in "$path".');
      }
    } catch (error, stackTrace) {
      stopwatch.stop();
      _log.e(
        'Scan failed after ${stopwatch.elapsedMilliseconds} ms: "$path".',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _result = null;
        _copyResult = null;
        _errorMessage = 'Could not index "$path": $error';
      });
    }
  }

  Future<void> _exportCsv() async {
    final result = _result;
    if (result == null || result.files.isEmpty || _isExporting) {
      _log.d('Ignoring CSV export request (no data or export in progress).');
      return;
    }

    _log.i('CSV export requested for ${result.files.length} row(s).');
    final stopwatch = Stopwatch()..start();

    setState(() => _isExporting = true);

    try {
      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File Index as CSV',
        fileName: 'file_index.csv',
        initialDirectory: result.rootPath,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );

      if (selectedPath == null || selectedPath.isEmpty) {
        _log.d('CSV save dialog was cancelled.');
        return;
      }

      final targetPath = selectedPath.toLowerCase().endsWith('.csv')
          ? selectedPath
          : '$selectedPath.csv';

      _log.d('CSV destination selected: "$targetPath".');

      await widget.indexService.writeCsv(
        targetPath,
        result.files,
        copiedTo: _copiedTo,
      );

      stopwatch.stop();

      if (!mounted) {
        _log.d('Screen was disposed before the export confirmation.');
        return;
      }

      _log.i(
        'CSV export finished in ${stopwatch.elapsedMilliseconds} ms: '
        '"$targetPath".',
      );
      _showSnackBar('Exported ${result.files.length} rows to $targetPath');
    } catch (error, stackTrace) {
      stopwatch.stop();
      _log.e(
        'CSV export failed after ${stopwatch.elapsedMilliseconds} ms.',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showSnackBar('Failed to export CSV: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Picks the folder that receives the per-document-code subfolders.
  Future<void> _pickDuplicateDestination() async {
    _log.d('Opening the duplicate destination picker.');

    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Destination for Duplicate Document Codes',
      );

      if (directoryPath == null || directoryPath.isEmpty) {
        _log.d('Duplicate destination picker was cancelled.');
        return;
      }

      _log.i('Duplicate destination selected: "$directoryPath".');
      setState(() => _duplicateDestinationController.text = directoryPath);
    } catch (error, stackTrace) {
      _log.e(
        'Duplicate destination picker failed.',
        error: error,
        stackTrace: stackTrace,
      );
      _showSnackBar('Failed to pick a destination: $error', isError: true);
    }
  }

  /// Suggests a sibling folder next to the indexed root when the destination
  /// is still empty. A sibling avoids re-indexing the copied files later.
  void _suggestDuplicateDestination() {
    if (_duplicateDestinationController.text.trim().isNotEmpty) return;

    final source = _result?.rootPath ?? _folderController.text.trim();
    if (source.isEmpty) return;

    final normalized = p.normalize(source);
    final parent = p.dirname(normalized);
    final name = p.basename(normalized);

    _duplicateDestinationController.text =
        (name.isEmpty || parent == normalized)
        ? p.join(normalized, 'Duplicate Codes')
        : p.join(parent, '$name - Duplicate Codes');
  }

  Future<void> _copyDuplicateCodes() async {
    final result = _result;
    if (result == null || _isCopying) {
      _log.d('Ignoring duplicate copy request (no index or copy running).');
      return;
    }

    final destination = _duplicateDestinationController.text.trim();
    if (destination.isEmpty) {
      _log.w('Duplicate copy requested without a destination folder.');
      _showSnackBar('Choose a destination folder for the duplicate codes.');
      return;
    }

    final groups = result.duplicateCodeGroups;
    if (groups.isEmpty) {
      _log.d('Duplicate copy requested but no duplicate codes were found.');
      _showSnackBar('No duplicate document codes were found in this index.');
      return;
    }

    _log.i(
      'Duplicate copy requested: ${groups.length} code(s), '
      '${result.duplicateFileCount} file(s) -> "$destination".',
    );
    final stopwatch = Stopwatch()..start();

    setState(() {
      _isCopying = true;
      _copyResult = null;
    });

    try {
      final copyResult = await widget.indexService.copyDuplicateCodeGroups(
        result.files,
        destinationRoot: destination,
      );

      stopwatch.stop();

      if (!mounted) {
        _log.d('Screen was disposed before the duplicate copy finished.');
        return;
      }

      _log.i(
        'Duplicate copy applied: ${copyResult.totalCopied} copied, '
        '${copyResult.totalSkipped} skipped, '
        '${copyResult.warnings.length} warning(s) in '
        '${stopwatch.elapsedMilliseconds} ms.',
      );

      setState(() {
        _copyResult = copyResult;
        _copiedTo = copyResult.copiedToBySource;
      });

      _showSnackBar(
        copyResult.hasWarnings && copyResult.totalCopied == 0
            ? 'Duplicate copy failed: ${copyResult.warnings.length} item(s) '
                  'could not be copied.'
            : 'Copied ${copyResult.totalCopied} file(s) into '
                  '${copyResult.totalGroups} document-code folder(s).',
        isError: copyResult.hasWarnings && copyResult.totalCopied == 0,
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      _log.e(
        'Duplicate copy failed after ${stopwatch.elapsedMilliseconds} ms.',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showSnackBar('Failed to copy duplicate codes: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }

  void _showErrorSnapshot(String message) {
    _log.d('Showing error state: $message');
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    _log.d('Snackbar (${isError ? 'error' : 'info'}): $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Files matching the current search text and document-type filter.
  List<IndexedFile> get _visibleFiles {
    final result = _result;
    if (result == null) return const [];

    final query = _searchController.text.trim().toLowerCase();

    return result.files
        .where((file) {
          if (_typeFilter == _unknownTypeFilter) {
            if (file.documentTypeCode.isNotEmpty) return false;
          } else if (_typeFilter != _allTypesFilter &&
              file.documentTypeCode != _typeFilter) {
            return false;
          }

          if (query.isEmpty) return true;

          return file.fileName.toLowerCase().contains(query) ||
              file.code.toLowerCase().contains(query) ||
              file.documentTypeCode.toLowerCase().contains(query) ||
              file.directoryPath.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text('File Indexer & CSV Export'),
        actions: const [AnimatedThemeToggle(), SizedBox(width: 12)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFolderCard(colorScheme),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorCard(colorScheme),
                ],
                if (_result != null &&
                    !_isScanning &&
                    _result!.warnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildWarningsCard(colorScheme),
                ],
                if (_copyResult != null) ...[
                  const SizedBox(height: 16),
                  _buildCopySummaryCard(colorScheme),
                ],
                const SizedBox(height: 16),
                Expanded(child: _buildBody(colorScheme)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isScanning) return _buildScanningState(colorScheme);
    if (_result == null) return _buildEmptyState(colorScheme);
    return _buildTableCard(colorScheme);
  }

  Widget _buildFolderCard(ColorScheme colorScheme) {
    final theme = Theme.of(context);

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
                Icon(Icons.folder_copy_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Folder to Index',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Every file is listed with its name, type and folder. '
                        'The document code is the first 18 characters of the '
                        'name; the document type is characters 12 and 13.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _folderController,
                    decoration: InputDecoration(
                      labelText: 'Folder Path',
                      hintText: r'e.g. D:\Documents\AS BUILT',
                      prefixIcon: const Icon(Icons.folder_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!_isScanning) _scanFolder();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.tonalIcon(
                    onPressed: _isScanning ? null : _pickFolder,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Browse Folder'),
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
                  child: FilledButton.icon(
                    onPressed: _isScanning ? null : _scanFolder,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.manage_search),
                    label: Text(_isScanning ? 'Indexing...' : 'Index Folder'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: _recursive,
                            onChanged: _isScanning
                                ? null
                                : (value) {
                                    _log.d(
                                      'Include subfolders changed to $value.',
                                    );
                                    setState(() => _recursive = value);
                                  },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Include subfolders',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: _copyDuplicates,
                            onChanged: _isScanning || _isCopying
                                ? null
                                : (value) {
                                    _log.d(
                                      'Copy duplicate document codes changed '
                                      'to $value.',
                                    );
                                    setState(() {
                                      _copyDuplicates = value;
                                      if (value) _suggestDuplicateDestination();
                                    });
                                  },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy duplicate document codes',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed:
                      (_result == null ||
                          _result!.files.isEmpty ||
                          _isScanning ||
                          _isExporting)
                      ? null
                      : _exportCsv,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(_isExporting ? 'Exporting...' : 'Export CSV'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            if (_copyDuplicates) ...[
              const SizedBox(height: 12),
              _buildDuplicateCopyControls(colorScheme, theme),
            ],
          ],
        ),
      ),
    );
  }

  /// Destination picker and copy trigger, shown when the duplicate-code switch
  /// is on.
  Widget _buildDuplicateCopyControls(ColorScheme colorScheme, ThemeData theme) {
    final result = _result;
    final groups = result?.duplicateCodeGroups ?? const <DuplicateCodeGroup>[];
    final hasDestination = _duplicateDestinationController.text
        .trim()
        .isNotEmpty;
    final canCopy =
        result != null &&
        groups.isNotEmpty &&
        hasDestination &&
        !_isScanning &&
        !_isCopying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _duplicateDestinationController,
                enabled: !_isScanning && !_isCopying,
                decoration: InputDecoration(
                  labelText: 'Duplicate Codes Destination',
                  hintText: r'e.g. D:\Documents\Duplicate Codes',
                  helperText:
                      'Use a folder outside the indexed tree so the copies '
                      'are not indexed again.',
                  prefixIcon: const Icon(Icons.outbox_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: FilledButton.tonalIcon(
                onPressed: _isScanning || _isCopying
                    ? null
                    : _pickDuplicateDestination,
                icon: const Icon(Icons.folder_open),
                label: const Text('Browse'),
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
              child: FilledButton.icon(
                onPressed: canCopy ? _copyDuplicateCodes : null,
                icon: _isCopying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.content_copy_outlined),
                label: Text(
                  _isCopying
                      ? 'Copying...'
                      : 'Copy Duplicates${groups.isEmpty ? '' : ' (${groups.length})'}',
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          groups.isEmpty
              ? (result == null
                    ? 'Index a folder to detect document codes shared by '
                          'several files.'
                    : 'No document codes are shared by more than one file.')
              : '${groups.length} document code(s) shared by '
                    '${result!.duplicateFileCount} files. Each code gets its '
                    'own folder; source files are copied, never moved.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCopySummaryCard(ColorScheme colorScheme) {
    final copyResult = _copyResult!;
    final hasWarnings = copyResult.hasWarnings;

    return Card(
      elevation: 0,
      color: hasWarnings
          ? colorScheme.tertiaryContainer
          : colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: hasWarnings,
        leading: Icon(
          hasWarnings
              ? Icons.warning_amber_outlined
              : Icons.check_circle_outline,
          color: hasWarnings
              ? colorScheme.onTertiaryContainer
              : colorScheme.onSecondaryContainer,
        ),
        title: Text(
          'Duplicate copy: ${copyResult.totalCopied} file(s) into '
          '${copyResult.totalGroups} code folder(s)',
          style: TextStyle(
            color: hasWarnings
                ? colorScheme.onTertiaryContainer
                : colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          copyResult.destinationRoot,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hasWarnings
                ? colorScheme.onTertiaryContainer
                : colorScheme.onSecondaryContainer,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (copyResult.totalSkipped > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${copyResult.totalSkipped} file(s) were already up to date.',
                style: TextStyle(
                  color: hasWarnings
                      ? colorScheme.onTertiaryContainer
                      : colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          for (final warning in copyResult.warnings.take(10))
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  warning,
                  style: TextStyle(
                    color: hasWarnings
                        ? colorScheme.onTertiaryContainer
                        : colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ColorScheme colorScheme) {
    return Card(
      color: colorScheme.errorContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }

  Widget _buildWarningsCard(ColorScheme colorScheme) {
    final warnings = _result!.warnings;

    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(
          Icons.info_outline,
          color: colorScheme.onSecondaryContainer,
        ),
        title: Text(
          '${warnings.length} item${warnings.length == 1 ? '' : 's'} skipped '
          'while scanning',
          style: TextStyle(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: warnings
            .take(20)
            .map(
              (warning) => Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    warning,
                    style: TextStyle(color: colorScheme.onSecondaryContainer),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildScanningState(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final folderPath = _folderController.text.trim();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 20),
              Text(
                'Indexing folder...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Text(
                  folderPath,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scanning files and extracting document codes. '
                'Large archives may take a moment.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No folder indexed yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a folder and press "Index Folder" to build the inventory.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(ColorScheme colorScheme) {
    final result = _result!;
    final visibleFiles = _visibleFiles;
    final theme = Theme.of(context);

    final pageCount = visibleFiles.isEmpty
        ? 1
        : ((visibleFiles.length - 1) ~/ _pageSize) + 1;
    final currentPage = _page < pageCount ? _page : pageCount - 1;
    final pageStart = currentPage * _pageSize;
    final pageEnd = pageStart + _pageSize < visibleFiles.length
        ? pageStart + _pageSize
        : visibleFiles.length;
    final pageFiles = pageStart >= visibleFiles.length
        ? const <IndexedFile>[]
        : visibleFiles.sublist(pageStart, pageEnd);

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.table_rows_outlined, color: colorScheme.primary),
                Text(
                  'Indexed Files',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.description_outlined, size: 16),
                  label: Text('${visibleFiles.length} of ${result.totalFiles}'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.category_outlined, size: 16),
                  label: Text('${result.extensions.length} file types'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.tag, size: 16),
                  label: Text('${result.documentTypes.length} document types'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.data_usage, size: 16),
                  label: Text(_formatBytes(result.totalSizeInBytes)),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.folder_outlined, size: 16),
                  label: Text('${result.scannedDirectories} folders scanned'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search name, code, type or folder',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: _searchController.clear,
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  height: 44,
                  child: DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _typeFilter,
                        isExpanded: true,
                        items: _buildTypeFilterItems(result),
                        onChanged: (value) {
                          if (value != null) {
                            _log.d(
                              'Document type filter changed to '
                              '"${value == _allTypesFilter ? 'all' : value}".',
                            );
                            setState(() {
                              _typeFilter = value;
                              _page = 0;
                            });
                            _scrollTableToTop();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: pageFiles.isEmpty
                  ? Center(
                      child: Text(
                        'No files match the current filters.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Give the scroll content at least the viewport width so
                        // the table is centered when it is narrower than the
                        // card, and still scrolls horizontally when it is wider.
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: Center(
                              child: SingleChildScrollView(
                                controller: _tableScrollController,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    colorScheme.surfaceContainerHighest,
                                  ),
                                  headingRowHeight: 44,
                                  dataRowMinHeight: 40,
                                  dataRowMaxHeight: 48,
                                  columnSpacing: 24,
                                  columns: const [
                                    DataColumn(
                                      label: Text('Index'),
                                      numeric: true,
                                    ),
                                    DataColumn(label: Text('File Name')),
                                    DataColumn(label: Text('Type')),
                                    DataColumn(label: Text('Doc Code')),
                                    DataColumn(label: Text('Doc Type')),
                                    DataColumn(label: Text('Directory')),
                                    DataColumn(label: Text('Size')),
                                  ],
                                  rows: [
                                    for (var i = 0; i < pageFiles.length; i++)
                                      _buildTableRow(
                                        pageFiles[i],
                                        colorScheme,
                                        theme,
                                        index:
                                            _indexByFile[pageFiles[i]] ??
                                            pageStart + i + 1,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (visibleFiles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Showing ${pageStart + 1}-$pageEnd of ${visibleFiles.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: currentPage > 0
                        ? () => _goToPage(currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Page ${currentPage + 1} of $pageCount',
                    style: theme.textTheme.bodySmall,
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: currentPage < pageCount - 1
                        ? () => _goToPage(currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  DataRow _buildTableRow(
    IndexedFile file,
    ColorScheme colorScheme,
    ThemeData theme, {
    required int index,
  }) {
    final documentTypeTitle =
        DocumentTypeInfo.standardTypes[file.documentTypeCode]?.title;

    return DataRow(
      cells: [
        DataCell(
          Text(
            '$index',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DataCell(
          Tooltip(
            message: file.fullPath,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(file.fileName, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
        DataCell(
          Text(
            file.extension.isEmpty ? '—' : file.extension,
            style: theme.textTheme.bodySmall,
          ),
        ),
        DataCell(
          Tooltip(
            message: file.hasCompleteCode
                ? file.code
                : 'File name is shorter than ${IndexedFile.codeLength} characters',
            child: Text(
              file.code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: file.hasCompleteCode ? null : colorScheme.error,
              ),
            ),
          ),
        ),
        DataCell(
          Tooltip(
            message: (documentTypeTitle != null && documentTypeTitle.isNotEmpty)
                ? documentTypeTitle
                : 'No registered title for this code',
            child: Text(
              file.hasDocumentType ? file.documentTypeCode : '—',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: file.hasDocumentType
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        DataCell(
          Tooltip(
            message: file.fullPath,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                file.directoryPath,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            _formatBytes(file.sizeInBytes),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildTypeFilterItems(FileIndexResult result) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: _allTypesFilter,
        child: Text('All document types'),
      ),
    ];

    for (final code in result.documentTypes) {
      final title = DocumentTypeInfo.standardTypes[code]?.title;
      items.add(
        DropdownMenuItem(
          value: code,
          child: Text(
            title == null || title.isEmpty
                ? 'Doc type $code'
                : '$code · $title',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (result.files.any((file) => file.documentTypeCode.isEmpty)) {
      items.add(
        const DropdownMenuItem(
          value: _unknownTypeFilter,
          child: Text('Unmapped / short names'),
        ),
      );
    }

    return items;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';

    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024;
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final decimals = value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }
}

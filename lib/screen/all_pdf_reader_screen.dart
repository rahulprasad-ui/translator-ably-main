import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../ads/ad_helper.dart';
import '../ads/controller/native_controller.dart';
import '../ads/widget/custom_native_ad.dart';
import '../helper/my_dialogs.dart';
import '../helper/pref.dart';
import 'excel_to_pdf_screen.dart';
import 'jpg_to_pdf_screen.dart';
import 'pdf_editor_screen.dart';
import 'pdf_tools_screen.dart';
import 'pptx_to_pdf_screen.dart';
import 'premium/premium_screen.dart';
import 'word_to_pdf_screen.dart';

// Document Model
class DocItem {
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime modified;
  final String ext;
  bool isBookmarked;
  final bool isSample;

  DocItem({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modified,
    required this.ext,
    this.isBookmarked = false,
    this.isSample = false,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final m = modified.month.toString().padLeft(2, '0');
    final d = modified.day.toString().padLeft(2, '0');
    return '$m/$d/${modified.year}';
  }
}

class AllPdfReaderScreen extends StatefulWidget {
  const AllPdfReaderScreen({super.key});

  @override
  State<AllPdfReaderScreen> createState() => _AllPdfReaderScreenState();
}

class _AllPdfReaderScreenState extends State<AllPdfReaderScreen> with WidgetsBindingObserver {
  static const MethodChannel _storageChannel = MethodChannel('com.translator/storage_channel');

  int _bottomNavIndex = 0; // 0: All files, 1: Recent, 2: Bookmarks, 3: Tools
  int _selectedTab = 0; // 0: All, 1: PDF, 2: Word, 3: Excel, 4: PPT

  final _tabs = ['All', 'PDF', 'Word', 'Excel', 'PPT'];
  final List<DocItem> _documents = [];
  final Set<String> _bookmarkedPaths = {};
  final List<String> _recentPaths = [];

  bool _isLoading = true;
  bool _hasStoragePermission = true;
  bool _isSearchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Multi-select mode
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};

  // Sort order: 0: Date desc, 1: Name asc, 2: Size desc
  int _sortOrder = 0;

  // Active folder filter (null = show all)
  String? _selectedFolderFilter;

  // Native Ad
  final _nativeAdController = NativeAdController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bookmarkedPaths.addAll(Pref.bookmarkedPdfPaths);
    _recentPaths.addAll(Pref.recentPdfPaths);
    AdHelper.loadNativeAd(
      adController: _nativeAdController,
      templateType: TemplateType.small,
    );
    _checkPermissionAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nativeAdController.ad?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndLoad(silent: true);
    }
  }

  Future<void> _checkPermissionAndLoad({bool silent = false}) async {
    if (Platform.isAndroid) {
      try {
        final hasPerm = await _storageChannel.invokeMethod<bool>('hasStoragePermission') ?? true;
        if (mounted) setState(() => _hasStoragePermission = hasPerm);
        if (!hasPerm && !silent) {
          _requestStoragePermission();
        }
      } catch (_) {}
    }
    _loadDocuments();
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        await _storageChannel.invokeMethod('requestStoragePermission');
      } catch (_) {}
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);

    final List<DocItem> list = [];

    // 1. Android MediaStore Query (Queries Android OS index of all documents across the phone)
    if (Platform.isAndroid) {
      try {
        final List<dynamic>? mediaStoreDocs = await _storageChannel.invokeMethod('queryAllDocuments');
        if (mediaStoreDocs != null) {
          for (final item in mediaStoreDocs) {
            try {
              final path = item['path'] as String? ?? '';
              final name = item['name'] as String? ?? '';
              final size = (item['size'] as num?)?.toInt() ?? 0;
              final modifiedMillis = (item['modified'] as num?)?.toInt() ?? 0;
              final actualName = name.isNotEmpty ? name : path.split(Platform.pathSeparator).last;
              if (actualName.startsWith('.')) continue;
              final ext = actualName.contains('.') ? actualName.split('.').last.toLowerCase() : 'pdf';

              if (path.isNotEmpty && File(path).existsSync()) {
                if (!list.any((d) => d.path == path)) {
                  list.add(DocItem(
                    name: actualName,
                    path: path,
                    sizeBytes: size,
                    modified: modifiedMillis > 0
                        ? DateTime.fromMillisecondsSinceEpoch(modifiedMillis)
                        : DateTime.now(),
                    ext: ext,
                    isBookmarked: _bookmarkedPaths.contains(path),
                  ));
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // 2. Comprehensive Filesystem Scan
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _scanDirectory(appDir, list, maxDepth: 2);

      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        _scanDirectory(extDir, list, maxDepth: 2);
      }

      if (Platform.isAndroid) {
        final rootDir = Directory('/storage/emulated/0');
        if (rootDir.existsSync()) {
          try {
            final topEntries = rootDir.listSync(followLinks: false);
            for (final entry in topEntries) {
              if (entry is File) {
                _checkAndAddFile(entry, list);
              } else if (entry is Directory) {
                final folderName = entry.path.split(Platform.pathSeparator).last;
                if (folderName.startsWith('.')) continue;

                if (folderName.toLowerCase() == 'android') {
                  // Specifically scan Android/media (WhatsApp, Telegram documents)
                  final mediaDir = Directory('${entry.path}/media');
                  if (mediaDir.existsSync()) {
                    _scanDirectory(mediaDir, list, currentDepth: 0, maxDepth: 4);
                  }
                  continue;
                }

                // Scan all other directories (Download, Documents, Bluetooth, WPS, Books, etc.)
                _scanDirectory(entry, list, currentDepth: 0, maxDepth: 5);
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 3. Include previously saved recent or bookmarked files if they exist on disk
    for (final path in {..._recentPaths, ..._bookmarkedPaths}) {
      if (!list.any((d) => d.path == path)) {
        final file = File(path);
        if (file.existsSync()) {
          try {
            final stat = file.statSync();
            final name = file.uri.pathSegments.isNotEmpty
                ? file.uri.pathSegments.last
                : path.split(Platform.pathSeparator).last;
            final ext = path.split('.').last.toLowerCase();
            list.add(DocItem(
              name: name,
              path: path,
              sizeBytes: stat.size,
              modified: stat.modified,
              ext: ext,
              isBookmarked: _bookmarkedPaths.contains(path),
            ));
          } catch (_) {}
        }
      }
    }

    // Clean up any recent paths that no longer exist on device
    _recentPaths.removeWhere((p) => !File(p).existsSync());
    Pref.recentPdfPaths = _recentPaths;

    // Apply bookmarks
    for (final doc in list) {
      if (_bookmarkedPaths.contains(doc.path)) {
        doc.isBookmarked = true;
      }
    }

    setState(() {
      _documents.clear();
      _documents.addAll(list);
      _isLoading = false;
    });
  }

  void _checkAndAddFile(File file, List<DocItem> outList) {
    final ext = file.path.split('.').last.toLowerCase();
    if (const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
      if (!outList.any((item) => item.path == file.path)) {
        try {
          final stat = file.statSync();
          final name = file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : file.path.split(Platform.pathSeparator).last;
          if (name.startsWith('.')) return;
          outList.add(DocItem(
            name: name,
            path: file.path,
            sizeBytes: stat.size,
            modified: stat.modified,
            ext: ext,
            isBookmarked: _bookmarkedPaths.contains(file.path),
          ));
        } catch (_) {}
      }
    }
  }

  void _scanDirectory(Directory dir, List<DocItem> outList, {int currentDepth = 0, int maxDepth = 5}) {
    if (!dir.existsSync()) return;
    try {
      final entries = dir.listSync(followLinks: false);
      for (final e in entries) {
        try {
          if (e is File) {
            _checkAndAddFile(e, outList);
          } else if (e is Directory && currentDepth < maxDepth) {
            final seg = e.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
            // Avoid hidden directories and restricted Android internal folders
            if (!seg.startsWith('.') && seg != 'data' && seg != 'obb') {
              _scanDirectory(e, outList, currentDepth: currentDepth + 1, maxDepth: maxDepth);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _pickAndImportFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
      );

      if (result.isNotEmpty) {
        for (final pf in result) {
          if (pf.path != null) {
            final file = File(pf.path!);
            if (file.existsSync()) {
              final ext = pf.extension?.toLowerCase() ?? 'pdf';
              final doc = DocItem(
                name: pf.name,
                path: pf.path!,
                sizeBytes: file.lengthSync(),
                modified: DateTime.now(),
                ext: ext,
              );
              setState(() {
                _documents.removeWhere((d) => d.path == doc.path);
                _documents.insert(0, doc);
              });
            }
          }
        }
        MyDialogs.success(msg: 'Imported ${result.length} file(s)');
      }
    } catch (e) {
      MyDialogs.error(msg: 'Failed to import files: $e');
    }
  }

  String _folderNameFromPath(String path) {
    final clean = path.replaceAll('\\', '/');
    final parts = clean.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Folder';
    return parts.last;
  }

  Future<void> _pickFolderFromStorage() async {
    try {
      final String? selectedDir = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Folder',
      );

      if (selectedDir == null || selectedDir.isEmpty) return;

      final dir = Directory(selectedDir);
      if (!dir.existsSync()) {
        MyDialogs.error(msg: 'Folder cannot be accessed');
        return;
      }

      final List<DocItem> folderDocs = [];
      _scanDirectory(dir, folderDocs, currentDepth: 0, maxDepth: 4);

      if (folderDocs.isNotEmpty) {
        setState(() {
          for (final doc in folderDocs) {
            if (!_documents.any((d) => d.path == doc.path)) {
              _documents.insert(0, doc);
            }
          }
        });
        if (mounted) {
          _showFolderContents(
            folderPath: selectedDir,
            folderName: _folderNameFromPath(selectedDir),
            docs: folderDocs,
          );
        }
      } else {
        MyDialogs.info(msg: 'No PDF or Office documents found in this folder');
      }
    } catch (e) {
      MyDialogs.error(msg: 'Could not open folder: $e');
    }
  }

  void _showFoldersBottomSheet() {
    final Map<String, List<DocItem>> folderMap = {};
    for (final doc in _documents) {
      final parent = File(doc.path).parent.path;
      folderMap.putIfAbsent(parent, () => []).add(doc);
    }

    final folderEntries = folderMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_rounded, color: Color(0xFFF59E0B), size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Device Folders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // Prominent Storage Folder Picker Card
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickFolderFromStorage();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.create_new_folder_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Browse Folder from Storage',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Choose any directory on device to open its documents',
                                    style: TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD97706), size: 22),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        'FOLDERS WITH DOCUMENTS (${folderEntries.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (folderEntries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(
                                'No document folders found yet',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...folderEntries.map((entry) {
                        final folderPath = entry.key;
                        final folderDocs = entry.value;
                        final folderName = _folderNameFromPath(folderPath);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7EB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.folder_rounded, color: Color(0xFFF59E0B), size: 24),
                            ),
                            title: Text(
                              folderName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              folderPath,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${folderDocs.length} files',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showFolderContents(
                                folderPath: folderPath,
                                folderName: folderName,
                                docs: folderDocs,
                              );
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderContents({
    required String folderPath,
    required String folderName,
    required List<DocItem> docs,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_rounded, color: Color(0xFFF59E0B), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folderName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${docs.length} document${docs.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedFolderFilter = folderPath;
                          _selectedTab = 0;
                        });
                      },
                      icon: const Icon(Icons.filter_alt_outlined, size: 16),
                      label: const Text('Filter list', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Text(
                          'No documents in this folder',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 64, color: Color(0xFFF5F5F5)),
                        itemBuilder: (c, idx) {
                          final doc = docs[idx];
                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _openDocument(doc);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  _docBadge(doc.ext),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${doc.formattedDate} · ${doc.formattedSize}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                                    onPressed: () => _showDocOptions(doc),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DocItem> get _filteredDocuments {
    List<DocItem> list = List.from(_documents);

    // Filter by selected folder if active
    if (_selectedFolderFilter != null) {
      list = list.where((d) => File(d.path).parent.path == _selectedFolderFilter).toList();
    }

    // Filter by bottom navigation
    if (_bottomNavIndex == 1) {
      // Recent: only documents whose path is in _recentPaths
      list = list.where((d) => _recentPaths.contains(d.path)).toList();
      // Sort by the order in _recentPaths (most recently opened first)
      list.sort((a, b) {
        final indexA = _recentPaths.indexOf(a.path);
        final indexB = _recentPaths.indexOf(b.path);
        return indexA.compareTo(indexB);
      });
    } else if (_bottomNavIndex == 2) {
      // Bookmarks
      list = list.where((d) => d.isBookmarked).toList();
    }

    // Filter by top tabs (All, PDF, Word, Excel, PPT)
    if (_selectedTab == 1) {
      list = list.where((d) => d.ext == 'pdf').toList();
    } else if (_selectedTab == 2) {
      list = list.where((d) => d.ext == 'doc' || d.ext == 'docx').toList();
    } else if (_selectedTab == 3) {
      list = list.where((d) => d.ext == 'xls' || d.ext == 'xlsx').toList();
    } else if (_selectedTab == 4) {
      list = list.where((d) => d.ext == 'ppt' || d.ext == 'pptx').toList();
    }

    // Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((d) => d.name.toLowerCase().contains(q)).toList();
    }

    // Sort order (apply only when not on Recent tab, or if user explicitly sorted)
    if (_bottomNavIndex != 1) {
      if (_sortOrder == 0) {
        list.sort((a, b) => b.modified.compareTo(a.modified));
      } else if (_sortOrder == 1) {
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else if (_sortOrder == 2) {
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      }
    }

    return list;
  }

  void _openDocument(DocItem doc) {
    if (_recentPaths.contains(doc.path)) {
      _recentPaths.remove(doc.path);
    }
    _recentPaths.insert(0, doc.path);
    Pref.recentPdfPaths = _recentPaths;

    if (doc.ext == 'pdf') {
      if (File(doc.path).existsSync()) {
        Get.to(() => PdfEditorScreen(initialPdfPath: doc.path));
      } else {
        MyDialogs.error(msg: 'File does not exist or has been removed');
      }
    } else if (doc.ext == 'doc' || doc.ext == 'docx') {
      Get.to(() => const WordToPdfScreen());
    } else if (doc.ext == 'xls' || doc.ext == 'xlsx') {
      Get.to(() => const ExcelToPdfScreen());
    } else if (doc.ext == 'ppt' || doc.ext == 'pptx') {
      Get.to(() => const PptxToPdfScreen());
    }
  }

  void _toggleBookmark(DocItem doc) {
    setState(() {
      doc.isBookmarked = !doc.isBookmarked;
      if (doc.isBookmarked) {
        _bookmarkedPaths.add(doc.path);
      } else {
        _bookmarkedPaths.remove(doc.path);
      }
      Pref.bookmarkedPdfPaths = _bookmarkedPaths.toList();
    });
  }

  void _shareDocument(DocItem doc) {
    if (File(doc.path).existsSync()) {
      Share.shareXFiles([XFile(doc.path)], text: doc.name);
    } else {
      MyDialogs.error(msg: 'File does not exist or has been removed');
    }
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Sort By',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Date (Newest first)'),
                trailing: _sortOrder == 0 ? const Icon(Icons.check, color: Color(0xFFE53935)) : null,
                onTap: () {
                  setState(() => _sortOrder = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha_rounded),
                title: const Text('Name (A - Z)'),
                trailing: _sortOrder == 1 ? const Icon(Icons.check, color: Color(0xFFE53935)) : null,
                onTap: () {
                  setState(() => _sortOrder = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.data_usage_rounded),
                title: const Text('Size (Largest first)'),
                trailing: _sortOrder == 2 ? const Icon(Icons.check, color: Color(0xFFE53935)) : null,
                onTap: () {
                  setState(() => _sortOrder = 2);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocOptions(DocItem doc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _docBadge(doc.ext),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('${doc.formattedDate} · ${doc.formattedSize}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded, color: Colors.black87),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                _openDocument(doc);
              },
            ),
            ListTile(
              leading: Icon(
                doc.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: doc.isBookmarked ? const Color(0xFFE53935) : Colors.black87,
              ),
              title: Text(doc.isBookmarked ? 'Remove Bookmark' : 'Add to Bookmarks'),
              onTap: () {
                Navigator.pop(context);
                _toggleBookmark(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.black87),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareDocument(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: Colors.black87),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(context);
                _showDetailsDialog(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _documents.remove(doc);
                  _recentPaths.remove(doc.path);
                  _bookmarkedPaths.remove(doc.path);
                  Pref.recentPdfPaths = _recentPaths;
                  Pref.bookmarkedPdfPaths = _bookmarkedPaths.toList();
                });
                MyDialogs.info(msg: 'File removed from list');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(DocItem doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('File Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${doc.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Size: ${doc.formattedSize}'),
            const SizedBox(height: 4),
            Text('Modified: ${doc.formattedDate}'),
            const SizedBox(height: 4),
            Text('Type: ${doc.ext.toUpperCase()} Document'),
            const SizedBox(height: 4),
            Text('Location: ${doc.path}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showAddFabBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Create / Add Document',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF0F6FF),
                  child: Icon(Icons.file_upload_rounded, color: Color(0xFF3B82F6)),
                ),
                title: const Text('Import from Storage'),
                subtitle: const Text('Pick PDF, Word, Excel, PPT files'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndImportFiles();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF0F2),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFFE53935)),
                ),
                title: const Text('Scan / Image to PDF'),
                subtitle: const Text('Convert images to PDF document'),
                onTap: () {
                  Navigator.pop(context);
                  Get.to(() => const JpgToPdfScreen());
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF9EC),
                  child: Icon(Icons.construction_rounded, color: Color(0xFFF59E0B)),
                ),
                title: const Text('All PDF Tools'),
                subtitle: const Text('Edit, compress, merge, convert and more'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _bottomNavIndex = 3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bottomNavIndex == 3) {
      // PDF Tools tab
      return Scaffold(
        body: const PdfToolsScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    final docs = _filteredDocuments;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Get.back(),
        ),
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : null,
        actions: [
          if (!_isSearchOpen) ...[
            IconButton(
              icon: Lottie.asset('assets/lottie/crown.json', width: 36),
              onPressed: () => Get.dialog(const PremiumScreen()),
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.black87, size: 24),
              onPressed: () => setState(() => _isSearchOpen = true),
            ),
            IconButton(
              icon: const Icon(Icons.sort_rounded, color: Colors.black87, size: 24),
              onPressed: _showSortDialog,
            ),
            IconButton(
              icon: Icon(
                _isSelectionMode ? Icons.close_rounded : Icons.check_box_outlined,
                color: Colors.black87,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  _selectedFilePaths.clear();
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.black87),
              onPressed: () {
                setState(() {
                  _isSearchOpen = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
          ],
        ],
      ),

      body: Column(
        children: [
          // ── Storage Permission Banner ──
          if (!_hasStoragePermission && Platform.isAndroid)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_shared_rounded, color: Color(0xFFEA580C), size: 26),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show All Device Documents',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Grant All Files Access to view all PDF, Word, Excel & PPT files.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _requestStoragePermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // ── 3 Quick Action Cards ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _quickActionCard(
                    iconBg: const Color(0xFFE8F1FD),
                    iconColor: const Color(0xFF3B82F6),
                    icon: Icons.drive_file_move_rounded,
                    label: 'Import files',
                    onTap: _pickAndImportFiles,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionCard(
                    iconBg: const Color(0xFFFFECEF),
                    iconColor: const Color(0xFFE53935),
                    icon: Icons.image_rounded,
                    label: 'Image to PDF',
                    onTap: () => Get.to(() => const JpgToPdfScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionCard(
                    iconBg: const Color(0xFFFFF7EB),
                    iconColor: const Color(0xFFF59E0B),
                    icon: Icons.folder_rounded,
                    label: 'Folder',
                    onTap: _showFoldersBottomSheet,
                  ),
                ),
              ],
            ),
          ),

          // ── Tabs (All, PDF, Word, Excel, PPT) ──
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final isSelected = _selectedTab == i;
                return InkWell(
                  onTap: () => setState(() => _selectedTab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? const Color(0xFFE53935) : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      _tabs[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? const Color(0xFFE53935) : const Color(0xFF757575),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── Active Folder Filter Chip ──
          if (_selectedFolderFilter != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7EB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_rounded, size: 20, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Folder: ${_folderNameFromPath(_selectedFolderFilter!)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF92400E)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedFolderFilter = null),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDE68A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),



          // ── Document List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
                : RefreshIndicator(
                    color: const Color(0xFFE53935),
                    onRefresh: _loadDocuments,
                    child: docs.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _bottomNavIndex == 1
                                              ? Icons.access_time_rounded
                                              : _bottomNavIndex == 2
                                                  ? Icons.bookmark_border_rounded
                                                  : Icons.folder_open_rounded,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'No matching documents found'
                                              : _bottomNavIndex == 1
                                                  ? 'No recent documents'
                                                  : _bottomNavIndex == 2
                                                      ? 'No bookmarks yet'
                                                      : 'No ${_selectedTab == 0 ? "documents" : _tabs[_selectedTab]} found on this device',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'Try searching with a different filename'
                                              : _bottomNavIndex == 1
                                                  ? 'Documents you open will be listed here'
                                                  : _bottomNavIndex == 2
                                                      ? 'Bookmark important files to access them quickly'
                                                      : 'If you have PDF files on your device, you can also import them directly',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        if (_searchQuery.isEmpty && _bottomNavIndex == 0) ...[
                                          const SizedBox(height: 20),
                                          ElevatedButton.icon(
                                            onPressed: _pickAndImportFiles,
                                            icon: const Icon(Icons.file_upload_outlined, size: 20),
                                            label: const Text('Import from Storage'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFE53935),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: docs.length >= 2 ? docs.length + 1 : docs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 64, color: Color(0xFFF5F5F5)),
                            itemBuilder: (ctx, index) {
                              // Insert native ad between 1st and 2nd item (index 1) when at least 2 items
                              if (docs.length >= 2 && index == 1) {
                                return CustomNativeAd(
                                  adController: _nativeAdController,
                                  height: 85,
                                  safeArea: false,
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                );
                              }

                              final docIndex = (docs.length >= 2 && index > 1) ? index - 1 : index;
                              if (docIndex >= docs.length) return const SizedBox();
                              final doc = docs[docIndex];
                              final isSelected = _selectedFilePaths.contains(doc.path);

                          return InkWell(
                            onTap: () {
                              if (_isSelectionMode) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedFilePaths.remove(doc.path);
                                  } else {
                                    _selectedFilePaths.add(doc.path);
                                  }
                                });
                              } else {
                                _openDocument(doc);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  if (_isSelectionMode) ...[
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: const Color(0xFFE53935),
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedFilePaths.add(doc.path);
                                          } else {
                                            _selectedFilePaths.remove(doc.path);
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                  ],

                                  // Badge Icon
                                  _docBadge(doc.ext),

                                  const SizedBox(width: 14),

                                  // File Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${doc.formattedDate} · ${doc.formattedSize}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF9E9E9E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Bookmark icon or 3-dots
                                  if (doc.isBookmarked)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.bookmark_rounded,
                                          color: Color(0xFFE53935), size: 18),
                                    ),

                                  IconButton(
                                    icon: const Icon(Icons.more_vert_rounded,
                                        color: Color(0xFF9E9E9E), size: 20),
                                    onPressed: () => _showDocOptions(doc),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ),
          ),
        ],
      ),

      // ── Floating Action Button ──
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE53935),
        elevation: 4,
        onPressed: _showAddFabBottomSheet,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),

      // ── Bottom Navigation Bar ──
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _quickActionCard({
    required Color iconBg,
    required Color iconColor,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docBadge(String ext) {
    Color bg;
    String label;

    switch (ext) {
      case 'pdf':
        bg = const Color(0xFFE53935);
        label = 'PDF';
        break;
      case 'doc':
      case 'docx':
        bg = const Color(0xFF2563EB);
        label = 'DOC';
        break;
      case 'xls':
      case 'xlsx':
        bg = const Color(0xFF16A34A);
        label = 'XLS';
        break;
      case 'ppt':
      case 'pptx':
        bg = const Color(0xFFEA580C);
        label = 'PPT';
        break;
      default:
        bg = Colors.grey;
        label = ext.toUpperCase();
    }

    return Container(
      width: 40,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Stack(
        children: [
          // Folded corner effect
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFD1D5DB),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4)),
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 9.5,
                  letterSpacing: .5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (i) => setState(() => _bottomNavIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFE53935),
        unselectedItemColor: const Color(0xFF757575),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.description_rounded),
            label: 'All files',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_rounded),
            label: 'Recent',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border_rounded),
            label: 'Bookmarks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Tools',
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/telegram_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_text_field.dart';
import '../../auth/presentation/dual_auth_screen.dart';
import '../../auth/presentation/telegram_auth_modal.dart';
import '../../transfers/data/telegram_transfer_service.dart';
import '../data/storage_repository.dart';
import '../domain/models/file_model.dart';
import '../domain/models/folder_model.dart';

class StorageHomeScreen extends StatefulWidget {
  final String? initialFolderId;
  final String initialFolderName;

  const StorageHomeScreen({
    super.key,
    this.initialFolderId,
    this.initialFolderName = 'Root Vault',
  });

  @override
  State<StorageHomeScreen> createState() => _StorageHomeScreenState();
}

class _StorageHomeScreenState extends State<StorageHomeScreen> {
  final StorageRepository _storageRepo = StorageRepository();
  final TelegramTransferService _transferService = TelegramTransferService.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;
  final TelegramService _telegram = TelegramService.instance;

  List<FolderModel> _folders = [];
  List<FileModel> _files = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // All, Folders, Images, Docs, Media
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContents() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final foldersFuture = _storageRepo.getFolders(
        userId: userId,
        parentId: widget.initialFolderId,
      );
      final filesFuture = _storageRepo.getFiles(
        userId: userId,
        folderId: widget.initialFolderId,
      );

      final results = await Future.wait([foldersFuture, filesFuture]);
      if (mounted) {
        setState(() {
          _folders = results[0] as List<FolderModel>;
          _files = results[1] as List<FileModel>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<FolderModel> get _filteredFolders {
    if (_selectedFilter != 'All' && _selectedFilter != 'Folders') return [];
    if (_searchQuery.isEmpty) return _folders;
    return _folders
        .where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<FileModel> get _filteredFiles {
    if (_selectedFilter == 'Folders') return [];
    var list = _files;
    if (_selectedFilter == 'Images') {
      list = list.where((f) => ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(f.extension.toLowerCase())).toList();
    } else if (_selectedFilter == 'Docs') {
      list = list.where((f) => ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx'].contains(f.extension.toLowerCase())).toList();
    } else if (_selectedFilter == 'Media') {
      list = list.where((f) => ['mp4', 'mkv', 'mp3', 'wav', 'mov'].contains(f.extension.toLowerCase())).toList();
    }

    if (_searchQuery.isEmpty) return list;
    return list
        .where((f) => f.filename.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int get _totalVaultBytes {
    return _files.fold<int>(0, (sum, f) => sum + f.size);
  }

  String _formatTotalBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: GlassCard(
          blur: 24,
          opacity: 0.16,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.create_new_folder_rounded, color: AppTheme.accentCyan, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Create New Folder',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GlassTextField(
                controller: controller,
                hintText: 'e.g. Work Documents, Photos 2026',
                prefixIcon: Icons.folder_open_rounded,
                autofocus: true,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.subtleText)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isNotEmpty && _auth.currentUser != null) {
                          Navigator.pop(ctx);
                          await _storageRepo.createFolder(
                            name: name,
                            userId: _auth.currentUser!.uid,
                            parentId: widget.initialFolderId,
                          );
                          _loadContents();
                        }
                      },
                      child: const Text('Create Folder', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final pickedFile = File(result.files.single.path!);
    final filename = result.files.single.name;
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final isTelegramConnected = _telegram.vaultChannelId != null;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isTelegramConnected
                    ? 'Uploading $filename to Telegram Cloud...'
                    : 'Saving $filename to Local Vault...',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceDark,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    try {
      await _transferService.uploadFile(
        file: pickedFile,
        filename: filename,
        mimeType: result.files.single.extension ?? 'application/octet-stream',
        userId: userId,
        folderId: widget.initialFolderId,
      );

      if (mounted) {
        _loadContents();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.accentCyan, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('$filename uploaded successfully!')),
              ],
            ),
            backgroundColor: AppTheme.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Upload info: $e'),
            backgroundColor: AppTheme.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showAddActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: GlassCard(
          blur: 24,
          opacity: 0.16,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: AppTheme.accentCyan),
                ),
                title: const Text('Upload File', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Upload up to 2GB to cloud vault', style: TextStyle(fontSize: 12, color: AppTheme.subtleText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadFile();
                },
              ),
              const Divider(color: AppTheme.glassBorder, height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.create_new_folder_rounded, color: AppTheme.accentPurple),
                ),
                title: const Text('Create Folder', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Organize your files in subdirectories', style: TextStyle(fontSize: 12, color: AppTheme.subtleText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateFolderDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTelegramSetup() {
    TelegramAuthModal.show(
      context,
      onAuthenticated: () {
        setState(() {});
        _loadContents();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRoot = widget.initialFolderId == null;
    final isTelegramReady = _telegram.vaultChannelId != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Clean Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  if (!isRoot) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.surfaceDark,
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialFolderName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: _showTelegramSetup,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isTelegramReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isTelegramReady ? 'Telegram MTProto 2GB Active' : 'Tap to Connect Telegram (2GB)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isTelegramReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search toggle
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, size: 22),
                    color: Colors.white70,
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchQuery = '';
                          _searchController.clear();
                        }
                      });
                    },
                  ),
                  // User Profile & Logout
                  PopupMenuButton<String>(
                    icon: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.2),
                      child: Text(
                        (_auth.currentUser?.email?.substring(0, 1) ?? 'U').toUpperCase(),
                        style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w700),
                      ),
                    ),
                    color: AppTheme.surfaceDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.glassBorder),
                    ),
                    onSelected: (val) async {
                      if (val == 'telegram') {
                        _showTelegramSetup();
                      } else if (val == 'logout') {
                        await _auth.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const DualAuthScreen()),
                          );
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                          _auth.currentUser?.email ?? 'User',
                          style: const TextStyle(fontSize: 12, color: AppTheme.subtleText),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'telegram',
                        child: Row(
                          children: [
                            Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: isTelegramReady ? const Color(0xFF10B981) : AppTheme.accentCyan,
                            ),
                            const SizedBox(width: 10),
                            Text(isTelegramReady ? 'Telegram Settings' : 'Connect Telegram (2GB)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar (if activated)
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                child: GlassTextField(
                  controller: _searchController,
                  hintText: 'Search files and folders...',
                  prefixIcon: Icons.search_rounded,
                  autofocus: true,
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

            // Vault Status Card (Only on root when Telegram not connected)
            if (isRoot && !isTelegramReady)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  opacity: 0.12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_upload_outlined, color: AppTheme.accentCyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unlock Unlimited 2GB Cloud',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Connect Telegram MTProto session',
                              style: TextStyle(fontSize: 11, color: AppTheme.subtleText),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _showTelegramSetup,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Connect',
                          style: TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Filter Tabs (Horizontal chips)
            Container(
              height: 42,
              margin: const EdgeInsets.only(top: 6, bottom: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: ['All', 'Folders', 'Images', 'Docs', 'Media'].map((tab) {
                  final isSelected = _selectedFilter == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedFilter = tab),
                      backgroundColor: AppTheme.surfaceDark,
                      selectedColor: AppTheme.accentCyan.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.accentCyan : AppTheme.subtleText,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AppTheme.accentCyan.withValues(alpha: 0.5) : AppTheme.glassBorder,
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),

            // Content List / Empty State
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, color: AppTheme.accentCyan))
                  : (_filteredFolders.isEmpty && _filteredFiles.isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceDark,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppTheme.glassBorder),
                                  ),
                                  child: const Icon(
                                    Icons.folder_open_rounded,
                                    size: 34,
                                    color: AppTheme.subtleText,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _searchQuery.isNotEmpty ? 'No matches found' : 'This folder is empty',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Try searching with a different filename'
                                      : 'Upload files up to 2GB or create folders to organize your vault',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppTheme.subtleText, fontSize: 13),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _showCreateFolderDialog,
                                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                                      label: const Text('New Folder'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: AppTheme.glassBorder),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: _pickAndUploadFile,
                                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                                      label: const Text('Upload'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentCyan,
                                        foregroundColor: Colors.black87,
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadContents,
                          color: AppTheme.accentCyan,
                          backgroundColor: AppTheme.surfaceDark,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                            children: [
                              // Folders Section
                              if (_filteredFolders.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Folders (${_filteredFolders.length})',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 2.2,
                                  ),
                                  itemCount: _filteredFolders.length,
                                  itemBuilder: (ctx, index) {
                                    final folder = _filteredFolders[index];
                                    return GlassCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => StorageHomeScreen(
                                              initialFolderId: folder.id,
                                              initialFolderName: folder.name,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentCyan.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.folder_rounded,
                                              color: AppTheme.accentCyan,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  folder.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                const Text(
                                                  'Folder',
                                                  style: TextStyle(
                                                    color: AppTheme.subtleText,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Files Section
                              if (_filteredFiles.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Files (${_filteredFiles.length})',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      _formatTotalBytes(_totalVaultBytes),
                                      style: const TextStyle(
                                        color: AppTheme.subtleText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredFiles.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, index) {
                                    final file = _filteredFiles[index];
                                    final isLocal = file.telegramFileId.startsWith('local:');

                                    return GlassCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: (isLocal ? AppTheme.accentPurple : AppTheme.accentCyan)
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              isLocal ? Icons.save_alt_rounded : Icons.cloud_done_rounded,
                                              color: isLocal ? AppTheme.accentPurple : AppTheme.accentCyan,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  file.filename,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                      file.formattedSize,
                                                      style: const TextStyle(color: AppTheme.subtleText, fontSize: 11),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      width: 3,
                                                      height: 3,
                                                      decoration: const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: AppTheme.subtleText,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      isLocal ? 'Local Vault' : 'Telegram MTProto',
                                                      style: TextStyle(
                                                        color: isLocal ? AppTheme.accentPurple : AppTheme.accentCyan,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.download_rounded, color: AppTheme.accentCyan, size: 20),
                                            onPressed: () async {
                                              final localPath = await _transferService.downloadFile(
                                                telegramFileId: file.telegramFileId,
                                                filename: file.filename,
                                                priority: 1,
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(localPath != null
                                                        ? 'Ready: $localPath'
                                                        : 'Downloading ${file.filename}...'),
                                                    backgroundColor: AppTheme.surfaceDark,
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentCyan,
        foregroundColor: Colors.black87,
        elevation: 4,
        onPressed: _showAddActionSheet,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Add to Vault', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

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
import 'widgets/file_actions_modal.dart';
import 'widgets/image_preview_dialog.dart';
import 'widgets/transfer_progress_banner.dart';

enum SortOption {
  nameAsc,
  nameDesc,
  dateNewest,
  dateOldest,
  sizeLargest,
  sizeSmallest,
}

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
  SortOption _sortOption = SortOption.dateNewest;
  String _searchQuery = '';
  bool _isSearching = false;
  int _totalGlobalVaultBytes = 0;
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
      final globalBytesFuture = _storageRepo.getTotalVaultBytes(userId: userId);

      final results = await Future.wait([foldersFuture, filesFuture, globalBytesFuture]);
      if (mounted) {
        setState(() {
          _folders = results[0] as List<FolderModel>;
          _files = results[1] as List<FileModel>;
          _totalGlobalVaultBytes = results[2] as int;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<FolderModel> get _filteredFolders {
    if (_selectedFilter != 'All' && _selectedFilter != 'Folders') return [];
    var list = _folders;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case SortOption.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.nameDesc:
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOption.dateNewest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.dateOldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      default:
        break;
    }
    return list;
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

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((f) => f.filename.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case SortOption.nameAsc:
        list.sort((a, b) => a.filename.toLowerCase().compareTo(b.filename.toLowerCase()));
        break;
      case SortOption.nameDesc:
        list.sort((a, b) => b.filename.toLowerCase().compareTo(a.filename.toLowerCase()));
        break;
      case SortOption.dateNewest:
        list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        break;
      case SortOption.dateOldest:
        list.sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
        break;
      case SortOption.sizeLargest:
        list.sort((a, b) => b.size.compareTo(a.size));
        break;
      case SortOption.sizeSmallest:
        list.sort((a, b) => a.size.compareTo(b.size));
        break;
    }
    return list;
  }

  String _formatTotalBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // --- Folder Management ---

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
                    'Buat Folder Baru',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GlassTextField(
                controller: controller,
                hintText: 'Contoh: Dokumen Kerja, Foto 2026',
                prefixIcon: Icons.folder_open_rounded,
                autofocus: true,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal', style: TextStyle(color: AppTheme.subtleText)),
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
                      child: const Text('Simpan', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600)),
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

  void _showRenameFolderDialog(FolderModel folder) {
    final controller = TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Text('Ganti Nama Folder', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: GlassTextField(
          controller: controller,
          hintText: 'Nama folder baru',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.subtleText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != folder.name && _auth.currentUser != null) {
                Navigator.pop(ctx);
                await _storageRepo.renameFolder(
                  folderId: folder.id,
                  newName: newName,
                  userId: _auth.currentUser!.uid,
                );
                _loadContents();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(FolderModel folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Text('Hapus Folder?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Folder "${folder.name}" beserta semua file di dalamnya akan dihapus permanen.',
          style: const TextStyle(color: AppTheme.subtleText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.subtleText)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_auth.currentUser != null) {
                Navigator.pop(ctx);
                await _storageRepo.deleteFolder(
                  folderId: folder.id,
                  userId: _auth.currentUser!.uid,
                );
                _loadContents();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // --- Multi-File Upload ---

  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final total = result.files.length;
    int successCount = 0;

    messenger.showSnackBar(
      SnackBar(
        content: Text('Memulai pengunggahan $total file ke vault...'),
        backgroundColor: AppTheme.surfaceDark,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    for (final picked in result.files) {
      if (picked.path == null) continue;
      try {
        await _transferService.uploadFile(
          file: File(picked.path!),
          filename: picked.name,
          mimeType: picked.extension ?? 'application/octet-stream',
          userId: userId,
          folderId: widget.initialFolderId,
        );
        successCount++;
      } catch (e) {
        debugPrint('[StorageHome] Gagal mengunggah ${picked.name}: $e');
      }
    }

    if (mounted) {
      _loadContents();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$successCount dari $total file berhasil diunggah.'),
          backgroundColor: AppTheme.surfaceDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                title: const Text('Unggah File (Multi-Select)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Pilih satu atau banyak file sekaligus (hingga 2GB per file)', style: TextStyle(fontSize: 12, color: AppTheme.subtleText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadFiles();
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
                title: const Text('Buat Folder Baru', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Kelompokkan file Anda dalam sub-direktori', style: TextStyle(fontSize: 12, color: AppTheme.subtleText)),
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

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Urutkan Berdasarkan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              RadioListTile<SortOption>(
                title: const Text('Tanggal Terbaru', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: SortOption.dateNewest,
                groupValue: _sortOption,
                activeColor: AppTheme.accentCyan,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Tanggal Terlama', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: SortOption.dateOldest,
                groupValue: _sortOption,
                activeColor: AppTheme.accentCyan,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Nama File (A - Z)', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: SortOption.nameAsc,
                groupValue: _sortOption,
                activeColor: AppTheme.accentCyan,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Nama File (Z - A)', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: SortOption.nameDesc,
                groupValue: _sortOption,
                activeColor: AppTheme.accentCyan,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Ukuran Terbesar', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: SortOption.sizeLargest,
                groupValue: _sortOption,
                activeColor: AppTheme.accentCyan,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('Ukuran Terkecil', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: SortOption.sizeSmallest,
                groupValue: _sortOption,
                activeColor: AppTheme.accentCyan,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
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

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Text('Keluar dari Akun?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'Sesi vault dan Telegram Anda akan ditutup.',
          style: TextStyle(color: AppTheme.subtleText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppTheme.subtleText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.signOut();
      await _telegram.logOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DualAuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRoot = widget.initialFolderId == null;
    final isTelegramReady = _telegram.vaultChannelId != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
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
                                  isTelegramReady ? 'Telegram MTProto 2GB Aktif' : 'Tap untuk Sambung Telegram (2GB)',
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
                  // User Profile & Options
                  PopupMenuButton<String>(
                    icon: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.2),
                      child: Text(
                        (_auth.currentUser?.email?.substring(0, 1) ?? 'U').toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.accentCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    color: AppTheme.surfaceDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.glassBorder),
                    ),
                    onSelected: (val) {
                      if (val == 'telegram') {
                        _showTelegramSetup();
                      } else if (val == 'logout') {
                        _handleLogout();
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
                            Text(isTelegramReady ? 'Pengaturan Telegram' : 'Sambungkan Telegram (2GB)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Keluar Akun', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: GlassTextField(
                  controller: _searchController,
                  hintText: 'Cari file dan folder...',
                  prefixIcon: Icons.search_rounded,
                  autofocus: true,
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

            // Real-Time Transfer Progress Banner
            const TransferProgressBanner(),

            // Vault Storage Metric Card (Root only)
            if (isRoot)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  opacity: 0.1,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cloud_done_outlined, color: AppTheme.accentCyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Penyimpanan Vault Global',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatTotalBytes(_totalGlobalVaultBytes)} digunakan • Kuota 2GB per file tanpa batas',
                              style: const TextStyle(fontSize: 11, color: AppTheme.subtleText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Filter Tabs & Sort Button Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
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
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.sort_rounded, color: AppTheme.accentCyan, size: 20),
                    tooltip: 'Urutkan',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppTheme.glassBorder),
                      ),
                    ),
                    onPressed: _showSortModal,
                  ),
                ],
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
                                  _searchQuery.isNotEmpty ? 'Tidak ada hasil cocok' : 'Folder ini masih kosong',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Coba cari dengan kata kunci lain'
                                      : 'Unggah file hingga 2GB atau buat folder untuk merapikan penyimpanan',
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
                                      label: const Text('Folder Baru'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: AppTheme.glassBorder),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: _pickAndUploadFiles,
                                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                                      label: const Text('Unggah'),
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
                                      'Folder (${_filteredFolders.length})',
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
                                    childAspectRatio: 2.1,
                                  ),
                                  itemCount: _filteredFolders.length,
                                  itemBuilder: (ctx, index) {
                                    final folder = _filteredFolders[index];
                                    return GlassCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                          const SizedBox(width: 8),
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
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert_rounded, size: 16, color: AppTheme.subtleText),
                                            padding: EdgeInsets.zero,
                                            color: AppTheme.surfaceDark,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              side: const BorderSide(color: AppTheme.glassBorder),
                                            ),
                                            onSelected: (action) {
                                              if (action == 'rename') {
                                                _showRenameFolderDialog(folder);
                                              } else if (action == 'delete') {
                                                _showDeleteFolderDialog(folder);
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                value: 'rename',
                                                child: Text('Ganti Nama', style: TextStyle(color: Colors.white, fontSize: 13)),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Hapus Folder', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                              ),
                                            ],
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
                                      'File (${_filteredFiles.length})',
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
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredFiles.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, index) {
                                    final file = _filteredFiles[index];
                                    final isLocal = file.telegramFileId.startsWith('local:');
                                    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif']
                                        .contains(file.extension.toLowerCase());

                                    return GlassCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        if (isImage && isLocal) {
                                          ImagePreviewDialog.show(
                                            context,
                                            imagePath: file.telegramFileId.replaceFirst('local:', ''),
                                            filename: file.filename,
                                          );
                                        } else {
                                          if (_auth.currentUser != null) {
                                            FileActionsModal.show(
                                              context,
                                              file: file,
                                              userId: _auth.currentUser!.uid,
                                              onModified: _loadContents,
                                            );
                                          }
                                        }
                                      },
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
                                            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.subtleText, size: 20),
                                            onPressed: () {
                                              if (_auth.currentUser != null) {
                                                FileActionsModal.show(
                                                  context,
                                                  file: file,
                                                  userId: _auth.currentUser!.uid,
                                                  onModified: _loadContents,
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

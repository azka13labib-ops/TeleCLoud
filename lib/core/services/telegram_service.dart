import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages — general_lib is a transitive dep of telegram_client
import 'package:general_lib/general_lib.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:telegram_client/telegram_client.dart';
import 'local_database_service.dart';

/// Enum representing the current authorization state of Telegram TDLib
enum TelegramAuthState {
  uninitialized,
  waitingCredentials,
  waitingParameters,
  waitingPhoneNumber,
  waitingCode,
  waitingPassword,    
  ready,
  loggingOut,
  closed,
  error,
}

/// Service managing the low-level TDLib client for Telegram MTProto.
/// Handles session persistence, TDLib parameters, and authorization updates.
class TelegramService {
  TelegramService._();
  static final TelegramService instance = TelegramService._();

  // TDLib API Credentials - Obtain yours from https://my.telegram.org
  static int _apiId = 0;
  static String _apiHash = '';

  static int get apiId => _apiId;
  static String get apiHash => _apiHash;
  static bool get hasValidCredentials =>
      _apiId != 0 && _apiHash.isNotEmpty && _apiHash != 'YOUR_API_HASH_HERE';

  late final Tdlib _tdlib;
  late final int _clientId;

  TelegramAuthState _currentState = TelegramAuthState.uninitialized;
  int? _vaultChannelId;
  String? _lastErrorMessage;
  String? _lastDbDir;
  String? _lastFilesDir;

  EventEmitterListener? _updateListener;
  final StreamController<TelegramAuthState> _authStateController =
      StreamController<TelegramAuthState>.broadcast();
  final StreamController<Map<dynamic, dynamic>> _fileUpdateController =
      StreamController<Map<dynamic, dynamic>>.broadcast();

  bool _isInitialized = false;

  /// Exposes the authorization state updates stream for UI consumers
  Stream<TelegramAuthState> get onAuthStateChanged => _authStateController.stream;
  /// Exposes TDLib real-time file transfer updates (uploading & downloading progress)
  Stream<Map<dynamic, dynamic>> get onFileUpdated => _fileUpdateController.stream;
  TelegramAuthState get currentState => _currentState;
  int get clientId => _clientId;
  Tdlib get tdlib => _tdlib;
  int? get vaultChannelId => _vaultChannelId;
  bool get isInitialized => _isInitialized;
  String? get lastErrorMessage => _lastErrorMessage;

  /// Allows updating credentials dynamically from UI or config and persists them
  Future<void> updateCredentials({required int id, required String hash}) async {
    _apiId = id;
    _apiHash = hash;
    _lastErrorMessage = null;
    await LocalDatabaseService.instance.setSetting('telegram_api_id', id.toString());
    await LocalDatabaseService.instance.setSetting('telegram_api_hash', hash);

    if (_lastDbDir != null && _lastFilesDir != null) {
      await _sendTdlibParameters(
        databaseDirectory: _lastDbDir!,
        filesDirectory: _lastFilesDir!,
      );
    }
  }

  /// Initializes TDLib instance, local database/file storage directories, and authorization stream
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;

    try {
      debugPrint('[TelegramService] Initializing TDLib MTProto client (User: $userId)...');

      // Load saved credentials from SQLite if available
      final savedIdStr = await LocalDatabaseService.instance.getSetting('telegram_api_id');
      final savedHash = await LocalDatabaseService.instance.getSetting('telegram_api_hash');
      if (savedIdStr != null && int.tryParse(savedIdStr) != null) {
        _apiId = int.parse(savedIdStr);
      }
      if (savedHash != null && savedHash.isNotEmpty) {
        _apiHash = savedHash;
      }

      _tdlib = Tdlib();
      _clientId = _tdlib.td_create_client_id();

      final appDocDir = await getApplicationDocumentsDirectory();
      final userScope = userId != null ? 'user_$userId' : 'shared';
      final tdlibBaseDir = Directory(p.join(appDocDir.path, 'telegram_cloud_vault', userScope));

      final dbDirectory = Directory(p.join(tdlibBaseDir.path, 'tdlib_db'));
      final filesDirectory = Directory(p.join(tdlibBaseDir.path, 'tdlib_files'));

      if (!await dbDirectory.exists()) {
        await dbDirectory.create(recursive: true);
      }
      if (!await filesDirectory.exists()) {
        await filesDirectory.create(recursive: true);
      }

      _lastDbDir = dbDirectory.path;
      _lastFilesDir = filesDirectory.path;

      _setupUpdateListener(
        databaseDirectory: dbDirectory.path,
        filesDirectory: filesDirectory.path,
      );

      _isInitialized = true;
      debugPrint('[TelegramService] TDLib client initialized. Client ID: $_clientId');
    } catch (e, stackTrace) {
      debugPrint('[TelegramService] Error initializing TDLib: $e\n$stackTrace');
      _lastErrorMessage = e.toString();
      _setState(TelegramAuthState.error);
      rethrow;
    }
  }

  void _setState(TelegramAuthState state) {
    _currentState = state;
    _authStateController.add(state);
  }

  /// Sets up event listening loop from TDLib client
  void _setupUpdateListener({
    required String databaseDirectory,
    required String filesDirectory,
  }) {
    _updateListener = _tdlib.on(
      _tdlib.event_update,
      (UpdateTelegramClientTdlib updateTd) async {
        try {
          final Map<dynamic, dynamic> update = updateTd.update;
          final String? type = update['@type'] as String?;
          if (type == null) return;

          switch (type) {
            case 'updateAuthorizationState':
              await _handleAuthorizationState(
                update['authorization_state'] as Map<dynamic, dynamic>?,
                databaseDirectory: databaseDirectory,
                filesDirectory: filesDirectory,
              );
              break;

            case 'updateConnectionState':
              final connectionState = update['state']?['@type'];
              debugPrint('[TelegramService] Connection State: $connectionState');
              break;

            case 'updateFile':
              final fileObj = update['file'] as Map<dynamic, dynamic>?;
              if (fileObj != null) {
                _fileUpdateController.add(fileObj);
              }
              break;

            default:
              break;
          }
        } catch (err, stack) {
          debugPrint('[TelegramService] Error processing update: $err\n$stack');
        }
      },
      onError: (Object error) {
        debugPrint('[TelegramService] Stream error encountered: $error');
      },
    );
  }

  /// Handles incoming authorization steps and supplies TdlibParameters when requested
  Future<void> _handleAuthorizationState(
    Map<dynamic, dynamic>? authState, {
    required String databaseDirectory,
    required String filesDirectory,
  }) async {
    if (authState == null) return;

    final String? stateType = authState['@type'] as String?;
    debugPrint('[TelegramService] UpdateAuthorizationState: $stateType');

    switch (stateType) {
      case 'authorizationStateWaitTdlibParameters':
        _lastDbDir = databaseDirectory;
        _lastFilesDir = filesDirectory;

        if (!hasValidCredentials) {
          debugPrint('[TelegramService] Credentials not configured. Requesting from user.');
          _setState(TelegramAuthState.waitingCredentials);
          return;
        }

        _setState(TelegramAuthState.waitingParameters);
        await _sendTdlibParameters(
          databaseDirectory: databaseDirectory,
          filesDirectory: filesDirectory,
        );
        break;

      case 'authorizationStateWaitEncryptionKey':
        debugPrint('[TelegramService] Handling authorizationStateWaitEncryptionKey (Unlocking database)...');
        try {
          final res = await _tdlib.invoke(
            'checkDatabaseEncryptionKey',
            parameters: {'encryption_key': ''},
            clientId: _clientId,
          );
          debugPrint('[TelegramService] checkDatabaseEncryptionKey result: $res');
        } catch (e) {
          debugPrint('[TelegramService] Error unlocking database encryption: $e');
        }
        break;

      case 'authorizationStateWaitPhoneNumber':
        _setState(TelegramAuthState.waitingPhoneNumber);
        break;

      case 'authorizationStateWaitCode':
        _setState(TelegramAuthState.waitingCode);
        break;

      case 'authorizationStateWaitPassword':
        _setState(TelegramAuthState.waitingPassword);
        break;

      case 'authorizationStateReady':
        _setState(TelegramAuthState.ready);
        debugPrint('[TelegramService] TDLib authorization state READY. 2GB transfer vault unlocked!');
        await _findOrCreateVaultChannel();
        break;

      case 'authorizationStateLoggingOut':
        _setState(TelegramAuthState.loggingOut);
        break;

      case 'authorizationStateClosing':
      case 'authorizationStateClosed':
        _setState(TelegramAuthState.closed);
        break;

      default:
        debugPrint('[TelegramService] Unhandled auth state: $stateType');
        break;
    }
  }

  /// Sends TdlibParameters to configure local databases, MTProto credentials, and encryption
  Future<void> _sendTdlibParameters({
    required String databaseDirectory,
    required String filesDirectory,
  }) async {
    _lastDbDir = databaseDirectory;
    _lastFilesDir = filesDirectory;

    if (!hasValidCredentials) {
      _setState(TelegramAuthState.waitingCredentials);
      return;
    }

    try {
      debugPrint('[TelegramService] Sending TdlibParameters with api_id: $apiId...');
      _setState(TelegramAuthState.waitingParameters);

      final Map<String, dynamic> parameters = {
        'database_directory': databaseDirectory,
        'files_directory': filesDirectory,
        'use_file_database': true,
        'use_chat_info_database': true,
        'use_message_database': true,
        'use_secret_chats': false,
        'api_id': apiId,
        'api_hash': apiHash,
        'system_language_code': 'en',
        'device_model': Platform.operatingSystem,
        'system_version': Platform.operatingSystemVersion,
        'application_version': '1.0.0',
        'enable_storage_optimizer': true,
      };

      final response = await _tdlib.invoke(
        'setTdlibParameters',
        parameters: parameters,
        clientId: _clientId,
      );

      debugPrint('[TelegramService] setTdlibParameters result: $response');
      if (response['@type'] == 'error') {
        final msg = response['message'] as String? ?? 'Invalid TDLib parameters';
        _lastErrorMessage = msg;
        debugPrint('[TelegramService] TDLib parameters rejected: $msg');
        if (msg.contains('API_ID') || msg.contains('HASH') || msg.contains('api_id')) {
          _setState(TelegramAuthState.waitingCredentials);
        } else {
          _setState(TelegramAuthState.error);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[TelegramService] Failed to set TdlibParameters: $e\n$stackTrace');
      _lastErrorMessage = e.toString();
      _setState(TelegramAuthState.error);
    }
  }

  // --- Telegram MTProto Auth Actions ---

  /// Submits phone number to request OTP code
  Future<Map> sendPhoneNumber(String phoneNumber) async {
    try {
      debugPrint('[TelegramService] Sending phone number: $phoneNumber');
      final result = await _tdlib.invoke(
        'setAuthenticationPhoneNumber',
        parameters: {
          'phone_number': phoneNumber.replaceAll(' ', '').trim(),
        },
        clientId: _clientId,
      );
      if (result['@type'] == 'error') {
        throw Exception(result['message'] ?? 'Failed to send phone number');
      }
      return result;
    } catch (e) {
      debugPrint('[TelegramService] Error sending phone number: $e');
      rethrow;
    }
  }

  /// Submits verification OTP code sent to user Telegram account
  Future<Map> checkAuthenticationCode(String code) async {
    try {
      debugPrint('[TelegramService] Checking authentication code...');
      final result = await _tdlib.invoke(
        'checkAuthenticationCode',
        parameters: {
          'code': code.trim(),
        },
        clientId: _clientId,
      );
      if (result['@type'] == 'error') {
        throw Exception(result['message'] ?? 'Invalid verification code');
      }
      return result;
    } catch (e) {
      debugPrint('[TelegramService] Error verifying auth code: $e');
      rethrow;
    }
  }

  /// Submits 2-Factor Authentication Password (if enabled)
  Future<Map> checkAuthenticationPassword(String password) async {
    try {
      debugPrint('[TelegramService] Checking 2FA password...');
      final result = await _tdlib.invoke(
        'checkAuthenticationPassword',
        parameters: {
          'password': password,
        },
        clientId: _clientId,
      );
      if (result['@type'] == 'error') {
        throw Exception(result['message'] ?? 'Invalid 2FA password');
      }
      return result;
    } catch (e) {
      debugPrint('[TelegramService] Error verifying 2FA password: $e');
      rethrow;
    }
  }

  /// Log out from TDLib
  Future<void> logOut() async {
    try {
      await _tdlib.invoke('logOut', clientId: _clientId);
      _vaultChannelId = null;
      _setState(TelegramAuthState.waitingCredentials);
    } catch (e) {
      debugPrint('[TelegramService] Error logging out: $e');
    }
  }

  // --- Private Channel Vault Management ---

  /// Finds existing "Personal Cloud Vault" channel or creates a new Private Supergroup/Channel
  /// Falls back to user's Saved Messages chat (getMe) if creation is restricted.
  Future<int?> _findOrCreateVaultChannel() async {
    try {
      debugPrint('[TelegramService] Searching for Personal Cloud Vault channel...');
      // 1. Query user chats
      final getChatsRes = await _tdlib.invoke(
        'getChats',
        parameters: {
          'chat_list': {'@type': 'chatListMain'},
          'limit': 100,
        },
        clientId: _clientId,
      );

      final chatIds = (getChatsRes['chat_ids'] as List?)?.cast<int>() ?? [];
      for (final chatId in chatIds) {
        final chat = await _tdlib.invoke(
          'getChat',
          parameters: {'chat_id': chatId},
          clientId: _clientId,
        );
        final title = chat['title'] as String? ?? '';
        if (title.toLowerCase().contains('cloud vault') ||
            title.toLowerCase().contains('terabox')) {
          _vaultChannelId = chatId;
          debugPrint('[TelegramService] Found existing Vault Channel: $_vaultChannelId ($title)');
          return _vaultChannelId;
        }
      }

      // 2. If not found, create a new private supergroup channel
      debugPrint('[TelegramService] Creating new Private Cloud Vault channel...');
      try {
        final createChannelRes = await _tdlib.invoke(
          'createNewSupergroupChat',
          parameters: {
            'title': 'Personal Cloud Vault',
            'is_channel': true,
            'description': 'Private storage vault managed by TeraBox Telegram Cloud app.',
          },
          clientId: _clientId,
        );

        if (createChannelRes['@type'] != 'error' && createChannelRes['id'] != null) {
          _vaultChannelId = createChannelRes['id'] as int;
          debugPrint('[TelegramService] Created new Vault Channel: $_vaultChannelId');
          return _vaultChannelId;
        }
      } catch (err) {
        debugPrint('[TelegramService] createNewSupergroupChat failed: $err');
      }

      // 3. Fallback: Use user's own "Saved Messages" chat (chat_id == user_id)
      debugPrint('[TelegramService] Falling back to user Saved Messages chat...');
      final me = await _tdlib.invoke('getMe', clientId: _clientId);
      if (me['id'] != null) {
        _vaultChannelId = me['id'] as int;
        debugPrint('[TelegramService] Using Saved Messages chat ID: $_vaultChannelId');
        return _vaultChannelId;
      }

      return _vaultChannelId;
    } catch (e) {
      debugPrint('[TelegramService] Failed to resolve vault channel: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _updateListener?.cancel();
    await _authStateController.close();
    _isInitialized = false;
  }
}

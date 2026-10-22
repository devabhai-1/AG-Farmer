import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import 'api_client.dart';

/// Sync / restore chats from Realtime Database (per logged-in email + uid).
/// Local phone storage is only a UI cache — server RTDB is source of truth.
class ChatSyncService {
  ChatSyncService();
  static final ChatSyncService instance = ChatSyncService();

  bool _restoredOnce = false;

  Future<List<ChatMessage>> restore({
    String mode = 'chat',
    String? cropId,
    String? sessionId,
    int limit = 400,
  }) async {
    if (!ApiClient.instance.hasSession) return const [];
    if (ApiClient.instance.isLikelyDown) return const [];
    try {
      final res = await ApiClient.instance.call(
        'chat.restore',
        auth: true,
        data: {
          'mode': mode,
          if (cropId != null && cropId.isNotEmpty) 'cropId': cropId,
          if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
          'limit': limit,
        },
        timeout: const Duration(seconds: 12),
      );
      final list = (res['messages'] as List?) ?? const [];
      final messages = list
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.text.trim().isNotEmpty || m.hasMedia)
          .toList();
      if (mode == 'chat') _restoredOnce = true;
      if (kDebugMode) {
        debugPrint(
          'Chat restore[$mode${cropId != null ? '/$cropId' : ''}'
          '${sessionId != null ? '/$sessionId' : ''}]: '
          '${messages.length} msgs storage=${res['storage']}',
        );
      }
      return messages;
    } catch (e) {
      if (kDebugMode) debugPrint('Chat restore skipped: $e');
      return const [];
    }
  }

  Future<void> sync(
    List<ChatMessage> messages, {
    String mode = 'chat',
    String? cropId,
    String? sessionId,
    String? chatName,
  }) async {
    if (!ApiClient.instance.hasSession) return;
    final payload = messages
        .where((m) => !m.id.startsWith('welcome_'))
        .map((m) => m.toJson())
        .toList();
    if (payload.isEmpty) return;
    try {
      await ApiClient.instance.call(
        'chat.sync',
        auth: true,
        data: {
          'messages': payload,
          'mode': mode,
          if (cropId != null && cropId.isNotEmpty) 'cropId': cropId,
          if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
          if (chatName != null && chatName.isNotEmpty) 'chatName': chatName,
        },
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Chat sync skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>> listSessions({String mode = 'chat'}) async {
    if (!ApiClient.instance.hasSession) return const [];
    try {
      final res = await ApiClient.instance.call(
        'chat.sessions.list',
        auth: true,
        data: {'mode': mode},
        timeout: const Duration(seconds: 10),
      );
      final list = (res['sessions'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Chat sessions list skipped: $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> createSession({
    String? sessionId,
    String? chatName,
  }) async {
    if (!ApiClient.instance.hasSession) return null;
    try {
      final res = await ApiClient.instance.call(
        'chat.sessions.create',
        auth: true,
        data: {
          if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
          if (chatName != null && chatName.isNotEmpty) 'chatName': chatName,
        },
        timeout: const Duration(seconds: 10),
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      if (kDebugMode) debugPrint('Chat session create skipped: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> deleteSession(String sessionId) async {
    if (!ApiClient.instance.hasSession) return null;
    if (sessionId.trim().isEmpty) return null;
    try {
      final res = await ApiClient.instance.call(
        'chat.sessions.delete',
        auth: true,
        data: {'sessionId': sessionId},
        timeout: const Duration(seconds: 12),
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      if (kDebugMode) debugPrint('Chat session delete skipped: $e');
      return null;
    }
  }

  bool get didRestore => _restoredOnce;
}

final chatSyncService = ChatSyncService.instance;

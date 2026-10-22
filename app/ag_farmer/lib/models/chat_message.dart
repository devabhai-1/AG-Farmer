enum MessageRole { user, assistant }

enum ChatMediaType { none, image, video, audio, file }

class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime createdAt;
  final String? imagePath;
  final String? mediaPath;
  final ChatMediaType mediaType;
  final String? mediaName;
  final int? mediaBytes;
  final String? dosageHighlight;
  final List<String> quickReplies;
  final String? cropTag;
  /// gemini | openai | local | fallback
  final String? aiProvider;
  /// e.g. internal model id (never shown in UI)
  final String? aiModel;
  final bool isStreaming;
  final bool isDeepResearch;
  final String? exampleImageUrl;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.createdAt,
    this.imagePath,
    this.mediaPath,
    this.mediaType = ChatMediaType.none,
    this.mediaName,
    this.mediaBytes,
    this.dosageHighlight,
    this.quickReplies = const [],
    this.cropTag,
    this.aiProvider,
    this.aiModel,
    this.isStreaming = false,
    this.isDeepResearch = false,
    this.exampleImageUrl,
  });

  String? get displayMediaPath => mediaPath ?? imagePath;

  bool get hasMedia =>
      mediaType != ChatMediaType.none &&
      (displayMediaPath != null && displayMediaPath!.isNotEmpty);

  String get aiLabel {
    final p = (aiProvider ?? '').toLowerCase();
    if (p == 'gemini') return 'AG High';
    if (p == 'openai') return 'AG Expert';
    if (p == 'fallback' || p == 'local') return 'AG Farmer';
    // Never expose vendor/model ids (gpt-*, gemini-*) in the UI.
    return '';
  }

  /// Short name for the compact picker button.
  static String providerDisplayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'gemini':
        return 'AG High';
      case 'openai':
        return 'AG Expert';
      default:
        return 'AG Expert';
    }
  }

  static String providerSubtitle(String provider, {required bool isHi}) {
    switch (provider.toLowerCase()) {
      case 'gemini':
        return isHi ? 'तेज़ व साफ़ खेती सलाह' : 'Clear farming tips';
      case 'openai':
        return isHi ? 'डीप व सटीक खेती सलाह' : 'Detailed farming advice';
      default:
        return isHi ? 'खेती AI सलाह' : 'Farming AI advice';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
        'dosageHighlight': dosageHighlight,
        'quickReplies': quickReplies,
        'cropTag': cropTag,
        'aiProvider': aiProvider,
        'aiModel': aiModel,
        'isStreaming': isStreaming,
        'isDeepResearch': isDeepResearch,
        'exampleImageUrl': exampleImageUrl,
        if (imagePath != null) 'imagePath': imagePath,
        if (mediaPath != null) 'mediaPath': mediaPath,
        'mediaType': mediaType.name,
        if (mediaName != null) 'mediaName': mediaName,
        if (mediaBytes != null) 'mediaBytes': mediaBytes,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> m) {
    final roleName = '${m['role'] ?? 'assistant'}';
    final mediaRaw = '${m['mediaType'] ?? 'none'}';
    return ChatMessage(
      id: '${m['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      text: '${m['text'] ?? ''}',
      role: roleName == 'user' ? MessageRole.user : MessageRole.assistant,
      createdAt: DateTime.tryParse('${m['createdAt']}') ?? DateTime.now(),
      imagePath: m['imagePath']?.toString(),
      mediaPath: m['mediaPath']?.toString(),
      mediaType: ChatMediaType.values.firstWhere(
        (e) => e.name == mediaRaw,
        orElse: () => ChatMediaType.none,
      ),
      mediaName: m['mediaName']?.toString(),
      mediaBytes: m['mediaBytes'] is int
          ? m['mediaBytes'] as int
          : int.tryParse('${m['mediaBytes'] ?? ''}'),
      dosageHighlight: m['dosageHighlight']?.toString(),
      quickReplies:
          (m['quickReplies'] as List?)?.map((e) => '$e').toList() ?? const [],
      cropTag: m['cropTag']?.toString(),
      aiProvider: m['aiProvider']?.toString() ?? m['source']?.toString(),
      aiModel: m['aiModel']?.toString() ?? m['model']?.toString(),
      isStreaming: m['isStreaming'] == true,
      isDeepResearch: m['isDeepResearch'] == true || m['deep'] == true,
      exampleImageUrl: m['exampleImageUrl']?.toString() ??
          m['exampleImage']?.toString() ??
          m['imageUrl']?.toString(),
    );
  }

  ChatMessage copyWith({
    String? id,
    String? text,
    MessageRole? role,
    DateTime? createdAt,
    String? imagePath,
    String? mediaPath,
    ChatMediaType? mediaType,
    String? mediaName,
    int? mediaBytes,
    String? dosageHighlight,
    List<String>? quickReplies,
    String? cropTag,
    String? aiProvider,
    String? aiModel,
    bool? isStreaming,
    bool? isDeepResearch,
    String? exampleImageUrl,
    bool clearExampleImageUrl = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      imagePath: imagePath ?? this.imagePath,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      mediaName: mediaName ?? this.mediaName,
      mediaBytes: mediaBytes ?? this.mediaBytes,
      dosageHighlight: dosageHighlight ?? this.dosageHighlight,
      quickReplies: quickReplies ?? this.quickReplies,
      cropTag: cropTag ?? this.cropTag,
      aiProvider: aiProvider ?? this.aiProvider,
      aiModel: aiModel ?? this.aiModel,
      isStreaming: isStreaming ?? this.isStreaming,
      isDeepResearch: isDeepResearch ?? this.isDeepResearch,
      exampleImageUrl: clearExampleImageUrl
          ? null
          : (exampleImageUrl ?? this.exampleImageUrl),
    );
  }
}

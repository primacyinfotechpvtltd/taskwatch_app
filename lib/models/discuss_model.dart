import 'package:get/get.dart';
import 'package:pi_task_watch/controllers/auth_controller.dart';
import 'package:pi_task_watch/utils/format_utils.dart';

class DiscussChannelModel {
  final int id;
  final String name;
  final String channelType; // 'chat', 'channel', 'group'
  final String? description;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int? otherPartnerId;
  final String? otherPartnerName;
  final String? imStatus; // 'online', 'offline', 'away', 'busy'

  bool get isOnline => imStatus == 'online';
  bool get isAway => imStatus == 'away' || imStatus == 'idle';
  bool get isBusy => imStatus == 'busy' || imStatus == 'dnd';
  bool get isOffline => imStatus == 'offline' || imStatus == null || imStatus!.isEmpty;

  DiscussChannelModel({
    required this.id,
    required this.name,
    required this.channelType,
    this.description,
    required this.unreadCount,
    this.lastMessage,
    this.lastMessageTime,
    this.otherPartnerId,
    this.otherPartnerName,
    this.imStatus,
  });

  factory DiscussChannelModel.fromJson(Map<String, dynamic> json, {int? currentPartnerId}) {
    // If it's a chat (direct message), name is typically "Partner A, Partner B" or similar,
    // or we can extract the other partner's name.
    String name = json['name'] is String ? json['name'] as String : 'Unnamed Channel';
    String channelType = json['channel_type'] is String ? json['channel_type'] as String : 'channel';
    
    int? otherId;
    String? otherName;

    // Parse partner_ids or channel_partner_ids to find the other user if it's a direct chat
    final partners = json['channel_partner_ids'] ?? json['partner_ids'];
    if (channelType == 'chat' && partners != null && currentPartnerId != null) {
      if (partners is List) {
        for (var p in partners) {
          if (p is int && p != currentPartnerId) {
            otherId = p;
          } else if (p is List && p.length >= 2) {
            final pId = p[0] as int;
            if (pId != currentPartnerId) {
              otherId = pId;
              otherName = p[1].toString();
            }
          }
        }
      }
    }

    // Clean channel name if it's other user's name
    if (channelType == 'chat') {
      if (otherName != null) {
        name = otherName;
      } else {
        String currentUserName = '';
        try {
          if (Get.isRegistered<AuthController>()) {
            currentUserName = Get.find<AuthController>().user.value?.name ?? '';
          }
        } catch (_) {}
        if (currentUserName.isNotEmpty) {
          final parts = name.split(',').map((s) => s.trim()).toList();
          final otherParts = parts.where((p) => p.toLowerCase() != currentUserName.toLowerCase()).toList();
          if (otherParts.isNotEmpty) {
            name = otherParts.join(', ');
          }
        }
      }
    }

    DateTime? lastMsgTime;
    if (json['last_message_date'] != null && json['last_message_date'] != false) {
      lastMsgTime = FormatUtils.tryParseOdooDateTime(json['last_message_date']);
    }

    final imStat = json['im_status'] is String ? json['im_status'] as String : null;

    return DiscussChannelModel(
      id: json['id'] is int ? json['id'] as int : 0,
      name: name,
      channelType: channelType,
      description: json['description'] is String ? json['description'] as String : null,
      unreadCount: json['message_unread_counter'] is int ? json['message_unread_counter'] as int : 0,
      lastMessage: json['last_message_body'] is String 
          ? FormatUtils.cleanHtml(json['last_message_body'] as String) 
          : null,
      lastMessageTime: lastMsgTime,
      otherPartnerId: otherId,
      otherPartnerName: otherName,
      imStatus: imStat,
    );
  }

  DiscussChannelModel copyWith({
    int? id,
    String? name,
    String? channelType,
    String? description,
    int? unreadCount,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? otherPartnerId,
    String? otherPartnerName,
    String? imStatus,
  }) {
    return DiscussChannelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      channelType: channelType ?? this.channelType,
      description: description ?? this.description,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      otherPartnerId: otherPartnerId ?? this.otherPartnerId,
      otherPartnerName: otherPartnerName ?? this.otherPartnerName,
      imStatus: imStatus ?? this.imStatus,
    );
  }
}

class DiscussAttachmentModel {
  final int id;
  final String name;
  final String mimetype;
  final int fileSize;

  DiscussAttachmentModel({
    required this.id,
    required this.name,
    required this.mimetype,
    required this.fileSize,
  });

  factory DiscussAttachmentModel.fromJson(Map<String, dynamic> json) {
    return DiscussAttachmentModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'File',
      mimetype: json['mimetype'] ?? 'application/octet-stream',
      fileSize: json['file_size'] ?? 0,
    );
  }
}

class DiscussMessageModel {
  final int id;
  final String body;
  final String cleanBody;
  final int? parentId;
  final String? replyAuthor;
  final String? replyText;
  final String contentBody;
  final int authorId;
  final String authorName;
  final DateTime date;
  final bool isOutgoing;
  final bool isStarred;
  final bool isDeleted;
  final List<int> attachmentIds;
  final List<DiscussAttachmentModel> attachments;

  DiscussMessageModel({
    required this.id,
    required this.body,
    required this.cleanBody,
    this.parentId,
    this.replyAuthor,
    this.replyText,
    String? contentBody,
    required this.authorId,
    required this.authorName,
    required this.date,
    required this.isOutgoing,
    this.isStarred = false,
    this.isDeleted = false,
    this.attachmentIds = const [],
    this.attachments = const [],
  }) : contentBody = contentBody ?? cleanBody;

  bool get isReply => (replyText != null && replyText!.isNotEmpty);

  String get displayBody {
    if (isDeleted || (contentBody.trim().isEmpty && cleanBody.trim().isEmpty && attachments.isEmpty && attachmentIds.isEmpty && !isReply)) {
      return 'This message is deleted';
    }
    final text = contentBody.isNotEmpty ? contentBody : cleanBody;
    if (text.trim().isEmpty && (attachments.isNotEmpty || attachmentIds.isNotEmpty)) {
      final isImage = attachments.any((a) => a.mimetype.startsWith('image/'));
      return isImage ? '📷 Image' : '📄 Attachment';
    }
    return text;
  }

  factory DiscussMessageModel.fromJson(Map<String, dynamic> json, int currentPartnerId) {
    int authId = 0;
    String authName = 'System';
    final authorField = json['author_id'];
    if (authorField is List && authorField.length >= 2) {
      authId = authorField[0] as int;
      authName = authorField[1].toString();
    } else if (authorField is int) {
      authId = authorField;
    }

    int? parentMsgId;
    final parentField = json['parent_id'];
    if (parentField is List && parentField.isNotEmpty) {
      parentMsgId = parentField[0] is int ? parentField[0] as int : null;
    } else if (parentField is int && parentField > 0) {
      parentMsgId = parentField;
    }

    String bodyStr = json['body'] ?? '';
    DateTime msgDate = DateTime.now();
    if (json['date'] != null && json['date'] != false) {
      msgDate = FormatUtils.parseOdooDateTime(json['date']);
    }

    final rawAttachments = json['attachment_ids'];
    List<int> attachmentsList = [];
    if (rawAttachments is List) {
      attachmentsList = rawAttachments.map<int>((x) {
        if (x is int) return x;
        if (x is Map && x['id'] is int) return x['id'] as int;
        return 0;
      }).where((id) => id > 0).toList();
    }

    final bool starred = json['starred'] == true || json['is_starred'] == true;

    String? replyAuthor;
    String? replyText;

    // Unescape HTML entities first to reliably detect quotes
    final unescaped = bodyStr
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    String cleanBody = FormatUtils.cleanHtml(unescaped);
    String contentBody = cleanBody;

    final cleanLower = cleanBody.toLowerCase().trim();
    final bodyLower = bodyStr.toLowerCase().trim();

    final bool isMsgDeleted = bodyLower.contains('this message is deleted') ||
        bodyLower.contains('this message was deleted') ||
        bodyLower.contains('message deleted') ||
        cleanLower == 'this message is deleted' ||
        cleanLower == 'this message was deleted' ||
        cleanLower == 'message deleted' ||
        (cleanLower.isEmpty && attachmentsList.isEmpty && (bodyLower == '<p></p>' || bodyLower == '<p><br></p>' || bodyLower == '<div></div>' || bodyLower.isEmpty));

    // Parse blockquote if present: e.g. <blockquote><b>Aniket Rai:</b> hi</blockquote> or &lt;blockquote&gt;
    final quoteMatch = RegExp(
      r'<blockquote[^>]*>(?:<p[^>]*>)?(?:<b[^>]*>)?([^:<]+)?(?::\s*</b>|:\s*</b\s*>|:)?\s*([\s\S]*?)(?:</p>)?</blockquote>',
      caseSensitive: false,
    ).firstMatch(unescaped);

    if (quoteMatch != null) {
      replyAuthor = quoteMatch.group(1)?.trim();
      replyText = FormatUtils.cleanHtml(quoteMatch.group(2) ?? '').trim();
      final remaining = unescaped.replaceFirst(quoteMatch.group(0)!, '');
      contentBody = FormatUtils.cleanHtml(remaining).trim();
    } else {
      // Also check for plain text quoted format: "» Author: text\nReply"
      final plainQuoteMatch = RegExp(
        r'^»\s*([^:\n]+):\s*([^\n]+)\n+([\s\S]*)',
        caseSensitive: false,
      ).firstMatch(cleanBody);
      if (plainQuoteMatch != null) {
        replyAuthor = plainQuoteMatch.group(1)?.trim();
        replyText = plainQuoteMatch.group(2)?.trim();
        contentBody = plainQuoteMatch.group(3)?.trim() ?? '';
      }
    }

    return DiscussMessageModel(
      id: json['id'] ?? 0,
      body: bodyStr,
      cleanBody: cleanBody,
      parentId: parentMsgId,
      replyAuthor: replyAuthor,
      replyText: replyText,
      contentBody: contentBody,
      authorId: authId,
      authorName: authName,
      date: msgDate,
      isOutgoing: authId == currentPartnerId,
      isStarred: starred,
      isDeleted: isMsgDeleted,
      attachmentIds: attachmentsList,
    );
  }

  DiscussMessageModel copyWith({
    int? id,
    String? body,
    String? cleanBody,
    int? parentId,
    String? replyAuthor,
    String? replyText,
    String? contentBody,
    int? authorId,
    String? authorName,
    DateTime? date,
    bool? isOutgoing,
    bool? isStarred,
    bool? isDeleted,
    List<int>? attachmentIds,
    List<DiscussAttachmentModel>? attachments,
  }) {
    return DiscussMessageModel(
      id: id ?? this.id,
      body: body ?? this.body,
      cleanBody: cleanBody ?? this.cleanBody,
      parentId: parentId ?? this.parentId,
      replyAuthor: replyAuthor ?? this.replyAuthor,
      replyText: replyText ?? this.replyText,
      contentBody: contentBody ?? this.contentBody,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      date: date ?? this.date,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      isStarred: isStarred ?? this.isStarred,
      isDeleted: isDeleted ?? this.isDeleted,
      attachmentIds: attachmentIds ?? this.attachmentIds,
      attachments: attachments ?? this.attachments,
    );
  }
}

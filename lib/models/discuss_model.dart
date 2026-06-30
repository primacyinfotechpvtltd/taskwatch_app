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
    if (json['last_message_date'] != null && json['last_message_date'] is String) {
      try {
        lastMsgTime = DateTime.parse(json['last_message_date'] as String);
      } catch (_) {}
    }

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
    );
  }
}

class DiscussMessageModel {
  final int id;
  final String body;
  final String cleanBody;
  final int authorId;
  final String authorName;
  final DateTime date;
  final bool isOutgoing;

  DiscussMessageModel({
    required this.id,
    required this.body,
    required this.cleanBody,
    required this.authorId,
    required this.authorName,
    required this.date,
    required this.isOutgoing,
  });

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

    String bodyStr = json['body'] ?? '';
    DateTime msgDate = DateTime.now();
    if (json['date'] != null) {
      try {
        msgDate = DateTime.parse(json['date']).toLocal();
      } catch (_) {}
    }

    return DiscussMessageModel(
      id: json['id'] ?? 0,
      body: bodyStr,
      cleanBody: FormatUtils.cleanHtml(bodyStr),
      authorId: authId,
      authorName: authName,
      date: msgDate,
      isOutgoing: authId == currentPartnerId,
    );
  }
}

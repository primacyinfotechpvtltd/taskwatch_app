import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:pi_task_watch/exports.dart';

enum MessageTickStatus {
  none,
  single,
  doubleGray,
  doubleBlue,
}

class DiscussController extends GetxController with WidgetsBindingObserver {
  final RxList<DiscussChannelModel> channels = <DiscussChannelModel>[].obs;
  final RxMap<int, List<DiscussMessageModel>> channelMessages = <int, List<DiscussMessageModel>>{}.obs;
  final Map<int, int> channelMemberIds = {};
  
  final RxBool isLoadingChannels = false.obs;
  final RxMap<int, bool> isLoadingMessages = <int, bool>{}.obs;
  final RxBool isSendingMessage = false.obs;
  
  final RxInt selectedChannelId = (-1).obs;
  final RxInt partnerId = (-1).obs;
  final RxString channelModelName = 'mail.channel'.obs;
  
  // For searching/starting direct messages
  final RxList<Map<String, dynamic>> usersToChat = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingUsers = false.obs;

  // WhatsApp-style Pinned messages, replies, reactions & star list
  final RxMap<int, DiscussMessageModel?> pinnedMessages =
      <int, DiscussMessageModel?>{}.obs;
  final RxMap<int, List<DiscussMessageModel>> channelPinnedList =
      <int, List<DiscussMessageModel>>{}.obs;
  final Rx<DiscussMessageModel?> replyingMessage =
      Rx<DiscussMessageModel?>(null);
  final RxMap<int, String> messageReactions = <int, String>{}.obs;
  final RxSet<int> starredMessageIds = <int>{}.obs;

  void pinMessage(int channelId, DiscussMessageModel message) {
    pinnedMessages[channelId] = message;
    final list = channelPinnedList[channelId] ?? [];
    if (!list.any((m) => m.id == message.id)) {
      channelPinnedList[channelId] = [message, ...list];
    }
    showToast('Message pinned to conversation', idSuccess: true);
  }

  void unpinMessage(int channelId, [int? messageId]) {
    if (messageId == null || pinnedMessages[channelId]?.id == messageId) {
      final list = channelPinnedList[channelId] ?? [];
      pinnedMessages[channelId] = list.isNotEmpty && list.first.id != messageId ? list.first : null;
    }
    if (messageId != null) {
      final list = channelPinnedList[channelId] ?? [];
      channelPinnedList[channelId] = list.where((m) => m.id != messageId).toList();
    } else {
      channelPinnedList.remove(channelId);
    }
    showToast('Message unpinned', idSuccess: true);
  }

  void toggleStarMessage(int messageId) {
    if (starredMessageIds.contains(messageId)) {
      starredMessageIds.remove(messageId);
      showToast('Message unstarred', idSuccess: true);
    } else {
      starredMessageIds.add(messageId);
      showToast('Message starred', idSuccess: true);
    }
  }

  List<DiscussMessageModel> getChannelPinnedMessages(int channelId) {
    final list = channelPinnedList[channelId] ?? [];
    final singlePinned = pinnedMessages[channelId];
    if (singlePinned != null && !list.any((m) => m.id == singlePinned.id)) {
      return [singlePinned, ...list];
    }
    return list;
  }

  List<DiscussAttachmentModel> getActiveChannelAttachments(int channelId) {
    final msgs = channelMessages[channelId] ?? [];
    final List<DiscussAttachmentModel> list = [];
    final Set<int> seenIds = {};
    for (var m in msgs) {
      for (var a in m.attachments) {
        if (!seenIds.contains(a.id)) {
          seenIds.add(a.id);
          list.add(a);
        }
      }
    }
    return list;
  }

  Future<void> startOdooCall(int channelId, {bool isVideo = true}) async {
    try {
      final server = OdooRpcApiManager.serverUrl;
      if (server.isNotEmpty) {
        final url = '$server/web#action=mail.action_discuss&active_id=$channelId';
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('START_CALL_ERROR: $e');
    }
  }

  void setReplyMessage(DiscussMessageModel? message) {
    replyingMessage.value = message;
  }

  void reactToMessage(int messageId, String emoji) {
    if (messageReactions[messageId] == emoji) {
      messageReactions.remove(messageId);
    } else {
      messageReactions[messageId] = emoji;
    }
  }
  
  // Scroll Controller for Chat Thread
  final ScrollController chatScrollController = ScrollController();
  
  StreamSubscription? _authSubscription;
  StreamSubscription? _wsSubscription;
  Timer? _wsDebounceTimer;

  void scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScrollController.hasClients) {
        if (animate) {
          chatScrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          chatScrollController.jumpTo(0.0);
        }
      }
    });
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    //LogUtils.i('DISCUSS_LIFECYCLE: DiscussController onInit started');
    
    // Watch auth state to load or clear discuss module
    final authController = Get.find<AuthController>();
    //LogUtils.i('DISCUSS_LIFECYCLE: Found AuthController, initial user = ${authController.user.value}');
    if (authController.user.value != null) {
      //LogUtils.i('DISCUSS_LIFECYCLE: User already logged in onInit, starting discuss...');
      initDiscuss();
    }
    
    _authSubscription = authController.user.listen((user) {
      //LogUtils.i('DISCUSS_LIFECYCLE: AuthController.user listener triggered. New user: $user');
      if (user != null) {
        initDiscuss();
      } else {
        clearDiscuss();
      }
    });
    //LogUtils.i('DISCUSS_LIFECYCLE: DiscussController onInit complete');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[DiscussController] App resumed. Ensuring WebSocket is connected...');
      OdooWebSocketService().ensureConnected();
      if (selectedChannelId.value != -1) {
        fetchMessages(selectedChannelId.value, background: true);
      }
      fetchChannels();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _wsSubscription?.cancel();
    _wsDebounceTimer?.cancel();
    OdooWebSocketService().disconnect();
    chatScrollController.dispose();
    super.onClose();
  }

  void clearDiscuss() {
    _wsSubscription?.cancel();
    _wsDebounceTimer?.cancel();
    OdooWebSocketService().disconnect();
    channels.clear();
    channelMessages.clear();
    selectedChannelId.value = -1;
    partnerId.value = -1;
  }

  Future<void> initDiscuss() async {
    try {
      isLoadingChannels.value = true;
      // 1. Fetch user's partner ID
      await _fetchPartnerId();
      
      if (partnerId.value == -1) {
        return;
      }
      
      // 2. Resolve active channel model name
      await _resolveChannelModel();
      
      // 3. Load channels
      await fetchChannels();
      
      // 4. Load users list for starting DMs
      await fetchUsers();
      
      // 5. Connect Odoo WebSocket for real-time messages
      _initWebSocket();
    } catch (e) {
      debugPrint('DISCUSS_INIT_ERROR: $e');
    } finally {
      isLoadingChannels.value = false;
    }
  }

  void _initWebSocket() {
    final wsService = OdooWebSocketService();
    
    final channelList = <String>[];
    if (partnerId.value != -1) {
      channelList.add('res.partner_${partnerId.value}');
    }
    for (var c in channels) {
      channelList.add('discuss.channel_${c.id}');
      channelList.add('mail.channel_${c.id}');
    }

    wsService.connect(initialChannels: channelList);

    _wsSubscription?.cancel();
    _wsSubscription = wsService.messageStream.listen((data) {
      _handleWebSocketEvent(data);
    });
  }

  void _handleWebSocketEvent(Map<String, dynamic> data) {
    try {
      final type = data['type'] as String?;
      final payload = data['payload'];

      debugPrint('[DiscussController] Real-time WS event received: $type');

      if (type == 'discuss.channel/new_message' && payload is Map) {
        _handleNewMessageFromWs(Map<String, dynamic>.from(payload));
      } else if (type == 'mail.record/insert' && payload is Map) {
        _handleRecordInsertFromWs(Map<String, dynamic>.from(payload));
      } else {
        // For other structural events (e.g. channel joined, channel archived), refresh channels
        _wsDebounceTimer?.cancel();
        _wsDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
          fetchChannels();
        });
      }
    } catch (e) {
      debugPrint('[DiscussController] Error handling WS event: $e');
    }
  }

  void _handleNewMessageFromWs(Map<String, dynamic> payload) {
    try {
      final channelId = payload['id'] is int ? payload['id'] as int : null;
      if (channelId == null) return;

      final data = payload['data'];
      if (data is! Map) return;

      final rawMsgs = data['mail.message'] as List?;
      final rawPartners = data['res.partner'] as List?;

      // Build map of partner names
      final Map<int, String> partnerNames = {};
      if (rawPartners != null) {
        for (var p in rawPartners) {
          if (p is Map && p['id'] is int && p['name'] != null) {
            partnerNames[p['id'] as int] = p['name'].toString();
          }
        }
      }

      if (rawMsgs != null && rawMsgs.isNotEmpty) {
        for (var raw in rawMsgs) {
          if (raw is! Map) continue;
          final rawMap = Map<String, dynamic>.from(raw);

          var newMsg = DiscussMessageModel.fromJson(rawMap, partnerId.value);
          if (partnerNames.containsKey(newMsg.authorId) &&
              (newMsg.authorName == 'System' || newMsg.authorName.isEmpty)) {
            newMsg = newMsg.copyWith(authorName: partnerNames[newMsg.authorId]!);
          }

          // 1. If message belongs to currently open active chat, update/insert immediately (0ms delay)
          if (channelId == selectedChannelId.value) {
            final currentList = channelMessages[channelId] != null
                ? List<DiscussMessageModel>.from(channelMessages[channelId]!)
                : <DiscussMessageModel>[];

            // Check if message already exists by server ID
            final existingIdx = currentList.indexWhere((m) => m.id == newMsg.id);
            if (existingIdx != -1) {
              currentList[existingIdx] = newMsg;
              channelMessages[channelId] = currentList;
              channelMessages.refresh();
            } else {
              // Check if replacing an optimistic local message
              final tempIdx = currentList.indexWhere((m) =>
                  m.id > 1000000000000 &&
                  m.isOutgoing &&
                  (m.cleanBody == newMsg.cleanBody || m.contentBody == newMsg.cleanBody));

              if (tempIdx != -1) {
                currentList[tempIdx] = newMsg;
                channelMessages[channelId] = currentList;
                channelMessages.refresh();
              } else {
                // Incoming message from another user!
                currentList.add(newMsg);
                channelMessages[channelId] = currentList;
                channelMessages.refresh();
                scrollToBottom(animate: true);
              }
            }
            markChannelAsSeen(channelId);
          }

          // 2. Update channel preview list item in real-time
          final chanIdx = channels.indexWhere((c) => c.id == channelId);
          if (chanIdx != -1) {
            final isCurrent = (channelId == selectedChannelId.value);
            final currentChan = channels[chanIdx];
            channels[chanIdx] = currentChan.copyWith(
              lastMessage: newMsg.displayBody,
              lastMessageTime: newMsg.date,
              unreadCount: isCurrent ? 0 : currentChan.unreadCount + 1,
            );
            channels.refresh();
            sortChannels();
          }
        }
      }
    } catch (e) {
      debugPrint('[DiscussController] Error processing new_message WS frame: $e');
    }
  }

  void _handleRecordInsertFromWs(Map<String, dynamic> payload) {
    try {
      if (payload.containsKey('discuss.channel.member') && payload['discuss.channel.member'] is List) {
        bool unreadChanged = false;
        for (var item in payload['discuss.channel.member']) {
          if (item is Map && item['partner_id'] == partnerId.value) {
            final chanInfo = item['channel_id'];
            int? cId;
            if (chanInfo is Map && chanInfo['id'] is int) {
              cId = chanInfo['id'] as int;
            } else if (chanInfo is int) {
              cId = chanInfo;
            }
            final unread = item['message_unread_counter'] as int?;
            if (cId != null && unread != null) {
              final idx = channels.indexWhere((c) => c.id == cId);
              if (idx != -1 && cId != selectedChannelId.value) {
                channels[idx] = channels[idx].copyWith(unreadCount: unread);
                unreadChanged = true;
              }
            }
          }
        }
        if (unreadChanged) {
          channels.refresh();
        }
      }

      // Also process any Message or mail.message records if pushed via mail.record/insert
      final rawMsgs = payload['Message'] ?? payload['mail.message'];
      if (rawMsgs is List && rawMsgs.isNotEmpty) {
        for (var raw in rawMsgs) {
          if (raw is! Map) continue;
          int? cId;
          if (raw['res_id'] is int) {
            cId = raw['res_id'] as int;
          } else if (raw['thread'] is Map && raw['thread']['id'] is int) {
            cId = raw['thread']['id'] as int;
          }
          if (cId != null) {
            _handleNewMessageFromWs({
              'id': cId,
              'data': {
                'mail.message': [raw],
                'res.partner': payload['res.partner'] ?? [],
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[DiscussController] Error processing mail.record/insert WS frame: $e');
    }
  }

  Future<void> _fetchPartnerId() async {
    try {
      final uid = OdooRpcApiManager.currentUserId;
      if (uid == null) return;

      //LogUtils.i('DISCUSS_PARTNER: Querying res.users for uid=$uid');
      final response = await OdooRpcApiManager.read(
        model: 'res.users',
        ids: [uid],
        fields: ['partner_id'],
      );

      if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
        final partnerField = response.data![0]['partner_id'];
        if (partnerField is List && partnerField.isNotEmpty) {
          partnerId.value = partnerField[0] as int;
          //LogUtils.i('DISCUSS_PARTNER: Resolved partner ID to ${partnerId.value}');
        } else if (partnerField is int) {
          partnerId.value = partnerField;
          //LogUtils.i('DISCUSS_PARTNER: Resolved partner ID to ${partnerId.value}');
        }
      }

      // Fallback 1: Search in res.partner by email
      if (partnerId.value == -1) {
        final email = Get.find<AuthController>().user.value?.email;
        if (email != null && email.isNotEmpty) {
          //LogUtils.i('DISCUSS_PARTNER: Fallback searching res.partner by email: $email');
          final partnerRes = await OdooRpcApiManager.searchRead(
            model: 'res.partner',
            domain: [['email', '=', email]],
            fields: ['id'],
            limit: 1,
          );
          if (partnerRes.isSuccess && partnerRes.data != null && partnerRes.data!.isNotEmpty) {
            partnerId.value = partnerRes.data![0]['id'] as int;
            //LogUtils.i('DISCUSS_PARTNER: Fallback resolved partner ID by email to ${partnerId.value}');
          }
        }
      }

      // Fallback 2: Search in res.users by login/email
      if (partnerId.value == -1) {
        final email = Get.find<AuthController>().user.value?.email;
        if (email != null && email.isNotEmpty) {
          //LogUtils.i('DISCUSS_PARTNER: Fallback searching res.users by login/email: $email');
          final userRes = await OdooRpcApiManager.searchRead(
            model: 'res.users',
            domain: ['|', ['login', '=', email], ['email', '=', email]],
            fields: ['partner_id'],
            limit: 1,
          );
          if (userRes.isSuccess && userRes.data != null && userRes.data!.isNotEmpty) {
            final pField = userRes.data![0]['partner_id'];
            if (pField is List && pField.isNotEmpty) {
              partnerId.value = pField[0] as int;
            } else if (pField is int) {
              partnerId.value = pField;
            }
            //LogUtils.i('DISCUSS_PARTNER: Fallback resolved partner ID from res.users search to ${partnerId.value}');
          }
        }
      }
    } catch (e) {
      //LogUtils.e('DISCUSS_PARTNER_ERROR: $e');
    }
  }

  Future<void> _resolveChannelModel() async {
    try {
      //LogUtils.i('DISCUSS_MODEL: Testing mail.channel...');
      // Try a simple search on mail.channel to check if it exists
      final testMail = await OdooRpcApiManager.searchRead(
        model: 'mail.channel',
        domain: [],
        fields: ['id'],
        limit: 1,
      );
      
      if (testMail.isSuccess) {
        channelModelName.value = 'mail.channel';
        //LogUtils.i('DISCUSS_MODEL: Resolved to mail.channel');
        return;
      }
    } catch (e) {
      //LogUtils.e('DISCUSS_MODEL: mail.channel test failed: $e');
    }

    try {
      //LogUtils.i('DISCUSS_MODEL: Testing discuss.channel...');
      // Try a simple search on discuss.channel to check if it exists
      final testDiscuss = await OdooRpcApiManager.searchRead(
        model: 'discuss.channel',
        domain: [],
        fields: ['id'],
        limit: 1,
      );
      
      if (testDiscuss.isSuccess) {
        channelModelName.value = 'discuss.channel';
        //LogUtils.i('DISCUSS_MODEL: Resolved to discuss.channel');
        return;
      }
    } catch (e) {
      //LogUtils.e('DISCUSS_MODEL: discuss.channel test failed: $e');
    }

    // Default fallback
    channelModelName.value = 'discuss.channel';
    //LogUtils.i('DISCUSS_MODEL: Defaulting to discuss.channel');
  }

  Future<void> fetchChannels() async {
    if (partnerId.value == -1) return;
    try {
      isLoadingChannels.value = true;
      //LogUtils.i('DISCUSS_CHANNELS: Fetching channels from Odoo...');
      
      // Try querying with channel_partner_ids first
      var response = await OdooRpcApiManager.searchRead(
        model: channelModelName.value,
        domain: [
          ['channel_partner_ids', 'in', [partnerId.value]]
        ],
        fields: ['id', 'name', 'channel_type', 'description', 'channel_partner_ids'],
        order: 'write_date desc',
      );

      // Fallback: If querying with channel_partner_ids fails, try querying with partner_ids
      if (!response.isSuccess) {
        //LogUtils.i('DISCUSS_CHANNELS: searchRead with channel_partner_ids failed. Retrying with partner_ids...');
        response = await OdooRpcApiManager.searchRead(
          model: channelModelName.value,
          domain: [
            ['partner_ids', 'in', [partnerId.value]]
          ],
          fields: ['id', 'name', 'channel_type', 'description', 'partner_ids'],
          order: 'write_date desc',
        );
      }

      // Final fallback if both failed (unrestricted query)
      if (!response.isSuccess) {
        //LogUtils.w('DISCUSS_CHANNELS: member filters failed. Falling back to unrestricted query...');
        response = await OdooRpcApiManager.searchRead(
          model: channelModelName.value,
          domain: [],
          fields: ['id', 'name', 'channel_type', 'description'],
          order: 'write_date desc',
        );
      }

      if (response.isSuccess && response.data != null) {
        // Fetch unread message counts from discuss.channel.member for current partner
        final Map<int, int> unreadCounters = {};
        try {
          final memberRes = await OdooRpcApiManager.searchRead(
            model: 'discuss.channel.member',
            domain: [
              ['partner_id', '=', partnerId.value]
            ],
            fields: ['id', 'channel_id', 'message_unread_counter'],
          );
          if (memberRes.isSuccess && memberRes.data != null) {
            for (var raw in memberRes.data!) {
              final memberId = raw['id'] as int;
              final channelIdVal = raw['channel_id'];
              final unreadVal = raw['message_unread_counter'];
              int? cId;
              if (channelIdVal is List && channelIdVal.isNotEmpty) {
                cId = channelIdVal[0] as int;
              } else if (channelIdVal is int) {
                cId = channelIdVal;
              }
              final unreadCount = unreadVal is int ? unreadVal : 0;
              if (cId != null) {
                unreadCounters[cId] = unreadCount;
                channelMemberIds[cId] = memberId;
              }
            }
          }
        } catch (e) {
          //LogUtils.w('DISCUSS_CHANNELS: Failed to fetch unread counts from discuss.channel.member: $e');
        }

        final List<DiscussChannelModel> fetched = [];
        for (var raw in response.data!) {
          try {
            final rawMap = Map<String, dynamic>.from(raw);
            final int channelId = rawMap['id'] as int;
            rawMap['message_unread_counter'] = unreadCounters[channelId] ?? 0;

            fetched.add(DiscussChannelModel.fromJson(
              rawMap,
              currentPartnerId: partnerId.value,
            ));
          } catch (e) {
            //LogUtils.e('DISCUSS_CHANNEL_PARSE_ERROR: $e on raw=$raw');
          }
        }

        // Fetch last messages for these channels in a single optimized RPC call
        if (fetched.isNotEmpty) {
          try {
            final channelIds = fetched.map((c) => c.id).toList();
            //LogUtils.i('DISCUSS_LAST_MSG: Querying mail.message for channels: $channelIds under model: ${channelModelName.value}');
            final msgResponse = await OdooRpcApiManager.searchRead(
              model: 'mail.message',
              domain: [
                ['model', '=', channelModelName.value],
                ['res_id', 'in', channelIds],
                ['message_type', '=', 'comment']
              ],
              fields: ['id', 'body', 'res_id', 'author_id', 'date', 'attachment_ids'],
              order: 'id desc',
              limit: 500,
            );

            //LogUtils.i('DISCUSS_LAST_MSG: msgResponse success=${msgResponse.isSuccess}, dataLength=${msgResponse.data?.length}');

            if (msgResponse.isSuccess && msgResponse.data != null) {
              final Map<int, DiscussMessageModel> latestMessages = {};
              for (var raw in msgResponse.data!) {
                try {
                  final msg = DiscussMessageModel.fromJson(
                    Map<String, dynamic>.from(raw),
                    partnerId.value,
                  );
                  final channelId = raw['res_id'] is int 
                      ? raw['res_id'] as int 
                      : (raw['res_id'] is List ? (raw['res_id'] as List)[0] as int : 0);
                  if (channelId != 0 && !latestMessages.containsKey(channelId)) {
                    latestMessages[channelId] = msg;
                  }
                } catch (e) {
                  //LogUtils.e('DISCUSS_CHANNEL_MSG_PARSE_ERROR: $e on raw=$raw');
                }
              }

              // Query attachment details for these latest messages to determine if they are images
              final allLastMsgAttachIds = latestMessages.values.expand((m) => m.attachmentIds).toList();
              if (allLastMsgAttachIds.isNotEmpty) {
                try {
                  final attachResponse = await OdooRpcApiManager.searchRead(
                    model: 'ir.attachment',
                    domain: [
                      ['id', 'in', allLastMsgAttachIds],
                    ],
                    fields: ['id', 'name', 'mimetype', 'file_size'],
                  );
                  if (attachResponse.isSuccess && attachResponse.data != null) {
                    final Map<int, DiscussAttachmentModel> attachmentsMap = {};
                    for (var rawAttach in attachResponse.data!) {
                      try {
                        final attachment = DiscussAttachmentModel.fromJson(
                          Map<String, dynamic>.from(rawAttach),
                        );
                        attachmentsMap[attachment.id] = attachment;
                      } catch (_) {}
                    }
                    // Assign attachments to latest messages
                    for (var channelId in latestMessages.keys) {
                      final msg = latestMessages[channelId]!;
                      final List<DiscussAttachmentModel> msgAttachments = [];
                      for (var id in msg.attachmentIds) {
                        if (attachmentsMap.containsKey(id)) {
                          msgAttachments.add(attachmentsMap[id]!);
                        }
                      }
                      if (msgAttachments.isNotEmpty) {
                        latestMessages[channelId] = msg.copyWith(attachments: msgAttachments);
                      }
                    }
                  }
                } catch (e) {
                  //LogUtils.e('DISCUSS_LAST_MSG_ATTACH_ERROR: $e');
                }
              }

              //LogUtils.i('DISCUSS_LAST_MSG: Resolved latestMessages keys: ${latestMessages.keys.toList()}');

              for (var i = 0; i < fetched.length; i++) {
                final c = fetched[i];
                if (latestMessages.containsKey(c.id)) {
                  final last = latestMessages[c.id]!;
                 // LogUtils.i('DISCUSS_LAST_MSG: Mapping lastMessage for channel id=${c.id} name=${c.name} -> "${last.displayBody}"');
                  fetched[i] = c.copyWith(
                    lastMessage: last.displayBody,
                    lastMessageTime: last.date,
                  );
                } else {
                 // LogUtils.i('DISCUSS_LAST_MSG: No message found in query for channel id=${c.id} name=${c.name}');
                }
              }

              // Fetch missing channels individually to ensure older/inactive channels show their last message
              final missingChannelIds = fetched
                  .where((c) => !latestMessages.containsKey(c.id))
                  .map((c) => c.id)
                  .toList();
              
              if (missingChannelIds.isNotEmpty) {
                //LogUtils.i('DISCUSS_LAST_MSG: Fetching last message for ${missingChannelIds.length} missing channels individually');
                final List<Future<void>> tasks = [];
                for (var id in missingChannelIds) {
                  tasks.add(() async {
                    try {
                      final r = await OdooRpcApiManager.searchRead(
                        model: 'mail.message',
                        domain: [
                          ['model', '=', channelModelName.value],
                          ['res_id', '=', id],
                          ['message_type', '=', 'comment'],
                        ],
                        fields: ['id', 'body', 'date', 'attachment_ids'],
                        order: 'id desc',
                        limit: 1,
                      );
                      if (r.isSuccess && r.data != null && r.data!.isNotEmpty) {
                        final raw = r.data!.first;
                        var msg = DiscussMessageModel.fromJson(
                          Map<String, dynamic>.from(raw),
                          partnerId.value,
                        );
                        if (msg.attachmentIds.isNotEmpty) {
                          try {
                            final attachR = await OdooRpcApiManager.searchRead(
                              model: 'ir.attachment',
                              domain: [['id', 'in', msg.attachmentIds]],
                              fields: ['id', 'name', 'mimetype', 'file_size'],
                            );
                            if (attachR.isSuccess && attachR.data != null) {
                              final List<DiscussAttachmentModel> attachList = [];
                              for (var rawAttach in attachR.data!) {
                                attachList.add(DiscussAttachmentModel.fromJson(Map<String, dynamic>.from(rawAttach)));
                              }
                              msg = msg.copyWith(attachments: attachList);
                            }
                          } catch (_) {}
                        }
                        final idx = fetched.indexWhere((c) => c.id == id);
                        if (idx != -1) {
                          fetched[idx] = fetched[idx].copyWith(
                            lastMessage: msg.displayBody,
                            lastMessageTime: msg.date,
                          );
                          //LogUtils.i('DISCUSS_LAST_MSG: Mapped missing channel id=$id -> "${msg.displayBody}"');
                        }
                      }
                    } catch (e) {
                      //LogUtils.e('DISCUSS_LAST_MSG_ERROR individually for channel id=$id: $e');
                    }
                  }());
                }
                await Future.wait(tasks);
              }
            } else {
                //LogUtils.w('DISCUSS_LAST_MSG: msgResponse failed or null data: error=${msgResponse.message}');
            }
          } catch (e) {
            //LogUtils.e('DISCUSS_CHANNELS_LAST_MSG_ERROR: $e');
          }
        }
        
        // Fetch partner online / im_status presence for direct chats
        final partnerIdsToQuery = fetched
            .where((c) => c.otherPartnerId != null && c.otherPartnerId! > 0)
            .map((c) => c.otherPartnerId!)
            .toSet()
            .toList();
        if (partnerIdsToQuery.isNotEmpty) {
          try {
            final presenceRes = await OdooRpcApiManager.searchRead(
              model: 'res.partner',
              domain: [
                ['id', 'in', partnerIdsToQuery]
              ],
              fields: ['id', 'im_status'],
            );
            if (presenceRes.isSuccess && presenceRes.data != null) {
              final Map<int, String> statusMap = {};
              for (var p in presenceRes.data!) {
                final pId = p['id'] as int;
                final stat = p['im_status']?.toString();
                if (stat != null) statusMap[pId] = stat;
              }
              for (var i = 0; i < fetched.length; i++) {
                final oId = fetched[i].otherPartnerId;
                if (oId != null && statusMap.containsKey(oId)) {
                  fetched[i] = fetched[i].copyWith(imStatus: statusMap[oId]);
                }
              }
            }
          } catch (e) {
            debugPrint('DISCUSS_PRESENCE_ERROR: $e');
          }
        }

        fetched.sort((a, b) {
          final timeA = a.lastMessageTime ?? DateTime(1970);
          final timeB = b.lastMessageTime ?? DateTime(1970);
          return timeB.compareTo(timeA);
        });
        channels.value = fetched;
        
        // Register any newly discovered channels on the WebSocket
        final List<String> channelSubs = [];
        for (var c in fetched) {
          channelSubs.add('discuss.channel_${c.id}');
          channelSubs.add('mail.channel_${c.id}');
        }
        if (channelSubs.isNotEmpty) {
          OdooWebSocketService().subscribe(channelSubs);
        }
        
        // Auto-select the first channel if none is selected
        if (selectedChannelId.value == -1 && channels.isNotEmpty) {
          selectChannel(channels.first.id);
        }
      }
    } catch (e) {
     // LogUtils.e('DISCUSS_CHANNELS_ERROR: $e');
    } finally {
      isLoadingChannels.value = false;
    }
  }

  Future<void> fetchUsers() async {
    try {
      isLoadingUsers.value = true;
      // Fetch users / partners that are employees or active users
      var response = await OdooRpcApiManager.searchRead(
        model: 'res.partner',
        domain: [
          ['active', '=', true],
          ['user_ids', '!=', false],
          ['id', '!=', partnerId.value]
        ],
        fields: ['id', 'name', 'email', 'im_status'],
        limit: 80,
      );

      List<Map<String, dynamic>> finalUsers = [];

      if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
        finalUsers = response.data!.map((e) {
          final m = Map<String, dynamic>.from(e);
          m['name'] = (m['name'] is String) ? m['name'] as String : 'Colleague';
          m['email'] = (m['email'] is String) ? m['email'] as String : '';
          return m;
        }).toList();
      }

      // Fallback 1: res.users query
      if (finalUsers.isEmpty) {
        debugPrint('DISCUSS_USERS: res.partner search empty/failed. Trying res.users...');
        final usersRes = await OdooRpcApiManager.searchRead(
          model: 'res.users',
          domain: [
            ['active', '=', true],
            ['share', '=', false],
            ['partner_id', '!=', false]
          ],
          fields: ['name', 'login', 'partner_id'],
          limit: 80,
        );

        if (usersRes.isSuccess && usersRes.data != null) {
          for (var u in usersRes.data!) {
            final pVal = u['partner_id'];
            int? pId;
            if (pVal is List && pVal.isNotEmpty) {
              pId = pVal[0] as int;
            } else if (pVal is int) {
              pId = pVal;
            }

            if (pId != null && pId != partnerId.value) {
              finalUsers.add({
                'id': pId,
                'name': u['name'] ?? (pVal is List && pVal.length > 1 ? pVal[1] : ''),
                'email': u['login'] ?? '',
              });
            }
          }
        }
      }

      // Fallback 2: hr.employee query
      if (finalUsers.isEmpty) {
        debugPrint('DISCUSS_USERS: res.users search empty/failed. Trying hr.employee...');
        final empRes = await OdooRpcApiManager.searchRead(
          model: 'hr.employee',
          domain: [
            ['active', '=', true],
          ],
          fields: ['id', 'name', 'work_email', 'work_contact_id', 'address_id'],
          limit: 80,
        );

        if (empRes.isSuccess && empRes.data != null) {
          for (var e in empRes.data!) {
            int? pId;
            final workContactVal = e['work_contact_id'];
            final addressVal = e['address_id'];

            if (workContactVal is List && workContactVal.isNotEmpty) {
              pId = workContactVal[0] as int;
            } else if (workContactVal is int) {
              pId = workContactVal;
            } else if (addressVal is List && addressVal.isNotEmpty) {
              pId = addressVal[0] as int;
            } else if (addressVal is int) {
              pId = addressVal;
            }

            if (pId != null && pId != partnerId.value) {
              finalUsers.add({
                'id': pId,
                'name': e['name'] ?? '',
                'email': e['work_email'] ?? '',
              });
            }
          }
        }
      }

      // De-duplicate final list by id
      final uniqueMap = <int, Map<String, dynamic>>{};
      for (var u in finalUsers) {
        final idVal = u['id'];
        if (idVal is int) {
          uniqueMap[idVal] = u;
        }
      }

      usersToChat.value = uniqueMap.values.toList();
      debugPrint('DISCUSS_USERS: Resolved ${usersToChat.length} colleagues for chat.');

    } catch (e) {
      debugPrint('DISCUSS_USERS_ERROR: $e');
    } finally {
      isLoadingUsers.value = false;
    }
  }

  void selectChannel(int channelId) {
    selectedChannelId.value = channelId;
    markChannelAsSeen(channelId);
    
    // Ensure WebSocket is connected
    OdooWebSocketService().ensureConnected();
    
    // Subscribe to channel on Odoo WebSocket
    OdooWebSocketService().subscribe([
      'discuss.channel_$channelId',
      'mail.channel_$channelId',
    ]);

    // Fetch messages for this channel
    if (!channelMessages.containsKey(channelId)) {
      fetchMessages(channelId);
    } else {
      // Refresh messages
      fetchMessages(channelId, background: true);
    }
    scrollToBottom(animate: false);
  }

  Future<void> fetchMessages(int channelId, {bool background = false}) async {
    if (channelId == -1) return;
    
    if (!background) {
      isLoadingMessages[channelId] = true;
      debugPrint('DISCUSS_MESSAGES: Querying messages for channel=$channelId');
    }

    try {
      
      // In Odoo, messages for a channel are linked via model and res_id
      final response = await OdooRpcApiManager.searchRead(
        model: 'mail.message',
        domain: [
          ['model', '=', channelModelName.value],
          ['res_id', '=', channelId],
          ['message_type', '=', 'comment']
        ],
        fields: [
          'id',
          'body',
          'author_id',
          'date',
          'message_type',
          'attachment_ids',
          'parent_id',
        ],
        order: 'id desc',
        limit: 50,
      );

      if (response.isSuccess && response.data != null) {
        final List<DiscussMessageModel> msgs = [];
        for (var raw in response.data!) {
          msgs.add(DiscussMessageModel.fromJson(
            Map<String, dynamic>.from(raw),
            partnerId.value,
          ));
        }

        // Resolve parent_id replies from available messages
        final Map<int, DiscussMessageModel> idMap = {for (final m in msgs) m.id: m};
        for (var i = 0; i < msgs.length; i++) {
          final m = msgs[i];
          if (m.parentId != null && m.parentId! > 0 && (m.replyText == null || m.replyText!.isEmpty)) {
            final parent = idMap[m.parentId!];
            if (parent != null) {
              msgs[i] = m.copyWith(
                replyAuthor: parent.authorName,
                replyText: parent.contentBody.isNotEmpty ? parent.contentBody : parent.cleanBody,
              );
            }
          }
        }

        // Collect all attachment IDs from fetched messages
        final allAttachmentIds = msgs.expand((m) => m.attachmentIds).toList();
        if (allAttachmentIds.isNotEmpty) {
          final attachResponse = await OdooRpcApiManager.searchRead(
            model: 'ir.attachment',
            domain: [
              ['id', 'in', allAttachmentIds],
            ],
            fields: ['id', 'name', 'mimetype', 'file_size'],
          );
          if (attachResponse.isSuccess && attachResponse.data != null) {
            final Map<int, DiscussAttachmentModel> attachmentsMap = {};
            for (var rawAttach in attachResponse.data!) {
              try {
                final attachment = DiscussAttachmentModel.fromJson(
                  Map<String, dynamic>.from(rawAttach),
                );
                attachmentsMap[attachment.id] = attachment;
              } catch (e) {
                debugPrint('DISCUSS_ATTACH_PARSE_ERROR: $e');
              }
            }
            // Map attachments back to their messages
            for (var i = 0; i < msgs.length; i++) {
              final List<DiscussAttachmentModel> msgAttachments = [];
              for (var id in msgs[i].attachmentIds) {
                if (attachmentsMap.containsKey(id)) {
                  msgAttachments.add(attachmentsMap[id]!);
                }
              }
              final bool shouldBeDeleted = msgs[i].isDeleted ||
                  (msgs[i].contentBody.trim().isEmpty &&
                      msgs[i].cleanBody.trim().isEmpty &&
                      msgAttachments.isEmpty &&
                      !msgs[i].isReply);

              msgs[i] = msgs[i].copyWith(
                attachments: msgAttachments,
                isDeleted: shouldBeDeleted,
              );
            }
          }
        }

        // Check for messages without attachments that might be empty/deleted
        for (var i = 0; i < msgs.length; i++) {
          if (msgs[i].contentBody.trim().isEmpty &&
              msgs[i].cleanBody.trim().isEmpty &&
              msgs[i].attachments.isEmpty &&
              !msgs[i].isReply) {
            msgs[i] = msgs[i].copyWith(isDeleted: true);
          }
        }
        
        // Odoo returns newest first, so we reverse to display chronologically in chat bubble flow
        final chronological = msgs.reversed.toList();
        
        final existingList = channelMessages[channelId];
        bool hasChanges = false;

        if (existingList == null || existingList.length != chronological.length) {
          hasChanges = true;
        } else if (existingList.isNotEmpty && chronological.isNotEmpty) {
          if (existingList.last.id != chronological.last.id ||
              existingList.first.id != chronological.first.id) {
            hasChanges = true;
          }
        }

        if (hasChanges) {
          channelMessages[channelId] = chronological;
          scrollToBottom(animate: false);
          
          // Update the channel's last message info only when actually changed
          if (chronological.isNotEmpty) {
            final last = chronological.last;
            final idx = channels.indexWhere((c) => c.id == channelId);
            if (idx != -1) {
              if (channels[idx].lastMessage != last.displayBody ||
                  channels[idx].lastMessageTime != last.date) {
                channels[idx] = channels[idx].copyWith(
                  lastMessage: last.displayBody,
                  lastMessageTime: last.date,
                );
                sortChannels();
              }
            }
            
            // Mark channel as read on Odoo server
            markChannelAsSeen(channelId);
          }
        }
      }
    } catch (e) {
      debugPrint('DISCUSS_MESSAGES_ERROR: $e');
    } finally {
      isLoadingMessages[channelId] = false;
    }
  }

  Future<void> markChannelAsSeen(int channelId) async {
    if (channelId == -1) return;

    // Immediately clear unread count in local UI
    final cIdx = channels.indexWhere((c) => c.id == channelId);
    if (cIdx != -1 && channels[cIdx].unreadCount > 0) {
      channels[cIdx] = channels[cIdx].copyWith(unreadCount: 0);
      channels.refresh();
    }

    int? memberId = channelMemberIds[channelId];
    if (memberId == null) {
      try {
        final memberRes = await OdooRpcApiManager.searchRead(
          model: 'discuss.channel.member',
          domain: [
            ['channel_id', '=', channelId],
            ['partner_id', '=', partnerId.value],
          ],
          fields: ['id'],
          limit: 1,
        );
        if (memberRes.isSuccess && memberRes.data != null && memberRes.data!.isNotEmpty) {
          memberId = memberRes.data![0]['id'] as int?;
          if (memberId != null) {
            channelMemberIds[channelId] = memberId;
          }
        }
      } catch (_) {}
    }

    if (memberId == null) return;

    final messages = channelMessages[channelId];
    int latestMessageId = 0;
    if (messages != null && messages.isNotEmpty) {
      final realMessages = messages.where((m) => m.id > 0 && m.id < 1000000000000).toList();
      if (realMessages.isNotEmpty) {
        latestMessageId = realMessages.last.id;
      }
    }

    try {
      final values = <String, dynamic>{
        'message_unread_counter': 0,
        'last_seen_dt': DateTime.now().toUtc().toString().substring(0, 19),
      };
      if (latestMessageId > 0) {
        values['seen_message_id'] = latestMessageId;
        values['fetched_message_id'] = latestMessageId;
        values['new_message_separator'] = latestMessageId + 1;
      }

      await OdooRpcApiManager.write(
        model: 'discuss.channel.member',
        ids: [memberId],
        values: values,
      );
    } catch (e) {
      debugPrint('[DiscussController] Failed to mark channel as seen: $e');
    }
  }

  Future<void> refreshActiveChannel() async {
    if (selectedChannelId.value == -1) return;
    await fetchMessages(selectedChannelId.value, background: true);
    // Also fetch updated channel details to update list unreads or updates
    var response = await OdooRpcApiManager.searchRead(
      model: channelModelName.value,
      domain: [
        ['channel_partner_ids', 'in', [partnerId.value]]
      ],
      fields: ['id', 'name', 'channel_type', 'description', 'channel_partner_ids'],
      order: 'write_date desc',
    );

    if (!response.isSuccess) {
      response = await OdooRpcApiManager.searchRead(
        model: channelModelName.value,
        domain: [
          ['partner_ids', 'in', [partnerId.value]]
        ],
        fields: ['id', 'name', 'channel_type', 'description', 'partner_ids'],
        order: 'write_date desc',
      );
    }

    if (response.isSuccess && response.data != null) {
      final List<DiscussChannelModel> fetched = [];
      for (var raw in response.data!) {
        try {
          fetched.add(DiscussChannelModel.fromJson(
            Map<String, dynamic>.from(raw),
            currentPartnerId: partnerId.value,
          ));
        } catch (_) {}
      }
      
      // Update unreads, but preserve local 0 if currently active
      for (var f in fetched) {
        final idx = channels.indexWhere((c) => c.id == f.id);
        if (idx != -1) {
          final existing = channels[idx];
          channels[idx] = f.copyWith(
            unreadCount: f.id == selectedChannelId.value ? 0 : f.unreadCount,
            lastMessage: existing.lastMessage,
            lastMessageTime: existing.lastMessageTime,
          );
        } else {
          channels.add(f);
        }
      }
      sortChannels();
    }
  }

  Future<bool> sendMessage(String text) async {
    final channelId = selectedChannelId.value;
    if (channelId == -1 || text.trim().isEmpty) return false;

    try {
      isSendingMessage.value = true;

      // Handle reply context if active
      final replying = replyingMessage.value;
      int? parentMessageId;
      String? replyAuthor;
      String? replyText;

      if (replying != null) {
        parentMessageId = replying.id > 0 ? replying.id : null;
        replyAuthor = replying.authorName;
        replyText = replying.contentBody.isNotEmpty
            ? replying.contentBody
            : (replying.cleanBody.isNotEmpty
                ? replying.cleanBody
                : (replying.attachments.isNotEmpty
                    ? '📎 ${replying.attachments.first.name}'
                    : 'Message'));
        replyingMessage.value = null;
      }

      final trimmedText = text.trim();
      final bodyForOdoo = trimmedText;
      
      // 1. Optimistic Local Update for UI responsiveness
      final localMsg = DiscussMessageModel(
        id: DateTime.now().millisecondsSinceEpoch, // temporary local id
        body: bodyForOdoo,
        cleanBody: trimmedText,
        parentId: parentMessageId,
        replyAuthor: replyAuthor,
        replyText: replyText,
        contentBody: trimmedText,
        authorId: partnerId.value,
        authorName: Get.find<AuthController>().user.value?.name ?? 'Me',
        date: DateTime.now(),
        isOutgoing: true,
      );
      
      if (channelMessages.containsKey(channelId)) {
        channelMessages[channelId] = [...channelMessages[channelId]!, localMsg];
      } else {
        channelMessages[channelId] = [localMsg];
      }
      scrollToBottom(animate: true);

      // 2. Perform remote API post with parent_id
      debugPrint('DISCUSS_SEND: Posting message to channel=$channelId, parent_id=$parentMessageId');
      final Map<String, dynamic> kwargs = {
        'body': bodyForOdoo,
        'message_type': 'comment',
        'subtype_xmlid': 'mail.mt_comment',
      };
      if (parentMessageId != null && parentMessageId > 0) {
        kwargs['parent_id'] = parentMessageId;
      }

      final response = await OdooRpcApiManager.call(
        model: channelModelName.value,
        method: 'message_post',
        args: [channelId],
        kwargs: kwargs,
      );

      if (response.isSuccess) {
        // Refresh to get official server state and ID
        await fetchMessages(channelId, background: true);
        return true;
      } else {
        // Remove local optimistic message if posting failed
        if (channelMessages.containsKey(channelId)) {
          final list = channelMessages[channelId]!;
          list.removeWhere((m) => m.id == localMsg.id);
          channelMessages[channelId] = [...list];
        }
        showToast(response.message.isNotEmpty ? response.message : 'Failed to send message', idSuccess: false);
        return false;
      }
    } catch (e) {
      debugPrint('DISCUSS_SEND_ERROR: $e');
      return false;
    } finally {
      isSendingMessage.value = false;
    }
  }

  /// Edit a previously sent message
  Future<bool> editMessage(int channelId, int messageId, String newText) async {
    try {
      final trimmed = newText.trim();
      if (trimmed.isEmpty) return false;

      // 1. Optimistic local update
      if (channelMessages.containsKey(channelId)) {
        final list = channelMessages[channelId]!;
        final idx = list.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(
            body: trimmed,
            cleanBody: trimmed,
            contentBody: trimmed,
          );
          channelMessages[channelId] = [...list];
        }
      }

      // 2. Remote update in Odoo mail.message
      final res = await OdooRpcApiManager.write(
        model: 'mail.message',
        ids: [messageId],
        values: {
          'body': trimmed,
        },
      );

      if (res.isSuccess) {
        showToast('Message edited', idSuccess: true);
        return true;
      } else {
        showToast('Failed to edit message: ${res.message}', idSuccess: false);
        return false;
      }
    } catch (e) {
      showToast('Error editing message: $e', idSuccess: false);
      return false;
    }
  }

  /// Delete a message sent by the user
  Future<bool> deleteMessage(int channelId, int messageId) async {
    try {
      // Find attachment IDs if any
      List<int> attachmentIdsToDelete = [];
      if (channelMessages.containsKey(channelId)) {
        final list = channelMessages[channelId]!;
        final msg = list.firstWhereOrNull((m) => m.id == messageId);
        if (msg != null) {
          attachmentIdsToDelete = [...msg.attachmentIds];
        }
      }

      // If attachment IDs were not in memory, query them from Odoo mail.message
      if (attachmentIdsToDelete.isEmpty) {
        try {
          final msgData = await OdooRpcApiManager.searchRead(
            model: 'mail.message',
            domain: [
              ['id', '=', messageId]
            ],
            fields: ['attachment_ids'],
            limit: 1,
          );
          if (msgData.isSuccess && msgData.data != null && (msgData.data as List).isNotEmpty) {
            final raw = (msgData.data as List).first;
            if (raw['attachment_ids'] is List) {
              attachmentIdsToDelete = (raw['attachment_ids'] as List)
                  .map((x) => x is int ? x : int.tryParse(x.toString()) ?? 0)
                  .where((x) => x > 0)
                  .toList();
            }
          }
        } catch (_) {}
      }

      // 1. Optimistic update: mark as deleted and wipe all attachments locally, retaining bubble in chat
      if (channelMessages.containsKey(channelId)) {
        final list = channelMessages[channelId]!;
        final idx = list.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(
            body: '<em>This message is deleted</em>',
            cleanBody: 'This message is deleted',
            contentBody: 'This message is deleted',
            isDeleted: true,
            attachments: [],
            attachmentIds: [],
          );
          channelMessages[channelId] = [...list];
        }
      }

      // 2. Unlink attachments from ir.attachment in Odoo so files are deleted from storage
      if (attachmentIdsToDelete.isNotEmpty) {
        try {
          await OdooRpcApiManager.unlink(
            model: 'ir.attachment',
            ids: attachmentIdsToDelete,
          );
          debugPrint('DISCUSS_DELETE: Successfully unlinked attachments: $attachmentIdsToDelete');
        } catch (e) {
          debugPrint('DISCUSS_DELETE: Error unlinking ir.attachment: $e');
        }
      }

      // 3. Update mail.message in Odoo: set body to deleted notice and clear attachment relations
      // (Keeps message bubble in chat history showing "This message is deleted" rather than disappearing)
      await OdooRpcApiManager.write(
        model: 'mail.message',
        ids: [messageId],
        values: {
          'body': '<p><em>This message is deleted</em></p>',
          'attachment_ids': [
            [6, 0, []] // Clears all attachment relations in Odoo
          ],
        },
      );

      showToast('Message deleted', idSuccess: true);
      return true;
    } catch (e) {
      showToast('Error deleting message: $e', idSuccess: false);
      return false;
    }
  }

  Future<void> startDirectChat(int targetPartnerId, String targetPartnerName) async {
    try {
      isLoadingChannels.value = true;
      debugPrint('DISCUSS_DM: Requesting chat with partner=$targetPartnerId');
      
      // 1. Search for existing DM channel containing both partners
      var searchResponse = await OdooRpcApiManager.searchRead(
        model: channelModelName.value,
        domain: [
          ['channel_type', '=', 'chat'],
          ['channel_partner_ids', 'in', [partnerId.value]],
          ['channel_partner_ids', 'in', [targetPartnerId]],
        ],
        fields: ['id', 'name', 'channel_type', 'description', 'channel_partner_ids'],
        limit: 10,
      );

      // Fallback: search using partner_ids
      if (!searchResponse.isSuccess) {
        searchResponse = await OdooRpcApiManager.searchRead(
          model: channelModelName.value,
          domain: [
            ['channel_type', '=', 'chat'],
            ['partner_ids', 'in', [partnerId.value]],
            ['partner_ids', 'in', [targetPartnerId]],
          ],
          fields: ['id', 'name', 'channel_type', 'description', 'partner_ids'],
          limit: 10,
        );
      }

      List<dynamic> existingChannels = [];
      if (searchResponse.isSuccess && searchResponse.data != null) {
        existingChannels = searchResponse.data!;
      }

      if (existingChannels.isNotEmpty) {
        final rawChannel = Map<String, dynamic>.from(existingChannels.first);
        final newChan = DiscussChannelModel.fromJson(rawChannel, currentPartnerId: partnerId.value);
        
        final existsIdx = channels.indexWhere((c) => c.id == newChan.id);
        if (existsIdx == -1) {
          channels.insert(0, newChan);
        }
        selectChannel(newChan.id);
        return;
      }

      // 2. No existing DM found, create a new discuss/mail channel
      debugPrint('DISCUSS_DM: No existing DM found, creating new channel...');
      var rpcCreate = await OdooRpcApiManager.create(
        model: channelModelName.value,
        values: {
          'name': targetPartnerName,
          'channel_type': 'chat',
          'channel_partner_ids': [
            [6, 0, [partnerId.value, targetPartnerId]]
          ],
        },
      );

      if (!rpcCreate.isSuccess) {
        // Try channel_member_ids
        rpcCreate = await OdooRpcApiManager.create(
          model: channelModelName.value,
          values: {
            'name': targetPartnerName,
            'channel_type': 'chat',
            'channel_member_ids': [
              [0, 0, {'partner_id': partnerId.value}],
              [0, 0, {'partner_id': targetPartnerId}],
            ],
          },
        );
      }

      if (rpcCreate.isSuccess && rpcCreate.data != null) {
        final createdId = rpcCreate.data!;
        
        // Read details of the newly created channel
        final rpcRead = await OdooRpcApiManager.searchRead(
          model: channelModelName.value,
          domain: [['id', '=', createdId]],
          fields: ['id', 'name', 'channel_type', 'description'],
        );

        if (rpcRead.isSuccess && rpcRead.data != null && rpcRead.data!.isNotEmpty) {
          final rawChannel = Map<String, dynamic>.from(rpcRead.data!.first);
          final newChan = DiscussChannelModel.fromJson(rawChannel, currentPartnerId: partnerId.value);
          
          final existsIdx = channels.indexWhere((c) => c.id == newChan.id);
          if (existsIdx == -1) {
            channels.insert(0, newChan);
          }
          selectChannel(newChan.id);
        }
      } else {
        showToast('Failed to start chat: ${rpcCreate.message}', idSuccess: false);
      }
    } catch (e) {
      debugPrint('DISCUSS_DM_ERROR: $e');
      showToast('Error starting direct chat: $e', idSuccess: false);
    } finally {
      isLoadingChannels.value = false;
    }
  }

  Future<bool> sendAttachment(String fileName, Uint8List fileBytes, {String caption = ''}) async {
    final channelId = selectedChannelId.value;
    if (channelId == -1 || fileBytes.isEmpty) return false;

    try {
      isSendingMessage.value = true;
     // LogUtils.i('DISCUSS_SEND_ATTACH: Starting upload for $fileName (${fileBytes.length} bytes)');

      // 1. Encode file content to Base64
      final base64Content = base64Encode(fileBytes);

      // 2. Upload file to ir.attachment
      final attachResponse = await OdooRpcApiManager.create(
        model: 'ir.attachment',
        values: {
          'name': fileName,
          'datas': base64Content,
          'res_model': channelModelName.value,
          'res_id': channelId,
        },
      );

      if (!attachResponse.isSuccess || attachResponse.data == null) {
        final err = attachResponse.message.isNotEmpty ? attachResponse.message : 'Attachment upload failed';
        showToast(err, idSuccess: false);
        //LogUtils.e('DISCUSS_SEND_ATTACH_ERROR: Upload failed: $err');
        return false;
      }

      final attachmentId = attachResponse.data!;
      //LogUtils.i('DISCUSS_SEND_ATTACH: Uploaded successfully, attachmentId=$attachmentId. Posting message...');

      // 3. Post the message with attachment_ids linked
      final postResponse = await OdooRpcApiManager.call(
        model: channelModelName.value,
        method: 'message_post',
        args: [channelId],
        kwargs: {
          'body': caption, // Pass the text caption as message body
          'message_type': 'comment',
          'subtype_xmlid': 'mail.mt_comment',
          'attachment_ids': [attachmentId],
        },
      );

      if (postResponse.isSuccess) {
        //LogUtils.i('DISCUSS_SEND_ATTACH: Message posted successfully. Refreshing messages...');
        await fetchMessages(channelId, background: true);
        return true;
      } else {
        final err = postResponse.message.isNotEmpty ? postResponse.message : 'Failed to post message with attachment';
        showToast(err, idSuccess: false);
        //LogUtils.e('DISCUSS_SEND_ATTACH_ERROR: Message post failed: $err');
        return false;
      }
    } catch (e) {
      //LogUtils.e('DISCUSS_SEND_ATTACH_ERROR: Exception: $e');
      showToast('Error sending attachment: $e', idSuccess: false);
      return false;
    } finally {
      isSendingMessage.value = false;
    }
  }

  MessageTickStatus getMessageTickStatus(DiscussMessageModel message) {
    if (!message.isOutgoing) return MessageTickStatus.none;
    if (message.id <= 0) {
      return MessageTickStatus.single;
    }
    return MessageTickStatus.doubleGray;
  }

  void sortChannels() {
    channels.sort((a, b) {
      final timeA = a.lastMessageTime ?? DateTime(1970);
      final timeB = b.lastMessageTime ?? DateTime(1970);
      return timeB.compareTo(timeA);
    });
  }
}

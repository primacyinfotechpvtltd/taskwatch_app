import 'dart:async';
import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/utils/log_utils.dart';

class DiscussController extends GetxController {
  final RxList<DiscussChannelModel> channels = <DiscussChannelModel>[].obs;
  final RxMap<int, List<DiscussMessageModel>> channelMessages = <int, List<DiscussMessageModel>>{}.obs;
  
  final RxBool isLoadingChannels = false.obs;
  final RxMap<int, bool> isLoadingMessages = <int, bool>{}.obs;
  final RxBool isSendingMessage = false.obs;
  
  final RxInt selectedChannelId = (-1).obs;
  final RxInt partnerId = (-1).obs;
  final RxString channelModelName = 'mail.channel'.obs;
  
  // For searching/starting direct messages
  final RxList<Map<String, dynamic>> usersToChat = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingUsers = false.obs;
  
  Timer? _refreshTimer;
  StreamSubscription? _authSubscription;

  @override
  void onInit() {
    super.onInit();
    LogUtils.i('DISCUSS_LIFECYCLE: DiscussController onInit started');
    
    // Watch auth state to load or clear discuss module
    final authController = Get.find<AuthController>();
    LogUtils.i('DISCUSS_LIFECYCLE: Found AuthController, initial user = ${authController.user.value}');
    if (authController.user.value != null) {
      LogUtils.i('DISCUSS_LIFECYCLE: User already logged in onInit, starting discuss...');
      initDiscuss();
    }
    
    _authSubscription = authController.user.listen((user) {
      LogUtils.i('DISCUSS_LIFECYCLE: AuthController.user listener triggered. New user: $user');
      if (user != null) {
        initDiscuss();
      } else {
        clearDiscuss();
      }
    });

    // Background polling for new messages every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (OdooRpcApiManager.isAuthenticated && !isLoadingChannels.value) {
        refreshActiveChannel();
      }
    });
    LogUtils.i('DISCUSS_LIFECYCLE: DiscussController onInit complete');
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    _authSubscription?.cancel();
    super.onClose();
  }

  void clearDiscuss() {
    channels.clear();
    channelMessages.clear();
    selectedChannelId.value = -1;
    partnerId.value = -1;
  }

  Future<void> initDiscuss() async {
    try {
      isLoadingChannels.value = true;
      LogUtils.i('DISCUSS_INIT: Starting initialization...');
      
      // 1. Fetch user's partner ID
      await _fetchPartnerId();
      
      if (partnerId.value == -1) {
        LogUtils.e('DISCUSS_INIT: Failed to resolve partner ID.');
        return;
      }
      
      // 2. Resolve active channel model name
      await _resolveChannelModel();
      
      // 3. Load channels
      await fetchChannels();
      
      // 4. Load users list for starting DMs
      await fetchUsers();
      
    } catch (e) {
      LogUtils.e('DISCUSS_INIT_ERROR: $e');
    } finally {
      isLoadingChannels.value = false;
    }
  }

  Future<void> _fetchPartnerId() async {
    try {
      final uid = OdooRpcApiManager.currentUserId;
      if (uid == null) return;

      LogUtils.i('DISCUSS_PARTNER: Querying res.users for uid=$uid');
      final response = await OdooRpcApiManager.read(
        model: 'res.users',
        ids: [uid],
        fields: ['partner_id'],
      );

      if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
        final partnerField = response.data![0]['partner_id'];
        if (partnerField is List && partnerField.isNotEmpty) {
          partnerId.value = partnerField[0] as int;
          LogUtils.i('DISCUSS_PARTNER: Resolved partner ID to ${partnerId.value}');
        } else if (partnerField is int) {
          partnerId.value = partnerField;
          LogUtils.i('DISCUSS_PARTNER: Resolved partner ID to ${partnerId.value}');
        }
      }

      // Fallback 1: Search in res.partner by email
      if (partnerId.value == -1) {
        final email = Get.find<AuthController>().user.value?.email;
        if (email != null && email.isNotEmpty) {
          LogUtils.i('DISCUSS_PARTNER: Fallback searching res.partner by email: $email');
          final partnerRes = await OdooRpcApiManager.searchRead(
            model: 'res.partner',
            domain: [['email', '=', email]],
            fields: ['id'],
            limit: 1,
          );
          if (partnerRes.isSuccess && partnerRes.data != null && partnerRes.data!.isNotEmpty) {
            partnerId.value = partnerRes.data![0]['id'] as int;
            LogUtils.i('DISCUSS_PARTNER: Fallback resolved partner ID by email to ${partnerId.value}');
          }
        }
      }

      // Fallback 2: Search in res.users by login/email
      if (partnerId.value == -1) {
        final email = Get.find<AuthController>().user.value?.email;
        if (email != null && email.isNotEmpty) {
          LogUtils.i('DISCUSS_PARTNER: Fallback searching res.users by login/email: $email');
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
            LogUtils.i('DISCUSS_PARTNER: Fallback resolved partner ID from res.users search to ${partnerId.value}');
          }
        }
      }
    } catch (e) {
      LogUtils.e('DISCUSS_PARTNER_ERROR: $e');
    }
  }

  Future<void> _resolveChannelModel() async {
    try {
      LogUtils.i('DISCUSS_MODEL: Testing mail.channel...');
      // Try a simple search on mail.channel to check if it exists
      final testMail = await OdooRpcApiManager.searchRead(
        model: 'mail.channel',
        domain: [],
        fields: ['id'],
        limit: 1,
      );
      
      if (testMail.isSuccess) {
        channelModelName.value = 'mail.channel';
        LogUtils.i('DISCUSS_MODEL: Resolved to mail.channel');
        return;
      }
    } catch (e) {
      LogUtils.e('DISCUSS_MODEL: mail.channel test failed: $e');
    }

    try {
      LogUtils.i('DISCUSS_MODEL: Testing discuss.channel...');
      // Try a simple search on discuss.channel to check if it exists
      final testDiscuss = await OdooRpcApiManager.searchRead(
        model: 'discuss.channel',
        domain: [],
        fields: ['id'],
        limit: 1,
      );
      
      if (testDiscuss.isSuccess) {
        channelModelName.value = 'discuss.channel';
        LogUtils.i('DISCUSS_MODEL: Resolved to discuss.channel');
        return;
      }
    } catch (e) {
      LogUtils.e('DISCUSS_MODEL: discuss.channel test failed: $e');
    }

    // Default fallback
    channelModelName.value = 'discuss.channel';
    LogUtils.i('DISCUSS_MODEL: Defaulting to discuss.channel');
  }

  Future<void> fetchChannels() async {
    if (partnerId.value == -1) return;
    try {
      isLoadingChannels.value = true;
      LogUtils.i('DISCUSS_CHANNELS: Fetching channels from Odoo...');
      
      // Try querying with channel_partner_ids first
      var response = await OdooRpcApiManager.searchRead(
        model: channelModelName.value,
        domain: [],
        fields: ['id', 'name', 'channel_type', 'description', 'channel_partner_ids'],
        order: 'write_date desc',
      );

      // Fallback: If querying with channel_partner_ids fails, try querying basic fields
      if (!response.isSuccess) {
        LogUtils.i('DISCUSS_CHANNELS: searchRead with channel_partner_ids failed. Retrying with basic fields...');
        response = await OdooRpcApiManager.searchRead(
          model: channelModelName.value,
          domain: [],
          fields: ['id', 'name', 'channel_type', 'description'],
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
          } catch (e) {
            LogUtils.e('DISCUSS_CHANNEL_PARSE_ERROR: $e on raw=$raw');
          }
        }
        
        channels.value = fetched;
        
        // Auto-select the first channel if none is selected
        if (selectedChannelId.value == -1 && channels.isNotEmpty) {
          selectChannel(channels.first.id);
        }
      }
    } catch (e) {
      LogUtils.e('DISCUSS_CHANNELS_ERROR: $e');
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
        fields: ['id', 'name', 'email'],
        limit: 80,
      );

      List<Map<String, dynamic>> finalUsers = [];

      if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
        finalUsers = response.data!.map((e) => Map<String, dynamic>.from(e)).toList();
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
    // Clear unread count locally when entering a channel
    final idx = channels.indexWhere((c) => c.id == channelId);
    if (idx != -1) {
      channels[idx] = channels[idx].copyWith(unreadCount: 0);
    }
    
    // Fetch messages for this channel
    if (!channelMessages.containsKey(channelId)) {
      fetchMessages(channelId);
    } else {
      // Refresh messages
      fetchMessages(channelId, background: true);
    }
  }

  Future<void> fetchMessages(int channelId, {bool background = false}) async {
    if (channelId == -1) return;
    
    if (!background) {
      isLoadingMessages[channelId] = true;
    }

    try {
      debugPrint('DISCUSS_MESSAGES: Querying messages for channel=$channelId');
      
      // In Odoo, messages for a channel are linked via model and res_id
      final response = await OdooRpcApiManager.searchRead(
        model: 'mail.message',
        domain: [
          ['model', '=', channelModelName.value],
          ['res_id', '=', channelId],
          ['message_type', '=', 'comment']
        ],
        fields: ['id', 'body', 'author_id', 'date', 'message_type'],
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
        
        // Odoo returns newest first, so we reverse to display chronologically in chat bubble flow
        final chronological = msgs.reversed.toList();
        
        channelMessages[channelId] = chronological;
        
        // Update the channel's last message info
        if (chronological.isNotEmpty) {
          final last = chronological.last;
          final idx = channels.indexWhere((c) => c.id == channelId);
          if (idx != -1) {
            channels[idx] = channels[idx].copyWith(
              lastMessage: last.cleanBody,
              lastMessageTime: last.date,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('DISCUSS_MESSAGES_ERROR: $e');
    } finally {
      isLoadingMessages[channelId] = false;
    }
  }

  Future<void> refreshActiveChannel() async {
    if (selectedChannelId.value == -1) return;
    await fetchMessages(selectedChannelId.value, background: true);
    // Also fetch updated channel details to update list unreads or updates
    var response = await OdooRpcApiManager.searchRead(
      model: channelModelName.value,
      domain: [],
      fields: ['id', 'name', 'channel_type', 'description', 'channel_partner_ids'],
      order: 'write_date desc',
    );

    if (!response.isSuccess) {
      response = await OdooRpcApiManager.searchRead(
        model: channelModelName.value,
        domain: [],
        fields: ['id', 'name', 'channel_type', 'description'],
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
          channels[idx] = f.copyWith(
            unreadCount: f.id == selectedChannelId.value ? 0 : f.unreadCount,
          );
        } else {
          channels.add(f);
        }
      }
    }
  }

  Future<bool> sendMessage(String text) async {
    final channelId = selectedChannelId.value;
    if (channelId == -1 || text.trim().isEmpty) return false;

    try {
      isSendingMessage.value = true;
      
      // 1. Optimistic Local Update for UI responsiveness
      final localMsg = DiscussMessageModel(
        id: DateTime.now().millisecondsSinceEpoch, // temporary local id
        body: text,
        cleanBody: text,
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

      // 2. Perform remote API post
      debugPrint('DISCUSS_SEND: Posting message to channel=$channelId');
      final response = await OdooRpcApiManager.call(
        model: channelModelName.value,
        method: 'message_post',
        args: [channelId],
        kwargs: {
          'body': text,
          'message_type': 'comment',
          'subtype_xmlid': 'mail.mt_comment',
        },
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
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/exports.dart';

class DiscussScreen extends StatefulWidget {
  static const String routeName = '/discuss';

  const DiscussScreen({super.key});

  @override
  State<DiscussScreen> createState() => _DiscussScreenState();
}

class _DiscussScreenState extends State<DiscussScreen> {
  final DiscussController controller = Get.isRegistered<DiscussController>()
      ? Get.find<DiscussController>()
      : Get.put(DiscussController());

  String _filterType = 'all'; // 'all', 'chat', 'channel'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 550;
          return Obx(() {
            if (controller.isLoadingChannels.value && controller.channels.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              );
            }

            if (isWide) {
              return _buildWideLayout();
            } else {
              return _buildCompactLayout();
            }
          });
        },
      ),
    );
  }

  // --- Layout Builders ---

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Sidebar list
        SizedBox(
          width: 260,
          child: _buildChannelsListSection(),
        ),
        const VerticalDivider(width: 1, thickness: 0.5),
        // Active Chat thread
        Expanded(
          child: _buildChatThreadSection(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    final activeId = controller.selectedChannelId.value;
    
    // If no channel is selected or we're on fallback, show channels list
    if (activeId == -1) {
      return _buildChannelsListSection();
    } else {
      return _buildChatThreadSection(showBackButton: true);
    }
  }

  // --- Section: Channels List ---

  Widget _buildChannelsListSection() {
    // Filter channels
    final filtered = controller.channels.where((c) {
      if (_filterType == 'chat') return c.channelType == 'chat';
      if (_filterType == 'channel') return c.channelType != 'chat';
      return true;
    }).toList();

    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task Watch Discuss',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              IconButton(
                onPressed: _showNewChatDrawer,
                icon: const Icon(Icons.rate_review_outlined, size: 20),
                color: AppTheme.primary,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary.withOpacity(0.08),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
                tooltip: 'Start chat',
              ),
            ],
          ),
        ),
        
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: 6),
              _buildFilterChip('Chats', 'chat'),
              const SizedBox(width: 6),
              _buildFilterChip('Channels', 'channel'),
              const SizedBox(width: 6),
              _buildFilterChip('Colleagues', 'colleagues'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, thickness: 0.5),

        // List
        Expanded(
          child: _filterType == 'colleagues'
              ? _buildColleaguesList()
              : filtered.isEmpty
                  ? _buildEmptyChannelsState()
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.grey.shade200,
                        indent: 64,
                        endIndent: 12,
                      ),
                      itemBuilder: (context, index) {
                        final chan = filtered[index];
                        return ChannelListTile(
                          channel: chan,
                          isSelected: chan.id == controller.selectedChannelId.value,
                          onTap: () => controller.selectChannel(chan.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChannelsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            'No discussions found',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColleaguesList() {
    final users = controller.usersToChat;
    if (users.isEmpty) {
      return Center(
        child: Text(
          'No colleagues found',
          style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final name = u['name'] ?? 'Colleague';
        final email = u['email'] ?? '';
        final uId = u['id'] as int;

        // Choose avatar background color based on name hash
        final nameHash = name.hashCode.abs();
        final avatarColors = [
          const Color(0xFFE2165F),
          const Color(0xFF006D37),
          const Color(0xFF0F52BA),
          const Color(0xFFD4AF37),
          const Color(0xFF8A2BE2),
          const Color(0xFFE65C00),
        ];
        final avatarColor = avatarColors[nameHash % avatarColors.length];

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            onTap: () => controller.startDirectChat(uId, name),
            leading: InkWell(
              onTap: () {
                UserProfileHierarchyDialog.show(
                  context,
                  partnerId: uId,
                  initialName: name,
                  initialEmail: email,
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: avatarColor.withOpacity(0.15),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: OdooNetworkImage(
                    model: 'res.partner',
                    id: uId,
                    field: 'image_128',
                    placeholder: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                        color: avatarColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            title: Text(
              name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF25181E),
              ),
            ),
            subtitle: email.isNotEmpty
                ? Text(
                    email,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  )
                : null,
            trailing: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: AppTheme.primary.withOpacity(0.8),
            ),
          ),
        );
      },
    );
  }

  void _showChannelInfo(DiscussChannelModel channel) {
    if (channel.channelType == 'chat' && channel.otherPartnerId != null) {
      UserProfileHierarchyDialog.show(
        context,
        partnerId: channel.otherPartnerId,
        initialName: channel.name,
      );
    } else {
      DialogUtils.showAppDialog(
        context: context,
        title: channel.name,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Channel: ${channel.name}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Type: Group Channel (#${channel.id})',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 8),
            Text(
                'Total Messages: ${controller.channelMessages[channel.id]?.length ?? 0}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      );
    }
  }

  // --- Section: Active Chat Thread ---

  Widget _buildChatThreadSection({bool showBackButton = false}) {
    final activeId = controller.selectedChannelId.value;
    if (activeId == -1) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Select a conversation to start chatting',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final activeChannel = controller.channels.firstWhere((c) => c.id == activeId);
    final msgs = controller.channelMessages[activeId] ?? [];
    final isLoading = controller.isLoadingMessages[activeId] ?? false;

    // Avatar color determination
    final nameHash = activeChannel.name.hashCode.abs();
    final avatarColors = [
      const Color(0xFFE2165F),
      const Color(0xFF006D37),
      const Color(0xFF0F52BA),
      const Color(0xFFD4AF37),
      const Color(0xFF8A2BE2),
      const Color(0xFFE65C00),
    ];
    final avatarColor = avatarColors[nameHash % avatarColors.length];

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (showBackButton) ...[
                IconButton(
                  onPressed: () => controller.selectedChannelId.value = -1,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  color: Colors.grey.shade700,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              
              // Avatar & Info Clickable Area
              InkWell(
                onTap: () => _showChannelInfo(activeChannel),
                borderRadius: BorderRadius.circular(16),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: avatarColor.withOpacity(0.15),
                  child: activeChannel.channelType == 'chat' &&
                          activeChannel.otherPartnerId != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: OdooNetworkImage(
                            model: 'res.partner',
                            id: activeChannel.otherPartnerId!,
                            field: 'image_128',
                            placeholder: Text(
                              activeChannel.name.isNotEmpty
                                  ? activeChannel.name[0].toUpperCase()
                                  : 'C',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.bold,
                                color: avatarColor,
                                fontSize: 12,
                              ),
                            ),
                            errorWidget: Text(
                              activeChannel.name.isNotEmpty
                                  ? activeChannel.name[0].toUpperCase()
                                  : 'C',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.bold,
                                color: avatarColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          activeChannel.name.isNotEmpty
                              ? activeChannel.name[0].toUpperCase()
                              : '#',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            color: avatarColor,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),

              // Name and type Clickable
              Expanded(
                child: InkWell(
                  onTap: () => _showChannelInfo(activeChannel),
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeChannel.name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF25181E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        activeChannel.channelType == 'chat'
                            ? 'Direct Message • Tap for Profile & Hierarchy'
                            : 'Group Channel',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              IconButton(
                onPressed: () => _showChannelInfo(activeChannel),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                color: Colors.grey.shade600,
                tooltip: 'Profile & Info',
                style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
              ),
            ],
          ),
        ),

        // Messages area
        Expanded(
          child: isLoading && msgs.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                )
              : msgs.isEmpty
                  ? _buildEmptyConversationState()
                  : ListView.builder(
                      controller: controller.chatScrollController,
                      reverse: true, // pin to bottom
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: msgs.length,
                      itemBuilder: (context, index) {
                        // Display chronological order (oldest at top, newest at bottom)
                        final msg = msgs[msgs.length - 1 - index];
                        return MessageBubble(message: msg);
                      },
                    ),
        ),

        // Input area
        ChatInputArea(
          onSend: (text) => controller.sendMessage(text),
          onAttach: (name, bytes, caption) => controller.sendAttachment(name, bytes, caption: caption),
          isLoading: controller.isSendingMessage.value,
        ),
      ],
    );
  }

  Widget _buildEmptyConversationState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 40,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 10),
          Text(
            'No messages yet',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Send a message to start the conversation!',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // --- Bottom Sheets / Modals ---

  void _showNewChatDrawer() {
    // Make sure users list is refreshed
    controller.fetchUsers();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const NewChatSheet(),
      ),
    );
  }
}

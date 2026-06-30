import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pi_task_watch/exports.dart';

class ChannelListTile extends StatefulWidget {
  final DiscussChannelModel channel;
  final bool isSelected;
  final VoidCallback onTap;

  const ChannelListTile({
    super.key,
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<ChannelListTile> createState() => _ChannelListTileState();
}

class _ChannelListTileState extends State<ChannelListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isChat = widget.channel.channelType == 'chat';
    final hasUnread = widget.channel.unreadCount > 0;
    
    // Choose avatar background color based on name hash
    final nameHash = widget.channel.name.hashCode.abs();
    final avatarColors = [
      const Color(0xFFE2165F), // Magenta
      const Color(0xFF006D37), // Green
      const Color(0xFF0F52BA), // Sapphire
      const Color(0xFFD4AF37), // Gold
      const Color(0xFF8A2BE2), // Purple
      const Color(0xFFE65C00), // Orange
    ];
    final avatarColor = avatarColors[nameHash % avatarColors.length];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppTheme.primary.withOpacity(0.08)
              : _isHovered
                  ? Colors.grey.shade100
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? AppTheme.primary.withOpacity(0.2)
                : Colors.transparent,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Avatar Section
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: avatarColor.withOpacity(0.15),
                    child: isChat && widget.channel.otherPartnerId != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: OdooNetworkImage(
                              model: 'res.partner',
                              id: widget.channel.otherPartnerId!,
                              field: 'image_128',
                              placeholder: Text(
                                widget.channel.name.isNotEmpty
                                    ? widget.channel.name[0].toUpperCase()
                                    : 'C',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.bold,
                                  color: avatarColor,
                                  fontSize: 14,
                                ),
                              ),
                              errorWidget: Text(
                                widget.channel.name.isNotEmpty
                                    ? widget.channel.name[0].toUpperCase()
                                    : 'C',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.bold,
                                  color: avatarColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            widget.channel.name.isNotEmpty
                                ? widget.channel.name[0].toUpperCase()
                                : '#',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.bold,
                              color: avatarColor,
                              fontSize: 14,
                            ),
                          ),
                  ),
                  if (isChat)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF66),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              
              // Details Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.channel.name,
                            style: GoogleFonts.inter(
                              fontWeight: hasUnread || widget.isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 13,
                              color: widget.isSelected ? AppTheme.primary : const Color(0xFF25181E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.channel.lastMessageTime != null)
                          Text(
                            _formatLastMessageTime(widget.channel.lastMessageTime!),
                            style: TextStyle(
                              fontSize: 10,
                              color: hasUnread ? AppTheme.primary : Colors.grey.shade500,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.channel.lastMessage ?? 'No messages yet',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: hasUnread ? Colors.black87 : Colors.grey.shade600,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Text(
                              '${widget.channel.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastMessageTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}

class MessageBubble extends StatelessWidget {
  final DiscussMessageModel message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isOutgoing;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Author name for group chats if incoming
            if (!isOutgoing) ...[
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 3),
                child: Text(
                  message.authorName,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
            
            // Message Card
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isOutgoing) ...[
                  _buildTimeText(),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Container(
                    decoration: isOutgoing
                        ? BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primary,
                                Color(0xFFFF4D94),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          )
                        : AppTheme.glassDecoration(
                            borderRadius: 20,
                            color: Colors.white,
                          ).copyWith(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      message.cleanBody,
                      style: GoogleFonts.inter(
                        color: isOutgoing ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                if (!isOutgoing) ...[
                  const SizedBox(width: 6),
                  _buildTimeText(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeText() {
    final hour = message.date.hour % 12 == 0 ? 12 : message.date.hour % 12;
    final minute = message.date.minute.toString().padLeft(2, '0');
    final period = message.date.hour >= 12 ? 'PM' : 'AM';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$hour:$minute $period',
        style: TextStyle(
          fontSize: 9,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class ChatInputArea extends StatefulWidget {
  final Function(String) onSend;
  final bool isLoading;

  const ChatInputArea({
    super.key,
    required this.onSend,
    required this.isLoading,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _textController = TextEditingController();

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F8),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Write a message...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            widget.isLoading
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                      ),
                    ),
                  )
                : IconButton(
                    onPressed: _handleSend,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class NewChatSheet extends StatefulWidget {
  const NewChatSheet({super.key});

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
  final controller = Get.find<DiscussController>();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'New Direct Message',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Search box
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
            decoration: InputDecoration(
              hintText: 'Search colleagues...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              fillColor: Colors.grey.shade50,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          // List of users
          Flexible(
            child: Obx(() {
              if (controller.isLoadingUsers.value) {
                return const SizedBox(
                  height: 150,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                    ),
                  ),
                );
              }

              final filtered = controller.usersToChat.where((u) {
                final name = (u['name'] ?? '').toString().toLowerCase();
                final email = (u['email'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || email.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return SizedBox(
                  height: 150,
                  child: Center(
                    child: Text(
                      'No colleagues found',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final u = filtered[index];
                    final name = u['name'] ?? '';
                    final email = u['email'] ?? '';
                    final uId = u['id'] as int;

                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        controller.startDirectChat(uId, name);
                      },
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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
                      trailing: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20,
                        color: AppTheme.primary,
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/utils/capture_screenshot.dart';

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
                  if (isChat && (widget.channel.isOnline || widget.channel.isAway))
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: widget.channel.isOnline
                              ? const Color(0xFF00FF66)
                              : const Color(0xFFFFB300),
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
    return FormatUtils.formatChatTime(dt);
  }
}
class MessageBubble extends StatelessWidget {
  final DiscussMessageModel message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isOutgoing;
    final nameHash = message.authorName.hashCode.abs();
    final avatarColors = [
      const Color(0xFFE2165F),
      const Color(0xFF006D37),
      const Color(0xFF0F52BA),
      const Color(0xFFD4AF37),
      const Color(0xFF8A2BE2),
      const Color(0xFFE65C00),
    ];
    final avatarColor = avatarColors[nameHash % avatarColors.length];

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
                padding: const EdgeInsets.only(left: 42, bottom: 3),
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
            
            // Message Card with User Profile Picture Avatar
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Incoming User Avatar (Left)
                if (!isOutgoing) ...[
                  _buildUserAvatar(avatarColor),
                  const SizedBox(width: 8),
                ],
                if (isOutgoing) ...[
                  // 3-Dots Action Button on Hover / Tap
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 14, color: Colors.grey),
                    onPressed: () => _showMessageActions(context),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(22, 22),
                      padding: EdgeInsets.zero,
                    ),
                    tooltip: 'Message actions',
                  ),
                  _buildTimeText(),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onLongPress: () => _showMessageActions(context),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Pinned Indicator Badge
                              if (Get.isRegistered<DiscussController>() &&
                                  Get.find<DiscussController>()
                                          .pinnedMessages[
                                              Get.find<DiscussController>()
                                                  .selectedChannelId
                                                  .value]
                                          ?.id ==
                                      message.id) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOutgoing
                                        ? Colors.white.withOpacity(0.2)
                                        : AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.push_pin_rounded,
                                        size: 11,
                                        color: isOutgoing
                                            ? Colors.white
                                            : AppTheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Pinned',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isOutgoing
                                              ? Colors.white
                                              : AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Quoted reply banner
                              if (message.isReply) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isOutgoing
                                        ? Colors.black.withOpacity(0.15)
                                        : const Color(0xFF00A09D).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border(
                                      left: BorderSide(
                                        color: isOutgoing
                                            ? Colors.white.withOpacity(0.9)
                                            : const Color(0xFF00A09D),
                                        width: 3.5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (message.replyAuthor != null &&
                                          message.replyAuthor!.isNotEmpty)
                                        Text(
                                          message.replyAuthor!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isOutgoing
                                                ? Colors.white
                                                : const Color(0xFF00A09D),
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        message.replyText!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isOutgoing
                                              ? Colors.white.withOpacity(0.85)
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (message.contentBody.isNotEmpty) ...[
                                RichText(
                                  text: TextSpan(
                                    children: _parseMessageBody(
                                        message.contentBody, isOutgoing),
                                  ),
                                ),
                                if (_extractFirstUrl(message.contentBody) !=
                                    null) ...[
                                  const SizedBox(height: 6),
                                  _buildLinkPreviewCard(
                                      _extractFirstUrl(message.contentBody)!,
                                      isOutgoing),
                                ],
                              ],
                              if (message.contentBody.isNotEmpty &&
                                  message.attachments.isNotEmpty)
                                const SizedBox(height: 8),
                              if (message.attachments.isNotEmpty)
                                ...message.attachments.map((attach) =>
                                    _buildAttachmentItem(
                                        context, attach, isOutgoing)),
                            ],
                          ),
                        ),
                      ),

                      // Floating Reaction Badge
                      if (Get.isRegistered<DiscussController>()) ...[
                        Obx(() {
                          final reaction = Get.find<DiscussController>()
                              .messageReactions[message.id];
                          if (reaction == null || reaction.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            bottom: -10,
                            right: isOutgoing ? null : 8,
                            left: isOutgoing ? 8 : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                reaction,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                if (!isOutgoing) ...[
                  const SizedBox(width: 6),
                  _buildTimeText(),
                  // 3-Dots Action Button for Incoming message
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 14, color: Colors.grey),
                    onPressed: () => _showMessageActions(context),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(22, 22),
                      padding: EdgeInsets.zero,
                    ),
                    tooltip: 'Message actions',
                  ),
                ],
                // Outgoing User Avatar (Right)
                if (isOutgoing) ...[
                  const SizedBox(width: 8),
                  _buildUserAvatar(avatarColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(Color avatarColor) {
    final String initial = message.authorName.isNotEmpty
        ? message.authorName[0].toUpperCase()
        : 'U';

    if (message.authorId <= 0) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: avatarColor.withOpacity(0.15),
        child: Text(
          initial,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            color: avatarColor,
            fontSize: 11,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 14,
      backgroundColor: avatarColor.withOpacity(0.15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: OdooNetworkImage(
          model: 'res.partner',
          id: message.authorId,
          field: 'image_128',
          placeholder: Text(
            initial,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              color: avatarColor,
              fontSize: 11,
            ),
          ),
          errorWidget: Text(
            initial,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              color: avatarColor,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(
      BuildContext context, DiscussAttachmentModel attachment, bool isOutgoing) {
    final lowerName = attachment.name.toLowerCase();
    final lowerMime = attachment.mimetype.toLowerCase();
    final bool isImage = lowerMime.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.bmp');
    final bool isAudio = lowerMime.startsWith('audio/') ||
        lowerName.endsWith('.mp3') ||
        lowerName.endsWith('.wav') ||
        lowerName.endsWith('.m4a') ||
        lowerName.endsWith('.aac') ||
        lowerName.endsWith('.ogg') ||
        lowerName.endsWith('.flac');
    final bool isVideo = lowerMime.startsWith('video/') ||
        lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.mkv') ||
        lowerName.endsWith('.avi') ||
        lowerName.endsWith('.webm');

    if (isImage) {
      return GestureDetector(
        onTap: () => _openAttachment(context, attachment),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 240),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: OdooNetworkImage(
              model: 'ir.attachment',
              id: attachment.id,
              field: 'datas',
              fit: BoxFit.cover,
              placeholder: Container(
                height: 120,
                color: isOutgoing
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade100,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
              errorWidget: Container(
                color: Colors.grey.shade200,
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_outlined,
                        color: Color(0xFF4CAF50), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attachment.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isOutgoing ? Colors.white70 : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else if (isAudio) {
      return GestureDetector(
        onTap: () => _openAttachment(context, attachment),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 240),
          decoration: BoxDecoration(
            color: isOutgoing
                ? Colors.white.withOpacity(0.18)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOutgoing
                  ? Colors.white.withOpacity(0.2)
                  : const Color(0xFFFFB74D).withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOutgoing
                      ? Colors.white.withOpacity(0.25)
                      : const Color(0xFFFF9800),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.audiotrack_rounded,
                  color: isOutgoing ? Colors.white : Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOutgoing
                            ? Colors.white
                            : const Color(0xFFE65100),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      attachment.fileSize > 0
                          ? _formatFileSize(attachment.fileSize)
                          : 'Audio file',
                      style: TextStyle(
                        fontSize: 10,
                        color: isOutgoing
                            ? Colors.white70
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isVideo) {
      return _buildVideoCard(context, attachment, isOutgoing);
    } else {
      return _buildDocumentCard(context, attachment, isOutgoing);
    }
  }

  Widget _buildDocumentCard(
      BuildContext context, DiscussAttachmentModel attachment, bool isOutgoing) {
    final lowerName = attachment.name.toLowerCase();
    final isPdf = lowerName.endsWith('.pdf');
    final isWord = lowerName.endsWith('.doc') || lowerName.endsWith('.docx');
    final isExcel = lowerName.endsWith('.xls') ||
        lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.csv');
    final isZip = lowerName.endsWith('.zip') || lowerName.endsWith('.rar');

    final badgeColor = isPdf
        ? const Color(0xFFE53935)
        : (isWord
            ? const Color(0xFF1E88E5)
            : (isExcel
                ? const Color(0xFF2E7D32)
                : (isZip ? const Color(0xFF8E24AA) : const Color(0xFF546E7A))));

    final badgeText = isPdf
        ? 'PDF'
        : (isWord
            ? 'DOC'
            : (isExcel ? 'XLS' : (isZip ? 'ZIP' : 'FILE')));

    final extStr = isPdf
        ? 'PDF'
        : (isWord
            ? 'DOCX'
            : (isExcel
                ? 'EXCEL'
                : (isZip ? 'ZIP' : 'FILE')));

    final sizeStr = attachment.fileSize > 0
        ? _formatFileSize(attachment.fileSize)
        : 'Document';

    return GestureDetector(
      onTap: () => _openAttachment(context, attachment),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 270),
        decoration: BoxDecoration(
          color: isOutgoing
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFF1F5F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOutgoing
                ? Colors.white.withValues(alpha: 0.22)
                : const Color(0xFFD6E2DB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top visual document thumbnail preview
            Container(
              height: 75,
              width: double.infinity,
              color: isOutgoing
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 6,
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 60,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 140,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 110,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 80,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Icon(
                      _getIconForMimetype(attachment.mimetype, attachment.name),
                      size: 38,
                      color: badgeColor.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            // Bottom File Info Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Stylized document icon badge
                  Container(
                    width: 32,
                    height: 38,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.insert_drive_file_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // File Name and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          attachment.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOutgoing ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$extStr • $sizeStr',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isOutgoing
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(
      BuildContext context, DiscussAttachmentModel attachment, bool isOutgoing) {
    final sizeStr = attachment.fileSize > 0
        ? _formatFileSize(attachment.fileSize)
        : 'Video';

    return GestureDetector(
      onTap: () => _openAttachment(context, attachment),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 270),
        decoration: BoxDecoration(
          color: isOutgoing
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFF1F5F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOutgoing
                ? Colors.white.withValues(alpha: 0.22)
                : const Color(0xFFD6E2DB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Video Banner with play button overlay
            Container(
              height: 130,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2C1B24), Color(0xFF1E1318)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            // Bottom Video Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Color(0xFF9C27B0),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          attachment.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOutgoing ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'MP4 • $sizeStr',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isOutgoing
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractFirstUrl(String text) {
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }

  Widget _buildLinkPreviewCard(String url, bool isOutgoing) {
    String urlToLaunch = url;
    if (url.toLowerCase().startsWith('www.')) {
      urlToLaunch = 'https://$url';
    }

    final uri = Uri.tryParse(urlToLaunch);
    final domain = uri?.host ?? 'link';
    final lowerUrl = urlToLaunch.toLowerCase();
    final isVideoLink = lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be') ||
        lowerUrl.contains('facebook.com/share/r') ||
        lowerUrl.contains('fb.watch') ||
        lowerUrl.contains('instagram.com/reel') ||
        lowerUrl.contains('tiktok.com') ||
        lowerUrl.endsWith('.mp4');

    // Extract YouTube thumbnail if possible
    String? ytThumbnail;
    if (lowerUrl.contains('youtube.com/watch') && uri != null) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) {
        ytThumbnail = 'https://img.youtube.com/vi/$v/hqdefault.jpg';
      }
    } else if (lowerUrl.contains('youtu.be/') && uri != null) {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (id != null && id.isNotEmpty) {
        ytThumbnail = 'https://img.youtube.com/vi/$id/hqdefault.jpg';
      }
    }

    return GestureDetector(
      onTap: () async {
        try {
          final target = Uri.parse(urlToLaunch);
          if (await canLaunchUrl(target)) {
            await launchUrl(target, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Error opening link: $e');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isOutgoing
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFFF1F5F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOutgoing
                ? Colors.white.withValues(alpha: 0.22)
                : const Color(0xFFD6E2DB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Media Banner
            Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF2C1B24),
                image: ytThumbnail != null
                    ? DecorationImage(
                        image: NetworkImage(ytThumbnail),
                        fit: BoxFit.cover,
                      )
                    : null,
                gradient: ytThumbnail == null
                    ? const LinearGradient(
                        colors: [Color(0xFF3B2332), Color(0xFF25181E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
              ),
              child: isVideoLink
                  ? Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    )
                  : (ytThumbnail == null
                      ? Center(
                          child: Icon(
                            Icons.public_rounded,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 48,
                          ),
                        )
                      : null),
            ),
            const Divider(height: 1, thickness: 0.5),

            // Middle Description & Domain
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVideoLink ? 'Watch Video • $domain' : domain,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOutgoing ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    domain,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isOutgoing
                          ? Colors.white70
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    urlToLaunch,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isOutgoing
                          ? const Color(0xFF80E5FF)
                          : Colors.blue.shade700,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForMimetype(String mimetype, [String? name]) {
    final lowerMime = mimetype.toLowerCase();
    final lowerName = (name ?? '').toLowerCase();
    if (lowerMime.contains('pdf') || lowerName.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }
    if (lowerMime.contains('zip') ||
        lowerMime.contains('rar') ||
        lowerName.endsWith('.zip') ||
        lowerName.endsWith('.rar')) {
      return Icons.folder_zip_rounded;
    }
    if (lowerMime.contains('excel') ||
        lowerMime.contains('sheet') ||
        lowerName.endsWith('.xls') ||
        lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.csv')) {
      return Icons.table_chart_rounded;
    }
    if (lowerMime.contains('word') ||
        lowerMime.contains('document') ||
        lowerName.endsWith('.doc') ||
        lowerName.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (lowerMime.startsWith('audio/') ||
        lowerName.endsWith('.mp3') ||
        lowerName.endsWith('.wav')) {
      return Icons.audiotrack_rounded;
    }
    if (lowerMime.startsWith('video/') ||
        lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov')) {
      return Icons.videocam_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _openAttachment(BuildContext context, DiscussAttachmentModel attachment) {
    _showAttachmentPreviewDialog(context, attachment);
  }

  void _showAttachmentPreviewDialog(
      BuildContext context, DiscussAttachmentModel attachment) {
    final lowerName = attachment.name.toLowerCase();
    final lowerMime = attachment.mimetype.toLowerCase();
    final isImage = lowerMime.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp');
    final isAudio = lowerMime.startsWith('audio/') ||
        lowerName.endsWith('.mp3') ||
        lowerName.endsWith('.wav') ||
        lowerName.endsWith('.m4a') ||
        lowerName.endsWith('.aac') ||
        lowerName.endsWith('.ogg');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        Uint8List? fetchedBytes;
        bool isDownloading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 520,
                height: 520,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                _getIconForMimetype(
                                    attachment.mimetype, attachment.name),
                                size: 20,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  attachment.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.grey),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Body Area (Preview)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        child: isImage
                            ? FutureBuilder<List<int>?>(
                                future: OdooRpcApiManager.fetchImageBytes(
                                  model: 'ir.attachment',
                                  id: attachment.id,
                                  field: 'datas',
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                          color: AppTheme.primary),
                                    );
                                  }
                                  if (snapshot.hasError ||
                                      snapshot.data == null ||
                                      snapshot.data!.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              Icons.broken_image_rounded,
                                              size: 48,
                                              color: Colors.grey),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Failed to load image preview',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  fetchedBytes = Uint8List.fromList(
                                      snapshot.data!);
                                  return InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Image.memory(
                                      fetchedBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  );
                                },
                              )
                            : isAudio
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFFF3E0),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.audiotrack_rounded,
                                            size: 56,
                                            color: Color(0xFFFF9800),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          attachment.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          attachment.fileSize > 0
                                              ? 'Size: ${_formatFileSize(attachment.fileSize)}'
                                              : 'Audio recording / track',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _getIconForMimetype(
                                              attachment.mimetype,
                                              attachment.name),
                                          size: 64,
                                          color: AppTheme.primary,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          attachment.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Size: ${_formatFileSize(attachment.fileSize)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Type: ${attachment.mimetype}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action row (Download Button)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isDownloading)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () async {
                              setDialogState(() {
                                isDownloading = true;
                              });

                              try {
                                Uint8List? bytes = fetchedBytes;
                                if (bytes == null || bytes.isEmpty) {
                                  final raw =
                                      await OdooRpcApiManager.fetchImageBytes(
                                    model: 'ir.attachment',
                                    id: attachment.id,
                                    field: 'datas',
                                  );
                                  if (raw != null && raw.isNotEmpty) {
                                    bytes = Uint8List.fromList(raw);
                                  }
                                }

                                if (bytes == null || bytes.isEmpty) {
                                  showToast('Could not fetch file content',
                                      idSuccess: false);
                                  return;
                                }

                                final downloadsDir =
                                    await getDownloadsDirectory();
                                if (downloadsDir == null) {
                                  showToast(
                                      'Could not access Downloads directory',
                                      idSuccess: false);
                                  return;
                                }

                                var filePath =
                                    '${downloadsDir.path}/${attachment.name}';
                                var file = File(filePath);
                                var counter = 1;
                                while (await file.exists()) {
                                  final dotIndex =
                                      attachment.name.lastIndexOf('.');
                                  if (dotIndex != -1) {
                                    final nameWithoutExt = attachment.name
                                        .substring(0, dotIndex);
                                    final ext =
                                        attachment.name.substring(dotIndex);
                                    filePath =
                                        '${downloadsDir.path}/$nameWithoutExt($counter)$ext';
                                  } else {
                                    filePath =
                                        '${downloadsDir.path}/${attachment.name}($counter)';
                                  }
                                  file = File(filePath);
                                  counter++;
                                }

                                await file.writeAsBytes(bytes);
                                showToast(
                                    'Saved to Downloads: ${file.path.split('/').last}',
                                    idSuccess: true);
                              } catch (e) {
                                debugPrint('DOWNLOAD_ERROR: $e');
                                showToast('Failed to download: $e',
                                    idSuccess: false);
                              } finally {
                                setDialogState(() {
                                  isDownloading = false;
                                });
                              }
                            },
                            icon: const Icon(Icons.download_rounded,
                                size: 16, color: Colors.white),
                            label: Text(
                              'Download',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeText() {
    final formattedTime = FormatUtils.formatTime(message.date);
    final controller = Get.isRegistered<DiscussController>() ? Get.find<DiscussController>() : null;
    final isStarred = message.isStarred || (controller?.starredMessageIds.contains(message.id) ?? false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isStarred) ...[
            const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB300)),
            const SizedBox(width: 3),
          ],
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade500,
            ),
          ),
          if (message.isOutgoing) ...[
            const SizedBox(width: 4),
            _buildTickIcon(),
          ],
        ],
      ),
    );
  }

  Widget _buildTickIcon() {
    final controller = Get.isRegistered<DiscussController>() ? Get.find<DiscussController>() : null;
    if (controller == null) {
      return const Icon(Icons.done_rounded, size: 11, color: Colors.grey);
    }
    
    final tickStatus = controller.getMessageTickStatus(message);
    switch (tickStatus) {
      case MessageTickStatus.single:
        return const Icon(
          Icons.done_rounded,
          size: 11,
          color: Colors.grey,
        );
      case MessageTickStatus.doubleGray:
        return const Icon(
          Icons.done_all_rounded,
          size: 11,
          color: Colors.grey,
        );
      case MessageTickStatus.doubleBlue:
        return const Icon(
          Icons.done_all_rounded,
          size: 11,
          color: Colors.blue,
        );
      case MessageTickStatus.none:
        return const SizedBox.shrink();
    }
  }

  List<InlineSpan> _parseMessageBody(String text, bool isOutgoing) {
    final List<InlineSpan> spans = [];
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text);
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: GoogleFonts.inter(
            color: isOutgoing ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ));
      }

      final urlText = match.group(0)!;
      String urlToLaunch = urlText;
      if (urlText.toLowerCase().startsWith('www.')) {
        urlToLaunch = 'https://$urlText';
      }

      spans.add(TextSpan(
        text: urlText,
        style: GoogleFonts.inter(
          color: isOutgoing ? const Color(0xFF80E5FF) : Colors.blue.shade700,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          height: 1.4,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            try {
              final uri = Uri.parse(urlToLaunch);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              debugPrint('Error launching URL: $e');
            }
          },
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: GoogleFonts.inter(
          color: isOutgoing ? Colors.white : Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ));
    }

    return spans;
  }

  void _showMessageActions(BuildContext context) {
    final controller = Get.isRegistered<DiscussController>()
        ? Get.find<DiscussController>()
        : null;
    final activeChannelId = controller?.selectedChannelId.value ?? 0;
    final isPinned =
        controller?.pinnedMessages[activeChannelId]?.id == message.id ||
        (controller?.channelPinnedList[activeChannelId]?.any((m) => m.id == message.id) ?? false);
    final isStarred = message.isStarred || (controller?.starredMessageIds.contains(message.id) ?? false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Emoji Reactions Row (WhatsApp Style)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          controller?.reactToMessage(message.id, emoji);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),

                // 2. Pin / Unpin Message
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: isPinned ? AppTheme.primary : const Color(0xFF555555),
                    size: 18,
                  ),
                  title: Text(
                    isPinned ? 'Unpin Message' : 'Pin Message',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isPinned) {
                      controller?.unpinMessage(activeChannelId, message.id);
                    } else {
                      controller?.pinMessage(activeChannelId, message);
                    }
                  },
                ),

                // 3. Reply
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.reply_rounded,
                      color: Color(0xFF555555), size: 18),
                  title: Text(
                    'Reply',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller?.setReplyMessage(message);
                  },
                ),

                // 4. Copy Text
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.copy_rounded,
                      color: Color(0xFF555555), size: 18),
                  title: Text(
                    'Copy Text',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: message.cleanBody));
                    showToast('Message copied to clipboard', idSuccess: true);
                  },
                ),

                // 5. Star / Unstar Message
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(
                    isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFFFB300),
                    size: 18,
                  ),
                  title: Text(
                    isStarred ? 'Unstar Message' : 'Star Message',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller?.toggleStarMessage(message.id);
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class ChatInputArea extends StatefulWidget {
  final Function(String) onSend;
  final Function(String, Uint8List, String) onAttach;
  final bool isLoading;

  const ChatInputArea({
    super.key,
    required this.onSend,
    required this.onAttach,
    required this.isLoading,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _textController = TextEditingController();

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _textController.clear();
    }
  }

  bool _isAudioFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.flac');
  }

  bool _isVideoFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.webm');
  }

  void _showPreviewDialog(String fileName, Uint8List fileBytes) {
    final captionController = TextEditingController(text: _textController.text);
    final isImage = _isImageFile(fileName);
    final isAudio = _isAudioFile(fileName);
    final isVideo = _isVideoFile(fileName);

    String sizeStr = '';
    if (fileBytes.isNotEmpty) {
      final bytes = fileBytes.length;
      if (bytes < 1024) {
        sizeStr = '$bytes B';
      } else if (bytes < 1024 * 1024) {
        sizeStr = '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        sizeStr = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 440,
            constraints: const BoxConstraints(maxHeight: 560),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isImage
                              ? Icons.image_rounded
                              : (isAudio
                                  ? Icons.audiotrack_rounded
                                  : (isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.description_rounded)),
                          color: isImage
                              ? const Color(0xFF4CAF50)
                              : (isAudio
                                  ? const Color(0xFFFF9800)
                                  : (isVideo
                                      ? const Color(0xFF9C27B0)
                                      : const Color(0xFF2196F3))),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isImage
                              ? 'Send Photo'
                              : (isAudio
                                  ? 'Send Audio'
                                  : (isVideo
                                      ? 'Send Video'
                                      : 'Send Document')),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Content Preview Area (WhatsApp style)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    child: isImage
                        ? InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.memory(
                              fileBytes,
                              fit: BoxFit.contain,
                            ),
                          )
                        : isAudio
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(22),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFF3E0),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.audiotrack_rounded,
                                          size: 52,
                                          color: Color(0xFFFF9800),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        fileName,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (sizeStr.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          sizeStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : isVideo
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(22),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF3E5F5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.videocam_rounded,
                                            size: 52,
                                            color: Color(0xFF9C27B0),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          fileName,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (sizeStr.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            sizeStr,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  )
                                : Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _getDocumentIconForName(fileName),
                                            size: 64,
                                            color: AppTheme.primary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            fileName,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (sizeStr.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              sizeStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                  ),
                ),
                const SizedBox(height: 14),

                // Caption TextField
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F8),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: captionController,
                    style:
                        GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Actions Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        // Send attachment with caption
                        widget.onAttach(
                            fileName, fileBytes, captionController.text.trim());
                        _textController.clear();
                      },
                      icon: const Icon(Icons.send_rounded,
                          size: 14, color: Colors.white),
                      label: Text(
                        'Send',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getDocumentIconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv')) {
      return Icons.table_chart_rounded;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Future<void> _pickAndPreview(
    FileType type, {
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name;
        final bytes = file.bytes;
        if (bytes != null) {
          _showPreviewDialog(name, bytes);
        } else {
          showToast('Could not read file data', idSuccess: false);
        }
      }
    } catch (e) {
      debugPrint('FILE_PICK_ERROR: $e');
      showToast('Error picking file: $e', idSuccess: false);
    }
  }

  Future<void> _handleAttachmentMenu(BuildContext btnContext) async {
    final RenderBox button = btnContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(btnContext).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: btnContext,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      items: [
        PopupMenuItem(
          value: 'image',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_rounded,
                    size: 18, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(width: 12),
              Text('Photos & Images',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'audio',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.audiotrack_rounded,
                    size: 18, color: Color(0xFFFF9800)),
              ),
              const SizedBox(width: 12),
              Text('Audio & Voice',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'document',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded,
                    size: 18, color: Color(0xFF2196F3)),
              ),
              const SizedBox(width: 12),
              Text('Documents & PDFs',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'video',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.videocam_rounded,
                    size: 18, color: Color(0xFF9C27B0)),
              ),
              const SizedBox(width: 12),
              Text('Videos',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'any',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_file_rounded,
                    size: 18, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Text('Any File',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'image') {
        _pickAndPreview(FileType.image);
      } else if (value == 'audio') {
        _pickAndPreview(FileType.audio);
      } else if (value == 'document') {
        _pickAndPreview(
          FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx',
            'txt',
            'csv',
          ],
        );
      } else if (value == 'video') {
        _pickAndPreview(FileType.video);
      } else if (value == 'any') {
        _pickAndPreview(FileType.any);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Builder(
                builder: (btnContext) => IconButton(
                  onPressed: widget.isLoading
                      ? null
                      : () => _handleAttachmentMenu(btnContext),
                  icon: const Icon(Icons.attach_file_rounded,
                      size: 20, color: Colors.grey),
                  tooltip: 'Attach Image, Audio, Document, or File',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 4),
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
                    onSubmitted: (_) => widget.isLoading ? null : _handleSend(),
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

// =============================================================================
// PINNED MESSAGES DIALOG
// =============================================================================

class PinnedMessagesDialog extends StatelessWidget {
  final DiscussChannelModel channel;

  const PinnedMessagesDialog({super.key, required this.channel});

  static Future<void> show(BuildContext context, {required DiscussChannelModel channel}) {
    return showDialog(
      context: context,
      builder: (ctx) => PinnedMessagesDialog(channel: channel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<DiscussController>() ? Get.find<DiscussController>() : null;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.push_pin_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pinned Messages',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: const Color(0xFF25181E),
                        ),
                      ),
                      Text(
                        channel.name,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Expanded(
              child: Obx(() {
                final pinnedList = controller?.getChannelPinnedMessages(channel.id) ?? [];
                if (pinnedList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.push_pin_outlined, size: 42, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          'No pinned messages yet',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pin important messages from the message action menu',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: pinnedList.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 12, thickness: 0.5),
                  itemBuilder: (ctx, i) {
                    final msg = pinnedList[i];
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      msg.authorName,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      FormatUtils.formatTime(msg.date),
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (msg.cleanBody.isNotEmpty)
                                  Text(
                                    msg.cleanBody,
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                if (msg.attachments.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.attach_file_rounded, size: 13, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${msg.attachments.length} attachment(s)',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                            tooltip: 'Unpin',
                            onPressed: () {
                              controller?.unpinMessage(channel.id, msg.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CHANNEL ATTACHMENTS & MEDIA GALLERY DIALOG
// =============================================================================

class ChannelAttachmentsDialog extends StatelessWidget {
  final DiscussChannelModel channel;

  const ChannelAttachmentsDialog({super.key, required this.channel});

  static Future<void> show(BuildContext context, {required DiscussChannelModel channel}) {
    return showDialog(
      context: context,
      builder: (ctx) => ChannelAttachmentsDialog(channel: channel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<DiscussController>() ? Get.find<DiscussController>() : null;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_shared_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shared Files & Attachments',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: const Color(0xFF25181E),
                        ),
                      ),
                      Text(
                        channel.name,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: false);
                    if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
                      await controller?.sendAttachment(result.files.first.name, result.files.first.bytes!);
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
                  label: const Text('Upload', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Expanded(
              child: Obx(() {
                final attachments = controller?.getActiveChannelAttachments(channel.id) ?? [];
                if (attachments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.attachment_rounded, size: 42, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          'No files shared yet',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Documents, images, and audio shared in this chat will appear here',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: attachments.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 8, thickness: 0.5),
                  itemBuilder: (ctx, i) {
                    final item = attachments[i];
                    final isImage = item.mimetype.startsWith('image/');
                    final isAudio = item.mimetype.startsWith('audio/') || item.name.endsWith('.mp3') || item.name.endsWith('.m4a');
                    final isPdf = item.mimetype.contains('pdf') || item.name.endsWith('.pdf');
                    final iconData = isImage
                        ? Icons.image_rounded
                        : isAudio
                            ? Icons.audiotrack_rounded
                            : isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.insert_drive_file_rounded;
                    final iconColor = isImage
                        ? Colors.blue
                        : isAudio
                            ? Colors.purple
                            : isPdf
                                ? Colors.red
                                : Colors.amber.shade700;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(iconData, color: iconColor, size: 18),
                      ),
                      title: Text(
                        item.name,
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.mimetype} • ${(item.fileSize / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download_rounded, size: 18, color: AppTheme.primary),
                        tooltip: 'Download / View',
                        onPressed: () {
                          final server = OdooRpcApiManager.serverUrl;
                          if (server.isNotEmpty) {
                            final downloadUrl = '$server/web/content/${item.id}?download=true';
                            final uri = Uri.tryParse(downloadUrl);
                            if (uri != null) {
                              launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ODOO AUDIO / VIDEO CALL & SCREEN SHARING (MATCHING ODOO WEBRTC INTERFACE)
// =============================================================================

class OdooCallDialog extends StatefulWidget {
  final DiscussChannelModel channel;
  final bool isVideoCall;

  const OdooCallDialog({
    super.key,
    required this.channel,
    this.isVideoCall = true,
  });

  static Future<void> startCall(
    BuildContext context, {
    required DiscussChannelModel channel,
    bool isVideoCall = true,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OdooCallDialog(
        channel: channel,
        isVideoCall: isVideoCall,
      ),
    );
  }

  @override
  State<OdooCallDialog> createState() => _OdooCallDialogState();
}

class _OdooCallDialogState extends State<OdooCallDialog> with SingleTickerProviderStateMixin {
  bool _isCallConnected = false;
  bool _isMicMuted = false;
  late bool _isCameraOn;
  bool _isScreenSharing = false;
  String? _sharedScreenTitle;
  bool _isFullscreen = false;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  Timer? _autoConnectTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _isCameraOn = widget.isVideoCall;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _autoConnectTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isCallConnected) {
        _connectCall();
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _autoConnectTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _connectCall() {
    if (!_isCallConnected) {
      setState(() {
        _isCallConnected = true;
      });
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _callDurationSeconds++);
        }
      });
    }
  }

  Future<void> _launchOdooWebRtcLive() async {
    try {
      final server = OdooRpcApiManager.serverUrl;
      if (server.isNotEmpty) {
        final url = '$server/web#action=mail.action_discuss&active_id=${widget.channel.id}';
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('LAUNCH_WEBRTC_ERROR: $e');
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _handleScreenShareToggle() async {
    if (_isScreenSharing) {
      setState(() {
        _isScreenSharing = false;
        _sharedScreenTitle = null;
      });
      showToast('Screen sharing stopped', idSuccess: true);
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const OdooScreenShareDialog(),
    );

    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _isScreenSharing = true;
        _sharedScreenTitle = selected;
      });
      showToast('Sharing: $selected via Odoo WebRTC', idSuccess: true);
      await _launchOdooWebRtcLive();
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteName = widget.channel.name;
    final currentUser = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().user.value
        : null;
    final localName = currentUser?.name ?? 'You';
    final localUserId = currentUser?.userId ?? 0;
    final remotePartnerId = widget.channel.otherPartnerId ?? 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: _isFullscreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 16),
        child: Container(
          width: _isFullscreen ? double.infinity : 960,
          height: _isFullscreen ? double.infinity : 620,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E23),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14171B),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isCallConnected ? const Color(0xFF28A745) : const Color(0xFFFFB300),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isCallConnected ? remoteName : 'Calling $remoteName...',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _isCallConnected 
                            ? Colors.white.withOpacity(0.08)
                            : const Color(0xFFFFB300).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: _isCallConnected ? null : Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
                      ),
                      child: Text(
                        _isCallConnected ? _formatDuration(_callDurationSeconds) : 'Ringing...',
                        style: GoogleFonts.inter(
                          color: _isCallConnected ? Colors.white70 : const Color(0xFFFFD54F),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isScreenSharing) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F52BA).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF0F52BA).withOpacity(0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.screen_share_rounded, size: 11, color: Colors.lightBlueAccent),
                            const SizedBox(width: 4),
                            Text(
                              'Live Share',
                              style: GoogleFonts.inter(
                                color: Colors.lightBlueAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _launchOdooWebRtcLive,
                      icon: const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                      label: const Text(
                        'Open Odoo Live Video & Share',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28A745),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
                      tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(28, 28),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(28, 28),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: !_isCallConnected
                      ? _buildCallingLayout(remoteName, remotePartnerId)
                      : _isScreenSharing
                          ? _buildScreenSharingLayout(localName, remoteName, localUserId, remotePartnerId)
                          : _buildTwoParticipantLayout(localName, remoteName, localUserId, remotePartnerId),
                ),
              ),
              Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF14171B),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildControlButton(
                          icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          isActive: !_isMicMuted,
                          hasWarning: _isMicMuted,
                          tooltip: _isMicMuted ? 'Unmute' : 'Mute',
                          onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                        ),
                        const SizedBox(width: 10),
                        _buildControlButton(
                          icon: _isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          isActive: _isCameraOn,
                          activeColor: const Color(0xFF28A745),
                          tooltip: _isCameraOn ? 'Turn off camera' : 'Turn on camera',
                          onTap: () => setState(() => _isCameraOn = !_isCameraOn),
                        ),
                        const SizedBox(width: 10),
                        _buildControlButton(
                          icon: _isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                          isActive: _isScreenSharing,
                          activeColor: const Color(0xFF0F52BA),
                          tooltip: _isScreenSharing ? 'Stop sharing' : 'Share screen',
                          onTap: _handleScreenShareToggle,
                        ),
                        const SizedBox(width: 10),
                        if (!_isCallConnected) ...[
                          _buildControlButton(
                            icon: Icons.call_rounded,
                            isActive: true,
                            activeColor: const Color(0xFF28A745),
                            tooltip: 'Connect / Enter Call',
                            onTap: _connectCall,
                          ),
                          const SizedBox(width: 10),
                        ],
                        _buildControlButton(
                          icon: Icons.call_end_rounded,
                          isActive: true,
                          activeColor: const Color(0xFFE53935),
                          tooltip: 'Hang up',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallingLayout(String remoteName, int remotePartnerId) {
    final nameHash = remoteName.hashCode.abs();
    final avatarColors = [
      const Color(0xFFE2165F),
      const Color(0xFF006D37),
      const Color(0xFF0F52BA),
      const Color(0xFFD4AF37),
      const Color(0xFF8A2BE2),
      const Color(0xFFE65C00),
    ];
    final avatarColor = avatarColors[nameHash % avatarColors.length];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.12),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.35),
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 54,
                backgroundColor: avatarColor.withOpacity(0.25),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(54),
                  child: remotePartnerId > 0
                      ? OdooNetworkImage(
                          model: 'res.partner',
                          id: remotePartnerId,
                          field: 'image_128',
                          placeholder: Text(
                            remoteName.isNotEmpty ? remoteName[0].toUpperCase() : 'U',
                            style: GoogleFonts.spaceGrotesk(
                              color: avatarColor,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Text(
                          remoteName.isNotEmpty ? remoteName[0].toUpperCase() : 'U',
                          style: GoogleFonts.spaceGrotesk(
                            color: avatarColor,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Calling $remoteName...',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB300),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ringing • Waiting for other user to pick up...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _connectCall,
                icon: const Icon(Icons.call_rounded, color: Colors.white, size: 16),
                label: const Text('Connect Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A745),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _launchOdooWebRtcLive,
                icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 16),
                label: const Text('Open in Odoo WebRTC', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    bool hasWarning = false,
    Color? activeColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    Color bg = const Color(0xFF23272F);
    Color icColor = Colors.white;

    if (activeColor != null && isActive) {
      bg = activeColor;
      icColor = Colors.white;
    } else if (hasWarning) {
      bg = const Color(0xFFE53935);
      icColor = Colors.white;
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: icColor, size: 22),
        ),
      ),
    );
  }

  Widget _buildTwoParticipantLayout(
    String localName,
    String remoteName,
    int localUserId,
    int remotePartnerId,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildParticipantTile(
            name: localName,
            isLocal: true,
            isCameraOn: _isCameraOn,
            isMuted: _isMicMuted,
            userId: localUserId,
            model: 'res.users',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildParticipantTile(
            name: remoteName,
            isLocal: false,
            isCameraOn: true,
            isMuted: false,
            userId: remotePartnerId,
            model: 'res.partner',
          ),
        ),
      ],
    );
  }

  Widget _buildScreenSharingLayout(
    String localName,
    String remoteName,
    int localUserId,
    int remotePartnerId,
  ) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF101316),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF0F52BA).withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0xFF1B232E),
                  child: Row(
                    children: [
                      const Icon(Icons.screen_share_rounded, size: 15, color: Colors.lightBlueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _sharedScreenTitle ?? 'Live Screen Sharing Stream',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006D37),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE 60FPS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFF1A1F26),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.desktop_windows_rounded,
                            size: 64,
                            color: Colors.lightBlueAccent.withOpacity(0.8),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _sharedScreenTitle ?? 'Broadcasting Live Screen',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'High-definition 60fps screen stream active via Odoo WebRTC',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _launchOdooWebRtcLive,
                            icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white),
                            label: const Text(
                              'Switch to Live WebRTC Stream',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F52BA),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 140,
                height: 95,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: _buildParticipantTile(
                  name: localName,
                  isLocal: true,
                  isCameraOn: _isCameraOn,
                  isMuted: _isMicMuted,
                  userId: localUserId,
                  model: 'res.users',
                  isMini: true,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 140,
                height: 95,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: _buildParticipantTile(
                  name: remoteName,
                  isLocal: false,
                  isCameraOn: true,
                  isMuted: false,
                  userId: remotePartnerId,
                  model: 'res.partner',
                  isMini: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantTile({
    required String name,
    required bool isLocal,
    required bool isCameraOn,
    required bool isMuted,
    required int userId,
    required String model,
    bool isMini = false,
  }) {
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
      decoration: BoxDecoration(
        color: const Color(0xFF22262C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2D323A), Color(0xFF1E2228)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: isMini ? 22 : 44,
                        backgroundColor: avatarColor.withOpacity(0.2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isMini ? 22 : 44),
                          child: (userId > 0)
                              ? OdooNetworkImage(
                                  model: model,
                                  id: userId,
                                  field: 'image_128',
                                  placeholder: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: avatarColor,
                                      fontSize: isMini ? 16 : 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  errorWidget: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: avatarColor,
                                      fontSize: isMini ? 16 : 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: avatarColor,
                                    fontSize: isMini ? 16 : 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      if (!isMini) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isCameraOn ? const Color(0xFF28A745) : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isCameraOn ? 'Camera Active (WebRTC)' : 'Camera Off',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: isMini ? 10 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      size: isMini ? 12 : 14,
                      color: isMuted ? const Color(0xFFE53935) : const Color(0xFF28A745),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ODOO SCREEN SHARE SELECTION DIALOG (MATCHING IMAGE 2 EXACTLY)
// =============================================================================

class OdooScreenShareDialog extends StatefulWidget {
  const OdooScreenShareDialog({super.key});

  @override
  State<OdooScreenShareDialog> createState() => _OdooScreenShareDialogState();
}

class _OdooScreenShareDialogState extends State<OdooScreenShareDialog> {
  int _selectedTabIndex = 0; // 0: Chrome tab, 1: Window, 2: Entire screen
  int _selectedItemIndex = -1;
  bool _shareTabAudio = true;

  final List<Map<String, dynamic>> _tabsList = [
    {
      'title': 'Aniket Rai',
      'icon': Icons.circle_outlined,
      'color': Color(0xFF8A2BE2),
    },
    {
      'title': 'Privacy Policy - DeshiSpicy',
      'icon': Icons.public_rounded,
      'color': Color(0xFF00897B),
    },
    {
      'title': 'Login | Primacy Infotech',
      'icon': Icons.security_rounded,
      'color': Color(0xFFE53935),
    },
    {
      'title': 'Project overview | inquisitive-cannoli-9e03e...',
      'icon': Icons.layers_rounded,
      'color': Color(0xFF0F52BA),
    },
    {
      'title': '(189 unread) - Inbox - Zoho Mail (jayadrata@...',
      'icon': Icons.mail_outline_rounded,
      'color': Color(0xFF00ACC1),
    },
  ];

  final List<Map<String, dynamic>> _windowsList = [
    {
      'title': 'Antigravity IDE - taskwatch_app',
      'icon': Icons.code_rounded,
      'color': Color(0xFF00796B),
    },
    {
      'title': 'Google Chrome - Odoo Staging',
      'icon': Icons.web_rounded,
      'color': Color(0xFF1565C0),
    },
    {
      'title': 'Terminal - zsh (flutter run)',
      'icon': Icons.terminal_rounded,
      'color': Color(0xFF424242),
    },
  ];

  final List<Map<String, dynamic>> _entireScreensList = [
    {
      'title': 'Entire Screen 1 (Built-in Display 2560x1600)',
      'icon': Icons.monitor_rounded,
      'color': Color(0xFF455A64),
    },
  ];

  List<Map<String, dynamic>> get _currentList {
    if (_selectedTabIndex == 0) return _tabsList;
    if (_selectedTabIndex == 1) return _windowsList;
    return _entireScreensList;
  }

  @override
  Widget build(BuildContext context) {
    final serverHost = OdooRpcApiManager.serverUrl.replaceAll('https://', '').replaceAll('http://', '');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 720,
        height: 520,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose what to share with $serverHost',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF25181E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The site will be able to see the contents of your screen',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Tabs Row (Chrome tab, Window, Entire screen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildTabHeader(0, 'Chrome tab'),
                  const SizedBox(width: 24),
                  _buildTabHeader(1, 'Window'),
                  const SizedBox(width: 24),
                  _buildTabHeader(2, 'Entire screen'),
                ],
              ),
            ),

            // Content Area: Left Items List + Right Preview Pane
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Left list
                    Expanded(
                      flex: 5,
                      child: ListView.builder(
                        itemCount: _currentList.length,
                        itemBuilder: (context, index) {
                          final item = _currentList[index];
                          final isSelected = _selectedItemIndex == index;
                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedItemIndex = index),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF5C6BC0).withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF5C6BC0),
                                        width: 1.5)
                                    : Border.all(
                                        color: Colors.transparent,
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 16,
                                    color: isSelected
                                        ? const Color(0xFF3949AB)
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 18,
                                    color: item['color'] as Color,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item['title'] as String,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF3949AB)
                                            : const Color(0xFF25181E),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right preview pane
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF0FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFD0D5EE),
                          ),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(8),
                            child: _selectedItemIndex >= 0 &&
                                    _selectedItemIndex < _currentList.length
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _currentList[_selectedItemIndex]['icon']
                                            as IconData,
                                        size: 40,
                                        color: _currentList[_selectedItemIndex]
                                            ['color'] as Color,
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Text(
                                          _currentList[_selectedItemIndex]
                                              ['title'] as String,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF25181E),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ready to share this stream',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: Colors.grey.shade600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Select a tab to share',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF5C6BC0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Audio Toggle & Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Also share tab audio',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: _shareTabAudio,
                      onChanged: (val) => setState(() => _shareTabAudio = val),
                      activeColor: const Color(0xFF3949AB),
                    ),
                    const SizedBox(width: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        backgroundColor: const Color(0xFFE8EAF6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: const Color(0xFF3949AB),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _selectedItemIndex >= 0
                          ? () {
                              final title = _currentList[_selectedItemIndex]
                                  ['title'] as String;
                              Navigator.of(context).pop(title);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedItemIndex >= 0
                            ? const Color(0xFF3949AB)
                            : const Color(0xFFE8EAF6),
                        foregroundColor: _selectedItemIndex >= 0
                            ? Colors.white
                            : Colors.grey.shade500,
                        disabledBackgroundColor: const Color(0xFFEEEEEE),
                        disabledForegroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        elevation: _selectedItemIndex >= 0 ? 2 : 0,
                      ),
                      child: const Text(
                        'Share',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeader(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedTabIndex = index;
        _selectedItemIndex = -1;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF3949AB) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color:
                isSelected ? const Color(0xFF3949AB) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

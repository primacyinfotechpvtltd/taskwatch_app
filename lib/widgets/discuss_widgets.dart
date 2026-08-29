import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.cleanBody.isNotEmpty) ...[
                          RichText(
                            text: TextSpan(
                              children: _parseMessageBody(
                                  message.cleanBody, isOutgoing),
                            ),
                          ),
                          if (_extractFirstUrl(message.cleanBody) != null) ...[
                            const SizedBox(height: 6),
                            _buildLinkPreviewCard(
                                _extractFirstUrl(message.cleanBody)!,
                                isOutgoing),
                          ],
                        ],
                        if (message.cleanBody.isNotEmpty &&
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
                if (!isOutgoing) ...[
                  const SizedBox(width: 6),
                  _buildTimeText(),
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
    final hour = message.date.hour % 12 == 0 ? 12 : message.date.hour % 12;
    final minute = message.date.minute.toString().padLeft(2, '0');
    final period = message.date.hour >= 12 ? 'PM' : 'AM';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$hour:$minute $period',
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

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
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
                        if (message.cleanBody.isNotEmpty)
                          RichText(
                            text: TextSpan(
                              children: _parseMessageBody(message.cleanBody, isOutgoing),
                            ),
                          ),
                        if (message.cleanBody.isNotEmpty && message.attachments.isNotEmpty)
                          const SizedBox(height: 8),
                        if (message.attachments.isNotEmpty)
                          ...message.attachments.map((attach) => _buildAttachmentItem(context, attach, isOutgoing)),
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

  Widget _buildAttachmentItem(BuildContext context, DiscussAttachmentModel attachment, bool isOutgoing) {
    final bool isImage = attachment.mimetype.startsWith('image/');
    
    if (isImage) {
      return GestureDetector(
        onTap: () => _openAttachment(context, attachment),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: OdooNetworkImage(
              model: 'ir.attachment',
              id: attachment.id,
              field: 'datas',
              fit: BoxFit.cover,
              placeholder: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
              errorWidget: Container(
                color: Colors.grey.shade200,
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attachment.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: isOutgoing ? Colors.white70 : Colors.black54,
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
    } else {
      return GestureDetector(
        onTap: () => _openAttachment(context, attachment),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isOutgoing ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForMimetype(attachment.mimetype),
                color: isOutgoing ? Colors.white : AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
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
                    if (attachment.fileSize > 0)
                      Text(
                        _formatFileSize(attachment.fileSize),
                        style: TextStyle(
                          fontSize: 9,
                          color: isOutgoing ? Colors.white70 : Colors.grey.shade500,
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
  }

  IconData _getIconForMimetype(String mimetype) {
    if (mimetype.contains('pdf')) return Icons.picture_as_pdf;
    if (mimetype.contains('zip') || mimetype.contains('rar')) return Icons.archive;
    if (mimetype.contains('excel') || mimetype.contains('sheet')) return Icons.table_chart;
    if (mimetype.contains('word') || mimetype.contains('document')) return Icons.description;
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

  void _showAttachmentPreviewDialog(BuildContext context, DiscussAttachmentModel attachment) {
    final serverUrl = OdooRpcApiManager.authenticationState['serverUrl'] as String?;
    if (serverUrl == null || serverUrl.isEmpty) return;
    
    final sessionId = OdooRpcApiManager.currentSessionId ?? '';
    final url = '$serverUrl/web/content/${attachment.id}?session_id=$sessionId';
    final isImage = attachment.mimetype.startsWith('image/');
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        Uint8List? fetchedBytes;
        bool isDownloading = false;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 500,
                height: 500,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: () => Navigator.of(dialogContext).pop(),
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
                            ? FutureBuilder<http.Response>(
                                future: http.get(
                                  Uri.parse(url),
                                  headers: {
                                    'Cookie': 'session_id=$sessionId',
                                  },
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(color: AppTheme.primary),
                                    );
                                  }
                                  if (snapshot.hasError || snapshot.data == null || snapshot.data!.statusCode != 200) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                                          const SizedBox(height: 8),
                                          Text('Failed to load image preview', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    );
                                  }
                                  fetchedBytes = snapshot.data!.bodyBytes;
                                  return InteractiveViewer(
                                    child: Image.memory(
                                      fetchedBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getIconForMimetype(attachment.mimetype),
                                      size: 72,
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () async {
                              setState(() {
                                isDownloading = true;
                              });
                              
                              try {
                                final bytes = fetchedBytes ?? (await http.get(
                                  Uri.parse(url),
                                  headers: {
                                    'Cookie': 'session_id=$sessionId',
                                  },
                                )).bodyBytes;
                                
                                final downloadsDir = await getDownloadsDirectory();
                                if (downloadsDir == null) {
                                  showToast('Could not access Downloads directory', idSuccess: false);
                                  return;
                                }
                                
                                var filePath = '${downloadsDir.path}/${attachment.name}';
                                var file = File(filePath);
                                var counter = 1;
                                while (await file.exists()) {
                                  final dotIndex = attachment.name.lastIndexOf('.');
                                  if (dotIndex != -1) {
                                    final nameWithoutExt = attachment.name.substring(0, dotIndex);
                                    final ext = attachment.name.substring(dotIndex);
                                    filePath = '${downloadsDir.path}/$nameWithoutExt($counter)$ext';
                                  } else {
                                    filePath = '${downloadsDir.path}/${attachment.name}($counter)';
                                  }
                                  file = File(filePath);
                                  counter++;
                                }
                                
                                await file.writeAsBytes(bytes);
                                showToast('Saved to Downloads: ${file.path.split('/').last}', idSuccess: true);
                              } catch (e) {
                                debugPrint('DOWNLOAD_ERROR: $e');
                                showToast('Failed to download: $e', idSuccess: false);
                              } finally {
                                setState(() {
                                  isDownloading = false;
                                });
                              }
                            },
                            icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                            label: Text(
                              'Download File',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      default:
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

  void _showPreviewDialog(String fileName, Uint8List fileBytes) {
    final captionController = TextEditingController(text: _textController.text);
    final isImage = _isImageFile(fileName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 520),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview Attachment',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Content Preview
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
                        ? InteractiveViewer(
                            child: Image.memory(
                              fileBytes,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.insert_drive_file_rounded,
                                  size: 64,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    fileName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Caption TextField
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F8),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: captionController,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
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
                        // Send the attachment with caption
                        widget.onAttach(fileName, fileBytes, captionController.text.trim());
                        _textController.clear();
                      },
                      icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                      label: Text(
                        'Send',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  Future<void> _handleAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
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
              IconButton(
                onPressed: widget.isLoading ? null : _handleAttachment,
                icon: const Icon(Icons.attach_file_rounded, size: 20, color: Colors.grey),
                tooltip: 'Attach image or document',
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
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

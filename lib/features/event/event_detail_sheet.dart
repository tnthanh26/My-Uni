import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_uni/models/event_model.dart';
import 'package:my_uni/utils/base64_image_cache.dart';
import 'package:my_uni/widgets/app_action_dialogs.dart';
import 'create_personal_event_page.dart';
import 'package:my_uni/features/services/notification_service.dart';

class EventDetailSheet {
  static void show(BuildContext context, EventModel ev, {VoidCallback? onRefresh}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final bool isPast = ev.dateTime.isBefore(now);
    final String formattedDate = DateFormat('dd/MM/yyyy • HH:mm').format(ev.dateTime);
    final String? endTimeStr = ev.endDateTime != null
        ? DateFormat('HH:mm').format(ev.endDateTime!)
        : null;
    final String displayTime = endTimeStr != null
        ? '$formattedDate - $endTimeStr'
        : formattedDate;

    final Color sheetColor = isDarkMode ? const Color(0xFF1E1E2C) : Colors.white;
    final Color primaryTextColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final Color secondaryTextColor = isDarkMode ? Colors.white60 : const Color(0xFF64748B);
    final Color borderColor = isDarkMode ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    const Color primaryBlue = Color(0xFF457EC0);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Image Banner if available
              if (ev.imageUrl != null && ev.imageUrl!.trim().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Base64ImageCache.buildSmartImage(
                    imageUrl: ev.imageUrl!,
                    height: 160,
                    width: double.infinity,
                    fallbackAsset: 'assets/images/news.png',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Badges & Close Button Row
              Row(
                children: [
                  // Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ev.isFromFacultyEvent
                          ? (isDarkMode ? const Color(0xFF3B82F6).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
                          : (isDarkMode ? const Color(0xFF8B5CF6).withValues(alpha: 0.2) : const Color(0xFFF5F3FF)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ev.isFromFacultyEvent
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                            : const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      ev.isFromFacultyEvent ? 'SỰ KIỆN KHOA' : 'SỰ KIỆN CÁ NHÂN',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ev.isFromFacultyEvent ? const Color(0xFF2563EB) : const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPast
                          ? (isDarkMode ? Colors.white10 : const Color(0xFFF1F5F9))
                          : (isDarkMode ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFECFDF5)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPast
                            ? Colors.grey.withValues(alpha: 0.3)
                            : const Color(0xFF10B981).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isPast ? 'ĐÃ DIỄN RA' : 'SẮP DIỄN RA',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPast ? secondaryTextColor : const Color(0xFF059669),
                      ),
                    ),
                  ),

                  if (ev.isOnline) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFFA855F7).withValues(alpha: 0.2) : const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_rounded, size: 12, color: Color(0xFF9333EA)),
                          SizedBox(width: 4),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9333EA),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(
                      Icons.close_rounded,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                ev.title,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // Faculty / Organizer tile
              _buildOrganizerTile(ev, isDarkMode, primaryTextColor, borderColor),
              const SizedBox(height: 16),

              // Warning box if original event deleted by BTC
              FutureBuilder<bool>(
                future: _checkOriginalEventExists(ev.facultyEventId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == false) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sự kiện gốc này đã bị hủy hoặc xóa khỏi hệ thống bởi Ban tổ chức.',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Details Rows
              _buildDetailRow(
                Icons.access_time_filled_rounded,
                'Thời gian',
                displayTime,
                primaryTextColor,
                secondaryTextColor,
              ),

              _buildDetailRow(
                ev.isOnline ? Icons.videocam_rounded : Icons.location_on_rounded,
                'Vị trí',
                ev.location.trim().isNotEmpty ? ev.location : (ev.isOnline ? 'Trực tuyến (Online)' : 'Chưa cập nhật'),
                primaryTextColor,
                secondaryTextColor,
              ),

              // CONTACT INFO SECTION (ALWAYS DISPLAYED & DYNAMICALLY FETCHED IF NEEDED)
              _buildContactDetailRow(ev, isDarkMode, primaryTextColor, secondaryTextColor),

              if (ev.reminder != 'Không' &&
                  ev.reminder != 'Đặt lời nhắc' &&
                  ev.reminder.trim().isNotEmpty)
                _buildDetailRow(
                  Icons.notifications_active_rounded,
                  'Nhắc nhở',
                  ev.reminder,
                  primaryTextColor,
                  secondaryTextColor,
                ),

              // Full Description Box
              if (ev.description.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Mô tả chi tiết',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: SelectableText(
                    ev.description.trim(),
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      height: 1.5,
                      color: primaryTextColor,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Online Link Button
              if (ev.onlineUrl != null && ev.onlineUrl!.trim().isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchURL(ev.onlineUrl!),
                    icon: const Icon(Icons.videocam_rounded, size: 18),
                    label: const Text(
                      'Tham gia Trực tuyến',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Source Article Link Button
              if (ev.sourceArticleUrl != null &&
                  ev.sourceArticleUrl!.trim().isNotEmpty &&
                  ev.sourceArticleUrl!.trim() != ev.onlineUrl?.trim()) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchURL(ev.sourceArticleUrl!),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text(
                      'Xem bài viết gốc',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Manage Action Buttons: Edit & Delete
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreatePersonalEventPage(event: ev),
                          ),
                        );
                        if (onRefresh != null) onRefresh();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Chỉnh sửa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBlue,
                        side: const BorderSide(color: primaryBlue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await AppActionDialogs.showConfirmDialog(
                          context: context,
                          title: 'Xóa sự kiện?',
                          message: 'Bạn có chắc chắn muốn xóa sự kiện "${ev.title}" không?',
                          confirmText: 'Xóa',
                        );
                        if (confirm == true) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _deletePersonalEvent(ev);
                          if (onRefresh != null) onRefresh();
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Xóa sự kiện'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildOrganizerTile(
      EventModel ev, bool isDarkMode, Color primaryText, Color border) {
    final String displayFaculty = ev.facultyName?.trim().isNotEmpty == true
        ? ev.facultyName!.trim()
        : (ev.isFromFacultyEvent ? 'Khoa / Đơn vị HCMUS' : 'Sự kiện cá nhân');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.school_rounded,
            size: 20,
            color: Color(0xFF457EC0),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayFaculty,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildContactDetailRow(
      EventModel ev, bool isDarkMode, Color primaryText, Color secondaryText) {
    final String? directContact = ev.contact?.trim();

    if (directContact != null && directContact.isNotEmpty) {
      return _buildDetailRow(
        Icons.contact_phone_rounded,
        'Liên hệ / BTC',
        directContact,
        primaryText,
        secondaryText,
      );
    }

    // If contact is empty but facultyEventId exists, fetch original faculty event
    if (ev.facultyEventId != null && ev.facultyEventId!.trim().isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('faculty_events')
            .doc(ev.facultyEventId!.trim())
            .get(),
        builder: (context, snapshot) {
          String contactVal = ev.facultyName?.trim().isNotEmpty == true
              ? ev.facultyName!.trim()
              : 'Ban tổ chức Khoa';

          if (snapshot.hasData && snapshot.data?.data() != null) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final fetchedContact = (data['contact'] ??
                    data['organizer'] ??
                    data['organizerName'] ??
                    data['contactInfo'] ??
                    data['facultyName'] ??
                    data['department'] ??
                    data['phone'] ??
                    data['email'])
                ?.toString()
                .trim();
            if (fetchedContact != null && fetchedContact.isNotEmpty) {
              contactVal = fetchedContact;
            }
          }

          return _buildDetailRow(
            Icons.contact_phone_rounded,
            'Liên hệ / BTC',
            contactVal,
            primaryText,
            secondaryText,
          );
        },
      );
    }

    // Fallback if facultyName is present
    if (ev.facultyName != null && ev.facultyName!.trim().isNotEmpty) {
      return _buildDetailRow(
        Icons.contact_phone_rounded,
        'Liên hệ / BTC',
        ev.facultyName!.trim(),
        primaryText,
        secondaryText,
      );
    }

    // Default fallback for pure personal events without explicit contact
    return _buildDetailRow(
      Icons.contact_phone_rounded,
      'Liên hệ / BTC',
      'Chưa cập nhật thông tin liên hệ',
      primaryText,
      secondaryText,
    );
  }

  static Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color primaryText,
    Color secondaryText,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF457EC0)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool> _checkOriginalEventExists(String? facultyEventId) async {
    if (facultyEventId == null || facultyEventId.trim().isEmpty) return true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('faculty_events')
          .doc(facultyEventId.trim())
          .get();
      return doc.exists;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _launchURL(String urlString) async {
    final cleanUrl = urlString.trim();
    if (cleanUrl.isEmpty) return;
    final Uri url = Uri.parse(cleanUrl);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static Future<void> _deletePersonalEvent(EventModel ev) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('personal_events')
        .doc(ev.id);

    final doc = await ref.get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['notificationIds'] is List) {
        final List ids = data['notificationIds'];
        for (var id in ids) {
          if (id is int) await NotificationService.cancelNotification(id);
        }
      }
    } else if (ev.notificationId != null) {
      await NotificationService.cancelNotification(ev.notificationId!);
    }

    await ref.delete();

    final String targetInterestedId = (ev.facultyEventId != null && ev.facultyEventId!.isNotEmpty)
        ? ev.facultyEventId!
        : ev.id;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('interested_events')
        .doc(targetInterestedId)
        .delete();

    if (ev.id != targetInterestedId) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('interested_events')
          .doc(ev.id)
          .delete();
    }
  }
}

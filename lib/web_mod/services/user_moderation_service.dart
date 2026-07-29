import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'mod_log_service.dart';
import 'mod_notification_service.dart';

class UserModerationService {
  static Future<void> suspendUser({
    required String uid,
    required Map<String, dynamic> data,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'status': 'suspended',
      'isBanned': true,
      'banReason': reason,
      'lastBanReason': reason,
      'violationCount': FieldValue.increment(1),
      'suspensionCount': FieldValue.increment(1),
      'lastViolationAt': FieldValue.serverTimestamp(),
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': FirebaseAuth.instance.currentUser?.uid,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await ModLogService.addUserActionLog(
      targetUserId: uid,
      targetUserEmail: data['email'] ?? '',
      action: 'suspend',
      reason: reason,
    );

    await ModNotificationService.sendUserNotification(
      userId: uid,
      title: "Tài khoản của bạn đã bị khóa",
      content: "Lý do: $reason",
      type: "account_suspended",
    );
  }

  static Future<void> restoreUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'status': 'active',
      'isBanned': false,
      'banReason': '',
      'bannedAt': FieldValue.delete(),
      'bannedBy': FieldValue.delete(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'restoredAt': FieldValue.serverTimestamp(),
      'restoredBy': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));

    await ModLogService.addUserActionLog(
      targetUserId: uid,
      targetUserEmail: data['email'] ?? '',
      action: 'restore',
      reason: 'Khôi phục tài khoản',
    );

    await ModNotificationService.sendUserNotification(
      userId: uid,
      title: "Tài khoản của bạn đã được khôi phục",
      content: "Bạn có thể tiếp tục sử dụng MyUni bình thường.",
      type: "account_restored",
    );
  }

  static Future<void> approveVerification({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isVerified': true,
      'verificationStatus': 'approved',
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': FirebaseAuth.instance.currentUser?.uid,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await ModLogService.addUserActionLog(
      targetUserId: uid,
      targetUserEmail: data['email'] ?? '',
      action: 'approve_verification',
      reason: 'Phê duyệt xác thực hồ sơ sinh viên',
    );

    await ModNotificationService.sendUserNotification(
      userId: uid,
      title: "Hồ sơ của bạn đã được xác thực!",
      content: "Ban Quản trị đã duyệt thông tin sinh viên của bạn. Bạn có thể sử dụng đầy đủ các tính năng trên MyUni.",
      type: "verification_approved",
    );
  }

  static Future<void> rejectVerification({
    required String uid,
    required Map<String, dynamic> data,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isVerified': false,
      'verificationStatus': 'rejected',
      'rejectionReason': reason,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await ModLogService.addUserActionLog(
      targetUserId: uid,
      targetUserEmail: data['email'] ?? '',
      action: 'reject_verification',
      reason: reason,
    );

    await ModNotificationService.sendUserNotification(
      userId: uid,
      title: "Xác thực hồ sơ bị từ chối",
      content: "Lý do: $reason",
      type: "verification_rejected",
    );
  }

  static Future<void> deleteUserAccount({
    required String uid,
    required Map<String, dynamic> data,
    required String reason,
  }) async {
    await ModLogService.addUserActionLog(
      targetUserId: uid,
      targetUserEmail: data['email'] ?? '',
      action: 'delete_user_account',
      reason: reason,
    );
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
  }
}
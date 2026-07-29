import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Tạo ID phòng chat cố định theo thứ tự 2 User ID (ví dụ: "uid1_uid2")
  static String generateRoomId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Lấy hoặc tạo mới phòng chat giữa User hiện tại và Target User
  Future<String> getOrCreateChatRoom(
    String targetUserId, {
    String? targetName,
    String? targetPhoto,
  }) async {
    final myUid = currentUserId;
    if (myUid == null) throw Exception('Vui lòng đăng nhập để nhắn tin');
    final cleanTargetId = targetUserId.trim();
    if (cleanTargetId.isEmpty) throw Exception('Thông tin người dùng không hợp lệ');
    if (myUid == cleanTargetId) throw Exception('Bạn không thể tự nhắn tin cho chính mình');

    final roomId = generateRoomId(myUid, cleanTargetId);
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);

    String myName = _auth.currentUser?.displayName ?? 'Sinh viên';
    String myPhoto = _auth.currentUser?.photoURL ?? '';
    try {
      final myDoc = await _firestore.collection('users').doc(myUid).get();
      if (myDoc.exists) {
        final myData = myDoc.data() ?? {};
        myName = myData['displayName'] ?? myData['name'] ?? myName;
        myPhoto = myData['photoURL'] ?? myData['avatar'] ?? myPhoto;
      }
    } catch (e) {
      debugPrint("Fetch my user profile error: $e");
    }

    String resolvedTargetName = targetName ?? 'Sinh viên';
    String resolvedTargetPhoto = targetPhoto ?? '';
    try {
      final targetDoc = await _firestore.collection('users').doc(cleanTargetId).get();
      if (targetDoc.exists) {
        final targetData = targetDoc.data() ?? {};
        resolvedTargetName = targetData['displayName'] ?? targetData['name'] ?? resolvedTargetName;
        resolvedTargetPhoto = targetData['photoURL'] ?? targetData['avatar'] ?? resolvedTargetPhoto;
      }
    } catch (e) {
      debugPrint("Fetch target user profile error: $e");
    }

    final participantNames = {
      myUid: myName.toString(),
      cleanTargetId: resolvedTargetName.toString(),
    };

    final participantPhotos = {
      myUid: myPhoto.toString(),
      cleanTargetId: resolvedTargetPhoto.toString(),
    };

    try {
      final roomDoc = await roomRef.get();
      if (!roomDoc.exists) {
        final newRoom = ChatRoom(
          id: roomId,
          participants: [myUid, cleanTargetId],
          participantNames: participantNames,
          participantPhotos: participantPhotos,
          lastMessage: 'Đã bắt đầu cuộc trò chuyện',
          lastMessageSenderId: myUid,
          lastMessageTime: DateTime.now(),
          unreadCounts: {myUid: 0, cleanTargetId: 0},
          updatedAt: DateTime.now(),
        );

        await roomRef.set(newRoom.toMap(), SetOptions(merge: true));
      } else {
        await roomRef.set({
          'participantNames': participantNames,
          'participantPhotos': participantPhotos,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Chat room doc fetch/set error: $e");
      await roomRef.set({
        'id': roomId,
        'participants': [myUid, cleanTargetId],
        'participantNames': participantNames,
        'participantPhotos': participantPhotos,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return roomId;
  }

  /// Stream danh sách các phòng chat của User hiện tại (Sắp xếp RAM để tránh composite index)
  Stream<List<ChatRoom>> getUserChatRoomsStream() {
    final myUid = currentUserId;
    if (myUid == null) return Stream.value([]);

    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList();
      list.sort((a, b) {
        final timeA = a.updatedAt ?? a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = b.updatedAt ?? b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
      return list;
    });
  }

  /// Stream danh sách tin nhắn trong 1 phòng chat
  Stream<List<ChatMessage>> getMessagesStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
    });
  }

  /// Gửi tin nhắn
  Future<void> sendMessage(
    String roomId,
    String text, {
    String? imageUrl,
    Map<String, String>? contactShare,
    Map<String, String>? fileShare,
  }) async {
    final myUid = currentUserId;
    if (myUid == null) throw Exception('Bạn chưa đăng nhập');

    final trimmedText = text.trim();
    if (trimmedText.isEmpty && imageUrl == null && contactShare == null && fileShare == null) return;

    final roomRef = _firestore.collection('chat_rooms').doc(roomId);

    // Tách otherUid từ roomId dạng "uid1_uid2" hoặc fetch từ roomDoc
    final roomParts = roomId.split('_');
    String otherUid = '';
    if (roomParts.length >= 2) {
      otherUid = roomParts.firstWhere((id) => id != myUid, orElse: () => '');
    }

    if (otherUid.isEmpty) {
      try {
        final roomDoc = await roomRef.get();
        if (roomDoc.exists) {
          final participants = List<String>.from(roomDoc.data()?['participants'] ?? []);
          otherUid = participants.firstWhere((id) => id != myUid, orElse: () => '');
        }
      } catch (e) {
        debugPrint("Error resolving target user ID: $e");
      }
    }

    String displayLastMsg = trimmedText;
    if (displayLastMsg.isEmpty && fileShare != null) {
      displayLastMsg = '[Tệp đính kèm: ${fileShare['fileName'] ?? 'Tài liệu'}]';
    } else if (displayLastMsg.isEmpty && contactShare != null) {
      displayLastMsg = '[Đã chia sẻ thông tin liên hệ]';
    } else if (displayLastMsg.isEmpty && imageUrl != null) {
      displayLastMsg = '[Hình ảnh]';
    }

    final messageRef = roomRef.collection('messages').doc();
    final now = DateTime.now();

    final message = ChatMessage(
      id: messageRef.id,
      senderId: myUid,
      text: trimmedText,
      imageUrl: imageUrl,
      contactShare: contactShare,
      fileShare: fileShare,
      timestamp: now,
    );

    // 1. Gửi bản ghi tin nhắn vào subcollection
    await messageRef.set(message.toMap());

    // 2. Cập nhật hoặc khởi tạo thông tin phòng chat
    Map<String, dynamic> roomUpdateData = {
      'id': roomId,
      'participants': (otherUid.isNotEmpty)
          ? [myUid, otherUid]
          : (roomParts.length >= 2 ? roomParts : FieldValue.arrayUnion([myUid])),
      'lastMessage': displayLastMsg,
      'lastMessageSenderId': myUid,
      'lastMessageTime': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    if (otherUid.isNotEmpty) {
      roomUpdateData['unreadCounts.$otherUid'] = FieldValue.increment(1);
    }

    try {
      await roomRef.set(roomUpdateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating room document: $e");
    }

    // 3. Gửi bản ghi thông báo hệ thống ngầm để kích hoạt Push Notification cho thiết bị nhận
    if (otherUid.isNotEmpty) {
      try {
        final senderDoc = await _firestore.collection('users').doc(myUid).get();
        final senderData = senderDoc.data();
        final senderName = (senderData?['displayName']?.toString().trim().isNotEmpty == true)
            ? senderData!['displayName']
            : 'Một sinh viên';

        await _firestore.collection('notifications').add({
          'userId': otherUid,
          'type': 'chat',
          'title': senderName,
          'content': displayLastMsg,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'roomId': roomId,
          'senderId': myUid,
          'senderName': senderName,
          'senderAvatar': senderData?['photoUrl'] ?? '',
        });
      } catch (e) {
        debugPrint("Error creating chat notification trigger: $e");
      }
    }
  }

  /// Đánh dấu đã đọc phòng chat
  Future<void> markRoomAsRead(String roomId) async {
    final myUid = currentUserId;
    if (myUid == null) return;

    try {
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'unreadCounts.$myUid': 0,
      });
    } catch (e) {
      debugPrint('Mark room as read error: $e');
    }
  }

  /// Thu hồi tin nhắn
  Future<void> recallMessage(String roomId, String messageId) async {
    final msgRef = _firestore.collection('chat_rooms').doc(roomId).collection('messages').doc(messageId);
    await msgRef.update({
      'isRecalled': true,
      'text': 'Tin nhắn đã thu hồi',
      'imageUrl': FieldValue.delete(),
      'contactShare': FieldValue.delete(),
      'fileShare': FieldValue.delete(),
    });

    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    try {
      await roomRef.update({
        'lastMessage': 'Tin nhắn đã thu hồi',
      });
    } catch (e) {
      debugPrint('Update room lastMessage error: $e');
    }
  }

  /// Chỉnh sửa nội dung tin nhắn
  Future<void> editMessage(String roomId, String messageId, String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    final msgRef = _firestore.collection('chat_rooms').doc(roomId).collection('messages').doc(messageId);
    await msgRef.update({
      'text': trimmed,
      'isEdited': true,
    });

    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    try {
      await roomRef.update({
        'lastMessage': trimmed,
      });
    } catch (e) {
      debugPrint('Update room lastMessage error: $e');
    }
  }

  /// Lấy danh sách liên hệ mạng xã hội đã lưu của user
  Future<Map<String, String>> getUserSocialContacts(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        if (data['socialContacts'] is Map) {
          return (data['socialContacts'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      }
    } catch (e) {
      debugPrint("Get social contacts error: $e");
    }
    return {};
  }

  /// Lưu danh sách liên hệ mạng xã hội của user
  Future<void> saveUserSocialContacts(String userId, Map<String, String> contacts) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'socialContacts': contacts,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Save social contacts error: $e");
    }
  }

  /// Lấy thông tin xác thực sinh viên từ Firestore
  Future<Map<String, dynamic>?> getStudentVerificationInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      return {
        'uid': userId,
        'displayName': data['displayName'] ?? data['name'] ?? 'Sinh viên',
        'email': data['email'] ?? '',
        'university': data['university'] ?? 'HCMUS - ĐH Khoa học Tự nhiên',
        'faculty': data['faculty'] ?? data['department'] ?? 'Chưa cập nhật khoa',
        'studentId': data['studentId'] ?? data['mssv'] ?? '',
        'photoURL': data['photoURL'] ?? data['avatar'] ?? '',
        'zalo': data['zalo'] ?? data['phone'] ?? '',
        'facebook': data['facebook'] ?? '',
        'phone': data['phone'] ?? '',
        'isVerified': data['isVerified'] ?? false,
      };
    } catch (e) {
      debugPrint('Error getting verification info: $e');
      return null;
    }
  }
}

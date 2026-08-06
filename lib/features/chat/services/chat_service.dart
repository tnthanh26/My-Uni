import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final Map<String, DateTime> _lastMarkedTimes = {};

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
    String resolvedTargetName = (targetName != null && targetName.trim().isNotEmpty) ? targetName.trim() : 'Sinh viên';
    String resolvedTargetPhoto = targetPhoto ?? '';

    // Tối ưu hóa performance: chạy song song (parallel) các truy vấn Firestore thay vì chờ từng call nối tiếp
    final bool needFetchTarget = targetName == null || targetName.trim().isEmpty;

    try {
      final results = await Future.wait([
        _firestore.collection('users').doc(myUid).get(),
        needFetchTarget
            ? _firestore.collection('users').doc(cleanTargetId).get()
            : Future.value(null),
        roomRef.get(),
      ]);

      final myDoc = results[0] as DocumentSnapshot?;
      final targetDoc = results[1] as DocumentSnapshot?;
      final roomDoc = results[2] as DocumentSnapshot?;

      if (myDoc != null && myDoc.exists) {
        final myData = myDoc.data() as Map<String, dynamic>? ?? {};
        myName = myData['displayName'] ?? myData['name'] ?? myData['username'] ?? myName;
        myPhoto = myData['photoURL'] ?? myData['photoUrl'] ?? myData['avatar'] ?? myData['authorAvatar'] ?? myData['avatarUrl'] ?? myData['userAvatar'] ?? myPhoto;
      }

      if (targetDoc != null && targetDoc.exists) {
        final targetData = targetDoc.data() as Map<String, dynamic>? ?? {};
        resolvedTargetName = targetData['displayName'] ?? targetData['name'] ?? targetData['username'] ?? resolvedTargetName;
        resolvedTargetPhoto = targetData['photoURL'] ?? targetData['photoUrl'] ?? targetData['avatar'] ?? targetData['authorAvatar'] ?? targetData['avatarUrl'] ?? targetData['userAvatar'] ?? resolvedTargetPhoto;
      }

      final participantNames = {
        myUid: myName.toString(),
        cleanTargetId: resolvedTargetName.toString(),
      };

      final participantPhotos = {
        myUid: myPhoto.toString(),
        cleanTargetId: resolvedTargetPhoto.toString(),
      };

      if (roomDoc != null && !roomDoc.exists) {
        final newRoom = ChatRoom(
          id: roomId,
          participants: [myUid, cleanTargetId],
          participantNames: participantNames,
          participantPhotos: participantPhotos,
          lastMessage: '',
          lastMessageSenderId: '',
          lastMessageTime: null,
          unreadCounts: {myUid: 0, cleanTargetId: 0},
          updatedAt: null,
        );

        await roomRef.set(newRoom.toMap(), SetOptions(merge: true));
      } else {
        await roomRef.set({
          'participantNames': participantNames,
          'participantPhotos': participantPhotos,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Chat room doc fetch/set error: $e");
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
        final bool aHasMsg = a.lastMessage.isNotEmpty &&
            a.lastMessage != 'Đã bắt đầu cuộc trò chuyện' &&
            a.lastMessageTime != null;
        final bool bHasMsg = b.lastMessage.isNotEmpty &&
            b.lastMessage != 'Đã bắt đầu cuộc trò chuyện' &&
            b.lastMessageTime != null;

        // Các phòng đã có tin nhắn thực sự luôn xếp TRÊN các phòng chưa chat chữ nào
        if (aHasMsg && !bHasMsg) return -1;
        if (!aHasMsg && bHasMsg) return 1;

        // Sắp xếp theo thời gian tin nhắn mới nhất
        final timeA = a.lastMessageTime ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = b.lastMessageTime ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
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
    try {
      final roomDoc = await roomRef.get();
      if (roomDoc.exists) {
        final updateMap = <String, dynamic>{
          'lastMessage': displayLastMsg,
          'lastMessageSenderId': myUid,
          'lastMessageTime': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'unreadCounts.$myUid': 0,
        };
        if (otherUid.isNotEmpty) {
          updateMap['unreadCounts.$otherUid'] = FieldValue.increment(1);
        }
        await roomRef.update(updateMap);
      } else {
        await roomRef.set({
          'id': roomId,
          'participants': (otherUid.isNotEmpty)
              ? [myUid, otherUid]
              : (roomParts.length >= 2 ? roomParts : [myUid]),
          'lastMessage': displayLastMsg,
          'lastMessageSenderId': myUid,
          'lastMessageTime': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'unreadCounts': {
            myUid: 0,
            if (otherUid.isNotEmpty) otherUid: 1,
          },
        });
      }
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

  Future<void> markRoomAsRead(String roomId) async {
    final myUid = currentUserId;
    if (myUid == null) return;

    // Rate limiter: Bỏ qua nếu vừa mới gọi đánh dấu đã đọc trong vòng 2 giây qua
    final now = DateTime.now();
    final lastMarked = _lastMarkedTimes[roomId];
    if (lastMarked != null && now.difference(lastMarked).inSeconds < 2) {
      return;
    }
    _lastMarkedTimes[roomId] = now;

    try {
      final roomRef = _firestore.collection('chat_rooms').doc(roomId);
      final roomDoc = await roomRef.get();
      if (roomDoc.exists) {
        final data = roomDoc.data() ?? {};
        
        // 1. Cập nhật map lồng nhau để đảm bảo unreadCounts[myUid] luôn là 0
        final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
        unreadCounts[myUid] = 0;
        await roomRef.update({
          'unreadCounts': unreadCounts,
        });

        // 2. Xóa các key lỗi dính dấu chấm ở root nếu có bằng set(merge: true) để tránh xóa nhầm dữ liệu trong map lồng
        final legacyRootKey = 'unreadCounts.$myUid';
        if (data.containsKey(legacyRootKey)) {
          try {
            await roomRef.set({
              legacyRootKey: FieldValue.delete(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Error deleting legacy root key: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Mark room as read error in chat_rooms: $e');
      try {
        await _firestore.collection('chat_rooms').doc(roomId).set({
          'unreadCounts': {myUid: 0},
        }, SetOptions(merge: true));
      } catch (err) {
        debugPrint('Fallback mark room as read error: $err');
      }
    }

    // Đánh dấu tất cả tin nhắn đối phương gửi trong phòng này là đã đọc (isRead = true)
    try {
      final roomParts = roomId.split('_');
      String otherUid = '';
      if (roomParts.length >= 2) {
        otherUid = roomParts.firstWhere((id) => id != myUid, orElse: () => '');
      }
      if (otherUid.isNotEmpty) {
        final messagesQuery = await _firestore
            .collection('chat_rooms')
            .doc(roomId)
            .collection('messages')
            .where('senderId', isEqualTo: otherUid)
            .where('isRead', isEqualTo: false)
            .get();

        if (messagesQuery.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in messagesQuery.docs) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('Mark messages as read error: $e');
    }

    // Đồng thời đánh dấu đã đọc các bản ghi thông báo trong notifications collection
    try {
      final notiDocs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: myUid)
          .where('roomId', isEqualTo: roomId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in notiDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking room notifications as read: $e");
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
        'photoURL': data['photoURL'] ?? data['photoUrl'] ?? data['avatar'] ?? data['authorAvatar'] ?? data['avatarUrl'] ?? data['userAvatar'] ?? '',
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
  static final Map<String, DateTime> _lastCleanupTimes = {};

  /// Tự động dọn dẹp các tin nhắn cũ hơn 30 ngày trong phòng chat
  Future<void> cleanupExpiredMessages(String roomId, {int daysThreshold = 30}) async {
    final now = DateTime.now();
    final lastCleanup = _lastCleanupTimes[roomId];

    // Rate Limiter: Chỉ dọn dẹp tối đa 1 lần mỗi 12 giờ cho mỗi phòng chat để tiết kiệm chi phí Firestore
    if (lastCleanup != null && now.difference(lastCleanup).inHours < 12) {
      return;
    }
    _lastCleanupTimes[roomId] = now;

    try {
      final cutoffDate = now.subtract(Duration(days: daysThreshold));
      final expiredMessagesQuery = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(100)
          .get();

      if (expiredMessagesQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in expiredMessagesQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint("ChatService: Auto-deleted ${expiredMessagesQuery.docs.length} messages older than $daysThreshold days in room: $roomId");
      }
    } catch (e) {
      debugPrint("ChatService: Error cleaning up expired messages in room $roomId: $e");
    }
  }

  /// Tự động quét dọn toàn bộ phòng chat của User hiện tại để xóa tin nhắn quá 30 ngày
  Future<void> cleanupAllUserExpiredChats({int daysThreshold = 30}) async {
    final myUid = currentUserId;
    if (myUid == null) return;

    try {
      final roomDocs = await _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: myUid)
          .get();

      for (var roomDoc in roomDocs.docs) {
        await cleanupExpiredMessages(roomDoc.id, daysThreshold: daysThreshold);
      }
    } catch (e) {
      debugPrint("ChatService: Error running global user chat cleanup: $e");
    }
  }

  /// Xóa toàn bộ cuộc trò chuyện (phòng chat và tất cả tin nhắn bên trong)
  Future<void> deleteChatRoom(String roomId) async {
    final myUid = currentUserId;
    if (myUid == null) throw Exception('Bạn chưa đăng nhập');

    final roomRef = _firestore.collection('chat_rooms').doc(roomId);

    // 1. Xóa các thông báo tin nhắn thuộc về chính User này
    try {
      final notisQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: myUid)
          .where('roomId', isEqualTo: roomId)
          .get();
      if (notisQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in notisQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error deleting user notifications: $e");
    }

    // 2. Thử xóa tất cả tin nhắn trong subcollection 'messages'
    try {
      final messagesQuery = await roomRef.collection('messages').get();
      if (messagesQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in messagesQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Batch message deletion permission restricted: $e");
      // Fallback: Xóa các tin nhắn do chính người dùng hiện tại gửi
      try {
        final myMessagesQuery = await roomRef
            .collection('messages')
            .where('senderId', isEqualTo: myUid)
            .get();
        if (myMessagesQuery.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in myMessagesQuery.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      } catch (_) {}
    }

    // 3. Xóa document phòng chat chính (hoặc rút khỏi danh sách tham gia nếu bị giới hạn quyền)
    try {
      await roomRef.delete();
      debugPrint("ChatService: Successfully deleted chat room $roomId");
    } catch (e) {
      debugPrint("Hard delete room permission restricted, removing participant: $e");
      try {
        await roomRef.update({
          'participants': FieldValue.arrayRemove([myUid]),
          'unreadCounts.$myUid': FieldValue.delete(),
        });
      } catch (err) {
        debugPrint("Error updating room participants: $err");
      }
    }
  }
}

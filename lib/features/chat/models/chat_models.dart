import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantPhotos;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCounts;
  final DateTime? updatedAt;

  ChatRoom({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantPhotos,
    this.lastMessage = '',
    this.lastMessageSenderId = '',
    this.lastMessageTime,
    this.unreadCounts = const {},
    this.updatedAt,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    Map<String, String> parseStringMap(dynamic mapData) {
      if (mapData is Map) {
        return mapData.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return {};
    }

    Map<String, int> parseIntMap(
      dynamic mapData,
      Map<String, dynamic> rawData,
    ) {
      final Map<String, int> result = {};
      // 1. Đọc các key dính dấu chấm cấp cao cũ (nếu có)
      rawData.forEach((k, v) {
        if (k.startsWith('unreadCounts.') && v is num) {
          final uid = k.substring('unreadCounts.'.length);
          result[uid] = v.toInt();
        }
      });
      // 2. Map lồng nhau chuẩn luôn được ưu tiên GHI ĐÈ dữ liệu mới nhất
      if (mapData is Map) {
        mapData.forEach((k, v) {
          if (v is num) {
            result[k.toString()] = v.toInt();
          }
        });
      }
      return result;
    }

    return ChatRoom(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: parseStringMap(data['participantNames']),
      participantPhotos: parseStringMap(data['participantPhotos']),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCounts: parseIntMap(data['unreadCounts'], data),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : FieldValue.serverTimestamp(),
      'unreadCounts': unreadCounts,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  String getOtherUserId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  String getOtherUserName(String currentUserId) {
    final otherId = getOtherUserId(currentUserId);
    return participantNames[otherId] ?? 'Sinh viên';
  }

  String getOtherUserPhoto(String currentUserId) {
    final otherId = getOtherUserId(currentUserId);
    return participantPhotos[otherId] ?? '';
  }

  int getUnreadCount(String currentUserId) {
    return unreadCounts[currentUserId] ?? 0;
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final String? imageUrl;
  final Map<String, String>?
  contactShare; // e.g. {'type': 'zalo'|'facebook'|'phone', 'value': '...', 'name': '...'}
  final Map<String, String>?
  fileShare; // e.g. {'fileName': '...', 'fileSize': '...', 'base64': '...', 'extension': '...'}
  final DateTime timestamp;
  final bool isRead;
  final bool isRecalled;
  final bool isEdited;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.contactShare,
    this.fileShare,
    required this.timestamp,
    this.isRead = false,
    this.isRecalled = false,
    this.isEdited = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    Map<String, String>? contactMap;
    if (data['contactShare'] is Map) {
      contactMap = (data['contactShare'] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }

    Map<String, String>? fileMap;
    if (data['fileShare'] is Map) {
      fileMap = (data['fileShare'] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      contactShare: contactMap,
      fileShare: fileMap,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      isRecalled: data['isRecalled'] ?? false,
      isEdited: data['isEdited'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'contactShare': contactShare,
      'fileShare': fileShare,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'isRecalled': isRecalled,
      'isEdited': isEdited,
    };
  }
}

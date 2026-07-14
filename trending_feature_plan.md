# 📈 Kế hoạch Triển khai Tính năng Trending (Xu hướng) cho Forum & Comments

Bản kế hoạch này hướng dẫn chi tiết cách tích hợp tính năng **Trending** (Xu hướng/Nổi bật) cho các bài viết (Posts) và bình luận (Comments) tại tab Diễn đàn (Forum) trên dự án My-Uni. Kế hoạch bao gồm thiết kế thuật toán, thay đổi cơ sở dữ liệu Firestore, Cloud Functions và mã nguồn Flutter.

---

## 🚀 1. Thuật toán Tính điểm Xu hướng (Trending Algorithm)

Để xác định bài đăng hoặc bình luận nào đang "trending", chúng ta cần một cơ chế đánh giá độ tương tác dựa trên:
1. **Mức độ tương tác (Engagement):** Lượt thích (Likes) và lượt bình luận (Comments).
2. **Thời gian suy giảm (Time Decay):** Ưu tiên các bài đăng mới để tránh việc các bài đăng cũ có lượng tương tác cao chiếm giữ vị trí đầu bảng mãi mãi.

### Công thức đề xuất (Hacker News / Reddit formula):
$$\text{Trending Score} = \frac{\text{LikeCount} \times w_{\text{like}} + \text{CommentCount} \times w_{\text{comment}} + 1}{(\text{TimeElapsedInHours} + 2)^G}$$

- **$w_{\text{like}}$ (Trọng số thích):** `1.5`
- **$w_{\text{comment}}$ (Trọng số bình luận):** `3.0` (Bình luận có trọng số cao hơn vì đòi hỏi nhiều công sức tương tác hơn).
- **$TimeElapsedInHours$:** Số giờ trôi q### Giải pháp được Chọn & Triển khai thực tế: Hybrid Epoch-based Client Sorting
*Sự kết hợp xuất sắc giữa công thức toán học tối ưu và tính an toàn cao.*
- **Cách hoạt động:**
  - Client đăng ký nhận luồng Stream dữ liệu các bài đăng của diễn đàn theo mặc định (sắp xếp theo `timestamp` giảm dần).
  - Khi luồng Stream trả dữ liệu về, nếu người dùng chọn bộ lọc **"Xu hướng 🔥"**, Client sẽ tự động tính toán điểm xu hướng `trendingScore` của từng bài viết trên RAM và sắp xếp giảm dần theo công thức Epoch:
    $$\text{trendingScore} = \text{engagementScore} + \frac{\text{EpochTimestamp}}{K}$$
    Trong đó:
    - $\text{engagementScore} = (\text{likeCount} \times 1.5) + (\text{commentCount} \times 3.0)$
    - $\text{EpochTimestamp}$ được trích xuất từ trường `timestamp` của Firestore (đơn vị: giây).
    - $K = 864$ (1 ngày mới = 100 điểm tương tác).
- **Lý do lựa chọn giải pháp này:**
  1. **Khắc phục triệt để lỗi Rules (Từ chối quyền truy cập):** Không cần ghi đè hay cập nhật trường `trendingScore` từ phía Client lên database. Do đó, các hành động Thích (Like) và Bình luận (Comment) không vi phạm luật bảo mật (Security Rules) của Firestore và chạy thành công 100%.
  2. **Không cần cấu hình Index phức tạp:** Vì query gốc chỉ sắp xếp theo `timestamp`, chúng ta không cần tạo thêm Composite Index trên Firebase Console.
  3. **Tương thích ngược hoàn hảo:** Các bài viết cũ trong cơ sở dữ liệu (vốn không có sẵn trường `trendingScore`) vẫn hiển thị và được sắp xếp chính xác.

---ày tháng `timestamp`, vì các bài đăng cũ sẽ tự động trôi xuống do điểm Epoch thấp hơn.
  - Không cần chạy Cron Job Cloud Functions hàng ngày để cập nhật điểm.
- **Nhược điểm:** Cần cấu hình composite index trên Firestore cho bộ đôi `status` và `trendingScore`.

### Phương án C: Cloud Functions Scheduler (Giải pháp thay thế quy mô lớn)
- **Cách hoạt động:**
  - Thêm trường `trendingScore` vào document `forum_posts`.
  - Tạo một Cloud Function loại `onSchedule` (chạy mỗi 1 giờ hoặc 2 giờ). Function này quét các bài viết 7 ngày gần nhất, tính toán điểm trending theo công thức suy giảm thời gian thực tế và cập nhật lại trường `trendingScore` trên Firestore.
- **Ưu điểm:** Độ suy giảm thời gian thực thi chính xác tuyệt đối theo hàm phi tuyến (không tuyến tính như Phương án B).
- **Nhược điểm:** Tốn số lượt đọc/ghi Firestore của Cloud Functions lớn khi số lượng bài đăng tăng cao.

---

## 🛠️ 3. Chi tiết triển khai mã nguồn (Code Implementation)

### 3.1. Cấu trúc dữ liệu Firestore bổ sung
- **`forum_posts/{postId}`**:
  - `likeCount`: `number` (đã có)
  - `commentCount`: `number` (đã có)
  - `engagementScore`: `number` (thêm mới)
  - `trendingScore`: `number` (thêm mới nếu dùng Phương án C)

- **`forum_posts/{postId}/comments/{commentId}`**:
  - `likes`: `array` (chứa các UID đã thích comment - đã có)
  - `likeCount`: `number` (thêm mới để tiện truy vấn / sắp xếp)

---

### 3.2. Cập nhật mã nguồn Cloud Functions (`functions/src/index.ts`)

#### A. Trình đếm bình luận tự động ở Backend (Tránh lỗi phân quyền Firestore)
Vì Firestore Security Rules ở Client chặn không cho người dùng thông thường tự cập nhật trường `commentCount` của bài đăng người khác, chúng tôi sử dụng các Firestore Document Triggers trên server (bằng quyền Admin SDK) để tự động tăng/giảm số lượng bình luận:

```typescript
import {onDocumentCreated, onDocumentDeleted} from "firebase-functions/v2/firestore";

/**
 * Tự động tăng commentCount của bài viết khi có bình luận mới
 */
export const onCommentCreated = onDocumentCreated(
  "forum_posts/{postId}/comments/{commentId}",
  async (event) => {
    if (!event.data) return;
    const postId = event.params.postId;
    const postRef = db.collection("forum_posts").doc(postId);

    await postRef.update({
      commentCount: admin.firestore.FieldValue.increment(1),
    });
    console.log(`Incremented commentCount for post ${postId}`);
  }
);

/**
 * Tự động giảm commentCount của bài viết khi bình luận bị xóa
 */
export const onCommentDeleted = onDocumentDeleted(
  "forum_posts/{postId}/comments/{commentId}",
  async (event) => {
    if (!event.data) return;
    const postId = event.params.postId;
    const postRef = db.collection("forum_posts").doc(postId);

    await postRef.update({
      commentCount: admin.firestore.FieldValue.increment(-1),
    });
    console.log(`Decremented commentCount for post ${postId}`);
  }
);
```

#### B. Sắp xếp điểm trending bằng Scheduler (Phương án C - Không bắt buộc)
Nếu lựa chọn chạy scheduler tính toán trending định kỳ bằng Cloud Functions thay vì sắp xếp client-side, bạn có thể triển khai hàm dưới đây:

```typescript
// Thêm scheduler tính toán điểm trending cho bài viết forum định kỳ mỗi giờ
export const updateForumTrendingScores = onSchedule("0 * * * *", async () => {
  const now = admin.firestore.Timestamp.now();
  const oneWeekAgo = new Date();
  oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

  // Lấy các bài viết đã được duyệt trong 7 ngày qua
  const postsQuery = await db.collection("forum_posts")
    .where("status", "==", "approved")
    .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(oneWeekAgo))
    .get();

  if (postsQuery.empty) {
    console.log("Không có bài viết nào hoạt động trong tuần qua.");
    return;
  }

  const batch = db.batch();
  const gravity = 1.5;

  postsQuery.docs.forEach((doc) => {
    const data = doc.data();
    const likeCount = data.likeCount || 0;
    const commentCount = data.commentCount || 0;
    const timestamp = data.timestamp as admin.firestore.Timestamp;

    // Tính thời gian trôi qua bằng giờ
    const elapsedHours = (now.toMillis() - timestamp.toMillis()) / (1000 * 60 * 60);

    // Thuật toán Hacker News
    const score = (likeCount * 1.5 + commentCount * 3.0 + 1) / Math.pow(elapsedHours + 2, gravity);

    batch.update(doc.ref, {
      trendingScore: score,
      lastScoreCalculatedAt: now,
    });
  });

  await batch.commit();
  console.log(`Đã cập nhật điểm Trending cho ${postsQuery.size} bài viết.`);
});
```

---

### 3.3. Cập nhật giao diện Diễn đàn trên Flutter (`forum_tab.dart`)
Chúng ta sẽ thêm một thanh lọc tab đầu trang (ví dụ: "Mới nhất" và "Trending") trong [forum_tab.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/home/forum_tab.dart).

#### Bước 1: Khai báo biến trạng thái lọc trong `_ForumTabState`
```dart
String _currentFilter = 'newest'; // 'newest' hoặc 'trending'
```

#### Bước 2: Thêm UI Toggle Filter ở đầu danh sách bài viết
Thêm một widget hàng để lựa chọn chế độ hiển thị bài đăng:
```dart
Widget _buildFilterRow(bool isDarkMode) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        _buildFilterChip("Mới nhất", 'newest', isDarkMode),
        const SizedBox(width: 10),
        _buildFilterChip("Xu hướng 🔥", 'trending', isDarkMode),
      ],
    ),
  );
}

Widget _buildFilterChip(String label, String value, bool isDarkMode) {
  final isSelected = _currentFilter == value;
  return ChoiceChip(
    label: Text(
      label,
      style: TextStyle(
        fontFamily: 'Encode Sans Expanded',
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
      ),
    ),
    selected: isSelected,
    selectedColor: const Color(0xFF5893D8),
    backgroundColor: isDarkMode ? Colors.white10 : const Color(0xFFF1F5F9),
    onSelected: (bool selected) {
      if (selected) {
        setState(() {
          _currentFilter = value;
        });
      }
    },
  );
}
```

#### Bước 3: Triển khai ghi và cập nhật điểm `trendingScore` nguyên tử

##### A. Khi tạo bài viết mới (ví dụ trong `create_post_page.dart`):
Khởi tạo điểm `trendingScore` ban đầu bằng giá trị Epoch Timestamp (chia hệ số $K = 864$):
```dart
final int epochSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
final double initialTrendingScore = epochSeconds / 864.0;

// Khi add document vào collection 'forum_posts':
await FirebaseFirestore.instance.collection('forum_posts').add({
  'content': contentText,
  'timestamp': FieldValue.serverTimestamp(),
  'likeCount': 0,
  'commentCount': 0,
  'trendingScore': initialTrendingScore, // Điểm cơ sở thời gian
  'status': 'pending', // Chờ duyệt
});
```

##### B. Khi thích/hủy thích bài viết (trong `post_action_row.dart`):
Sử dụng `FieldValue.increment` để thay đổi điểm số một cách nguyên tử mà không bị tranh chấp dữ liệu:
```dart
// Trong hàm _handleLike:
final double trendingScoreDelta = isLiked ? -1.5 : 1.5;

await postRef.update({
  'likeCount': FieldValue.increment(isLiked ? -1 : 1),
  'trendingScore': FieldValue.increment(trendingScoreDelta), // Cập nhật nguyên tử
});
```

##### C. Khi người dùng thêm bình luận mới (trong `post_detail_page.dart`):
Tăng điểm `trendingScore` của bài viết lên $+3.0$:
```dart
// Khi add comment thành công, cập nhật số lượng comment và điểm trending của bài viết:
await _firestore.collection('forum_posts').doc(widget.docId).update({
  'commentCount': FieldValue.increment(1),
  'trendingScore': FieldValue.increment(3.0), // Tăng 3.0 điểm trending
});
```

#### Bước 4: Truy vấn StreamBuilder linh hoạt dựa theo bộ lọc
Tại phương thức `build` của [forum_tab.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/home/forum_tab.dart#L202), chúng ta sẽ chuyển đổi giữa 2 Stream truy vấn trực tiếp từ Firestore thay vì sắp xếp tại Client. Việc này giúp giảm tải băng thông tải dữ liệu:

```dart
// Chọn Stream tương ứng với bộ lọc của người dùng
final Stream<QuerySnapshot> _postsStream = _currentFilter == 'trending'
    ? FirebaseFirestore.instance
        .collection('forum_posts')
        .where('status', isEqualTo: 'approved')
        .orderBy('trendingScore', descending: true) // Sắp xếp theo xu hướng trực tiếp từ DB
        .snapshots()
    : FirebaseFirestore.instance
        .collection('forum_posts')
        .where('status', isEqualTo: 'approved')
        .orderBy('timestamp', descending: true) // Sắp xếp theo mới nhất
        .snapshots();
```

Truyền `_postsStream` này vào `StreamBuilder`:
```dart
StreamBuilder<QuerySnapshot>(
  stream: _postsStream,
  builder: (context, snapshot) {
    // ... logic vẽ giao diện như bình thường ...
  }
)
```

> [!IMPORTANT]
> **Cần cấu hình Composite Index trên Firebase Console:**
> Khi sử dụng truy vấn `.where('status', isEqualTo: 'approved').orderBy('trendingScore', descending: true)`, bạn phải tạo một chỉ mục liên hợp (Composite Index) cho collection `forum_posts` trên Firebase Console với các trường:
> 1. `status` (Ascending)
> 2. `trendingScore` (Descending)
> Nếu không có index này, Firestore sẽ trả về lỗi kèm đường link trong log console để bạn click vào tạo tự động.

---

### 3.4. Triển khai Trending Comments (Bình luận nổi bật)
Để sắp xếp bình luận có nhiều lượt thích lên đầu trong [post_detail_page.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/home/post_detail_page.dart):

#### Bước 1: Khai báo biến chế độ xem bình luận trong `_PostDetailPageState`
```dart
String _commentSortMode = 'newest'; // 'newest' (cũ nhất/mới nhất) hoặc 'top' (nhiều like nhất)
```

#### Bước 2: Thêm thanh chọn sắp xếp ở đầu danh sách bình luận
Tại giao diện, đặt phần điều hướng bên trên danh sách bình luận:
```dart
Widget _buildCommentSortHeader() {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Bình luận",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        DropdownButton<String>(
          value: _commentSortMode,
          dropdownColor: isDarkMode ? const Color(0xFF15171A) : Colors.white,
          underline: const SizedBox(),
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? Colors.white70 : Colors.black87,
            fontFamily: 'Encode Sans Expanded',
          ),
          items: const [
            DropdownMenuItem(value: 'newest', child: Text("Đăng sớm nhất")),
            DropdownMenuItem(value: 'top', child: Text("Nổi bật nhất 🔥")),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _commentSortMode = val;
              });
            }
          },
        ),
      ],
    ),
  );
}
```

#### Bước 3: Sắp xếp bình luận In-Memory
Tại `_buildCommentSection()` trong [post_detail_page.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/home/post_detail_page.dart#L2277):

```dart
var allComments = snapshot.data!.docs
    .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
    .where((c) {
      final status = c['status'];
      return status == 'approved' || status == null;
    })
    .toList();

// Thực hiện sắp xếp theo chế độ được chọn
if (_commentSortMode == 'top') {
  allComments.sort((a, b) {
    final List<dynamic> aLikes = a['likes'] ?? [];
    final List<dynamic> bLikes = b['likes'] ?? [];
    return bLikes.length.compareTo(aLikes.length); // Sắp xếp giảm dần theo số lượng like
  });
}
```

---

## 🎯 4. Các bước triển khai tiếp theo
1. **Lựa chọn Phương án thiết kế:** Xác định quy mô dữ liệu của trường để chọn Phương án A (Client-side), B (Real-time Filter) hay C (Cloud Functions).
2. **Tạo index trên Firestore:** Nếu chọn truy vấn trực tiếp từ database (nhất là khi dùng `.orderBy('trendingScore')` hoặc `.orderBy('timestamp')` lọc kèm `status`), truy cập Firebase Console và thêm các composite index tương ứng.
3. **Cập nhật Flutter Code:** Copy/paste phần sửa đổi sắp xếp client side vào các trang `forum_tab.dart` và `post_detail_page.dart` để kiểm tra trải nghiệm người dùng trước tiên.

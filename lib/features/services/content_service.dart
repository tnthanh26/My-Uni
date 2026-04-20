class ContentService {
  static const List<String> _blackList = [
    'dit', 'du', 'deo', 'dech',
    'dit me', 'dm', 'dmm', 'dcm', 'vcl', 'clm'
    'oc cho', 'suc vat', 'rac ruoi',
    'chet di', 'cut', 'bien di',
    'phan dong', 'ba que'
  ];

  /// Hàm loại bỏ dấu tiếng Việt
  static String _removeDiacritics(String str) {
    var withDia = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    var noDia   = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    String result = str.toLowerCase();
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], noDia[i]);
    }
    return result;
  }

  /// Trả về danh sách các từ vi phạm tìm thấy trong văn bản (quét cả có dấu và không dấu)
  static List<String> getViolatedWords(String text) {
    if (text.isEmpty) return [];

    // 1. Chuyển nội dung người dùng về dạng không dấu, chữ thường
    String normalized = _removeDiacritics(text);

    // 2. Loại bỏ các ký tự đặc biệt lách luật (ví dụ: d.m, d-m, d_m)
    // Giữ lại khoảng trắng để tách từ
    String cleanText = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), '');

    List<String> foundViolations = [];

    // 3. Kiểm tra từng cụm từ trong blacklist
    for (var toxic in _blackList) {
      // Dùng RegExp với \b (word boundary) để tránh bị bắt nhầm
      // Ví dụ: không bắt nhầm từ "video" khi có từ "deo"
      RegExp regExp = RegExp(r'\b' + RegExp.escape(toxic) + r'\b');

      if (regExp.hasMatch(cleanText)) {
        foundViolations.add(toxic);
      }
    }

    return foundViolations;
  }
}
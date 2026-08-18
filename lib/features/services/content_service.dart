class ContentService {
  static const List<String> _unaccentedBlackList = [
    "dm",
    "dmm",
    "dcm",
    "clm",
    "vcl",
    "vkl",
    "đm",
    "đmm",
    "đcm",
    "cmn",
    "cl",
    "dit me",
    "djt me",
    "ditme",
    "djtme",
    "địt mẹ",
    "địt cụ",
    "dit cu",
    "địt cụ mày",
    "du ma",
    "duma",
    "du me",
    "dume",
    "đụ mẹ",
    "đụ má",
    "deo me",
    "deome",
    "đéo mẹ",
    "đéo cụ",
    "oc cho",
    "suc vat",
    "rac ruoi",
    "chet di",
    "bien di",
    "phan dong",
    "ba que",
    "dit nhau",
    "djt nhau",
    "chich nhau",
  ];

  static const List<String> _accentedBlackList = [
    "địt",
    "đụ",
    "đéo",
    "cút",
    "lồn",
    "cặc",
    "buồi",
    "đĩ",
    "chịch",
    "nện",
    "phịch",
  ];

  static const List<String> _unaccentedSensitiveList = [
    "lua dao",
    "scam",
    "da cap",
    "viec nhe luong cao",
    "kiem tien online",
    "chuyen khoan truoc",
    "coc truoc",
    "dau tu loi nhuan cao",
    "cam ket loi nhuan",
    "keo thom",
    "tay chay",
    "dinh cong",
    "bieu tinh",
    "boc phot",
    "thi ho",
    "gian lan",
    "quay cop",
    "mua diem",
    "chay diem",
    "fake diem",
    "lo de",
    "ca do",
    "danh bai",
    "danh bac",
    "casino",
    "nha cai",
  ];

  static const List<String> _accentedSensitiveList = [
    "cọc",
    "kèo",
    "cò",
    "lừa",
    "độ",
  ];

  /// Hàm loại bỏ dấu tiếng Việt
  static String _removeDiacritics(String str) {
    var withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    var noDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    String result = str.toLowerCase();
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], noDia[i]);
    }
    return result;
  }

  /// Helper to match a whole word or phrase in a preprocessed text
  static bool _matchWord(String cleanText, String targetWord) {
    String escapedWord = RegExp.escape(
      targetWord,
    ).replaceAll(RegExp(r'\s+'), r'\s+');
    RegExp regExp = RegExp('(^|\\s)$escapedWord(\\s|\$)');
    return regExp.hasMatch(cleanText);
  }

  /// Trả về danh sách các từ vi phạm thuộc blacklist (cấm hoàn toàn)
  static List<String> getBlacklistedWords(String text) {
    if (text.isEmpty) return [];

    // 1. Chuẩn bị text gốc có dấu (chuyển sang chữ thường, thay ký tự đặc biệt bằng khoảng trắng)
    String cleanAccented = text.toLowerCase().replaceAll(
      RegExp(
        r'[^a-z0-9àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ\s]',
      ),
      ' ',
    );

    // 2. Chuẩn bị text không dấu
    String normalized = _removeDiacritics(text.toLowerCase());
    String cleanUnaccented = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    List<String> foundViolations = [];

    // 3. Quét qua danh sách không dấu
    for (var word in _unaccentedBlackList) {
      if (_matchWord(cleanUnaccented, word)) {
        foundViolations.add(word);
      }
    }

    // 4. Quét qua danh sách có dấu
    for (var word in _accentedBlackList) {
      if (_matchWord(cleanAccented, word)) {
        foundViolations.add(word);
      }
    }

    return foundViolations;
  }

  /// Trả về danh sách các từ vi phạm thuộc sensitive list (nhạy cảm - cảnh báo chờ duyệt)
  static List<String> getSensitiveWords(String text) {
    if (text.isEmpty) return [];

    // 1. Chuẩn bị text gốc có dấu
    String cleanAccented = text.toLowerCase().replaceAll(
      RegExp(
        r'[^a-z0-9àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ\s]',
      ),
      ' ',
    );

    // 2. Chuẩn bị text không dấu
    String normalized = _removeDiacritics(text.toLowerCase());
    String cleanUnaccented = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    List<String> foundViolations = [];

    // 3. Quét qua danh sách nhạy cảm không dấu
    for (var word in _unaccentedSensitiveList) {
      if (_matchWord(cleanUnaccented, word)) {
        foundViolations.add(word);
      }
    }

    // 4. Quét qua danh sách nhạy cảm có dấu
    for (var word in _accentedSensitiveList) {
      if (_matchWord(cleanAccented, word)) {
        foundViolations.add(word);
      }
    }

    return foundViolations;
  }

  // Giữ lại hàm cũ để tránh lỗi tương thích nếu có chỗ gọi chưa cập nhật
  static List<String> getViolatedWords(String text) {
    return getBlacklistedWords(text);
  }
}

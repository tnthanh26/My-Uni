import 'package:timeago/timeago.dart' as timeago;

class CustomViMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';

  // Xóa suffix 'trước' mặc định để có thể tùy chỉnh 'Vừa xong' không bị nối chữ
  @override
  String suffixAgo() => '';
  @override
  String suffixFromNow() => '';

  @override
  String lessThanOneMinute(int seconds) => 'Vừa xong';
  @override
  String aboutAMinute(int minutes) => '1 phút trước';
  @override
  String minutes(int minutes) => '${minutes.round()} phút trước';
  @override
  String aboutAnHour(int minutes) => '1 giờ trước';
  @override
  String hours(int hours) => '${hours.round()} giờ trước';
  @override
  String aDay(int hours) => '1 ngày trước';
  @override
  String days(int days) => '${days.round()} ngày trước';
  @override
  String aboutAMonth(int days) => '1 tháng trước';
  @override
  String months(int months) => '${months.round()} tháng trước';
  @override
  String aboutAYear(int year) => '1 năm trước';
  @override
  String years(int years) => '${years.round()} năm trước';
  @override
  String wordSeparator() => ' ';
}

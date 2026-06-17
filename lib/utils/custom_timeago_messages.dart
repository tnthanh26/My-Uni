import 'package:timeago/timeago.dart';

/// Vietnamese messages for timeago with custom "vừa xong" for less than a minute.
class CustomViMessages implements LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => 'trước';
  @override
  String suffixFromNow() => 'nữa';
  @override
  String lessThanOneMinute(int seconds) => 'vừa xong';
  @override
  String aboutAMinute(int minutes) => '1 phút';
  @override
  String minutes(int minutes) => '$minutes phút';
  @override
  String aboutAnHour(int minutes) => '1 giờ';
  @override
  String hours(int hours) => '$hours giờ';
  @override
  String aDay(int hours) => '1 ngày';
  @override
  String days(int days) => '$days ngày';
  @override
  String aboutAMonth(int days) => '1 tháng';
  @override
  String months(int months) => '$months tháng';
  @override
  String aboutAYear(int year) => '1 năm';
  @override
  String years(int years) => '$years năm';
  @override
  String wordSeparator() => ' ';
}

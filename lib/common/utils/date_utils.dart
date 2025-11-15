import 'package:intl/intl.dart';

class SDateUtils {
  SDateUtils._internal();
  factory SDateUtils() => _instance;
  static final SDateUtils _instance = SDateUtils._internal();

  /// 传入时间字符串2022-12-21T07:30:00
  static String formatDate(String? date, {String pattern = "yyyy-MM-dd"}) {
    final dateStr = date ?? DateTime.now().toString();
    final dateTime = DateTime.tryParse(dateStr);
    if (dateTime == null) return dateStr;
    return DateFormat(pattern).format(dateTime);
  }

  static String formatDateByInt(int millisecondsSinceEpoch,
      {String pattern = "yyyy-MM-dd HH:mm"}) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch,
        isUtc: true);
    return DateFormat(pattern).format(dateTime);
  }
}

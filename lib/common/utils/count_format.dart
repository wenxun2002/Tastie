/// Compact display for like/fav counts on cards and detail bars.
///
/// - Below 1000: full number
/// - 1000–999,999: `1k`, `1.5k`, `10k`, `999k`
/// - 1,000,000+: `1M`, `1.2M`, …
String formatEngagementCount(int count) {
  if (count < 0) return '0';
  if (count < 1000) return count.toString();

  if (count < 1000000) {
    final double k = count / 1000.0;
    if (k == k.floorToDouble()) {
      return '${k.toInt()}k';
    }
    final String s = k.toStringAsFixed(1);
    return '${s.replaceAll(RegExp(r'\.0$'), '')}k';
  }

  final double m = count / 1000000.0;
  if (m == m.floorToDouble()) {
    return '${m.toInt()}M';
  }
  final String s = m.toStringAsFixed(1);
  return '${s.replaceAll(RegExp(r'\.0$'), '')}M';
}

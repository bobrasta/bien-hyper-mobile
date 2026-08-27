String formatDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')} '
      '${_months[dt.month - 1]} ${dt.year}';
}

String formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String tshShort(int n) {
  if (n >= 1000000000) return 'TSh ${(n / 1e9).toStringAsFixed(2)}B';
  if (n >= 1000000)    return 'TSh ${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1000)       return 'TSh ${(n / 1e3).toStringAsFixed(0)}K';
  return 'TSh $n';
}

String tshFromDouble(num n) {
  if (n >= 1000000000) return 'TSh ${(n / 1e9).toStringAsFixed(2)}B';
  if (n >= 1000000)    return 'TSh ${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1000)       return 'TSh ${(n / 1e3).toStringAsFixed(0)}K';
  return 'TSh ${n.toStringAsFixed(0)}';
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  if (diff.inDays < 7)     return '${diff.inDays}d ago';
  return formatDate(dt);
}

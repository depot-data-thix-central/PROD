// lib/utils/time_ago.dart

/// Lightweight "time ago" formatter to avoid extra dependencies.
String formatTimeAgo(DateTime dateTime, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(dateTime);
  if (diff.inSeconds < 45) return 'à l’instant';
  if (diff.inMinutes < 2) return 'il y a 1 min';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 2) return 'il y a 1 h';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 2) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return 'il y a $weeks sem';
  final months = (diff.inDays / 30).floor();
  if (months < 12) return 'il y a $months mois';
  final years = (diff.inDays / 365).floor();
  return 'il y a $years an${years > 1 ? 's' : ''}';
}

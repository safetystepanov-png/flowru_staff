String staffDeadlineLabel(DateTime? deadline, DateTime now, {String before = 'До выдачи'}) {
 if (deadline == null) return 'Время уточняется';
 final remaining = deadline.difference(now).inSeconds;
 String clock(int seconds) {
  final total = seconds.abs();
  final hours = total ~/ 3600;
  final minutes = (total ~/ 60) % 60;
  final secs = total % 60;
  final tail = '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  return hours > 0 ? '$hours:$tail' : tail;
 }
 if (!now.isBefore(deadline)) return 'Просрочено на ${clock(remaining)}';
 return '$before ${clock(remaining)}';
}

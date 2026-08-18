// lib/presentation/thix_weeding/providers/countdown_provider.dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'countdown_provider.g.dart';

class CountdownState {
  final int days;
  final int hours;
  final int minutes;
  final int seconds;
  final bool isFinished;
  final Duration total;

  const CountdownState({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.isFinished,
    required this.total,
  });

  factory CountdownState.fromDuration(Duration d) {
    return CountdownState(
      days: d.inDays,
      hours: d.inHours % 24,
      minutes: d.inMinutes % 60,
      seconds: d.inSeconds % 60,
      isFinished: false,
      total: d,
    );
  }

  factory CountdownState.finished() {
    return const CountdownState(days: 0, hours: 0, minutes: 0, seconds: 0, isFinished: true, total: Duration.zero);
  }
}

/// Stream temps réel, autoDispose, cancel auto quand plus écouté
/// Coût CPU quasi nul pour des millions d'users
@riverpod
Stream<CountdownState> countdown(CountdownRef ref, DateTime targetDate) async* {
  while (true) {
    final now = DateTime.now();
    final diff = targetDate.difference(now);

    if (diff.isNegative) {
      yield CountdownState.finished();
      break; // stop le stream = plus de timer
    } else {
      yield CountdownState.fromDuration(diff);
    }

    // Tick chaque seconde exacte
    await Future.delayed(const Duration(seconds: 1));
  }
}

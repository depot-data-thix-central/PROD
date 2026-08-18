// lib/presentation/thix_weeding/providers/rsvp_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/failure.dart';
import '../data/repositories/wedding_repository_impl.dart';
import '../domain/entities/wedding_entity.dart';

part 'rsvp_provider.g.dart';

class RsvpFormState {
  final String guestName;
  final String status;
  final int count;
  final String message;
  const RsvpFormState({this.guestName = '', this.status = 'yes', this.count = 1, this.message = ''});
  RsvpFormState copyWith({String? guestName, String? status, int? count, String? message}) => RsvpFormState(guestName: guestName ?? this.guestName, status: status ?? this.status, count: count ?? this.count, message: message ?? this.message);
}

@riverpod
class RsvpForm extends _$RsvpForm {
  @override
  RsvpFormState build() => const RsvpFormState();
  void updateName(String v) => state = state.copyWith(guestName: v);
  void updateStatus(String v) => state = state.copyWith(status: v);
  void updateCount(int v) {
    if (v < 1) return;
    if (v > 10) return;
    state = state.copyWith(count: v);
  }
  void updateMessage(String v) => state = state.copyWith(message: v);
  void reset() => state = const RsvpFormState();
}

@riverpod
class RsvpController extends _$RsvpController {
  @override
  FutureOr<void> build() {}

  Future<bool> submit(String weddingId) async {
    final form = ref.read(rsvpFormProvider);
    if (form.guestName.trim().length < 2) {
      state = AsyncError(const Failure('Nom invalide (min 2 caractères)'), StackTrace.current);
      return false;
    }
    try {
      state = const AsyncLoading();
      final entity = RsvpEntity(
        weddingId: weddingId,
        guestName: form.guestName.trim(),
        status: form.status,
        count: form.count,
        message: form.message.trim(),
      );
      final repo = ref.read(weddingRepositoryProvider);
      await repo.submitRsvp(entity);
      state = const AsyncData(null);
      return true;
    } on Failure catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncError(Failure(e.toString()), StackTrace.current);
      return false;
    }
  }
}

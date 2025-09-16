// lib/features/quick_actions/providers/booking_providers.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal booking domain models (adapt/extend to your backend types).
@immutable
class BookingSlot {
  const BookingSlot({
    required this.slotId,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    this.priceCents,
    this.currency,
  });

  final String slotId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final int? priceCents;
  final String? currency;
}

@immutable
class BookingQuote {
  const BookingQuote({
    required this.quoteId,
    required this.placeId,
    required this.slotId,
    required this.partySize,
    required this.expiresAt,
    this.totalCents,
    this.currency,
    this.extras, // e.g., taxes, fees
  });

  final String quoteId;
  final String placeId;
  final String slotId;
  final int partySize;
  final DateTime expiresAt;
  final int? totalCents;
  final String? currency;
  final Map<String, Object?>? extras;
}

@immutable
class Reservation {
  const Reservation({
    required this.reservationId,
    required this.placeId,
    required this.slotId,
    required this.partySize,
    required this.confirmedAt,
    this.qr,
    this.meta,
  });

  final String reservationId;
  final String placeId;
  final String slotId;
  final int partySize;
  final DateTime confirmedAt;
  final String? qr;
  final Map<String, Object?>? meta;
}

/// Repository contract so UI and providers remain decoupled from transport.
abstract class BookingRepository {
  Future<List<BookingSlot>> fetchAvailability({
    required String placeId,
    required DateTime dayLocal,
    required int partySize,
  });

  Future<BookingQuote> createQuote({
    required String placeId,
    required String slotId,
    required int partySize,
    Map<String, Object?>? options,
  });

  Future<Reservation> confirmReservation({
    required String quoteId,
    Map<String, Object?>? payment, // token or payload as needed
  });

  Future<bool> cancelReservation({required String reservationId});

  Future<bool> rebookFromHistory({
    required String previousReservationId,
    int? partySizeOverride,
  });
}

/// Provide a concrete implementation higher in the tree with overrideWithValue.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  throw UnimplementedError('Provide BookingRepository via override in main.dart');
}); // A repository Provider centralizes data access and can be overridden in tests or app bootstrap. [15][12]

/// Stateless filter state for availability lookups (families prefer value types).
@immutable
class AvailabilityKey {
  const AvailabilityKey({
    required this.placeId,
    required this.dayLocal,
    required this.partySize,
  });

  final String placeId;
  final DateTime dayLocal;
  final int partySize;

  @override
  bool operator ==(Object other) {
    return other is AvailabilityKey &&
        other.placeId == placeId &&
        other.dayLocal.year == dayLocal.year &&
        other.dayLocal.month == dayLocal.month &&
        other.dayLocal.day == dayLocal.day &&
        other.partySize == partySize;
  }

  @override
  int get hashCode => Object.hash(placeId, dayLocal.year, dayLocal.month, dayLocal.day, partySize);
}

/// Availability is read-only async data -> FutureProvider.family is ideal.
final availabilityProvider = FutureProvider.family.autoDispose<List<BookingSlot>, AvailabilityKey>((ref, key) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final slots = await repo.fetchAvailability(
    placeId: key.placeId,
    dayLocal: DateTime(key.dayLocal.year, key.dayLocal.month, key.dayLocal.day),
    partySize: key.partySize,
  );
  return slots;
}); // FutureProvider.family exposes parameterized async fetches with caching and autoDispose for lifecycles. [15][18]

/// Quote/Reserve controller: imperative async workflow with explicit states.
@immutable
class BookingFlowState {
  const BookingFlowState._({
    required this.stage,
    this.quote,
    this.reservation,
    this.error,
  });

  final BookingStage stage;
  final BookingQuote? quote;
  final Reservation? reservation;
  final Object? error;

  const BookingFlowState.idle() : this._(stage: BookingStage.idle);
  const BookingFlowState.quoting() : this._(stage: BookingStage.quoting);
  const BookingFlowState.quoted(BookingQuote q) : this._(stage: BookingStage.quoted, quote: q);
  const BookingFlowState.reserving(BookingQuote q) : this._(stage: BookingStage.reserving, quote: q);
  const BookingFlowState.reserved(Reservation r) : this._(stage: BookingStage.reserved, reservation: r);
  const BookingFlowState.failure(Object e) : this._(stage: BookingStage.failure, error: e);
}

enum BookingStage { idle, quoting, quoted, reserving, reserved, failure }

/// AsyncNotifier for multi-step booking flows (quote -> confirm).
class BookingController extends AsyncNotifier<BookingFlowState> {
  @override
  FutureOr<BookingFlowState> build() {
    return const BookingFlowState.idle();
  } // AsyncNotifier can async-initialize and exposes ref for side-effects and reads. [1][3]

  Future<void> requestQuote({
    required String placeId,
    required String slotId,
    required int partySize,
    Map<String, Object?>? options,
  }) async {
    final repo = ref.read(bookingRepositoryProvider);
    state = const AsyncValue.loading();
    try {
      // stage: quoting
      final quoting = const BookingFlowState.quoting();
      state = AsyncValue.data(quoting);
      final q = await repo.createQuote(
        placeId: placeId,
        slotId: slotId,
        partySize: partySize,
        options: options,
      );
      state = AsyncValue.data(BookingFlowState.quoted(q));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      state = const AsyncValue.data(BookingFlowState.failure('Failed to quote'));
    }
  }

  Future<void> confirm({
    required String quoteId,
    Map<String, Object?>? payment,
  }) async {
    final repo = ref.read(bookingRepositoryProvider);
    final current = state.valueOrNull ?? const BookingFlowState.idle();
    final q = current.quote;
    state = const AsyncValue.loading();
    try {
      // stage: reserving (retain quote if available)
      final reserving = q == null ? const BookingFlowState.reserving(BookingQuote(quoteId: '', placeId: '', slotId: '', partySize: 0, expiresAt: DateTime(1970))) : BookingFlowState.reserving(q);
      state = AsyncValue.data(reserving);
      final r = await repo.confirmReservation(quoteId: quoteId, payment: payment);
      state = AsyncValue.data(BookingFlowState.reserved(r));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      state = const AsyncValue.data(BookingFlowState.failure('Failed to reserve'));
    }
  }

  void reset() {
    state = const AsyncValue.data(BookingFlowState.idle());
  }
}

/// Provider for booking flow controller.
final bookingControllerProvider = AsyncNotifierProvider<BookingController, BookingFlowState>(() {
  return BookingController();
}); // AsyncNotifierProvider wires the controller class to a watchable AsyncValue for UI. [1][3]

/// One-tap rebook controller (returns true on success).
class RebookController extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() {
    return false;
  } // AsyncNotifier build sets initial state, and methods can set AsyncLoading/guarded results. [1][2]

  Future<bool> rebook({required String previousReservationId, int? partySizeOverride}) async {
    final repo = ref.read(bookingRepositoryProvider);
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => repo.rebookFromHistory(
          previousReservationId: previousReservationId,
          partySizeOverride: partySizeOverride,
        ));
    state = result;
    return result.value ?? false;
  }
}

/// Provider for one-tap rebooking.
final rebookControllerProvider = AsyncNotifierProvider<RebookController, bool>(() {
  return RebookController();
}); // A dedicated AsyncNotifier cleanly encapsulates rebooking side-effects and exposes a boolean outcome. [1][4]

/// Facade for widgets that want simple function calls without managing controllers.
class BookingActions {
  BookingActions(this._read);
  final Ref _read;

  Future<List<BookingSlot>> availability({
    required String placeId,
    required DateTime dayLocal,
    required int partySize,
  }) {
    final key = AvailabilityKey(placeId: placeId, dayLocal: dayLocal, partySize: partySize);
    return _read(availabilityProvider(key).future);
  }

  Future<BookingQuote> quote({
    required String placeId,
    required String slotId,
    required int partySize,
    Map<String, Object?>? options,
  }) async {
    final ctl = _read(bookingControllerProvider.notifier);
    await ctl.requestQuote(placeId: placeId, slotId: slotId, partySize: partySize, options: options);
    final s = _read(bookingControllerProvider).valueOrNull;
    if (s?.quote == null) throw StateError('Quote not available');
    return s!.quote!;
  }

  Future<Reservation> reserve({required String quoteId, Map<String, Object?>? payment}) async {
    final ctl = _read(bookingControllerProvider.notifier);
    await ctl.confirm(quoteId: quoteId, payment: payment);
    final s = _read(bookingControllerProvider).valueOrNull;
    if (s?.reservation == null) throw StateError('Reservation not available');
    return s!.reservation!;
  }

  Future<bool> rebook({required String previousReservationId, int? partySizeOverride}) async {
    final ctl = _read(rebookControllerProvider.notifier);
    return ctl.rebook(previousReservationId: previousReservationId, partySizeOverride: partySizeOverride);
  }
}

/// Expose actions via a simple Provider for convenient read/ref usage in widgets.
final bookingActionsProvider = Provider<BookingActions>((ref) {
  return BookingActions(ref.read);
}); // A plain Provider exposes a small facade to simplify calling flows from UI callbacks. [15][12]

/// Example glue helpers for screens/widgets (optional).
extension BookingUiHelpers on WidgetRef {
  /// Attach to a RebookButton: onRebook: () => ref.read(bookingActionsProvider).rebook(...)
  Future<bool> rebookPrevious(String reservationId, {int? partySizeOverride}) {
    return read(bookingActionsProvider).rebook(previousReservationId: reservationId, partySizeOverride: partySizeOverride);
  }

  /// Observe booking flow in UI with ref.watch(bookingControllerProvider).
  AsyncValue<BookingFlowState> watchBookingFlow() => watch(bookingControllerProvider);
}

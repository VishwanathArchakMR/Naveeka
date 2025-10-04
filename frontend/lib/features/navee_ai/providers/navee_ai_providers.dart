// lib/features/navee_ai/providers/navee_ai_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/navee_ai_api.dart';
import '../presentation/widgets/ai_settings.dart';

/// Settings state & controller (immutable state exposed; methods to mutate).
class AiSettingsNotifier extends StateNotifier<AiSettings> {
  AiSettingsNotifier()
      : super(const AiSettings(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: '',
          model: 'gpt-4o-mini',
          temperature: 0.6,
          jsonOnly: true,
          stripFences: true,
        ));

  void setAll(AiSettings next) => state = next;

  void setBaseUrl(String v) => state = state.copyWith(baseUrl: v);
  void setApiKey(String v) => state = state.copyWith(apiKey: v);
  void setModel(String v) => state = state.copyWith(model: v);
  void setTemperature(double v) => state = state.copyWith(temperature: v);
  void setMaxTokens(int? v) => state = state.copyWith(maxTokens: v);
  void setJsonOnly(bool v) => state = state.copyWith(jsonOnly: v);
  void setStripFences(bool v) => state = state.copyWith(stripFences: v);
  void setUseModeration(bool v) => state = state.copyWith(useModeration: v);
}

/// Global AI settings provider (override in tests via ProviderScope.overrides).
final aiSettingsProvider =
    StateNotifierProvider<AiSettingsNotifier, AiSettings>((ref) {
  return AiSettingsNotifier();
}); // StateNotifierProvider exposes an immutable state and centralizes mutations in the notifier for maintainability. [1][2]

/// NaveeAiApi client derived from settings; rebuilt when settings change.
final naveeAiApiProvider = Provider<NaveeAiApi>((ref) {
  final s = ref.watch(aiSettingsProvider);
  return NaveeAiApi(
    baseUrl: s.baseUrl,
    apiKey: s.apiKey,
    defaultModel: s.model,
  );
}); // Provider is ideal for dependency injection of services; watching settings makes the client reactive to config changes. [4][7]

/// Chat request arguments for the chat family.
class ChatArgs {
  ChatArgs({
    required this.messages, // List<Map<String,String>> with "role" and "content"
    this.temperature,
    this.maxTokens,
    this.extra,
  });
  final List<Map<String, String>> messages;
  final double? temperature;
  final int? maxTokens;
  final Map<String, dynamic>? extra;

  @override
  bool operator ==(Object other) {
    return other is ChatArgs &&
        other.temperature == temperature &&
        other.maxTokens == maxTokens &&
        _listEquals(other.messages, messages) &&
        _mapEquals(other.extra, extra);
  }

  @override
  int get hashCode => Object.hash(
      temperature, maxTokens, _deepHash(messages), _deepHash(extra));

  static bool _listEquals(List a, List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals(Map? a, Map? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || a[k] != b[k]) return false;
    }
    return true;
  }

  static int _deepHash(Object? v) {
    if (v == null) return 0;
    if (v is List) return Object.hashAll(v.map(_deepHash));
    if (v is Map) {
      return Object.hashAll(
          v.entries.map((e) => Object.hash(e.key, _deepHash(e.value))));
    }
    return v.hashCode;
  }
}

/// Auto‑dispose family for calling chat; throws ApiError on failure.
final chatProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ChatArgs>((ref, args) async {
  final api = ref.watch(naveeAiApiProvider);
  final s = ref.read(aiSettingsProvider);
  final res = await api.chat(
    messages: args.messages,
    temperature: args.temperature ?? s.temperature,
    maxTokens: args.maxTokens ?? s.maxTokens,
    extra: args.extra,
  );
  return res.fold(
    onSuccess: (data) => data,
    onError: (e) => throw e,
  );
}); // FutureProvider.family performs and caches async operations parameterized by arguments; autoDispose frees memory when unused. [15][12][17]

/// Suggestion family (destination -> list of suggestions)
final suggestItinerariesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, destination) async {
  final api = ref.watch(naveeAiApiProvider);
  final res =
      await api.suggestItineraries(destination: destination, maxSuggestions: 6);
  return res.fold(
    onSuccess: (list) => list,
    onError: (e) => throw e,
  );
}); // Families associate unique states per parameter, which is ideal for requests keyed by destination or IDs. [12][6]

/// Plan-trip args & provider
class PlanTripArgs {
  const PlanTripArgs({
    required this.origin,
    required this.destination,
    required this.startDateIso,
    required this.endDateIso,
    this.adults = 2,
    this.children = 0,
    this.style,
    this.interests = const <String>[],
    this.currency,
    this.language,
  });

  final String origin;
  final String destination;
  final String startDateIso;
  final String endDateIso;
  final int adults;
  final int children;
  final String? style;
  final List<String> interests;
  final String? currency;
  final String? language;

  @override
  bool operator ==(Object other) {
    return other is PlanTripArgs &&
        other.origin == origin &&
        other.destination == destination &&
        other.startDateIso == startDateIso &&
        other.endDateIso == endDateIso &&
        other.adults == adults &&
        other.children == children &&
        other.style == style &&
        _listEquals(other.interests, interests) &&
        other.currency == currency &&
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(
        origin,
        destination,
        startDateIso,
        endDateIso,
        adults,
        children,
        style,
        Object.hashAll(interests),
        currency,
        language,
      );

  static bool _listEquals(List a, List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final planTripProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, PlanTripArgs>((ref, args) async {
  final api = ref.watch(naveeAiApiProvider);
  final s = ref.read(aiSettingsProvider);
  final res = await api.planTrip(
    origin: args.origin,
    destination: args.destination,
    startDateIso: args.startDateIso,
    endDateIso: args.endDateIso,
    adults: args.adults,
    children: args.children,
    style: args.style,
    interests: args.interests,
    currency: args.currency,
    language: args.language,
    model: s.model,
  );
  return res.fold(
    onSuccess: (data) => data,
    onError: (e) => throw e,
  );
}); // FutureProvider.family gives a clean async API surface for planning requests while letting the UI consume AsyncValue via ref.watch. [15][12]

/// Example: moderation wrapper (string input)
final moderationProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, input) async {
  final api = ref.watch(naveeAiApiProvider);
  final s = ref.read(aiSettingsProvider);
  if (!s.useModeration) return <String, dynamic>{'skipped': true};
  final res = await api.moderate(input: input);
  return res.fold(
    onSuccess: (data) => data,
    onError: (e) => throw e,
  );
}); // Providers can layer cross-cutting logic, and toggles from settings can gate network calls while keeping the API consistent. [16][4]

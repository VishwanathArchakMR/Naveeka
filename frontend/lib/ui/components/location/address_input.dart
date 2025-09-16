// lib/ui/components/location/address_input.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// Simple immutable address value object used by the input widget.
@immutable
class AddressModel {
  const AddressModel({
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = '',
    this.latitude,
    this.longitude,
  });

  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final double? latitude;
  final double? longitude;

  AddressModel copyWith({
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    double? latitude,
    double? longitude,
  }) {
    return AddressModel(
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

/// Signature for fetching suggestions for Address Line 1.
/// Return top suggestions for a query (already trimmed).
typedef FetchAddressSuggestions = Future<List<String>> Function(String query);

/// A Material 3 address form widget:
/// - Address line 1 (with optional async suggestions)
/// - Address line 2
/// - City, State/Province
/// - Postal/ZIP code
/// - Country (free text with optional dropdown suggestions list)
/// - "Use current location" and "Pick on map" hooks
/// - Debounced suggestion querying, surfaceContainerHighest backgrounds,
///   and wide‑gamut safe alpha via Color.withValues (no withOpacity).
class AddressInput extends StatefulWidget {
  const AddressInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.fetchSuggestions, // for Address line 1
    this.onUseMyLocation,
    this.onPickOnMap,
    this.countries, // optional dropdown list
    this.showActions = true,
    this.enabled = true,
    this.compact = false,
    this.requiredA1 = true,
    this.requiredCity = true,
    this.requiredState = false,
    this.requiredPostal = false,
    this.requiredCountry = false,
    this.debounce = const Duration(milliseconds: 250),
  });

  final AddressModel value;
  final ValueChanged<AddressModel> onChanged;

  /// Optional async suggestions provider for Address line 1.
  final FetchAddressSuggestions? fetchSuggestions;

  /// Optional quick action hooks.
  final VoidCallback? onUseMyLocation;
  final VoidCallback? onPickOnMap;

  /// Optional country choices to render a dropdown; falls back to free text.
  final List<String>? countries;

  /// Whether to show quick actions row.
  final bool showActions;

  /// Enable/disable the entire form.
  final bool enabled;

  /// Tighter paddings and sizes.
  final bool compact;

  /// Field requirement flags (validators will enforce when true).
  final bool requiredA1;
  final bool requiredCity;
  final bool requiredState;
  final bool requiredPostal;
  final bool requiredCountry;

  /// Debounce duration for suggestions fetch.
  final Duration debounce;

  @override
  State<AddressInput> createState() => _AddressInputState();
}

class _AddressInputState extends State<AddressInput> {
  late final TextEditingController _a1 = TextEditingController(text: widget.value.addressLine1);
  late final TextEditingController _a2 = TextEditingController(text: widget.value.addressLine2);
  late final TextEditingController _city = TextEditingController(text: widget.value.city);
  late final TextEditingController _state = TextEditingController(text: widget.value.state);
  late final TextEditingController _postal = TextEditingController(text: widget.value.postalCode);
  late final TextEditingController _country = TextEditingController(text: widget.value.country);

  final FocusNode _a1Focus = FocusNode();
  final FocusNode _a2Focus = FocusNode();
  final FocusNode _cityFocus = FocusNode();
  final FocusNode _stateFocus = FocusNode();
  final FocusNode _postalFocus = FocusNode();
  final FocusNode _countryFocus = FocusNode();

  // Suggestions for Address line 1 (kept in memory after debounce).
  List<String> _a1Suggestions = <String>[];
  Timer? _debounceTimer;

  @override
  void didUpdateWidget(AddressInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external value updates (controlled pattern).
    if (widget.value.addressLine1 != _a1.text) _a1.text = widget.value.addressLine1;
    if (widget.value.addressLine2 != _a2.text) _a2.text = widget.value.addressLine2;
    if (widget.value.city != _city.text) _city.text = widget.value.city;
    if (widget.value.state != _state.text) _state.text = widget.value.state;
    if (widget.value.postalCode != _postal.text) _postal.text = widget.value.postalCode;
    if (widget.value.country != _country.text) _country.text = widget.value.country;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _a1.dispose();
    _a2.dispose();
    _city.dispose();
    _state.dispose();
    _postal.dispose();
    _country.dispose();

    _a1Focus.dispose();
    _a2Focus.dispose();
    _cityFocus.dispose();
    _stateFocus.dispose();
    _postalFocus.dispose();
    _countryFocus.dispose();
    super.dispose();
  }

  void _emitChange() {
    widget.onChanged(
      widget.value.copyWith(
        addressLine1: _a1.text,
        addressLine2: _a2.text,
        city: _city.text,
        state: _state.text,
        postalCode: _postal.text,
        country: _country.text,
      ),
    );
  }

  void _debouncedSuggest(String query) {
    if (widget.fetchSuggestions == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () async {
      final q = query.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _a1Suggestions = <String>[]);
        return;
      }
      try {
        final list = await widget.fetchSuggestions!(q);
        if (!mounted) return;
        setState(() => _a1Suggestions = list);
      } catch (_) {
        // ignore suggestion fetch errors
      }
    });
  }

  String? _requiredValidator(String? v, {required bool requiredFlag, String field = 'This field'}) {
    if (!requiredFlag) return null;
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$field is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final dense = widget.compact;

    final inputPadding = dense
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);

    final decorationBase = InputDecoration(
      filled: true,
      fillColor: cs.surfaceContainerHighest, // modern neutral surface
      isDense: dense,
      contentPadding: inputPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final colGap = SizedBox(height: dense ? 10 : 12);
    final rowGap = SizedBox(width: dense ? 10 : 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Address Line 1 with optional suggestions
        if (widget.fetchSuggestions != null)
          _A1Autocomplete(
            controller: _a1,
            focusNode: _a1Focus,
            enabled: widget.enabled,
            label: 'Address line 1',
            decoration: decorationBase.copyWith(
              hintText: 'House / street / area',
              prefixIcon: const Icon(Icons.place_rounded),
            ),
            suggestions: _a1Suggestions,
            onChanged: (value) {
              _emitChange();
              _debouncedSuggest(value);
            },
            onSelected: (value) {
              _a1.text = value;
              _emitChange();
            },
            validator: (v) => _requiredValidator(v, requiredFlag: widget.requiredA1, field: 'Address line 1'),
          )
        else
          TextFormField(
            controller: _a1,
            focusNode: _a1Focus,
            enabled: widget.enabled,
            onChanged: (_) => _emitChange(),
            textInputAction: TextInputAction.next,
            decoration: decorationBase.copyWith(
              labelText: 'Address line 1',
              hintText: 'House / street / area',
              prefixIcon: const Icon(Icons.place_rounded),
            ),
            validator: (v) => _requiredValidator(v, requiredFlag: widget.requiredA1, field: 'Address line 1'),
          ),

        colGap,

        // Address Line 2
        TextFormField(
          controller: _a2,
          focusNode: _a2Focus,
          enabled: widget.enabled,
          onChanged: (_) => _emitChange(),
          textInputAction: TextInputAction.next,
          decoration: decorationBase.copyWith(
            labelText: 'Address line 2 (optional)',
            hintText: 'Apartment / suite / landmark',
            prefixIcon: const Icon(Icons.home_work_rounded),
          ),
        ),

        colGap,

        // Row: City + State
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _city,
                focusNode: _cityFocus,
                enabled: widget.enabled,
                onChanged: (_) => _emitChange(),
                textInputAction: TextInputAction.next,
                decoration: decorationBase.copyWith(
                  labelText: 'City',
                  prefixIcon: const Icon(Icons.location_city_rounded),
                ),
                validator: (v) => _requiredValidator(v, requiredFlag: widget.requiredCity, field: 'City'),
              ),
            ),
            rowGap,
            Expanded(
              child: TextFormField(
                controller: _state,
                focusNode: _stateFocus,
                enabled: widget.enabled,
                onChanged: (_) => _emitChange(),
                textInputAction: TextInputAction.next,
                decoration: decorationBase.copyWith(
                  labelText: 'State / Province',
                  prefixIcon: const Icon(Icons.map_rounded),
                ),
                validator: (v) => _requiredValidator(v, requiredFlag: widget.requiredState, field: 'State / Province'),
              ),
            ),
          ],
        ),

        colGap,

        // Row: Postal + Country (dropdown if provided)
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _postal,
                focusNode: _postalFocus,
                enabled: widget.enabled,
                onChanged: (_) => _emitChange(),
                textInputAction: TextInputAction.next,
                decoration: decorationBase.copyWith(
                  labelText: 'Postal / ZIP code',
                  prefixIcon: const Icon(Icons.tag_rounded),
                ),
                validator: (v) => _requiredValidator(v, requiredFlag: widget.requiredPostal, field: 'Postal / ZIP code'),
              ),
            ),
            rowGap,
            Expanded(
              child: widget.countries == null || widget.countries!.isEmpty
                  ? TextFormField(
                      controller: _country,
                      focusNode: _countryFocus,
                      enabled: widget.enabled,
                      onChanged: (_) => _emitChange(),
                      textInputAction: TextInputAction.done,
                      decoration: decorationBase.copyWith(
                        labelText: 'Country',
                        prefixIcon: const Icon(Icons.public_rounded),
                      ),
                      validator: (v) => _requiredValidator(v, requiredFlag: widget.requiredCountry, field: 'Country'),
                    )
                  : _CountryDropdown(
                      items: widget.countries!,
                      value: _country.text,
                      enabled: widget.enabled,
                      decoration: decorationBase.copyWith(
                        labelText: 'Country',
                        prefixIcon: const Icon(Icons.public_rounded),
                      ),
                      onChanged: (v) {
                        _country.text = v ?? '';
                        _emitChange();
                      },
                      validator: (v) =>
                          _requiredValidator(v, requiredFlag: widget.requiredCountry, field: 'Country'),
                    ),
            ),
          ],
        ),

        if (widget.showActions && (widget.onUseMyLocation != null || widget.onPickOnMap != null)) ...<Widget>[
          SizedBox(height: dense ? 8 : 10),
          Row(
            children: <Widget>[
              if (widget.onUseMyLocation != null)
                TextButton.icon(
                  onPressed: widget.enabled ? widget.onUseMyLocation : null,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Use current location'),
                ),
              const Spacer(),
              if (widget.onPickOnMap != null)
                OutlinedButton.icon(
                  onPressed: widget.enabled ? widget.onPickOnMap : null,
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                  label: const Text('Pick on map'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Autocomplete for Address line 1:
/// - Uses a given suggestions list (kept up-to-date by parent via debounced fetch)
/// - Filters locally for simple UX
class _A1Autocomplete extends StatelessWidget {
  const _A1Autocomplete({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.label,
    required this.decoration,
    required this.suggestions,
    required this.onChanged,
    required this.onSelected,
    required this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String label;
  final InputDecoration decoration;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue tev) {
        final q = tev.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        // Local filter over the last fetched set.
        return suggestions.where((s) => s.toLowerCase().contains(q));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, textEditingController, node, onFieldSubmitted) {
        // Keep external controller in sync with the field controller.
        if (textEditingController != controller) {
          textEditingController
            ..text = controller.text
            ..selection = controller.selection;
          textEditingController.addListener(() {
            controller
              ..text = textEditingController.text
              ..selection = textEditingController.selection;
          });
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          onChanged: onChanged,
          textInputAction: TextInputAction.next,
          decoration: decoration.copyWith(
            labelText: label,
          ),
          validator: validator,
        );
      },
      optionsViewBuilder: (context, onSelectedCb, opts) {
        final options = opts.toList(growable: false);
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, minWidth: 280),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest, // modern surface
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemBuilder: (context, i) {
                    final s = options[i];
                    return ListTile(
                      dense: true,
                      title: Text(s, maxLines: 2, overflow: TextOverflow.ellipsis),
                      leading: Icon(Icons.place_rounded, color: cs.onSurfaceVariant),
                      onTap: () => onSelectedCb(s),
                    );
                  },
                  separatorBuilder: (context, _) => Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 1.0),
                  ),
                  itemCount: options.length,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A dropdown-style country selector that still accepts manual typing when unfocused.
class _CountryDropdown extends StatefulWidget {
  const _CountryDropdown({
    required this.items,
    required this.value,
    required this.enabled,
    required this.decoration,
    required this.onChanged,
    required this.validator,
  });

  final List<String> items;
  final String value;
  final bool enabled;
  final InputDecoration decoration;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  @override
  State<_CountryDropdown> createState() => _CountryDropdownState();
}

class _CountryDropdownState extends State<_CountryDropdown> {
  late String? _selected = widget.value.isEmpty ? null : widget.value;

  @override
  void didUpdateWidget(_CountryDropdown old) {
    super.didUpdateWidget(old);
    if (widget.value != (old.value)) {
      _selected = widget.value.isEmpty ? null : widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selected != null && widget.items.contains(_selected) ? _selected : null,
      items: widget.items
          .map((c) => DropdownMenuItem<String>(
                value: c,
                child: Text(c),
              ))
          .toList(growable: false),
      onChanged: widget.enabled
          ? (v) {
              setState(() => _selected = v);
              widget.onChanged(v);
            }
          : null,
      decoration: widget.decoration,
      validator: widget.validator,
    );
  }
}

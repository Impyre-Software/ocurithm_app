import 'package:flutter/material.dart';
import 'package:ocurithm/core/utils/egypt_locations.dart';

/// Governorate (Alexandria by default) and, for Alexandria, an area picked from
/// its districts — the structured half of the patient-registration address. The
/// street details stay a free-text field on the form. Mirrors web's
/// `AddressPicker`.
class PatientAddressPicker extends StatelessWidget {
  const PatientAddressPicker({
    super.key,
    required this.governorate,
    required this.area,
    required this.onGovernorateChanged,
    required this.onAreaChanged,
  });

  final String governorate;
  final String? area;
  final ValueChanged<String> onGovernorateChanged;

  /// Null clears the area.
  final ValueChanged<String?> onAreaChanged;

  bool get _isAlexandria => governorate == EgyptLocations.defaultGovernorate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PickerField(
          label: 'Governorate',
          value: governorate,
          icon: Icons.map_outlined,
          onTap: () async {
            final picked = await _showSearchablePicker(
              context,
              title: 'Governorate',
              groups: {'': EgyptLocations.governorates},
              allowCustom: false,
            );
            if (picked != null) onGovernorateChanged(picked);
          },
        ),
        if (_isAlexandria) ...[
          const SizedBox(height: 12),
          _PickerField(
            label: 'Area',
            value: area,
            placeholder: 'Choose an area',
            icon: Icons.location_on_outlined,
            onClear: area == null ? null : () => onAreaChanged(null),
            onTap: () async {
              final picked = await _showSearchablePicker(
                context,
                title: 'Area',
                groups: EgyptLocations.alexandriaDistricts,
                allowCustom: true,
              );
              if (picked != null) onAreaChanged(picked);
            },
          ),
        ],
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.placeholder,
    this.onClear,
  });

  final String label;
  final String? value;
  final String? placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: theme.cardColor,
          prefixIcon: Icon(icon, color: theme.primaryColor),
          suffixIcon: onClear != null
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: theme.primaryColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: theme.primaryColor),
          ),
        ),
        child: Text(
          hasValue ? value! : (placeholder ?? ''),
          style: hasValue
              ? theme.textTheme.bodyLarge
              : theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
        ),
      ),
    );
  }
}

/// A searchable list in a bottom sheet. [groups] maps a heading ('' for none) to
/// its options. With [allowCustom], typed text that matches nothing can be used
/// as is.
Future<String?> _showSearchablePicker(
  BuildContext context, {
  required String title,
  required Map<String, List<String>> groups,
  required bool allowCustom,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _SearchablePickerSheet(
      title: title,
      groups: groups,
      allowCustom: allowCustom,
    ),
  );
}

class _SearchablePickerSheet extends StatefulWidget {
  const _SearchablePickerSheet({
    required this.title,
    required this.groups,
    required this.allowCustom,
  });

  final String title;
  final Map<String, List<String>> groups;
  final bool allowCustom;

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final term = _query.trim().toLowerCase();
    final filtered = <String, List<String>>{
      for (final entry in widget.groups.entries)
        entry.key: entry.value
            .where((option) => option.toLowerCase().contains(term))
            .toList(),
    }..removeWhere((_, options) => options.isEmpty);
    final hasExactMatch = widget.groups.values
        .expand((options) => options)
        .any((option) => option.toLowerCase() == term);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.allowCustom
                    ? 'Search, or type a new one'
                    : 'Search',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  if (widget.allowCustom && term.isNotEmpty && !hasExactMatch)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text('Use "${_query.trim()}"'),
                      onTap: () => Navigator.pop(context, _query.trim()),
                    ),
                  for (final entry in filtered.entries) ...[
                    if (entry.key.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.hintColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    for (final option in entry.value)
                      ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => Navigator.pop(context, option),
                      ),
                  ],
                  if (filtered.isEmpty && !widget.allowCustom)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No matches.'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

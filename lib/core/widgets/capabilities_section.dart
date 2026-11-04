import 'package:flutter/material.dart';
import '../../modules/Login/data/model/login_response.dart';

/// Picks which capabilities a user holds.
///
/// With a [catalog] the list is grouped by area, each capability shows the
/// plain-language description of what it unlocks, and task bundles at the top
/// tick everything a common job needs in one tap. Without one (an older API) it
/// falls back to a flat list. Mirrors web's `CapabilitiesField`.
class CapabilitiesSection extends StatefulWidget {
  final List<Capability> capabilities;
  final List<Capability> initialSelectedCapabilities;
  final Function(List<Capability>) onSelectionChanged;
  final bool? readOnly;
  final CapabilityCatalog? catalog;

  const CapabilitiesSection({
    Key? key,
    required this.capabilities,
    required this.initialSelectedCapabilities,
    required this.onSelectionChanged,
    this.readOnly = false,
    this.catalog,
  }) : super(key: key);

  @override
  State<CapabilitiesSection> createState() => _CapabilitiesSectionState();
}

class _CapabilitiesSectionState extends State<CapabilitiesSection>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Set<Capability> _selectedCapabilities;

  static const _otherGroup = CapabilityGroup(key: '__other', label: 'Other');

  @override
  void initState() {
    super.initState();
    _selectedCapabilities = _initializeSelectedCapabilities();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  Set<Capability> _initializeSelectedCapabilities() {
    final initialSet = <Capability>{};
    for (final initial in widget.initialSelectedCapabilities) {
      final matchingCapability = widget.capabilities.firstWhere(
        (cap) => cap.name == initial.name && cap.id == initial.id,
        orElse: () => initial,
      );
      initialSet.add(matchingCapability);
    }
    return initialSet;
  }

  @override
  void didUpdateWidget(CapabilitiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_areListsEqual(widget.initialSelectedCapabilities,
        oldWidget.initialSelectedCapabilities)) {
      setState(() {
        _selectedCapabilities = _initializeSelectedCapabilities();
      });
    }
  }

  bool _areListsEqual(List<Capability> list1, List<Capability> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _toggleSelection(Capability capability) {
    if (widget.readOnly == true) return;

    setState(() {
      if (_isSelected(capability)) {
        _selectedCapabilities.removeWhere(
            (cap) => cap.name == capability.name && cap.id == capability.id);
      } else {
        _selectedCapabilities.add(capability);
      }
      widget.onSelectionChanged(_selectedCapabilities.toList());
    });
  }

  bool _isSelected(Capability capability) {
    return _selectedCapabilities.any((selected) =>
        selected.name == capability.name && selected.id == capability.id);
  }

  /// The bundle's capabilities that exist in the catalog.
  List<Capability> _bundleCapabilities(CapabilityBundle bundle) => widget
      .capabilities
      .where((cap) => bundle.capabilities.contains(cap.name))
      .toList();

  /// A bundle only adds: removing is a deliberate per-box choice, since bundles
  /// share capabilities (most include "View appointments").
  void _applyBundle(CapabilityBundle bundle) {
    if (widget.readOnly == true) return;
    setState(() {
      for (final capability in _bundleCapabilities(bundle)) {
        if (!_isSelected(capability)) _selectedCapabilities.add(capability);
      }
      widget.onSelectionChanged(_selectedCapabilities.toList());
    });
  }

  /// Capabilities grouped by area in catalog order; unknown areas go to "Other".
  List<MapEntry<CapabilityGroup, List<Capability>>> _grouped() {
    final groups = widget.catalog?.groups ?? const <CapabilityGroup>[];
    final knownKeys = groups.map((group) => group.key).toSet();
    final byGroup = <String, List<Capability>>{};
    for (final capability in widget.capabilities) {
      final key = knownKeys.contains(capability.group)
          ? capability.group!
          : _otherGroup.key;
      byGroup.putIfAbsent(key, () => []).add(capability);
    }

    return [...groups, _otherGroup]
        .where((group) => byGroup[group.key]?.isNotEmpty ?? false)
        .map((group) {
      final items = byGroup[group.key]!
        ..sort((a, b) {
          final byOrder = (a.order ?? 1 << 30).compareTo(b.order ?? 1 << 30);
          return byOrder != 0 ? byOrder : a.title.compareTo(b.title);
        });
      return MapEntry(group, items);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(_isExpanded ? 8 : 30),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.1))
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: _toggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category, color: theme.primaryColor),
                      const SizedBox(width: 16),
                      Text(
                        'Capabilities',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedCapabilities.length}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: _isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: theme.dividerColor),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.catalog == null
                        ? widget.capabilities
                            .map((cap) => _buildRow(theme, cap))
                            .toList()
                        : [
                            if (widget.readOnly != true &&
                                widget.catalog!.bundles.isNotEmpty)
                              _buildBundles(theme),
                            ..._grouped().expand((entry) => [
                                  _buildGroupHeader(theme, entry),
                                  ...entry.value
                                      .map((cap) => _buildRow(theme, cap)),
                                ]),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundles(ThemeData theme) {
    final bundles = widget.catalog!.bundles
        .where((bundle) => _bundleCapabilities(bundle).isNotEmpty)
        .toList();
    if (bundles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add everything a job needs',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: bundles.map((bundle) {
              final isApplied =
                  _bundleCapabilities(bundle).every(_isSelected);
              return Tooltip(
                message: bundle.description,
                child: ActionChip(
                  avatar: Icon(isApplied ? Icons.check : Icons.add, size: 16),
                  label: Text(bundle.label),
                  onPressed: isApplied ? null : () => _applyBundle(bundle),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(
      ThemeData theme, MapEntry<CapabilityGroup, List<Capability>> entry) {
    final granted = entry.value.where(_isSelected).length;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.key.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text('$granted/${entry.value.length}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }

  Widget _buildRow(ThemeData theme, Capability capability) {
    final isSelected = _isSelected(capability);
    final description = capability.description?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap:
            widget.readOnly == true ? null : () => _toggleSelection(capability),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? theme.primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomCheckbox(
                isSelected: isSelected,
                onChanged: widget.readOnly == true
                    ? null
                    : (_) => _toggleSelection(capability),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(capability.title, style: theme.textTheme.bodyLarge),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomCheckbox extends StatelessWidget {
  final bool isSelected;
  final ValueChanged<bool>? onChanged;

  const CustomCheckbox({
    Key? key,
    required this.isSelected,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!isSelected) : null,
      child: Container(
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey,
          ),
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                size: 19,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}

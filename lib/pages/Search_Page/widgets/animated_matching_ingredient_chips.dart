import 'package:flutter/material.dart';

/// Per-chip enter/exit; the parent section should not re-animate on every keystroke.
class AnimatedMatchingIngredientChips extends StatefulWidget {
  const AnimatedMatchingIngredientChips({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.duration = const Duration(milliseconds: 240),
  });

  final List<String> suggestions;
  final void Function(String name) onSelected;
  final Duration duration;

  @override
  State<AnimatedMatchingIngredientChips> createState() =>
      _AnimatedMatchingIngredientChipsState();
}

class _AnimatedMatchingIngredientChipsState
    extends State<AnimatedMatchingIngredientChips> {
  final List<String> _renderOrder = [];
  final Set<String> _exiting = {};

  @override
  void initState() {
    super.initState();
    _syncToSuggestions(widget.suggestions, animate: false);
  }

  @override
  void didUpdateWidget(AnimatedMatchingIngredientChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_listEquals(oldWidget.suggestions, widget.suggestions)) {
      _syncToSuggestions(widget.suggestions, animate: true);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _syncToSuggestions(List<String> target, {required bool animate}) {
    final targetSet = target.toSet();
    var orderChanged = false;

    if (animate) {
      for (final name in List<String>.from(_renderOrder)) {
        if (!targetSet.contains(name) && !_exiting.contains(name)) {
          _exiting.add(name);
          orderChanged = true;
        }
      }
    } else {
      _exiting.clear();
      _renderOrder
        ..clear()
        ..addAll(target);
      return;
    }

    final nextOrder = <String>[...target];
    for (final name in _renderOrder) {
      if (_exiting.contains(name) && !nextOrder.contains(name)) {
        nextOrder.add(name);
      }
    }

    if (!_listEquals(_renderOrder, nextOrder) || orderChanged) {
      setState(() {
        _renderOrder
          ..clear()
          ..addAll(nextOrder);
      });
    } else if (orderChanged) {
      setState(() {});
    }
  }

  void _onChipExitComplete(String name) {
    if (!mounted) return;
    setState(() {
      _exiting.remove(name);
      _renderOrder.remove(name);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_renderOrder.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _renderOrder
          .map(
            (name) => _AnimatedMatchingChip(
              key: ValueKey(name),
              name: name,
              exiting: _exiting.contains(name),
              duration: widget.duration,
              onTap: () => widget.onSelected(name),
              onExitComplete: () => _onChipExitComplete(name),
            ),
          )
          .toList(),
    );
  }
}

class _AnimatedMatchingChip extends StatefulWidget {
  const _AnimatedMatchingChip({
    super.key,
    required this.name,
    required this.exiting,
    required this.onTap,
    required this.duration,
    this.onExitComplete,
  });

  final String name;
  final bool exiting;
  final VoidCallback onTap;
  final VoidCallback? onExitComplete;
  final Duration duration;

  @override
  State<_AnimatedMatchingChip> createState() => _AnimatedMatchingChipState();
}

class _AnimatedMatchingChipState extends State<_AnimatedMatchingChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.exiting) {
      _controller.value = 1;
      _runExit();
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedMatchingChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.exiting && widget.exiting) {
      _runExit();
    }
  }

  Future<void> _runExit() async {
    await _controller.reverse();
    widget.onExitComplete?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(_animation),
        child: ActionChip(
          label: Text(widget.name),
          onPressed: widget.exiting ? null : widget.onTap,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// An [IndexedStack] that builds a child the first time it is shown, then keeps
/// it alive.
///
/// Used by the tab shells so a heavy tab (the map) is not started until the user
/// opens it, while a visited tab keeps its scroll position and state.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    required this.index,
    required this.children,
    super.key,
  });

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final Set<int> _built = <int>{widget.index};

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _built.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: <Widget>[
        for (var i = 0; i < widget.children.length; i++)
          _built.contains(i) ? widget.children[i] : const SizedBox.shrink(),
      ],
    );
  }
}

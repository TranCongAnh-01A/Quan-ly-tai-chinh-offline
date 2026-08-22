import 'package:flutter/material.dart';

class FadeInSlideDown extends StatefulWidget {
  final Widget child;
  final int index;
  final double delay;

  const FadeInSlideDown({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = 0.1,
  });

  @override
  State<FadeInSlideDown> createState() => _FadeInSlideDownState();
}

class _FadeInSlideDownState extends State<FadeInSlideDown> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Staggered delay based on index
    Future.delayed(Duration(milliseconds: (widget.index * widget.delay * 1000).toInt()), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

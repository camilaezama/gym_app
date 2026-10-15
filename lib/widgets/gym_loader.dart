import 'package:flutter/material.dart';

/// Indicador de carga: una mancuerna que "late" (crece y se achica) y se
/// inclina levemente, como si alguien la estuviera levantando.
class GymLoader extends StatefulWidget {
  const GymLoader({super.key, this.size = 72, this.message});

  final double size;
  final String? message;

  @override
  State<GymLoader> createState() => _GymLoaderState();
}

class _GymLoaderState extends State<GymLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: .min,
      children: [
        AnimatedBuilder(
          animation: _curve,
          builder: (context, child) {
            final t = _curve.value;
            return Transform.rotate(
              angle: -0.35 + 0.7 * t,
              child: Transform.scale(scale: 0.75 + 0.4 * t, child: child),
            );
          },
          child: Icon(
            Icons.fitness_center,
            size: widget.size,
            color: scheme.primary,
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 20),
          Text(
            widget.message!,
            textAlign: .center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ],
    );
  }
}

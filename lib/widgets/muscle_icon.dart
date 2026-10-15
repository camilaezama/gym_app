import 'package:flutter/material.dart';

import '../data/gym_store.dart';
import '../models.dart';

/// La imagen de un ícono de músculo, pintada del color del tema. Si la
/// imagen todavía no está cargada en assets/muscles, muestra [fallback].
class MuscleIconImage extends StatelessWidget {
  const MuscleIconImage({
    super.key,
    required this.icon,
    required this.fallback,
    this.size = 20,
    this.color,
  });

  final MuscleIcon icon;
  final IconData fallback;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.secondary;
    return Image.asset(
      icon.asset,
      width: size,
      height: size,
      color: color,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Icon(fallback, size: size, color: color),
    );
  }
}

/// Ícono de un ejercicio: el de su músculo si tiene, si no el del tipo de
/// peso.
class ExerciseIcon extends StatelessWidget {
  const ExerciseIcon(this.exercise, {super.key, this.size = 20, this.color});

  final Exercise exercise;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = gymStore.muscleOf(exercise)?.icon;
    if (icon == null) {
      return Icon(exercise.weightType.icon, size: size, color: color);
    }
    return MuscleIconImage(
      icon: icon,
      fallback: exercise.weightType.icon,
      size: size,
      color: color ?? IconTheme.of(context).color,
    );
  }
}

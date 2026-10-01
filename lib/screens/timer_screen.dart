import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/gym_store.dart';

enum _Phase { idle, preparing, running, done }

/// Cuenta regresiva configurable, con tiempo de preparación opcional.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int _minutes = 1;
  int _seconds = 0;
  bool _withPrep = false;

  _Phase _phase = .idle;
  bool _paused = false;
  Timer? _ticker;

  /// Momento en que termina la fase actual. Se calcula contra el reloj (y no
  /// contando ticks) para que no se atrase si el navegador frena la pestaña.
  DateTime _phaseEnd = DateTime(0);

  /// Tiempo que le queda a la fase actual.
  Duration _left = Duration.zero;

  /// Tiempo de preparación con el que arrancó la cuenta actual. Se fija al
  /// iniciar para que cambiarlo en Perfil no afecte una cuenta en curso.
  Duration _prepTime = Duration.zero;

  Duration get _total => Duration(minutes: _minutes, seconds: _seconds);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _prepTime = Duration(seconds: gymStore.prepSeconds);
    final first = _withPrep ? _prepTime : _total;
    setState(() {
      _phase = _withPrep ? .preparing : .running;
      _paused = false;
      _left = first;
      _phaseEnd = clock.now().add(first);
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    if (_paused) return;
    var phase = _phase;
    var left = _phaseEnd.difference(clock.now());
    if (phase == _Phase.preparing && left <= Duration.zero) {
      phase = .running;
      _phaseEnd = _phaseEnd.add(_total);
      left = _phaseEnd.difference(clock.now());
    }
    if (phase == _Phase.running && left <= Duration.zero) {
      phase = .done;
      left = Duration.zero;
      _ticker?.cancel();
    }
    setState(() {
      _phase = phase;
      _left = left;
    });
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (!_paused) _phaseEnd = clock.now().add(_left);
    });
  }

  void _reset() {
    _ticker?.cancel();
    setState(() => _phase = .idle);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = _phase == _Phase.done;
    // Al terminar toda la pantalla se pone roja para que se note de lejos.
    return Material(
      color: done ? scheme.error : Colors.transparent,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Temporizador',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: done ? scheme.onError : null,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: _phase == _Phase.idle
                    ? _buildSetup()
                    : _buildCountdown(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetup() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: .center,
          children: [
            _Wheel(
              label: 'min',
              value: _minutes,
              onChanged: (value) => setState(() => _minutes = value),
            ),
            const SizedBox(width: 24),
            _Wheel(
              label: 'seg',
              value: _seconds,
              onChanged: (value) => setState(() => _seconds = value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Los segundos se configuran en Perfil.
        ListenableBuilder(
          listenable: gymStore,
          builder: (context, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tiempo de preparación'),
            subtitle: Text(
              gymStore.prepSeconds == 1
                  ? '1 segundo antes de empezar'
                  : '${gymStore.prepSeconds} segundos antes de empezar',
            ),
            value: _withPrep,
            onChanged: (value) => setState(() => _withPrep = value),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _total == Duration.zero ? null : _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar'),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    final scheme = Theme.of(context).colorScheme;
    final preparing = _phase == _Phase.preparing;
    final done = _phase == _Phase.done;
    final phaseTotal = preparing ? _prepTime : _total;
    // Se redondea hacia arriba para que el 0 aparezca recién al terminar.
    final secondsLeft = (_left.inMilliseconds / 1000).ceil();
    // Sobre el fondo rojo del final, todo va en el color de contraste.
    final foreground = done ? scheme.onError : scheme.onSurface;
    return Column(
      children: [
        SizedBox.square(
          dimension: 250,
          child: Stack(
            fit: .expand,
            children: [
              CircularProgressIndicator(
                value: _left.inMilliseconds / phaseTotal.inMilliseconds,
                strokeWidth: 10,
                strokeCap: .round,
                color: preparing ? scheme.secondary : scheme.primary,
                backgroundColor: done
                    ? scheme.onError.withValues(alpha: 0.3)
                    : scheme.surfaceContainer,
              ),
              Column(
                mainAxisAlignment: .center,
                children: [
                  Text(
                    preparing
                        ? 'Preparate'
                        : done
                        ? '¡Tiempo!'
                        : _paused
                        ? 'En pausa'
                        : '',
                    style: TextStyle(
                      fontSize: done ? 30 : 16,
                      fontWeight: done ? .bold : null,
                      color: done ? foreground : scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    preparing ? '$secondsLeft' : _formatClock(secondsLeft),
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: .w600,
                      color: foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: done
                    ? OutlinedButton.styleFrom(
                        foregroundColor: foreground,
                        side: BorderSide(color: foreground),
                      )
                    : null,
                child: Text(done ? 'Listo' : 'Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: done
                  ? FilledButton.icon(
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: foreground,
                        foregroundColor: scheme.error,
                      ),
                      icon: const Icon(Icons.replay),
                      label: const Text('Repetir'),
                    )
                  : FilledButton.icon(
                      onPressed: _togglePause,
                      icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                      label: Text(_paused ? 'Reanudar' : 'Pausar'),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// mm:ss
String _formatClock(int totalSeconds) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(totalSeconds ~/ 60)}:${two(totalSeconds % 60)}';
}

/// Rueda para elegir un valor de 0 a 59.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 80,
          height: 180,
          // Por defecto el mouse no arrastra listas: se habilita para poder
          // usar la rueda también desde la computadora.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {...PointerDeviceKind.values},
            ),
            child: CupertinoPicker(
              scrollController: _controller,
              itemExtent: 52,
              looping: true,
              selectionOverlay: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSelectedItemChanged: widget.onChanged,
              children: [
                for (var i = 0; i < 60; i++)
                  Center(
                    child: Text(
                      i.toString().padLeft(2, '0'),
                      style: TextStyle(fontSize: 34, color: scheme.onSurface),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(widget.label, style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

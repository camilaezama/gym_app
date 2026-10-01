import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'bottom_inset_stub.dart'
    if (dart.library.js_interop) 'bottom_inset_web.dart';

/// Parte de la franja que se reserva. La franja completa que informa el
/// iPhone (34 px) deja demasiado espacio vacío: con la mitad el menú ya no
/// queda debajo de la línea de inicio. Subir hacia 1 para dejar más espacio.
const _insetFraction = 0.5;

/// Reserva la franja inferior de la barra de gestos del celular (la línea de
/// inicio del iPhone), para que la app no quede dibujada debajo.
///
/// Flutter web no siempre informa esa franja: acá se la mide en el navegador
/// y se la suma al MediaQuery, así SafeArea y las barras inferiores la
/// respetan.
class BottomSafeArea extends StatefulWidget {
  const BottomSafeArea({super.key, required this.child});

  final Widget child;

  @override
  State<BottomSafeArea> createState() => _BottomSafeAreaState();
}

class _BottomSafeAreaState extends State<BottomSafeArea>
    with WidgetsBindingObserver {
  double _inset = 0;
  final List<Timer> _retries = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inset = measureBottomInset() * _insetFraction;
    // El navegador puede tardar en informar la franja: se vuelve a medir
    // varias veces mientras la página termina de armarse.
    for (final delay in const [100, 500, 1500, 4000]) {
      _retries.add(Timer(Duration(milliseconds: delay), _measure));
    }
  }

  @override
  void dispose() {
    for (final timer in _retries) {
      timer.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Cambia, por ejemplo, al girar el celular.
  @override
  void didChangeMetrics() => _measure();

  void _measure() {
    final inset = measureBottomInset() * _insetFraction;
    if (mounted && inset != _inset) setState(() => _inset = inset);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          bottom: max(media.padding.bottom, _inset),
        ),
        viewPadding: media.viewPadding.copyWith(
          bottom: max(media.viewPadding.bottom, _inset),
        ),
      ),
      child: widget.child,
    );
  }
}

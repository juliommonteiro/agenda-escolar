import 'package:flutter/material.dart';

import 'Screens/login_screen.dart';
import 'sessao.dart';

/// Transição de tela com efeito de "fade".
Route<T> rotaSuave<T>(Widget pagina) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => pagina,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

/// Transição de tela subindo de baixo para cima (formulários).
Route<T> rotaDeBaixo<T>(Widget pagina) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => pagina,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.ease));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

/// Encerra a sessão e volta para a tela de login.
void sair(BuildContext context) {
  Sessao.encerrar();
  Navigator.pushAndRemoveUntil(context, rotaSuave(const LoginScreen()), (_) => false);
}

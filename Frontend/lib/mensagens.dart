import 'package:flutter/material.dart';

import 'api_config.dart';

void mostrarMensagem(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(texto),
      backgroundColor: erro ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Mostra o erro para o usuário. Sessão expirada já é tratada no main.dart.
void mostrarErro(BuildContext context, Object erro) {
  if (erro is SessaoExpiradaException) return;
  mostrarMensagem(context, erro.toString().replaceAll('Exception: ', ''), erro: true);
}

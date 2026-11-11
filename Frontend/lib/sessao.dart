/// Guarda o token JWT e os dados do usuário logado enquanto o app está aberto.
class Sessao {
  static String? token;
  static Map<String, dynamic>? usuario;

  static int? get usuarioId => usuario?['id'] as int?;

  static void iniciar(String novoToken, Map<String, dynamic> dadosUsuario) {
    token = novoToken;
    usuario = dadosUsuario;
  }

  static void encerrar() {
    token = null;
    usuario = null;
  }
}

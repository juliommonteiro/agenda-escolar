import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'sessao.dart';

/// Lançada quando o token expira ou fica inválido. O app volta para o login.
class SessaoExpiradaException implements Exception {
  @override
  String toString() => 'Sua sessão expirou. Faça login novamente.';
}

/// Endereço da API em Python e funções para chamar as rotas.
///
/// - Emulador Android: http://10.0.2.2:8000 (o "localhost" do computador)
/// - Web / Desktop / iOS Simulator: http://127.0.0.1:8000
/// - Celular físico: rode com
///   `flutter run --dart-define=API_URL=http://IP_DO_COMPUTADOR:8000`
class ApiConfig {
  static const String _urlDefinida = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_urlDefinida.isNotEmpty) return _urlDefinida;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Chamado quando a API responde 401 (token expirado). Definido no main.dart.
  static VoidCallback? aoExpirarSessao;

  static Uri _uri(String caminho) => Uri.parse('$baseUrl$caminho');

  /// Cabeçalhos de toda requisição, incluindo o token JWT se o usuário estiver logado.
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        if (Sessao.token != null) 'Authorization': 'Bearer ${Sessao.token}',
      };

  static Future<http.Response> get(String caminho) =>
      _enviar(() => http.get(_uri(caminho), headers: _headers));

  static Future<http.Response> post(String caminho, Object? corpo) =>
      _enviar(() => http.post(_uri(caminho), headers: _headers, body: jsonEncode(corpo)));

  static Future<http.Response> put(String caminho, Object? corpo) =>
      _enviar(() => http.put(_uri(caminho), headers: _headers, body: jsonEncode(corpo)));

  static Future<http.Response> delete(String caminho) =>
      _enviar(() => http.delete(_uri(caminho), headers: _headers));

  /// Executa a requisição tratando falta de conexão e sessão expirada.
  static Future<http.Response> _enviar(Future<http.Response> Function() requisicao) async {
    final http.Response resposta;
    try {
      resposta = await requisicao().timeout(const Duration(seconds: 10));
    } catch (_) {
      throw Exception('Não foi possível conectar ao servidor. Verifique se a API está rodando.');
    }

    if (resposta.statusCode == 401 && Sessao.token != null) {
      Sessao.encerrar();
      aoExpirarSessao?.call();
      throw SessaoExpiradaException();
    }
    return resposta;
  }

  /// Lê o JSON da resposta respeitando acentos (UTF-8).
  static dynamic lerJson(http.Response resposta) => jsonDecode(utf8.decode(resposta.bodyBytes));

  /// Lança uma exceção com a mensagem da API (campo "detail") se a resposta não for 200.
  static void verificar(http.Response resposta, String mensagemPadrao) {
    if (resposta.statusCode == 200) return;
    String mensagem = mensagemPadrao;
    try {
      final dados = lerJson(resposta);
      if (dados is Map && dados['detail'] is String) mensagem = dados['detail'] as String;
    } catch (_) {}
    throw Exception(mensagem);
  }
}

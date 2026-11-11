import 'api_config.dart';
import 'sessao.dart';

class UsuarioRepository {
  /// Faz login, guarda o token na [Sessao] e retorna os dados do usuário: {id, nome, email, perfil}
  Future<Map<String, dynamic>> fazerLogin(String email, String senha, String perfil) async {
    Sessao.encerrar(); // garante que não há token antigo
    final resposta = await ApiConfig.post('/login/', {'email': email, 'senha': senha, 'perfil': perfil});
    ApiConfig.verificar(resposta, 'E-mail, senha ou perfil incorretos.');

    final dados = ApiConfig.lerJson(resposta) as Map;
    final usuario = Map<String, dynamic>.from(dados['usuario'] as Map);
    Sessao.iniciar(dados['access_token'] as String, usuario);
    return usuario;
  }

  // --- Somente Coordenador ---

  Future<List<Map<String, dynamic>>> listarUsuarios() async {
    final resposta = await ApiConfig.get('/usuarios/');
    ApiConfig.verificar(resposta, 'Falha ao carregar os usuários.');
    final lista = ApiConfig.lerJson(resposta) as List<dynamic>;
    return lista.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> criarUsuario(Map<String, dynamic> usuario) async {
    final resposta = await ApiConfig.post('/usuarios/', usuario);
    ApiConfig.verificar(resposta, 'Não foi possível criar a conta.');
  }

  Future<void> deletarUsuario(int id) async {
    final resposta = await ApiConfig.delete('/usuarios/$id');
    ApiConfig.verificar(resposta, 'Não foi possível excluir o usuário.');
  }
}

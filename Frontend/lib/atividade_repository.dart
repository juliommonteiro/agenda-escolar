import 'api_config.dart';

class AtividadeRepository {
  // Busca as atividades no Python (GET).
  // O aluno é identificado pelo token, então "concluida" já vem com o progresso DELE.
  Future<List<Map<String, dynamic>>> listarAtividades() async {
    final resposta = await ApiConfig.get('/atividades/');
    ApiConfig.verificar(resposta, 'Falha ao carregar as atividades.');
    final lista = ApiConfig.lerJson(resposta) as List<dynamic>;
    return lista.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // Envia uma nova atividade para o Python (POST)
  Future<void> criarAtividade(Map<String, dynamic> atividade) async {
    final resposta = await ApiConfig.post('/atividades/', atividade);
    ApiConfig.verificar(resposta, 'Falha ao salvar a atividade.');
  }

  // Atualiza uma atividade existente no Python (PUT)
  Future<void> atualizarAtividade(int id, Map<String, dynamic> atividade) async {
    final resposta = await ApiConfig.put('/atividades/$id', atividade);
    ApiConfig.verificar(resposta, 'Falha ao atualizar a atividade.');
  }

  // O aluno logado marca/desmarca uma tarefa como concluída
  Future<void> marcarConclusao(int atividadeId, bool concluida) async {
    final resposta = await ApiConfig.put('/atividades/$atividadeId/conclusao', {'concluida': concluida});
    ApiConfig.verificar(resposta, 'Falha ao salvar no servidor.');
  }

  // Deleta uma atividade no Python (DELETE)
  Future<void> deletarAtividade(int id) async {
    final resposta = await ApiConfig.delete('/atividades/$id');
    ApiConfig.verificar(resposta, 'Falha ao excluir a atividade.');
  }
}

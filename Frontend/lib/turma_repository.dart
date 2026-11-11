import 'api_config.dart';

class TurmaRepository {
  /// Coordenador recebe todas; professor, as que leciona; aluno, a sua.
  /// Cada turma: {id, nome, professor: {id, nome, email} | null, alunos: [{id, nome, email}]}
  Future<List<Map<String, dynamic>>> listarTurmas() async {
    final resposta = await ApiConfig.get('/turmas/');
    ApiConfig.verificar(resposta, 'Falha ao carregar as turmas.');
    final lista = ApiConfig.lerJson(resposta) as List<dynamic>;
    return lista.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // --- Somente Coordenador ---

  Future<void> criarTurma(String nome, int? professorId, List<int> alunoIds) async {
    final resposta = await ApiConfig.post('/turmas/', _corpo(nome, professorId, alunoIds));
    ApiConfig.verificar(resposta, 'Não foi possível criar a turma.');
  }

  Future<void> atualizarTurma(int id, String nome, int? professorId, List<int> alunoIds) async {
    final resposta = await ApiConfig.put('/turmas/$id', _corpo(nome, professorId, alunoIds));
    ApiConfig.verificar(resposta, 'Não foi possível salvar a turma.');
  }

  Future<void> deletarTurma(int id) async {
    final resposta = await ApiConfig.delete('/turmas/$id');
    ApiConfig.verificar(resposta, 'Não foi possível excluir a turma.');
  }

  Map<String, dynamic> _corpo(String nome, int? professorId, List<int> alunoIds) =>
      {'nome': nome, 'professor_id': professorId, 'aluno_ids': alunoIds};
}

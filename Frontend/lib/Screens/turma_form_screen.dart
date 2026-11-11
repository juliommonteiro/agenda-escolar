import 'package:flutter/material.dart';
import '../mensagens.dart';
import '../turma_repository.dart';
import '../usuario_repository.dart';

/// Criar (sem [turma]) ou editar (com [turma]) uma turma: nome, professor e alunos.
/// Retorna `true` ao salvar, para a lista ser recarregada.
class TurmaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? turma;

  const TurmaFormScreen({super.key, this.turma});

  @override
  State<TurmaFormScreen> createState() => _TurmaFormScreenState();
}

class _TurmaFormScreenState extends State<TurmaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _buscaController = TextEditingController();
  final _turmaRepository = TurmaRepository();
  final _usuarioRepository = UsuarioRepository();

  List<Map<String, dynamic>> _professores = [];
  List<Map<String, dynamic>> _alunos = [];
  int? _professorId;
  final Set<int> _alunosSelecionados = {};
  bool _carregando = true;
  bool _salvando = false;

  bool get _isEdicao => widget.turma != null;

  @override
  void initState() {
    super.initState();
    final turma = widget.turma;
    if (turma != null) {
      _nomeController.text = turma['nome'] ?? '';
      _professorId = (turma['professor'] as Map?)?['id'] as int?;
      for (final aluno in (turma['alunos'] as List? ?? [])) {
        _alunosSelecionados.add((aluno as Map)['id'] as int);
      }
    }
    _buscaController.addListener(() => setState(() {}));
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final usuarios = await _usuarioRepository.listarUsuarios();
      if (!mounted) return;
      setState(() {
        _professores = usuarios.where((u) => u['perfil'] == 'Professor').toList();
        _alunos = usuarios.where((u) => u['perfil'] == 'Aluno').toList();
        if (!_professores.any((p) => p['id'] == _professorId)) _professorId = null;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, e);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final nome = _nomeController.text.trim();
      final alunos = _alunosSelecionados.toList();
      if (_isEdicao) {
        await _turmaRepository.atualizarTurma(widget.turma!['id'] as int, nome, _professorId, alunos);
      } else {
        await _turmaRepository.criarTurma(nome, _professorId, alunos);
      }
      if (!mounted) return;
      mostrarMensagem(context, _isEdicao ? 'Turma atualizada!' : 'Turma criada com sucesso!');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarErro(context, e);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_isEdicao ? 'Editar Turma' : 'Nova Turma', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan, Colors.lightBlueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TextFormField(
                    controller: _nomeController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nome da turma',
                      hintText: 'Ex.: 3º Ano A',
                      prefixIcon: Icon(Icons.groups_outlined, color: Colors.cyan),
                    ),
                    validator: (valor) => (valor == null || valor.trim().isEmpty) ? 'Informe o nome da turma' : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int?>(
                    initialValue: _professorId,
                    decoration: const InputDecoration(
                      labelText: 'Professor responsável',
                      prefixIcon: Icon(Icons.co_present_outlined, color: Colors.cyan),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Sem professor')),
                      for (final professor in _professores)
                        DropdownMenuItem<int?>(value: professor['id'] as int, child: Text(professor['nome'] as String)),
                    ],
                    onChanged: (valor) => setState(() => _professorId = valor),
                  ),
                  const SizedBox(height: 28),
                  _buildCabecalhoAlunos(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _buscaController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar aluno por nome ou e-mail',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildListaAlunos(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _salvando ? null : _salvar,
                    child: _salvando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _isEdicao ? 'SALVAR ALTERAÇÕES' : 'CRIAR TURMA',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCabecalhoAlunos() {
    return Row(
      children: [
        const Expanded(
          child: Text('Alunos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Text(
          '${_alunosSelecionados.length} selecionado(s)',
          style: TextStyle(color: Colors.cyan[700], fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  List<Widget> _buildListaAlunos() {
    if (_alunos.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Nenhum aluno cadastrado. Cadastre alunos na aba "Usuários".',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }

    final busca = _buscaController.text.trim().toLowerCase();
    final filtrados = _alunos.where((a) {
      if (busca.isEmpty) return true;
      return '${a['nome']} ${a['email']}'.toLowerCase().contains(busca);
    });

    return [
      for (final aluno in filtrados) _buildItemAluno(aluno),
    ];
  }

  Widget _buildItemAluno(Map<String, dynamic> aluno) {
    final id = aluno['id'] as int;
    final selecionado = _alunosSelecionados.contains(id);
    final turmaAtualId = aluno['turma_id'] as int?;
    final turmaAtualNome = aluno['turma_nome'] as String?;
    // Aluno que está em OUTRA turma será transferido para esta ao salvar
    final emOutraTurma = turmaAtualId != null && turmaAtualId != widget.turma?['id'];

    String? subtitulo = aluno['email'] as String?;
    if (emOutraTurma) {
      subtitulo = selecionado
          ? '$subtitulo\nSerá transferido de "$turmaAtualNome"'
          : '$subtitulo\nAtualmente em "$turmaAtualNome"';
    }

    return CheckboxListTile(
      value: selecionado,
      activeColor: Colors.cyan,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(aluno['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitulo ?? '',
        style: TextStyle(color: emOutraTurma && selecionado ? Colors.orange[800] : Colors.grey[700]),
      ),
      isThreeLine: emOutraTurma,
      onChanged: (marcado) => setState(() {
        if (marcado == true) {
          _alunosSelecionados.add(id);
        } else {
          _alunosSelecionados.remove(id);
        }
      }),
    );
  }
}

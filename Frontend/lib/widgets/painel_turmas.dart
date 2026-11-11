import 'package:flutter/material.dart';
import '../Screens/turma_form_screen.dart';
import '../mensagens.dart';
import '../turma_repository.dart';

/// Lista de turmas com criar / editar / excluir. Usado somente pelo Coordenador.
class PainelTurmas extends StatefulWidget {
  const PainelTurmas({super.key});

  @override
  State<PainelTurmas> createState() => _PainelTurmasState();
}

class _PainelTurmasState extends State<PainelTurmas> {
  final TurmaRepository _repository = TurmaRepository();
  List<Map<String, dynamic>> _turmas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final dados = await _repository.listarTurmas();
      if (!mounted) return;
      setState(() {
        _turmas = dados;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarErro(context, e);
    }
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? turma}) async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => TurmaFormScreen(turma: turma)),
    );
    if (salvou == true && mounted) {
      setState(() => _isLoading = true);
      await _carregarDados();
    }
  }

  Future<void> _excluir(Map<String, dynamic> turma) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Turma?'),
        content: Text(
          'A turma "${turma['nome']}" será apagada definitivamente.\n\n'
          'Todas as atividades dela também serão excluídas, e os alunos ficarão sem turma.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _repository.deletarTurma(turma['id'] as int);
      await _carregarDados();
      if (!mounted) return;
      mostrarMensagem(context, 'Turma excluída com sucesso!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : RefreshIndicator(
              color: Colors.cyan,
              onRefresh: _carregarDados,
              child: _turmas.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Icon(Icons.groups_outlined, size: 80, color: Colors.cyan[200]),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhuma turma cadastrada.\nToque em "Nova Turma" para começar.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: _turmas.length,
                      itemBuilder: (context, index) => _buildCard(_turmas[index]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _isLoading ? null : () => _abrirFormulario(),
        backgroundColor: Colors.cyan,
        elevation: 4,
        icon: const Icon(Icons.group_add, color: Colors.white),
        label: const Text('Nova Turma', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> turma) {
    final professor = turma['professor'] as Map?;
    final totalAlunos = (turma['alunos'] as List? ?? []).length;

    return Card(
      elevation: 4,
      shadowColor: Colors.cyan.withValues(alpha: 0.2),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _abrirFormulario(turma: turma),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.groups_rounded, color: Colors.cyan[700], size: 28),
        ),
        title: Text(turma['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.co_present_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      professor == null ? 'Sem professor' : professor['nome'] as String,
                      style: TextStyle(
                        color: professor == null ? Colors.orange[800] : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.school_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('$totalAlunos aluno(s)', style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: 'Excluir',
          onPressed: () => _excluir(turma),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../atividade_repository.dart';
import '../formatadores.dart';
import '../mensagens.dart';
import '../navegacao.dart';
import '../turma_repository.dart';

class AlunoDashboard extends StatefulWidget {
  /// Dados do aluno logado: {id, nome, email, perfil}
  final Map<String, dynamic> usuario;

  const AlunoDashboard({super.key, required this.usuario});

  @override
  State<AlunoDashboard> createState() => _AlunoDashboardState();
}

class _AlunoDashboardState extends State<AlunoDashboard> {
  final AtividadeRepository _repository = AtividadeRepository();
  final TurmaRepository _turmaRepository = TurmaRepository();
  List<Map<String, dynamic>> _atividades = [];
  String? _turmaNome; // null = aluno ainda sem turma
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  // Função que busca os dados no Python (com o progresso DESTE aluno)
  Future<void> _carregarDados() async {
    try {
      // A API devolve só as atividades da turma do aluno
      final resultados = await Future.wait([
        _repository.listarAtividades(),
        _turmaRepository.listarTurmas(),
      ]);
      if (!mounted) return;
      setState(() {
        _atividades = resultados[0];
        final turmas = resultados[1];
        _turmaNome = turmas.isEmpty ? null : turmas.first['nome'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarErro(context, e);
    }
  }

  Future<void> _alternarConclusao(Map<String, dynamic> item, bool concluida) async {
    // Salva o status anterior caso dê erro na internet
    final statusAnterior = item['concluida'];
    setState(() => item['concluida'] = concluida);

    try {
      await _repository.marcarConclusao(item['id'] as int, concluida);
    } catch (e) {
      if (!mounted) return;
      // Se der erro, desfaz a animação visual e avisa o aluno
      setState(() => item['concluida'] = statusAnterior);
      mostrarErro(context, e);
    }
  }

  void _mostrarDetalhes(Map<String, dynamic> item) {
    final isTarefa = item['tipo'] == 'Tarefa';
    final cor = isTarefa ? Colors.cyan : Colors.orange;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isTarefa ? Icons.menu_book_rounded : Icons.event_note_rounded, color: cor),
                  const SizedBox(width: 8),
                  Text(
                    isTarefa ? 'Tarefa' : 'Evento Escolar',
                    style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item['titulo'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                  Text(
                    '${isTarefa ? 'Entrega' : 'Data'}: ${formatarData(item['data'])}',
                    style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(
                item['descricao'] ?? 'Nenhuma descrição informada.',
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tarefas = _atividades.where((a) => a['tipo'] == 'Tarefa').toList();
    final concluidas = tarefas.where((a) => a['concluida'] == true).length;
    final progresso = tarefas.isNotEmpty ? concluidas / tarefas.length : 0.0;
    final primeiroNome = (widget.usuario['nome'] as String? ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Agenda do Aluno', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan, Colors.lightBlueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sair',
            onPressed: () => sair(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan)) // Bolinha de carregamento
          : RefreshIndicator(
              color: Colors.cyan,
              onRefresh: _carregarDados,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCardProgresso(primeiroNome, concluidas, tarefas.length, progresso),
                  const SizedBox(height: 16),
                  if (_atividades.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(
                            _turmaNome == null ? Icons.group_off_outlined : Icons.celebration_outlined,
                            size: 80,
                            color: Colors.cyan[200],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _turmaNome == null
                                ? 'Você ainda não está em nenhuma turma.\nFale com a coordenação.'
                                : 'Nenhuma atividade por enquanto!',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ..._atividades.map(_buildCardAtividade),
                ],
              ),
            ),
    );
  }

  Widget _buildCardProgresso(String nome, int concluidas, int total, double progresso) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Olá, $nome!',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          if (_turmaNome != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 16, color: Colors.cyan[700]),
                const SizedBox(width: 4),
                Text(_turmaNome!, style: TextStyle(color: Colors.cyan[700], fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Seu progresso nas tarefas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '$concluidas de $total concluídas',
                  key: ValueKey<int>(concluidas),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.cyan[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progresso),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardAtividade(Map<String, dynamic> item) {
    final isTarefa = item['tipo'] == 'Tarefa';
    final isConcluida = item['concluida'] == true;
    final atrasada = isTarefa && !isConcluida && estaAtrasada(item['data']);

    return Card(
      key: ValueKey(item['id']),
      elevation: 4,
      shadowColor: Colors.cyan.withValues(alpha: 0.15),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _mostrarDetalhes(item),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(
          isTarefa ? Icons.menu_book_rounded : Icons.event_rounded,
          color: isTarefa ? Colors.cyan[700] : Colors.orange[700],
          size: 28,
        ),
        title: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            decoration: isConcluida ? TextDecoration.lineThrough : TextDecoration.none,
            color: isConcluida ? Colors.grey : Colors.black87,
            fontFamily: 'Roboto',
          ),
          child: Text(item['titulo'] ?? ''),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text.rich(
            TextSpan(
              text: '${item['tipo']} • Para: ${formatarData(item['data'])}',
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
              children: [
                if (atrasada)
                  const TextSpan(
                    text: '  • Atrasada',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
        trailing: isTarefa
            ? Checkbox(
                value: isConcluida,
                activeColor: Colors.cyan,
                onChanged: (val) => _alternarConclusao(item, val ?? false),
              )
            : null,
      ),
    );
  }
}

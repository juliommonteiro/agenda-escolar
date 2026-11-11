import 'package:flutter/material.dart';
import '../Screens/nova_atividade_screen.dart';
import '../atividade_repository.dart';
import '../formatadores.dart';
import '../mensagens.dart';
import '../navegacao.dart';

/// Lista de atividades com criar / editar / excluir.
/// Usado pelo Professor e pelo Coordenador.
class PainelAtividades extends StatefulWidget {
  /// Dados do usuário logado: {id, nome, email, perfil}
  final Map<String, dynamic> usuario;

  const PainelAtividades({super.key, required this.usuario});

  @override
  State<PainelAtividades> createState() => _PainelAtividadesState();
}

class _PainelAtividadesState extends State<PainelAtividades> {
  final AtividadeRepository _repository = AtividadeRepository();
  List<Map<String, dynamic>> _atividades = [];
  bool _isLoading = true;
  String _filtroAtual = 'Todas';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final dados = await _repository.listarAtividades();
      if (!mounted) return;
      setState(() {
        _atividades = dados; // A API já devolve ordenado por data
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarErro(context, e);
    }
  }

  /// Abre o formulário. Sem [atividade] cria uma nova; com [atividade] edita.
  Future<void> _abrirFormulario({Map<String, dynamic>? atividade}) async {
    final resultado = await Navigator.push(
      context,
      rotaDeBaixo<Map<String, dynamic>>(NovaAtividadeScreen(atividade: atividade)),
    );
    if (resultado == null || !mounted) return;

    // MOSTRA A BOLINHA DE CARREGANDO enquanto salva no Python
    setState(() => _isLoading = true);
    try {
      if (atividade == null) {
        await _repository.criarAtividade(resultado);
      } else {
        await _repository.atualizarAtividade(atividade['id'] as int, resultado);
      }
      await _carregarDados();
      if (!mounted) return;
      mostrarMensagem(context, atividade == null ? 'Atividade criada com sucesso!' : 'Atividade atualizada!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarErro(context, e);
    }
  }

  Future<void> _excluir(Map<String, dynamic> atividade) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Atividade?'),
        content: Text('"${atividade['titulo']}" será apagada definitivamente.'),
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
      await _repository.deletarAtividade(atividade['id'] as int);
      await _carregarDados();
      if (!mounted) return;
      mostrarMensagem(context, 'Atividade excluída com sucesso!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final atividadesFiltradas = _filtroAtual == 'Todas'
        ? _atividades
        : _atividades.where((a) => a['tipo'] == _filtroAtual).toList();
    final primeiroNome = (widget.usuario['nome'] as String? ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan)) // Bolinha de carregamento
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Text(
                        'Olá, $primeiroNome! Há ${_atividades.length} atividade(s) cadastrada(s).',
                        style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFiltroChip('Todas', Icons.list_alt_rounded),
                          _buildFiltroChip('Tarefa', Icons.menu_book_rounded),
                          _buildFiltroChip('Evento', Icons.event_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: Colors.cyan,
                    onRefresh: _carregarDados,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: atividadesFiltradas.isEmpty
                          ? _buildListaVazia()
                          : ListView.builder(
                              key: ValueKey(_filtroAtual),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                              itemCount: atividadesFiltradas.length,
                              itemBuilder: (context, index) => _buildCard(atividadesFiltradas[index]),
                            ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag nulo evita conflito quando há outro botão flutuante na mesma tela
        heroTag: null,
        onPressed: _isLoading ? null : () => _abrirFormulario(),
        backgroundColor: Colors.cyan,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Atividade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildListaVazia() {
    // ListView para o "puxar para atualizar" funcionar mesmo com a lista vazia
    return ListView(
      key: const ValueKey('vazio'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.inbox_outlined, size: 80, color: Colors.cyan[200]),
        const SizedBox(height: 16),
        Text(
          _filtroAtual == 'Todas'
              ? 'Nenhuma atividade cadastrada.\nToque em "Nova Atividade" para começar.'
              : 'Nenhuma atividade do tipo "$_filtroAtual" encontrada.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> atividade) {
    final isTarefa = atividade['tipo'] == 'Tarefa';
    final totalConcluidas = (atividade['total_concluidas'] ?? 0) as int;
    final cor = isTarefa ? Colors.cyan : Colors.orange;

    return Card(
      elevation: 4,
      shadowColor: Colors.cyan.withValues(alpha: 0.2),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _abrirFormulario(atividade: atividade),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isTarefa ? Icons.menu_book : Icons.event,
            color: isTarefa ? Colors.cyan[700] : Colors.orange[700],
            size: 28,
          ),
        ),
        title: Text(
          atividade['titulo'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${atividade['tipo']} • Para: ${formatarData(atividade['data'])}',
                style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
              ),
              if (isTarefa) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      totalConcluidas == 1 ? '1 aluno concluiu' : '$totalConcluidas alunos concluíram',
                      style: TextStyle(color: Colors.green[700], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: 'Excluir',
          onPressed: () => _excluir(atividade),
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String titulo, IconData icone) {
    final selecionado = _filtroAtual == titulo;
    return ChoiceChip(
      selected: selecionado,
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: selecionado ? Colors.white : Colors.cyan[700]),
          const SizedBox(width: 6),
          Text(titulo),
        ],
      ),
      selectedColor: Colors.cyan,
      backgroundColor: Colors.grey[100],
      labelStyle: TextStyle(
        color: selecionado ? Colors.white : Colors.grey[800],
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selecionado ? Colors.cyan : Colors.grey.shade300),
      ),
      onSelected: (_) => setState(() => _filtroAtual = titulo),
    );
  }
}

import 'package:flutter/material.dart';
import '../Screens/novo_usuario_screen.dart';
import '../mensagens.dart';
import '../sessao.dart';
import '../usuario_repository.dart';

/// E-mail do coordenador criado automaticamente pela API (não pode ser excluído).
const _coordenadorPadrao = 'coordenador@example.com';

/// Lista de usuários com criar / excluir. Usado somente pelo Coordenador.
class PainelUsuarios extends StatefulWidget {
  const PainelUsuarios({super.key});

  @override
  State<PainelUsuarios> createState() => _PainelUsuariosState();
}

class _PainelUsuariosState extends State<PainelUsuarios> {
  final UsuarioRepository _repository = UsuarioRepository();
  List<Map<String, dynamic>> _usuarios = [];
  bool _isLoading = true;
  String _filtroAtual = 'Todos';

  static const _filtros = {
    'Todos': Icons.groups_rounded,
    'Aluno': Icons.school_rounded,
    'Professor': Icons.co_present_rounded,
    'Coordenador': Icons.admin_panel_settings_rounded,
  };

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final dados = await _repository.listarUsuarios();
      if (!mounted) return;
      setState(() {
        _usuarios = dados;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarErro(context, e);
    }
  }

  Future<void> _novoUsuario() async {
    final criado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const NovoUsuarioScreen()),
    );
    if (criado == true && mounted) {
      setState(() => _isLoading = true);
      await _carregarDados();
    }
  }

  Future<void> _excluir(Map<String, dynamic> usuario) async {
    final isAluno = usuario['perfil'] == 'Aluno';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Usuário?'),
        content: Text(
          'A conta de "${usuario['nome']}" (${usuario['email']}) será apagada definitivamente.'
          '${isAluno ? '\n\nO progresso do aluno nas tarefas também será apagado.' : ''}',
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
      await _repository.deletarUsuario(usuario['id'] as int);
      await _carregarDados();
      if (!mounted) return;
      mostrarMensagem(context, 'Usuário excluído com sucesso!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarErro(context, e);
    }
  }

  /// O coordenador padrão e a própria conta não podem ser excluídos.
  bool _podeExcluir(Map<String, dynamic> usuario) =>
      usuario['email'] != _coordenadorPadrao && usuario['id'] != Sessao.usuarioId;

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtroAtual == 'Todos'
        ? _usuarios
        : _usuarios.where((u) => u['perfil'] == _filtroAtual).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Text(
                        '${_usuarios.length} usuário(s) cadastrado(s)',
                        style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final filtro in _filtros.entries) _buildFiltroChip(filtro.key, filtro.value),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: Colors.cyan,
                    onRefresh: _carregarDados,
                    child: filtrados.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Icon(Icons.person_off_outlined, size: 80, color: Colors.cyan[200]),
                              const SizedBox(height: 16),
                              const Text(
                                'Nenhum usuário encontrado.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                            itemCount: filtrados.length,
                            itemBuilder: (context, index) => _buildCard(filtrados[index]),
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag nulo evita conflito com o botão do painel de atividades
        heroTag: null,
        onPressed: _isLoading ? null : _novoUsuario,
        backgroundColor: Colors.cyan,
        elevation: 4,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Novo Usuário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> usuario) {
    final perfil = usuario['perfil'] as String? ?? '';
    final cor = switch (perfil) {
      'Coordenador' => Colors.deepPurple,
      'Professor' => Colors.orange,
      _ => Colors.cyan,
    };
    final nome = usuario['nome'] as String? ?? '';
    final ehVoce = usuario['id'] == Sessao.usuarioId;

    return Card(
      elevation: 2,
      shadowColor: Colors.cyan.withValues(alpha: 0.2),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.15),
          child: Text(
            nome.isEmpty ? '?' : nome[0].toUpperCase(),
            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          ehVoce ? '$nome (você)' : nome,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(usuario['email'] ?? '', style: TextStyle(color: Colors.grey[700])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(perfil, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        trailing: _podeExcluir(usuario)
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Excluir',
                onPressed: () => _excluir(usuario),
              )
            : Tooltip(
                message: 'Esta conta não pode ser excluída',
                child: Icon(Icons.lock_outline, color: Colors.grey[400]),
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

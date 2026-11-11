import 'package:flutter/material.dart';
import '../mensagens.dart';
import '../turma_repository.dart';
import '../usuario_repository.dart';

class NovoUsuarioScreen extends StatefulWidget {
  const NovoUsuarioScreen({super.key});

  @override
  State<NovoUsuarioScreen> createState() => _NovoUsuarioScreenState();
}

class _NovoUsuarioScreenState extends State<NovoUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  // Senha padrão já preenchida; o coordenador pode trocar se quiser
  final _senhaController = TextEditingController(text: 'teste');
  String _perfilSelecionado = 'Aluno';
  bool _isLoading = false;
  bool _mostrarSenha = false;
  final UsuarioRepository _repo = UsuarioRepository();
  final TurmaRepository _turmaRepo = TurmaRepository();
  List<Map<String, dynamic>> _turmas = [];
  int? _turmaId; // opcional, só para alunos

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  Future<void> _carregarTurmas() async {
    try {
      final turmas = await _turmaRepo.listarTurmas();
      if (mounted) setState(() => _turmas = turmas);
    } catch (_) {
      // Sem turmas o cadastro continua funcionando; o aluno pode ser colocado numa turma depois
    }
  }

  void _salvarUsuario() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _repo.criarUsuario({
          'nome': _nomeController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'senha': _senhaController.text,
          'perfil': _perfilSelecionado,
          'turma_id': _perfilSelecionado == 'Aluno' ? _turmaId : null,
        });

        if (mounted) {
          mostrarMensagem(context, 'Conta criada com sucesso!');
          Navigator.pop(context, true); // Volta pro painel e avisa que precisa recarregar
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          mostrarErro(context, e);
        }
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Conta', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.cyan,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                validator: (val) {
                  final email = val?.trim() ?? '';
                  if (email.isEmpty) return 'Informe o e-mail';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'E-mail inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: !_mostrarSenha,
                decoration: InputDecoration(
                  labelText: 'Senha (Provisória)',
                  helperText: 'Senha padrão: "teste". Pode ser alterada.',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_mostrarSenha ? Icons.visibility_off : Icons.visibility),
                    tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
                    onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Crie uma senha';
                  if (val.length < 3) return 'A senha precisa ter pelo menos 3 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _perfilSelecionado,
                decoration: const InputDecoration(labelText: 'Tipo de Conta', border: OutlineInputBorder()),
                items: ['Aluno', 'Professor', 'Coordenador'].map((perfil) {
                  return DropdownMenuItem(value: perfil, child: Text(perfil));
                }).toList(),
                onChanged: (val) => setState(() => _perfilSelecionado = val!),
              ),
              if (_perfilSelecionado == 'Aluno' && _turmas.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: _turmaId,
                  decoration: const InputDecoration(labelText: 'Turma (opcional)', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Sem turma')),
                    for (final turma in _turmas)
                      DropdownMenuItem<int?>(value: turma['id'] as int, child: Text(turma['nome'] as String)),
                  ],
                  onChanged: (val) => setState(() => _turmaId = val),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _salvarUsuario,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('CRIAR CONTA', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
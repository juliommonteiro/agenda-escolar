import 'package:flutter/material.dart';
import 'aluno_dashboard.dart';
import 'coordenador_dashboard.dart';
import 'professor_dashboard.dart';
import '../mensagens.dart';
import '../navegacao.dart';
import '../usuario_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _perfis = ['Aluno', 'Professor', 'Coordenador'];

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final UsuarioRepository _usuarioRepo = UsuarioRepository();
  bool _isLoading = false;

  String _tipoPerfil = 'Aluno';

  void _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Vai no banco de dados verificar (Note o .trim() no e-mail)
      final usuario = await _usuarioRepo.fazerLogin(
        _emailController.text.trim(),
        _senhaController.text,
        _tipoPerfil,
      );

      if (!mounted) return;
      final Widget painel = switch (usuario['perfil']) {
        'Coordenador' => CoordenadorDashboard(usuario: usuario),
        'Professor' => ProfessorDashboard(usuario: usuario),
        _ => AlunoDashboard(usuario: usuario),
      };
      Navigator.pushReplacement(context, rotaSuave(painel));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarErro(context, e);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.cyan, Colors.lightBlueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.cyan,
                            child: Icon(Icons.school_rounded, size: 40, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Agenda Escolar',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Selecione seu perfil para continuar',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 32),
                        _buildSeletorPerfil(),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'E-mail institucional',
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.cyan),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Informe seu e-mail' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _senhaController,
                          obscureText: true,
                          onFieldSubmitted: (_) => _isLoading ? null : _fazerLogin(),
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.cyan),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Informe sua senha' : null,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          // Se estiver carregando, desativa o botão (null) para não clicarem duas vezes
                          onPressed: _isLoading ? null : _fazerLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : FittedBox(
                                  child: Text(
                                    'ENTRAR COMO ${_tipoPerfil.toUpperCase()}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Botões "Aluno | Professor | Coordenador" com animação na seleção.
  Widget _buildSeletorPerfil() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          for (final perfil in _perfis)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tipoPerfil = perfil),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: _tipoPerfil == perfil ? Colors.cyan : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      perfil,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _tipoPerfil == perfil ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

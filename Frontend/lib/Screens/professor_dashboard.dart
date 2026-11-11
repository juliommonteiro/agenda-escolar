import 'package:flutter/material.dart';
import '../navegacao.dart';
import '../widgets/painel_atividades.dart';

class ProfessorDashboard extends StatelessWidget {
  /// Dados do professor logado: {id, nome, email, perfil}
  final Map<String, dynamic> usuario;

  const ProfessorDashboard({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Professor', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 0,
        centerTitle: true,
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
      body: PainelAtividades(usuario: usuario),
    );
  }
}

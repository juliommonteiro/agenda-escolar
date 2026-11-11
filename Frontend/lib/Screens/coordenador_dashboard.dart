import 'package:flutter/material.dart';
import '../navegacao.dart';
import '../widgets/painel_atividades.dart';
import '../widgets/painel_turmas.dart';
import '../widgets/painel_usuarios.dart';

class CoordenadorDashboard extends StatefulWidget {
  /// Dados do coordenador logado: {id, nome, email, perfil}
  final Map<String, dynamic> usuario;

  const CoordenadorDashboard({super.key, required this.usuario});

  @override
  State<CoordenadorDashboard> createState() => _CoordenadorDashboardState();
}

class _CoordenadorDashboardState extends State<CoordenadorDashboard> {
  int _abaAtual = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Coordenador', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
      // Cada aba é recarregada ao ser aberta, assim mudanças feitas em uma
      // (ex.: nova turma) já aparecem nas outras
      body: switch (_abaAtual) {
        0 => PainelAtividades(usuario: widget.usuario),
        1 => const PainelTurmas(),
        _ => const PainelUsuarios(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _abaAtual,
        onDestinationSelected: (indice) => setState(() => _abaAtual = indice),
        indicatorColor: Colors.cyan.withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Atividades',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Turmas',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Usuários',
          ),
        ],
      ),
    );
  }
}

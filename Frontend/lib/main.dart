import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // <-- 1. Import de Idiomas
import 'Screens/login_screen.dart';
import 'api_config.dart';

final _navigatorKey = GlobalKey<NavigatorState>();
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  // Se o token expirar em qualquer tela, volta para o login com um aviso
  ApiConfig.aoExpirarSessao = () {
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Sua sessão expirou. Faça login novamente.'),
        backgroundColor: Colors.orange,
      ),
    );
  };

  runApp(const AgendaEscolarApp());
}

class AgendaEscolarApp extends StatelessWidget {
  const AgendaEscolarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda Escolar',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      
      // --- 2. Configuração do Calendário e Idioma para o Brasil ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'), // Português do Brasil
      ],
      // -----------------------------------------------------------

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          primary: Colors.cyan,
          secondary: Colors.cyanAccent,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.cyan, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
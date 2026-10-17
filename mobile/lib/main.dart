import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Se já existe um token salvo, abre direto na lista de tarefas
  final loggedIn = await api.loadToken();
  runApp(TarefasApp(loggedIn: loggedIn));
}

class TarefasApp extends StatelessWidget {
  final bool loggedIn;
  const TarefasApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tarefas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: loggedIn ? const TasksScreen() : const LoginScreen(),
    );
  }
}

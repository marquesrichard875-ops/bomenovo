import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

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
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system, // acompanha o modo claro/escuro do celular
      home: loggedIn ? const TasksScreen() : const LoginScreen(),
    );
  }
}
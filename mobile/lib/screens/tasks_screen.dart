import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'task_form_screen.dart';

/// Lista as tarefas (GET /tasks) e permite marcar, editar e excluir.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Task> _tasks = [];
  String _userName = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([api.currentUserName(), api.listTasks()]);
      setState(() {
        _userName = results[0] as String;
        _tasks = results[1] as List<Task>;
      });
    } on ApiException catch (e) {
      // Token expirado/inválido: volta para o login
      if (e.statusCode == 401) return _logout(message: e.message);
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Executa uma ação na API e mostra o erro (se houver) em um SnackBar.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on ApiException catch (e) {
      if (e.statusCode == 401) return _logout(message: e.message);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _logout({String? message}) async {
    await api.logout();
    if (!mounted) return;
    if (message != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openForm([Task? task]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir tarefa'),
        content: Text('Deseja excluir "${task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) _run(() => api.deleteTask(task.id));
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
        ]),
      );
    }
    if (_tasks.isEmpty) return const Center(child: Text('Nenhuma tarefa ainda. Toque em + para criar.'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _tasks.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final t = _tasks[i];
          return ListTile(
            leading: Checkbox(
              value: t.done,
              onChanged: (v) => _run(() => api.updateTask(t.id, done: v)),
            ),
            title: Text(
              t.title,
              style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null),
            ),
            subtitle: (t.description?.isNotEmpty ?? false) ? Text(t.description!) : null,
            onTap: () => _openForm(t),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir',
              onPressed: () => _confirmDelete(t),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_userName.isEmpty ? 'Minhas tarefas' : 'Tarefas de $_userName'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Atualizar', onPressed: _load),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sair', onPressed: _logout),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Nova tarefa',
        child: const Icon(Icons.add),
      ),
    );
  }
}

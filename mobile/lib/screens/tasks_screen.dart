import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'task_form_screen.dart';

enum _Filter { all, pending, done }

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
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [silent] = não troca a tela por um spinner (usado após marcar/excluir).
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([api.currentUserName(), api.listTasks()]);
      if (!mounted) return;
      setState(() {
        _userName = results[0] as String;
        _tasks = results[1] as List<Task>;
        _error = null;
      });
    } on ApiException catch (e) {
      // Token expirado/inválido: volta para o login
      if (e.statusCode == 401) return _logout(message: e.message);
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Executa uma ação na API e mostra o erro (se houver) em um SnackBar.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load(silent: true);
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
    if (changed == true) _load(silent: true);
  }

  Future<bool> _askDelete(Task task) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: scheme.error, size: 32),
        title: const Text('Excluir tarefa'),
        content: Text('Deseja excluir "${task.title}"?', textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Remove da lista na hora e avisa a API; se falhar, recarrega.
  Future<void> _delete(Task task) async {
    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    try {
      await api.deleteTask(task.id);
    } on ApiException catch (e) {
      if (e.statusCode == 401) return _logout(message: e.message);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      _load(silent: true);
    }
  }

  // ---------------------------------------------------------------- UI

  Widget _buildHeader() {
    final total = _tasks.length;
    final done = _tasks.where((t) => t.done).length;
    final progress = total == 0 ? 0.0 : done / total;
    final firstName = _userName.trim().split(' ').first;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        gradient: appGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstName.isEmpty ? 'Olá 👋' : 'Olá, $firstName 👋',
                      style: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Vamos organizar o seu dia',
                      style: textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: Colors.white,
                tooltip: 'Atualizar',
                onPressed: _load,
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                color: Colors.white,
                tooltip: 'Sair',
                onPressed: _logout,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          total == 0 ? 'Nenhuma tarefa ainda' : '$done de $total concluídas',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final pending = _tasks.where((t) => !t.done).length;
    final done = _tasks.length - pending;
    final scheme = Theme.of(context).colorScheme;

    Widget chip(_Filter f, String label) {
      final selected = _filter == f;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: selected ? Colors.transparent : scheme.outlineVariant),
        onSelected: (_) => setState(() => _filter = f),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Wrap(
        spacing: 8,
        children: [
          chip(_Filter.all, 'Todas (${_tasks.length})'),
          chip(_Filter.pending, 'Pendentes ($pending)'),
          chip(_Filter.done, 'Concluídas ($done)'),
        ],
      ),
    );
  }

  Widget _buildList() {
    final visible = switch (_filter) {
      _Filter.all => _tasks,
      _Filter.pending => _tasks.where((t) => !t.done).toList(),
      _Filter.done => _tasks.where((t) => t.done).toList(),
    };

    if (visible.isEmpty) {
      final noTasks = _tasks.isEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          _StateMessage(
            icon: noTasks ? Icons.edit_note_rounded : Icons.filter_list_off_rounded,
            title: noTasks ? 'Nenhuma tarefa por aqui' : 'Nada nesse filtro',
            subtitle: noTasks
                ? 'Toque em "Nova tarefa" para criar a primeira.'
                : 'Troque o filtro para ver outras tarefas.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110), // espaço para o botão
      itemCount: visible.length,
      itemBuilder: (_, i) {
        final t = visible[i];
        return TweenAnimationBuilder<double>(
          key: ValueKey(t.id),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 250 + (i < 8 ? i : 8) * 50),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: ValueKey('dismiss-${t.id}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _askDelete(t),
              onDismissed: (_) => _delete(t),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              child: _TaskCard(
                task: t,
                onToggle: () => _run(() => api.updateTask(t.id, done: !t.done)),
                onTap: () => _openForm(t),
                onDelete: () async {
                  if (await _askDelete(t)) _delete(t);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: _StateMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Não foi possível carregar',
          subtitle: _error!,
          action: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(silent: true),
            child: _buildList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nova tarefa', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// Cartão de uma tarefa: bolinha para concluir, título, descrição e lixeira.
class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDescription = task.description?.isNotEmpty ?? false;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                _RoundCheck(done: task.done, onTap: onToggle),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: task.done ? 0.5 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            decoration: task.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (hasDescription) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error.withValues(alpha: 0.8)),
                  tooltip: 'Excluir',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkbox redondo com degradê verde quando concluído.
class _RoundCheck extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  const _RoundCheck({required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: done ? successGradient : null,
          border: done ? null : Border.all(color: scheme.outline, width: 2),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: done
              ? const Icon(Icons.check_rounded, key: ValueKey('on'), color: Colors.white, size: 20)
              : const SizedBox(key: ValueKey('off')),
        ),
      ),
    );
  }
}

/// Mensagem central usada nos estados vazio e de erro.
class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 44, color: scheme.primary),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
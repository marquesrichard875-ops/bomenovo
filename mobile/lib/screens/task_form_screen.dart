import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_service.dart';
import '../widgets/gradient_page.dart';

/// Formulário usado tanto para criar (POST /tasks) quanto para editar (PUT /tasks/{id}).
class TaskFormScreen extends StatefulWidget {
  final Task? task; // null = nova tarefa
  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(text: widget.task?.description);
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final title = _title.text.trim();
      final description = _description.text.trim();
      if (_isEditing) {
        await api.updateTask(widget.task!.id, title: title, description: description);
      } else {
        await api.createTask(title, description.isEmpty ? null : description);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientPage(
      icon: _isEditing ? Icons.edit_note_rounded : Icons.add_task_rounded,
      title: _isEditing ? 'Editar tarefa' : 'Nova tarefa',
      subtitle: _isEditing ? 'Ajuste os detalhes abaixo' : 'O que você precisa fazer?',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Título',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o título' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 72),
                  child: Icon(Icons.notes_rounded),
                ),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isEditing ? 'Salvar alterações' : 'Criar tarefa'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
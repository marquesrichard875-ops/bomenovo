/// Representa uma tarefa retornada pela API.
class Task {
  final int id;
  final String title;
  final String? description;
  final bool done;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.done,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        done: json['done'],
      );
}

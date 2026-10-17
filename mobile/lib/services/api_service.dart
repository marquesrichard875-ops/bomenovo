import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/task.dart';

/// Erro vindo da API, com a mensagem amigável enviada pelo backend.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Centraliza todas as chamadas HTTP para o backend FastAPI.
class ApiService {
  static const _tokenKey = 'access_token';
  String? _token;

  /// Carrega o token salvo no aparelho (mantém o usuário logado).
  Future<bool> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    return _token != null;
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // Rotas protegidas exigem o header Authorization: Bearer <token>
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Executa a requisição e converte erros HTTP em ApiException.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request();
    } catch (_) {
      throw ApiException(0, 'Não foi possível conectar à API em $apiUrl');
    }
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    var message = 'Erro ${res.statusCode}';
    if (body is Map && body['detail'] is String) {
      message = body['detail'];
      // Erros de validação trazem a lista de campos inválidos
      if (body['errors'] is List && (body['errors'] as List).isNotEmpty) {
        final e = body['errors'][0];
        message += '\n${e['campo']}: ${e['erro']}';
      }
    }
    throw ApiException(res.statusCode, message);
  }

  Uri _uri(String path) => Uri.parse('$apiUrl$path');

  // ---------- Autenticação ----------

  Future<void> register(String name, String email, String password) => _send(() => http.post(
        _uri('/auth/register'),
        headers: _headers,
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ));

  Future<void> login(String email, String password) async {
    final data = await _send(() => http.post(
          _uri('/auth/login'),
          headers: _headers,
          body: jsonEncode({'email': email, 'password': password}),
        ));
    _token = data['access_token'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
  }

  Future<String> currentUserName() async {
    final data = await _send(() => http.get(_uri('/auth/me'), headers: _headers));
    return data['name'];
  }

  // ---------- CRUD de tarefas ----------

  Future<List<Task>> listTasks() async {
    final data = await _send(() => http.get(_uri('/tasks'), headers: _headers)) as List;
    return data.map((e) => Task.fromJson(e)).toList();
  }

  Future<Task> createTask(String title, String? description) async {
    final data = await _send(() => http.post(
          _uri('/tasks'),
          headers: _headers,
          body: jsonEncode({'title': title, 'description': description}),
        ));
    return Task.fromJson(data);
  }

  Future<Task> updateTask(int id, {String? title, String? description, bool? done}) async {
    final data = await _send(() => http.put(
          _uri('/tasks/$id'),
          headers: _headers,
          body: jsonEncode({
            // Envia apenas os campos informados (atualização parcial).
            // O '?' antes do valor omite a chave quando o valor é null.
            'title': ?title,
            'description': ?description,
            'done': ?done,
          }),
        ));
    return Task.fromJson(data);
  }

  Future<void> deleteTask(int id) => _send(() => http.delete(_uri('/tasks/$id'), headers: _headers));
}

/// Instância única usada por todas as telas.
final api = ApiService();

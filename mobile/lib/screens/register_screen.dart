import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/gradient_page.dart';

/// Tela de cadastro: envia os dados para POST /auth/register.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.register(_name.text.trim(), _email.text.trim(), _password.text);
      messenger.showSnackBar(const SnackBar(content: Text('Conta criada! Faça login.')));
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientPage(
      heroTag: 'auth-badge',
      icon: Icons.person_add_alt_1_rounded,
      title: 'Criar conta',
      subtitle: 'Leva menos de um minuto',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().length < 2) ? 'Mínimo de 2 caracteres' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              obscureText: _hidePassword,
              validator: (v) => (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Cadastrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter_test/flutter_test.dart';
import 'package:tarefas_app/main.dart';

void main() {
  testWidgets('Sem token, o app abre na tela de login', (tester) async {
    await tester.pumpWidget(const TarefasApp(loggedIn: false));
    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Não tem conta? Cadastre-se'), findsOneWidget);
  });
}

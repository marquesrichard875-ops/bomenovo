# Interface Web (Python/Flask)

Segunda interface do trabalho: uma aplicação **web em Flask** que consome a **mesma API FastAPI** usada pelo app Flutter.
Ela **não acessa o banco**: tudo passa pela API (cadastro, login com JWT e CRUD de tarefas), então os dados ficam centralizados.

## Como rodar

Em um terminal, suba o backend (porta 8000):

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Em outro terminal, suba a interface web (porta 5000):

```bash
cd web
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Abra **http://localhost:5000**.

Configuração opcional: copie `.env.example` para `.env` para mudar `API_URL` (ex.: `http://192.168.0.10:8000`), a porta ou o intervalo de atualização.

## Estrutura

```
web/
├── app.py            # Rotas Flask (login, cadastro, CRUD), CSRF e tratamento de erros
├── api_client.py     # Único ponto de contato com a API (requests + header Bearer)
├── config.py         # API_URL, chave da sessão, intervalo de atualização
├── templates/        # HTML (Jinja2): login, cadastro, lista, formulário, erro
├── static/           # style.css e app.js (atualização automática da lista)
└── tests/test_web.py # Testes com a API simulada (rodam sem o backend)
```

## Exemplos de uso

1. **Cadastro** — `/register`: nome, e-mail e senha (6 a 72 caracteres). A API salva a senha com bcrypt.
2. **Login** — `/login`: a API devolve o token JWT, que a interface guarda na sessão (cookie assinado) e envia como `Authorization: Bearer <token>` nas rotas protegidas.
3. **Create** — botão **+ Nova tarefa**: título (obrigatório), descrição e se já está concluída.
4. **Read** — a lista mostra as tarefas do usuário; **Editar** abre a tarefa buscada por ID (`GET /tasks/{id}`).
5. **Update** — **Editar** → **Salvar**, ou clique no ☐/☑ para marcar como concluída.
6. **Delete** — **Excluir** (pede confirmação).
7. **Sair** — encerra a sessão.

Mensagens de erro da API aparecem na tela: e-mail ou senha inválidos (401), e-mail repetido (409), título vazio (422), tarefa inexistente (404), token expirado (volta ao login) e API fora do ar (503).

### Teste de sincronização entre Flutter e web

1. Entre com **a mesma conta** no app Flutter e na interface web (`http://localhost:5000`).
2. Crie, edite, conclua ou exclua uma tarefa no **Flutter** → em até 5 segundos a lista da web se atualiza sozinha (ou clique em *atualizar agora*).
3. Faça o contrário: altere pela **web** e puxe para atualizar a lista no Flutter.

### Equivalência com a API (o que a web chama por trás)

| Ação na web | Requisição à API |
|---|---|
| Login | `POST /auth/login` |
| Cadastro | `POST /auth/register` |
| Listar | `GET /tasks` |
| Abrir para editar | `GET /tasks/{id}` |
| Criar | `POST /tasks` |
| Salvar / concluir | `PUT /tasks/{id}` |
| Excluir | `DELETE /tasks/{id}` |

## Testes

```bash
cd web
pytest -v
```

Os testes simulam a API em memória, então não precisam do backend rodando.

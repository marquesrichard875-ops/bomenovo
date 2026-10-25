"""Testes da interface web. A API é simulada (mock), então o backend não precisa estar rodando.

Rodar (dentro da pasta web, com o venv ativo):  pytest -v
"""
import re
from unittest.mock import patch

import pytest
import requests

from app import create_app


class FakeResponse:
    def __init__(self, status=200, body=None):
        self.status_code = status
        self._body = body
        self.content = b"" if body is None else b"x"

    def json(self):
        return self._body


class FakeApi:
    """Imita as rotas da API FastAPI em memória (mesmos códigos e mensagens)."""

    def __init__(self):
        self.tasks, self.next_id, self.down = [], 1, False
        self.users = {"maria@email.com": "senha123"}

    def __call__(self, method, url, headers=None, json=None, timeout=None):
        if self.down:
            raise requests.ConnectionError()
        path = url.split("://", 1)[1].split("/", 1)[1]
        path = "/" + path
        if path == "/auth/login":
            if self.users.get(json["email"]) != json["password"]:
                return FakeResponse(401, {"detail": "E-mail ou senha inválidos."})
            user = {"id": 1, "name": "Maria", "email": json["email"], "created_at": "2026-10-18T10:00:00"}
            return FakeResponse(200, {"access_token": "tok", "token_type": "bearer", "user": user})
        if path == "/auth/register":
            if json["email"] in self.users:
                return FakeResponse(409, {"detail": "Este e-mail já está cadastrado."})
            self.users[json["email"]] = json["password"]
            return FakeResponse(201, {"id": 2, **{k: json[k] for k in ("name", "email")}})
        # --- rotas protegidas
        if (headers or {}).get("Authorization") != "Bearer tok":
            return FakeResponse(401, {"detail": "Token inválido ou expirado. Faça login novamente."})
        m = re.fullmatch(r"/tasks(?:/(\d+))?", path)
        tid = int(m.group(1)) if m and m.group(1) else None
        found = next((t for t in self.tasks if t["id"] == tid), None)
        if method == "GET" and tid is None:
            return FakeResponse(200, list(self.tasks))
        if method == "POST" and tid is None:
            if not json["title"]:
                return FakeResponse(422, {"detail": "Dados inválidos na requisição.",
                                          "errors": [{"campo": "title", "erro": "String should have at least 1 character"}]})
            task = {"id": self.next_id, "created_at": "2026-10-18T10:00:00", "owner_id": 1, **json}
            self.next_id += 1
            self.tasks.append(task)
            return FakeResponse(201, task)
        if found is None:
            return FakeResponse(404, {"detail": f"Tarefa {tid} não encontrada."})
        if method == "GET":
            return FakeResponse(200, found)
        if method == "PUT":
            found.update(json)
            return FakeResponse(200, found)
        if method == "DELETE":
            self.tasks.remove(found)
            return FakeResponse(204)


@pytest.fixture
def fake():
    return FakeApi()


@pytest.fixture
def client(fake):
    app = create_app()
    app.config["TESTING"] = True
    with patch("api_client.requests.request", side_effect=fake):
        yield app.test_client()


def csrf(client, path="/login"):
    """Abre uma página para criar a sessão e devolve o token CSRF dela."""
    html = client.get(path).get_data(as_text=True)
    return re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)


def login(client):
    token = csrf(client)
    return client.post("/login", data={"email": "maria@email.com", "password": "senha123", "csrf_token": token})


def post(client, url, **data):
    return client.post(url, data={"csrf_token": csrf(client, "/tasks/new"), **data}, follow_redirects=True)


def test_rota_protegida_sem_login_redireciona(client):
    resp = client.get("/tasks")
    assert resp.status_code == 302 and "/login" in resp.headers["Location"]


def test_post_sem_csrf_e_bloqueado(client):
    assert client.post("/login", data={"email": "a@a.com", "password": "x"}).status_code == 400


def test_login_invalido_mostra_mensagem_da_api(client):
    token = csrf(client)
    resp = client.post("/login", data={"email": "x@x.com", "password": "errada", "csrf_token": token})
    assert "E-mail ou senha inválidos." in resp.get_data(as_text=True)


def test_login_ok_e_lista_vazia(client):
    assert login(client).status_code == 302
    assert "Nenhuma tarefa ainda" in client.get("/tasks").get_data(as_text=True)


def test_cadastro_e_email_duplicado(client):
    token = csrf(client, "/register")
    ok = client.post("/register", data={"name": "Joao", "email": "joao@email.com", "password": "abc123",
                                        "confirm": "abc123", "csrf_token": token}, follow_redirects=True)
    assert "Cadastro realizado" in ok.get_data(as_text=True)
    dup = client.post("/register", data={"name": "Joao", "email": "joao@email.com", "password": "abc123",
                                         "confirm": "abc123", "csrf_token": token})
    assert "Este e-mail já está cadastrado." in dup.get_data(as_text=True)


def test_crud_completo(client, fake):
    login(client)
    # Create
    html = post(client, "/tasks/new", title="Estudar FastAPI", description="Docs").get_data(as_text=True)
    assert "Estudar FastAPI" in html and len(fake.tasks) == 1
    # Read por ID (tela de edição)
    assert "Estudar FastAPI" in client.get("/tasks/1/edit").get_data(as_text=True)
    # Update
    post(client, "/tasks/1/edit", title="Estudar Flask", description="", done="on")
    assert fake.tasks[0]["title"] == "Estudar Flask" and fake.tasks[0]["done"] is True
    # Toggle
    post(client, "/tasks/1/toggle")
    assert fake.tasks[0]["done"] is False
    # Delete
    post(client, "/tasks/1/delete")
    assert fake.tasks == []


def test_mudanca_externa_aparece_no_fragmento(client, fake):
    """Simula o app Flutter criando uma tarefa direto na API: a web enxerga na próxima atualização."""
    login(client)
    fake.tasks.append({"id": 9, "title": "Criada pelo Flutter", "description": None, "done": False,
                       "created_at": "2026-10-18T10:00:00", "owner_id": 1})
    assert "Criada pelo Flutter" in client.get("/tasks/fragment").get_data(as_text=True)


def test_titulo_vazio_mostra_erro_da_api(client):
    login(client)
    html = post(client, "/tasks/new", title="", description="").get_data(as_text=True)
    assert "Dados inválidos" in html and "title" in html


def test_tarefa_inexistente_404(client):
    login(client)
    resp = client.get("/tasks/99/edit")
    assert resp.status_code == 404 and "Tarefa 99 não encontrada." in resp.get_data(as_text=True)


def test_token_expirado_volta_para_login(client):
    login(client)
    with client.session_transaction() as s:
        s["token"] = "expirado"
    resp = client.get("/tasks", follow_redirects=True)
    assert "Token inválido ou expirado" in resp.get_data(as_text=True)


def test_api_fora_do_ar(client, fake):
    login(client)
    fake.down = True
    resp = client.get("/tasks")
    assert resp.status_code == 503 and "backend está rodando" in resp.get_data(as_text=True)

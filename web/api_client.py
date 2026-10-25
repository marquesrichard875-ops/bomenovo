"""Cliente HTTP da API FastAPI.

Toda a comunicação com o backend passa por aqui. A interface web NÃO acessa o banco:
ela só faz requisições HTTP (como o app Flutter), por isso os dados ficam centralizados.
"""
from __future__ import annotations

import requests

import config


class ApiError(Exception):
    """Erro devolvido pela API (4xx/5xx), já com a mensagem pronta para mostrar ao usuário."""

    def __init__(self, status_code: int, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.message = message


class ApiUnavailable(ApiError):
    """A API está fora do ar ou não respondeu a tempo."""

    def __init__(self):
        super().__init__(503, f"Não foi possível conectar à API em {config.API_URL}. O backend está rodando?")


def _extract_message(response: requests.Response) -> str:
    """Extrai a mensagem de erro do JSON da API (campo 'detail' e, no 422, a lista 'errors')."""
    try:
        body = response.json()
    except ValueError:
        return f"Erro {response.status_code} na API."

    detail = body.get("detail") if isinstance(body, dict) else None
    if isinstance(detail, list):  # formato padrão do FastAPI para 422
        return "; ".join(str(item.get("msg", item)) for item in detail)
    message = str(detail) if detail else f"Erro {response.status_code} na API."

    # Nosso handler de validação devolve também {"errors": [{"campo": ..., "erro": ...}]}
    errors = body.get("errors") if isinstance(body, dict) else None
    if errors:
        extras = "; ".join(f"{e.get('campo')}: {e.get('erro')}" for e in errors)
        message = f"{message} {extras}"
    return message


class ApiClient:
    """Envolve as rotas da API. Recebe o token JWT do usuário (quando houver)."""

    def __init__(self, token: str | None = None, base_url: str | None = None):
        self.token = token
        self.base_url = (base_url or config.API_URL).rstrip("/")

    # ---------- infraestrutura ----------
    def _request(self, method: str, path: str, **kwargs):
        headers = kwargs.pop("headers", {})
        if self.token:
            # Rotas protegidas: Authorization: Bearer <token>
            headers["Authorization"] = f"Bearer {self.token}"
        try:
            response = requests.request(
                method, f"{self.base_url}{path}", headers=headers, timeout=config.API_TIMEOUT, **kwargs
            )
        except requests.RequestException:
            raise ApiUnavailable() from None

        if response.status_code >= 400:
            raise ApiError(response.status_code, _extract_message(response))
        if response.status_code == 204 or not response.content:
            return None
        return response.json()

    # ---------- autenticação ----------
    def register(self, name: str, email: str, password: str) -> dict:
        return self._request("POST", "/auth/register", json={"name": name, "email": email, "password": password})

    def login(self, email: str, password: str) -> dict:
        """Devolve {'access_token': ..., 'token_type': 'bearer', 'user': {...}}."""
        return self._request("POST", "/auth/login", json={"email": email, "password": password})

    def me(self) -> dict:
        return self._request("GET", "/auth/me")

    # ---------- CRUD de tarefas ----------
    def list_tasks(self) -> list[dict]:
        return self._request("GET", "/tasks")

    def get_task(self, task_id: int) -> dict:
        return self._request("GET", f"/tasks/{task_id}")

    def create_task(self, title: str, description: str | None, done: bool = False) -> dict:
        return self._request("POST", "/tasks", json={"title": title, "description": description, "done": done})

    def update_task(self, task_id: int, **fields) -> dict:
        return self._request("PUT", f"/tasks/{task_id}", json=fields)

    def delete_task(self, task_id: int) -> None:
        self._request("DELETE", f"/tasks/{task_id}")

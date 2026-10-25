"""Interface web (Flask) do Gerenciador de Tarefas.

Consome a MESMA API FastAPI usada pelo app Flutter. Qualquer alteração feita em um
dos dois clientes aparece no outro, pois os dados ficam centralizados no backend.

Rodar:  python app.py      ->  http://localhost:5000
"""
from __future__ import annotations

import secrets
from datetime import datetime
from functools import wraps

from flask import Flask, abort, flash, redirect, render_template, request, session, url_for

import config
from api_client import ApiClient, ApiError


def create_app() -> Flask:
    app = Flask(__name__)
    app.secret_key = config.SECRET_KEY

    # ------------------------------------------------------------------ utilidades
    def api() -> ApiClient:
        """Cliente da API já com o token do usuário logado (guardado na sessão)."""
        return ApiClient(session.get("token"))

    def login_required(view):
        """Redireciona para o login se não houver token; trata token expirado (401) da API."""

        @wraps(view)
        def wrapper(*args, **kwargs):
            if not session.get("token"):
                flash("Faça login para continuar.", "error")
                return redirect(url_for("login"))
            try:
                return view(*args, **kwargs)
            except ApiError as err:
                if err.status_code == 401:  # token inválido/expirado
                    session.clear()
                    flash(err.message, "error")
                    if request.headers.get("X-Requested-With") == "fetch":
                        return ("", 401)
                    return redirect(url_for("login"))
                raise

        return wrapper

    # ------------------------------------------------------------------ CSRF simples
    def csrf_token() -> str:
        if "csrf" not in session:
            session["csrf"] = secrets.token_hex(16)
        return session["csrf"]

    @app.before_request
    def check_csrf():
        """Todo POST precisa trazer o token CSRF da sessão (evita requisições forjadas)."""
        if request.method == "POST":
            sent = request.form.get("csrf_token", "")
            if not sent or sent != session.get("csrf"):
                abort(400, "Token CSRF inválido. Recarregue a página e tente de novo.")

    @app.context_processor
    def inject_globals():
        return {
            "csrf_token": csrf_token,
            "current_user": session.get("user"),
            "refresh_seconds": config.REFRESH_SECONDS,
            "api_url": config.API_URL,
        }

    @app.template_filter("datahora")
    def datahora(value: str) -> str:
        """Converte '2026-10-18T14:30:00' em '18/10/2026 14:30'."""
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).strftime("%d/%m/%Y %H:%M")
        except (ValueError, AttributeError):
            return value or ""

    @app.errorhandler(400)
    def bad_request(err):
        return render_template("error.html", message=err.description), 400

    @app.errorhandler(ApiError)
    def api_error(err: ApiError):
        """Qualquer erro da API não tratado numa rota vira uma página com a mensagem clara."""
        return render_template("error.html", message=err.message), err.status_code

    # ------------------------------------------------------------------ autenticação
    @app.get("/")
    def index():
        return redirect(url_for("tasks" if session.get("token") else "login"))

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if request.method == "POST":
            email = request.form.get("email", "").strip()
            password = request.form.get("password", "")
            try:
                data = ApiClient().login(email, password)
            except ApiError as err:
                flash(err.message, "error")
                return render_template("login.html", email=email), err.status_code if err.status_code >= 500 else 200
            session["token"] = data["access_token"]
            session["user"] = data["user"]
            return redirect(url_for("tasks"))
        return render_template("login.html", email="")

    @app.route("/register", methods=["GET", "POST"])
    def register():
        if request.method == "POST":
            form = {k: request.form.get(k, "").strip() for k in ("name", "email")}
            password = request.form.get("password", "")
            if password != request.form.get("confirm", ""):
                flash("As senhas não conferem.", "error")
                return render_template("register.html", **form)
            try:
                ApiClient().register(form["name"], form["email"], password)
            except ApiError as err:
                flash(err.message, "error")
                return render_template("register.html", **form)
            flash("Cadastro realizado! Faça login.", "success")
            return redirect(url_for("login"))
        return render_template("register.html", name="", email="")

    @app.post("/logout")
    def logout():
        session.clear()
        flash("Você saiu da conta.", "success")
        return redirect(url_for("login"))

    # ------------------------------------------------------------------ CRUD de tarefas
    @app.get("/tasks")
    @login_required
    def tasks():
        return render_template("tasks.html", tasks=api().list_tasks())

    @app.get("/tasks/fragment")
    @login_required
    def tasks_fragment():
        """Somente a tabela: usada pelo JavaScript para atualizar a lista sem recarregar a página."""
        return render_template("_tasks_table.html", tasks=api().list_tasks())

    @app.route("/tasks/new", methods=["GET", "POST"])
    @login_required
    def task_new():  # Create
        if request.method == "POST":
            title = request.form.get("title", "").strip()
            description = request.form.get("description", "").strip() or None
            try:
                api().create_task(title, description, done=bool(request.form.get("done")))
            except ApiError as err:
                if err.status_code == 401:
                    raise
                flash(err.message, "error")
                return render_template("task_form.html", task={"title": title, "description": description or ""})
            flash("Tarefa criada.", "success")
            return redirect(url_for("tasks"))
        return render_template("task_form.html", task=None)

    @app.route("/tasks/<int:task_id>/edit", methods=["GET", "POST"])
    @login_required
    def task_edit(task_id: int):  # Read (por ID) + Update
        if request.method == "POST":
            title = request.form.get("title", "").strip()
            description = request.form.get("description", "").strip() or None
            done = bool(request.form.get("done"))
            try:
                api().update_task(task_id, title=title, description=description, done=done)
            except ApiError as err:
                if err.status_code in (401, 404):
                    raise
                flash(err.message, "error")
                task = {"id": task_id, "title": title, "description": description or "", "done": done}
                return render_template("task_form.html", task=task)
            flash("Tarefa atualizada.", "success")
            return redirect(url_for("tasks"))
        return render_template("task_form.html", task=api().get_task(task_id))

    @app.post("/tasks/<int:task_id>/toggle")
    @login_required
    def task_toggle(task_id: int):
        """Marca/desmarca como concluída (PUT parcial só com o campo 'done')."""
        task = api().get_task(task_id)
        api().update_task(task_id, done=not task["done"])
        return redirect(url_for("tasks"))

    @app.post("/tasks/<int:task_id>/delete")
    @login_required
    def task_delete(task_id: int):  # Delete
        api().delete_task(task_id)
        flash("Tarefa excluída.", "success")
        return redirect(url_for("tasks"))

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=config.WEB_PORT, debug=True)

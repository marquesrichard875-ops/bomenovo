"""Importa os modelos para que o SQLAlchemy registre todas as tabelas."""
from app.models.task import Task
from app.models.user import User

__all__ = ["Task", "User"]

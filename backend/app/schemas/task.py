"""Esquemas Pydantic de tarefa (validação e serialização)."""
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class TaskCreate(BaseModel):
    """Dados para criar uma tarefa."""
    title: str = Field(min_length=1, max_length=120, examples=["Estudar FastAPI"])
    description: str | None = Field(default=None, examples=["Ler a documentação oficial"])
    done: bool = False


class TaskUpdate(BaseModel):
    """Dados para atualizar uma tarefa. Todos os campos são opcionais (atualização parcial)."""
    title: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = None
    done: bool | None = None


class TaskOut(BaseModel):
    """Tarefa devolvida pela API."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None
    done: bool
    created_at: datetime
    owner_id: int

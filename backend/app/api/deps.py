"""Dependências compartilhadas pelas rotas, como a obtenção do usuário autenticado."""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decode_access_token
from app.models.user import User
from app.repositories.user_repository import UserRepository

# auto_error=False permite devolver nossas próprias mensagens de erro em português.
# O esquema "HTTPBearer" também faz o Swagger exibir o botão "Authorize".
bearer_scheme = HTTPBearer(auto_error=False, description="Cole aqui o access_token retornado no login")


def _unauthorized(message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=message,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Lê o header 'Authorization: Bearer <token>', valida o JWT e devolve o usuário."""
    if credentials is None:
        raise _unauthorized("Token de acesso não informado. Envie o header 'Authorization: Bearer <token>'.")

    user_id = decode_access_token(credentials.credentials)
    if user_id is None:
        raise _unauthorized("Token inválido ou expirado. Faça login novamente.")

    user = UserRepository(db).get_by_id(int(user_id))
    if user is None:
        raise _unauthorized("Usuário do token não existe mais.")
    return user

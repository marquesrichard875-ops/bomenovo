"""Regras de negócio de cadastro e login."""
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserCreate, UserLogin


class AuthService:
    def __init__(self, db: Session):
        self.users = UserRepository(db)

    def register(self, data: UserCreate) -> User:
        """Cadastra um usuário novo; o e-mail precisa ser único."""
        if self.users.get_by_email(data.email):
            raise HTTPException(status.HTTP_409_CONFLICT, detail="Este e-mail já está cadastrado.")
        return self.users.create(data.name, data.email, hash_password(data.password))

    def login(self, data: UserLogin) -> tuple[str, User]:
        """Valida as credenciais e devolve (token, usuário)."""
        user = self.users.get_by_email(data.email)
        # Mesma mensagem para e-mail inexistente ou senha errada (não revela qual dos dois falhou)
        if not user or not verify_password(data.password, user.hashed_password):
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="E-mail ou senha inválidos.")
        return create_access_token(str(user.id)), user

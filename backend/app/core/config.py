"""Configurações da aplicação, lidas de variáveis de ambiente ou do arquivo .env."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Chave usada para assinar os tokens JWT (troque em produção!)
    SECRET_KEY: str = "dev-secret-key-troque-em-producao-1234567890"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # SQLite por padrão: o arquivo tarefas.db é criado na pasta backend/
    DATABASE_URL: str = "sqlite:///./tarefas.db"


settings = Settings()

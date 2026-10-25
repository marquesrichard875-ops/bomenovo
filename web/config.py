"""Configurações da interface web, lidas de variáveis de ambiente (ou do arquivo .env)."""
import os

try:  # python-dotenv é opcional: se existir um .env, ele é carregado
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:  # pragma: no cover
    pass

# Endereço da API FastAPI. É a MESMA API usada pelo app Flutter.
API_URL = os.getenv("API_URL", "http://localhost:8000").rstrip("/")

# Chave que assina o cookie de sessão (guarda o token JWT do usuário logado)
SECRET_KEY = os.getenv("FLASK_SECRET_KEY", "dev-web-secret-troque-em-producao")

# Tempo máximo de espera por uma resposta da API (segundos)
API_TIMEOUT = float(os.getenv("API_TIMEOUT", "8"))

# Porta e intervalo de atualização automática da lista (em segundos)
WEB_PORT = int(os.getenv("WEB_PORT", "5000"))
REFRESH_SECONDS = int(os.getenv("REFRESH_SECONDS", "5"))

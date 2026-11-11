import hashlib
import hmac
import os
import secrets
from datetime import datetime, timedelta, timezone

import jwt

# --- HASH DE SENHAS ---

_ITERACOES = 200_000
_PREFIXO = "pbkdf2_sha256"


def gerar_hash(senha: str) -> str:
    """Gera um hash PBKDF2 com salt aleatório no formato prefixo$iteracoes$salt$hash."""
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", senha.encode(), salt.encode(), _ITERACOES).hex()
    return f"{_PREFIXO}${_ITERACOES}${salt}${digest}"


def eh_hash(valor: str) -> bool:
    return valor.startswith(_PREFIXO + "$")


def verificar_senha(senha: str, armazenada: str) -> bool:
    if not eh_hash(armazenada):
        # Compatibilidade com bancos antigos que guardavam a senha em texto puro
        return hmac.compare_digest(senha, armazenada)
    _, iteracoes, salt, digest = armazenada.split("$")
    calculado = hashlib.pbkdf2_hmac("sha256", senha.encode(), salt.encode(), int(iteracoes)).hex()
    return hmac.compare_digest(calculado, digest)


# --- TOKEN JWT ---

# Em produção, defina a variável de ambiente JWT_SECRET com um valor secreto
JWT_SECRET = os.getenv("JWT_SECRET", "agenda-escolar-chave-de-desenvolvimento-troque-em-producao")
JWT_ALGORITMO = "HS256"
JWT_EXPIRACAO_HORAS = 8


def gerar_token(usuario_id: int, perfil: str) -> str:
    agora = datetime.now(timezone.utc)
    payload = {
        "sub": str(usuario_id),
        "perfil": perfil,
        "iat": agora,
        "exp": agora + timedelta(hours=JWT_EXPIRACAO_HORAS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITMO)


def ler_token(token: str) -> int:
    """Retorna o id do usuário do token. Lança jwt.InvalidTokenError se inválido ou expirado."""
    payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITMO])
    return int(payload["sub"])

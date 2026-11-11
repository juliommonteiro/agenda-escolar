import os
import sys
import tempfile
from pathlib import Path

import pytest

# Usa um banco temporário para não mexer no agenda.db de desenvolvimento
_tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp.name}"
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient  # noqa: E402

import main  # noqa: E402
import models  # noqa: E402
from database import SessionLocal  # noqa: E402


EMAILS_INICIAIS = [u["email"] for u in main.USUARIOS_INICIAIS]


@pytest.fixture()
def client():
    # Limpa tudo entre os testes, mantendo só as contas iniciais
    with SessionLocal() as db:
        db.query(models.Conclusao).delete()
        db.query(models.Atividade).delete()
        db.query(models.Usuario).filter(models.Usuario.email.not_in(EMAILS_INICIAIS)).delete()
        db.commit()
    return TestClient(main.app)


def _login(client, email, perfil, senha="teste"):
    resp = client.post("/login/", json={"email": email, "senha": senha, "perfil": perfil})
    assert resp.status_code == 200, resp.text
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


@pytest.fixture()
def coord(client):
    return _login(client, "coordenador@example.com", "Coordenador")


@pytest.fixture()
def prof(client):
    return _login(client, "professor@example.com", "Professor")


@pytest.fixture()
def aluno(client):
    return _login(client, "aluno@example.com", "Aluno")


@pytest.fixture()
def login(client):
    return lambda email, perfil, senha="teste": _login(client, email, perfil, senha)

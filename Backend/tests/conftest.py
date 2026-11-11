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
    # Limpa tudo entre os testes, mantendo só as contas iniciais e a "Turma Exemplo"
    with SessionLocal() as db:
        db.query(models.Conclusao).delete()
        db.query(models.Atividade).delete()
        db.query(models.Usuario).update({models.Usuario.turma_id: None})
        db.query(models.Usuario).filter(models.Usuario.email.not_in(EMAILS_INICIAIS)).delete()
        db.query(models.Turma).filter(models.Turma.nome != main.TURMA_INICIAL).delete()
        turma = db.query(models.Turma).filter_by(nome=main.TURMA_INICIAL).first()
        if turma is None:  # algum teste excluiu a turma de exemplo
            turma = models.Turma(nome=main.TURMA_INICIAL)
            db.add(turma)
        turma.professor = db.query(models.Usuario).filter_by(email="professor@example.com").one()
        turma.alunos = [db.query(models.Usuario).filter_by(email="aluno@example.com").one()]
        db.commit()
    return TestClient(main.app)


@pytest.fixture()
def turma_id(client):
    """Id da "Turma Exemplo" (professor@example.com + aluno@example.com)."""
    with SessionLocal() as db:
        return db.query(models.Turma).filter_by(nome=main.TURMA_INICIAL).one().id


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

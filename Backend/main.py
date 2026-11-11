from typing import List

import jwt
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func
from sqlalchemy.orm import Session

import models
import schemas
from database import SessionLocal, engine
from seguranca import eh_hash, gerar_hash, gerar_token, ler_token, verificar_senha

# Contas criadas automaticamente na primeira execução (senha padrão: "teste")
SENHA_PADRAO = "teste"
COORDENADOR_PADRAO = "coordenador@example.com"
USUARIOS_INICIAIS = [
    {"nome": "Coordenador Padrão", "email": COORDENADOR_PADRAO, "perfil": "Coordenador"},
    {"nome": "Professor Padrão", "email": "professor@example.com", "perfil": "Professor"},
    {"nome": "Aluno Padrão", "email": "aluno@example.com", "perfil": "Aluno"},
]

# Quem pode criar, editar e excluir atividades
GESTORES_DE_ATIVIDADES = ("Professor", "Coordenador")

# Cria as tabelas no banco de dados automaticamente
models.Base.metadata.create_all(bind=engine)

# Injeta as contas padrão caso ainda não existam
with SessionLocal() as db_setup:
    for dados in USUARIOS_INICIAIS:
        if not db_setup.query(models.Usuario).filter(models.Usuario.email == dados["email"]).first():
            db_setup.add(models.Usuario(**dados, senha=gerar_hash(SENHA_PADRAO)))
    db_setup.commit()

app = FastAPI(title="API Agenda Escolar")

# Libera o acesso da API para o Flutter Web / navegador
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# --- AUTENTICAÇÃO (JWT) ---

_bearer = HTTPBearer(auto_error=False)


def get_usuario_atual(
    credenciais: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> models.Usuario:
    """Lê o token enviado no cabeçalho 'Authorization: Bearer <token>'."""
    nao_autorizado = HTTPException(
        status_code=401,
        detail="Sessão inválida ou expirada. Faça login novamente.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credenciais is None:
        raise nao_autorizado
    try:
        usuario_id = ler_token(credenciais.credentials)
    except (jwt.InvalidTokenError, KeyError, ValueError):
        raise nao_autorizado

    usuario = db.get(models.Usuario, usuario_id)
    if usuario is None:  # usuário excluído depois de logar
        raise nao_autorizado
    return usuario


def exigir_perfil(*perfis: str):
    """Dependência que só deixa passar usuários com um dos perfis informados."""

    def verificar(usuario: models.Usuario = Depends(get_usuario_atual)) -> models.Usuario:
        if usuario.perfil not in perfis:
            raise HTTPException(status_code=403, detail="Você não tem permissão para esta ação")
        return usuario

    return verificar


# --- FUNÇÕES AUXILIARES ---

def _buscar_atividade(db: Session, atividade_id: int) -> models.Atividade:
    atividade = db.get(models.Atividade, atividade_id)
    if not atividade:
        raise HTTPException(status_code=404, detail="Atividade não encontrada")
    return atividade


def _para_resposta(atividade: models.Atividade, concluida: bool = False, total: int = 0) -> schemas.AtividadeResponse:
    return schemas.AtividadeResponse(
        id=atividade.id,
        titulo=atividade.titulo,
        tipo=atividade.tipo,
        data=atividade.data,
        descricao=atividade.descricao,
        concluida=concluida,
        total_concluidas=total,
    )


# --- ROTAS DE LOGIN ---

@app.post("/login/", response_model=schemas.LoginResponse)
def fazer_login(dados: schemas.UsuarioLogin, db: Session = Depends(get_db)):
    usuario = db.query(models.Usuario).filter(
        models.Usuario.email == dados.email.strip().lower(),
        models.Usuario.perfil == dados.perfil,
    ).first()

    if not usuario or not verificar_senha(dados.senha, usuario.senha):
        raise HTTPException(status_code=401, detail="E-mail, senha ou perfil incorretos")

    # Converte senhas antigas (texto puro) para hash no primeiro login
    if not eh_hash(usuario.senha):
        usuario.senha = gerar_hash(dados.senha)
        db.commit()

    return {"access_token": gerar_token(usuario.id, usuario.perfil), "usuario": usuario}


@app.get("/usuarios/me", response_model=schemas.UsuarioResponse)
def usuario_logado(usuario: models.Usuario = Depends(get_usuario_atual)):
    return usuario


# --- ROTAS DE USUÁRIOS (somente Coordenador) ---

@app.get("/usuarios/", response_model=List[schemas.UsuarioResponse])
def listar_usuarios(
    db: Session = Depends(get_db),
    _: models.Usuario = Depends(exigir_perfil("Coordenador")),
):
    return db.query(models.Usuario).order_by(models.Usuario.perfil, models.Usuario.nome).all()


@app.post("/usuarios/", response_model=schemas.UsuarioResponse)
def criar_usuario(
    usuario: schemas.UsuarioCreate,
    db: Session = Depends(get_db),
    _: models.Usuario = Depends(exigir_perfil("Coordenador")),
):
    email = usuario.email.strip().lower()
    if db.query(models.Usuario).filter(models.Usuario.email == email).first():
        raise HTTPException(status_code=400, detail="E-mail já cadastrado")

    db_usuario = models.Usuario(
        nome=usuario.nome.strip(),
        email=email,
        senha=gerar_hash(usuario.senha),
        perfil=usuario.perfil,
    )
    db.add(db_usuario)
    db.commit()
    db.refresh(db_usuario)
    return db_usuario


@app.delete("/usuarios/{usuario_id}")
def deletar_usuario(
    usuario_id: int,
    db: Session = Depends(get_db),
    coordenador: models.Usuario = Depends(exigir_perfil("Coordenador")),
):
    db_usuario = db.get(models.Usuario, usuario_id)
    if not db_usuario:
        raise HTTPException(status_code=404, detail="Usuário não encontrado")
    if db_usuario.email == COORDENADOR_PADRAO:
        raise HTTPException(status_code=400, detail="Não é permitido excluir o coordenador padrão")
    if db_usuario.id == coordenador.id:
        raise HTTPException(status_code=400, detail="Você não pode excluir a sua própria conta")

    db.delete(db_usuario)  # o progresso do aluno (conclusões) é apagado junto
    db.commit()
    return {"mensagem": "Usuário excluído com sucesso"}


# --- ROTAS DE ATIVIDADES ---

@app.get("/atividades/", response_model=List[schemas.AtividadeResponse])
def listar_atividades(
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(get_usuario_atual),
):
    """Lista as atividades ordenadas por data (qualquer usuário logado).

    - `concluida`: se o usuário logado (aluno) concluiu a tarefa.
    - `total_concluidas`: quantos alunos concluíram (útil para professor/coordenador).
    """
    atividades = db.query(models.Atividade).order_by(models.Atividade.data, models.Atividade.id).all()

    totais = dict(
        db.query(models.Conclusao.atividade_id, func.count(models.Conclusao.id))
        .group_by(models.Conclusao.atividade_id)
        .all()
    )
    concluidas_pelo_usuario = {
        c.atividade_id
        for c in db.query(models.Conclusao).filter(models.Conclusao.usuario_id == usuario.id)
    }

    return [
        _para_resposta(a, concluida=a.id in concluidas_pelo_usuario, total=totais.get(a.id, 0))
        for a in atividades
    ]


@app.post("/atividades/", response_model=schemas.AtividadeResponse)
def criar_atividade(
    atividade: schemas.AtividadeCreate,
    db: Session = Depends(get_db),
    _: models.Usuario = Depends(exigir_perfil(*GESTORES_DE_ATIVIDADES)),
):
    dados = atividade.model_dump()
    dados["data"] = atividade.data.isoformat()
    db_atividade = models.Atividade(**dados)
    db.add(db_atividade)
    db.commit()
    db.refresh(db_atividade)
    return _para_resposta(db_atividade)


@app.put("/atividades/{atividade_id}", response_model=schemas.AtividadeResponse)
def atualizar_atividade(
    atividade_id: int,
    atividade: schemas.AtividadeCreate,
    db: Session = Depends(get_db),
    _: models.Usuario = Depends(exigir_perfil(*GESTORES_DE_ATIVIDADES)),
):
    db_atividade = _buscar_atividade(db, atividade_id)

    db_atividade.titulo = atividade.titulo
    db_atividade.tipo = atividade.tipo
    db_atividade.data = atividade.data.isoformat()
    db_atividade.descricao = atividade.descricao

    db.commit()
    db.refresh(db_atividade)
    return _para_resposta(db_atividade, total=len(db_atividade.conclusoes))


@app.put("/atividades/{atividade_id}/conclusao", response_model=schemas.AtividadeResponse)
def marcar_conclusao(
    atividade_id: int,
    dados: schemas.ConclusaoUpdate,
    db: Session = Depends(get_db),
    aluno: models.Usuario = Depends(exigir_perfil("Aluno")),
):
    """O aluno logado marca/desmarca uma tarefa como concluída (só afeta o progresso dele)."""
    db_atividade = _buscar_atividade(db, atividade_id)
    if db_atividade.tipo != "Tarefa":
        raise HTTPException(status_code=400, detail="Apenas tarefas podem ser concluídas")

    existente = db.query(models.Conclusao).filter(
        models.Conclusao.usuario_id == aluno.id,
        models.Conclusao.atividade_id == atividade_id,
    ).first()

    if dados.concluida and not existente:
        db.add(models.Conclusao(usuario_id=aluno.id, atividade_id=atividade_id))
    elif not dados.concluida and existente:
        db.delete(existente)
    db.commit()
    db.refresh(db_atividade)

    return _para_resposta(db_atividade, concluida=dados.concluida, total=len(db_atividade.conclusoes))


@app.delete("/atividades/{atividade_id}")
def deletar_atividade(
    atividade_id: int,
    db: Session = Depends(get_db),
    _: models.Usuario = Depends(exigir_perfil(*GESTORES_DE_ATIVIDADES)),
):
    db_atividade = _buscar_atividade(db, atividade_id)
    db.delete(db_atividade)
    db.commit()
    return {"mensagem": "Deletado com sucesso"}

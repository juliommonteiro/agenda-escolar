from typing import List, Optional

import jwt
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, inspect, text
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
TURMA_INICIAL = "Turma Exemplo"

# --- CRIAÇÃO E ATUALIZAÇÃO DO BANCO ---

# Cria as tabelas que ainda não existem
models.Base.metadata.create_all(bind=engine)


def _migrar_banco_existente():
    """Adiciona colunas novas em bancos criados por versões antigas do sistema."""
    colunas_novas = [("usuarios", "turma_id"), ("atividades", "turma_id")]
    inspetor = inspect(engine)
    with engine.begin() as conexao:
        for tabela, coluna in colunas_novas:
            existentes = {c["name"] for c in inspetor.get_columns(tabela)}
            if coluna not in existentes:
                conexao.execute(text(f"ALTER TABLE {tabela} ADD COLUMN {coluna} INTEGER REFERENCES turmas(id)"))


def _criar_dados_iniciais():
    """Cria as contas padrão e, se não houver nenhuma turma, uma turma de exemplo com elas."""
    with SessionLocal() as db:
        for dados in USUARIOS_INICIAIS:
            if not db.query(models.Usuario).filter(models.Usuario.email == dados["email"]).first():
                db.add(models.Usuario(**dados, senha=gerar_hash(SENHA_PADRAO)))
        db.flush()  # grava as contas novas para poderem ser consultadas abaixo

        if db.query(models.Turma).count() == 0:
            professor = db.query(models.Usuario).filter(models.Usuario.email == "professor@example.com").first()
            aluno = db.query(models.Usuario).filter(models.Usuario.email == "aluno@example.com").first()
            alunos = [aluno] if aluno and aluno.turma_id is None else []
            db.add(models.Turma(nome=TURMA_INICIAL, professor=professor, alunos=alunos))
        db.commit()


_migrar_banco_existente()
_criar_dados_iniciais()

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

def _buscar(db: Session, modelo, id_: int, mensagem: str):
    """Busca pelo id ou responde 404 com a mensagem informada."""
    objeto = db.get(modelo, id_)
    if not objeto:
        raise HTTPException(status_code=404, detail=mensagem)
    return objeto


def _pode_gerenciar_turma(usuario: models.Usuario, turma: Optional[models.Turma]) -> bool:
    """Coordenador gerencia qualquer turma; professor só as turmas em que leciona."""
    if usuario.perfil == "Coordenador":
        return True
    return usuario.perfil == "Professor" and turma is not None and turma.professor_id == usuario.id


def _contagens(db: Session):
    """Retorna (alunos por turma, conclusões por atividade contando só alunos da própria turma)."""
    alunos_por_turma = dict(
        db.query(models.Usuario.turma_id, func.count(models.Usuario.id))
        .filter(models.Usuario.perfil == "Aluno", models.Usuario.turma_id.is_not(None))
        .group_by(models.Usuario.turma_id)
        .all()
    )
    conclusoes_por_atividade = dict(
        db.query(models.Conclusao.atividade_id, func.count(models.Conclusao.id))
        .join(models.Usuario, models.Usuario.id == models.Conclusao.usuario_id)
        .join(models.Atividade, models.Atividade.id == models.Conclusao.atividade_id)
        .filter(models.Usuario.turma_id == models.Atividade.turma_id)
        .group_by(models.Conclusao.atividade_id)
        .all()
    )
    return alunos_por_turma, conclusoes_por_atividade


def _para_resposta(db: Session, atividade: models.Atividade, concluida: bool = False) -> schemas.AtividadeResponse:
    alunos_por_turma, conclusoes = _contagens(db)
    return _montar_resposta(atividade, concluida, alunos_por_turma, conclusoes)


def _montar_resposta(atividade, concluida, alunos_por_turma, conclusoes) -> schemas.AtividadeResponse:
    return schemas.AtividadeResponse(
        id=atividade.id,
        titulo=atividade.titulo,
        tipo=atividade.tipo,
        data=atividade.data,
        descricao=atividade.descricao,
        turma_id=atividade.turma_id,
        turma_nome=atividade.turma.nome if atividade.turma else None,
        concluida=concluida,
        total_concluidas=conclusoes.get(atividade.id, 0),
        total_alunos=alunos_por_turma.get(atividade.turma_id, 0),
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

    if usuario.turma_id is not None:
        if usuario.perfil != "Aluno":
            raise HTTPException(status_code=400, detail="Somente alunos podem ser colocados em uma turma")
        _buscar(db, models.Turma, usuario.turma_id, "Turma não encontrada")

    db_usuario = models.Usuario(
        nome=usuario.nome.strip(),
        email=email,
        senha=gerar_hash(usuario.senha),
        perfil=usuario.perfil,
        turma_id=usuario.turma_id,
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
    db_usuario = _buscar(db, models.Usuario, usuario_id, "Usuário não encontrado")
    if db_usuario.email == COORDENADOR_PADRAO:
        raise HTTPException(status_code=400, detail="Não é permitido excluir o coordenador padrão")
    if db_usuario.id == coordenador.id:
        raise HTTPException(status_code=400, detail="Você não pode excluir a sua própria conta")

    # O progresso do aluno é apagado junto; turmas do professor ficam sem professor
    db.delete(db_usuario)
    db.commit()
    return {"mensagem": "Usuário excluído com sucesso"}


# --- ROTAS DE TURMAS ---

@app.get("/turmas/", response_model=List[schemas.TurmaResponse])
def listar_turmas(
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(get_usuario_atual),
):
    """Coordenador vê todas; professor, as que leciona; aluno, a sua."""
    consulta = db.query(models.Turma).order_by(models.Turma.nome)
    if usuario.perfil == "Professor":
        consulta = consulta.filter(models.Turma.professor_id == usuario.id)
    elif usuario.perfil == "Aluno":
        if usuario.turma_id is None:
            return []
        consulta = consulta.filter(models.Turma.id == usuario.turma_id)
    return consulta.all()


def _aplicar_dados_turma(db: Session, turma: models.Turma, dados: schemas.TurmaCreate):
    nome = dados.nome.strip()
    duplicada = db.query(models.Turma).filter(func.lower(models.Turma.nome) == nome.lower()).first()
    if duplicada and duplicada.id != turma.id:
        raise HTTPException(status_code=400, detail="Já existe uma turma com esse nome")

    professor = None
    if dados.professor_id is not None:
        professor = _buscar(db, models.Usuario, dados.professor_id, "Usuário não encontrado")
        if professor.perfil != "Professor":
            raise HTTPException(status_code=400, detail="O responsável pela turma precisa ser um professor")

    alunos = []
    for aluno_id in dict.fromkeys(dados.aluno_ids):  # remove ids repetidos
        aluno = _buscar(db, models.Usuario, aluno_id, "Usuário não encontrado")
        if aluno.perfil != "Aluno":
            raise HTTPException(status_code=400, detail=f"{aluno.nome} não é um aluno")
        alunos.append(aluno)

    turma.nome = nome
    turma.professor = professor
    # Alunos removidos ficam sem turma; alunos de outra turma são transferidos para esta
    turma.alunos = alunos


@app.post("/turmas/", response_model=schemas.TurmaResponse)
def criar_turma(
    dados: schemas.TurmaCreate,
    db: Session = Depends(get_db),
    _: models.Usuario = Depends(exigir_perfil("Coordenador")),
):
    turma = models.Turma()
    _aplicar_dados_turma(db, turma, dados)
    db.add(turma)
    db.commit()
    db.refresh(turma)
    return turma


@app.put("/turmas/{turma_id}", response_model=schemas.TurmaResponse)
def atualizar_turma(
    turma_id: int,
    dados: schemas.TurmaCreate,
    db: Session = Depends(get_db),
    _: models.Usuario = Depends(exigir_perfil("Coordenador")),
):
    turma = _buscar(db, models.Turma, turma_id, "Turma não encontrada")
    _aplicar_dados_turma(db, turma, dados)
    db.commit()
    db.refresh(turma)
    return turma


@app.delete("/turmas/{turma_id}")
def deletar_turma(
    turma_id: int,
    db: Session = Depends(get_db),
    _: models.Usuario = Depends(exigir_perfil("Coordenador")),
):
    turma = _buscar(db, models.Turma, turma_id, "Turma não encontrada")
    db.delete(turma)  # atividades da turma são excluídas; alunos ficam sem turma
    db.commit()
    return {"mensagem": "Turma excluída com sucesso"}


# --- ROTAS DE ATIVIDADES ---

@app.get("/atividades/", response_model=List[schemas.AtividadeResponse])
def listar_atividades(
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(get_usuario_atual),
):
    """Lista as atividades ordenadas por data.

    - Coordenador: todas. Professor: das turmas em que leciona. Aluno: da sua turma.
    - `concluida`: se o usuário logado (aluno) concluiu a tarefa.
    - `total_concluidas` / `total_alunos`: progresso da turma na tarefa.
    """
    consulta = db.query(models.Atividade)
    if usuario.perfil == "Professor":
        consulta = consulta.join(models.Turma).filter(models.Turma.professor_id == usuario.id)
    elif usuario.perfil == "Aluno":
        if usuario.turma_id is None:
            return []
        consulta = consulta.filter(models.Atividade.turma_id == usuario.turma_id)
    atividades = consulta.order_by(models.Atividade.data, models.Atividade.id).all()

    alunos_por_turma, conclusoes = _contagens(db)
    concluidas_pelo_usuario = {
        c.atividade_id
        for c in db.query(models.Conclusao).filter(models.Conclusao.usuario_id == usuario.id)
    }
    return [
        _montar_resposta(a, a.id in concluidas_pelo_usuario, alunos_por_turma, conclusoes)
        for a in atividades
    ]


def _validar_turma_da_atividade(db: Session, usuario: models.Usuario, turma_id: int) -> models.Turma:
    turma = _buscar(db, models.Turma, turma_id, "Turma não encontrada")
    if not _pode_gerenciar_turma(usuario, turma):
        raise HTTPException(status_code=403, detail="Você só pode gerenciar atividades das suas turmas")
    return turma


@app.post("/atividades/", response_model=schemas.AtividadeResponse)
def criar_atividade(
    atividade: schemas.AtividadeCreate,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(exigir_perfil("Professor", "Coordenador")),
):
    _validar_turma_da_atividade(db, usuario, atividade.turma_id)
    dados = atividade.model_dump()
    dados["data"] = atividade.data.isoformat()
    db_atividade = models.Atividade(**dados)
    db.add(db_atividade)
    db.commit()
    db.refresh(db_atividade)
    return _para_resposta(db, db_atividade)


@app.put("/atividades/{atividade_id}", response_model=schemas.AtividadeResponse)
def atualizar_atividade(
    atividade_id: int,
    atividade: schemas.AtividadeCreate,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(exigir_perfil("Professor", "Coordenador")),
):
    db_atividade = _buscar(db, models.Atividade, atividade_id, "Atividade não encontrada")
    if not _pode_gerenciar_turma(usuario, db_atividade.turma):
        raise HTTPException(status_code=403, detail="Você só pode gerenciar atividades das suas turmas")
    _validar_turma_da_atividade(db, usuario, atividade.turma_id)

    db_atividade.titulo = atividade.titulo
    db_atividade.tipo = atividade.tipo
    db_atividade.data = atividade.data.isoformat()
    db_atividade.descricao = atividade.descricao
    db_atividade.turma_id = atividade.turma_id

    db.commit()
    db.refresh(db_atividade)
    return _para_resposta(db, db_atividade)


@app.put("/atividades/{atividade_id}/conclusao", response_model=schemas.AtividadeResponse)
def marcar_conclusao(
    atividade_id: int,
    dados: schemas.ConclusaoUpdate,
    db: Session = Depends(get_db),
    aluno: models.Usuario = Depends(exigir_perfil("Aluno")),
):
    """O aluno logado marca/desmarca uma tarefa da sua turma como concluída."""
    db_atividade = _buscar(db, models.Atividade, atividade_id, "Atividade não encontrada")
    if aluno.turma_id is None or db_atividade.turma_id != aluno.turma_id:
        raise HTTPException(status_code=403, detail="Esta tarefa não é da sua turma")
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

    return _para_resposta(db, db_atividade, concluida=dados.concluida)


@app.delete("/atividades/{atividade_id}")
def deletar_atividade(
    atividade_id: int,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(exigir_perfil("Professor", "Coordenador")),
):
    db_atividade = _buscar(db, models.Atividade, atividade_id, "Atividade não encontrada")
    if not _pode_gerenciar_turma(usuario, db_atividade.turma):
        raise HTTPException(status_code=403, detail="Você só pode gerenciar atividades das suas turmas")
    db.delete(db_atividade)
    db.commit()
    return {"mensagem": "Deletado com sucesso"}

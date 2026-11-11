from datetime import date
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Perfil = Literal["Aluno", "Professor", "Coordenador"]
TipoAtividade = Literal["Tarefa", "Evento"]


# --- SCHEMAS DE ATIVIDADES ---

class AtividadeBase(BaseModel):
    titulo: str = Field(min_length=1)
    tipo: TipoAtividade
    data: date  # o Flutter envia AAAA-MM-DD
    descricao: Optional[str] = "Nenhuma descrição informada."
    turma_id: int  # toda atividade pertence a uma turma


# Usado na hora de criar (POST) e editar (PUT)
class AtividadeCreate(AtividadeBase):
    pass


# Usado na hora de enviar para o Flutter (GET)
class AtividadeResponse(BaseModel):
    id: int
    titulo: str
    tipo: str
    data: str
    descricao: Optional[str] = None
    turma_id: Optional[int] = None
    turma_nome: Optional[str] = None
    # Para o aluno: se ELE concluiu a tarefa
    concluida: bool = False
    # Para o professor/coordenador: quantos alunos da turma concluíram e quantos existem
    total_concluidas: int = 0
    total_alunos: int = 0


class ConclusaoUpdate(BaseModel):
    # O aluno é identificado pelo token, não precisa enviar o id
    concluida: bool


# --- SCHEMAS DE USUÁRIOS ---

class UsuarioLogin(BaseModel):
    email: str
    senha: str
    perfil: Perfil


class UsuarioCreate(BaseModel):
    nome: str = Field(min_length=1)
    email: str = Field(min_length=3)
    senha: str = Field(min_length=3)
    perfil: Perfil
    turma_id: Optional[int] = None  # só para alunos


class UsuarioResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nome: str
    email: str
    perfil: str
    turma_id: Optional[int] = None
    turma_nome: Optional[str] = None


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioResponse


# --- SCHEMAS DE TURMAS ---

class UsuarioResumo(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nome: str
    email: str


class TurmaCreate(BaseModel):
    nome: str = Field(min_length=1)
    professor_id: Optional[int] = None
    aluno_ids: List[int] = []


class TurmaResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nome: str
    professor: Optional[UsuarioResumo] = None
    alunos: List[UsuarioResumo] = []

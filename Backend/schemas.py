from datetime import date
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Perfil = Literal["Aluno", "Professor", "Coordenador"]
TipoAtividade = Literal["Tarefa", "Evento"]


# --- SCHEMAS DE ATIVIDADES ---

class AtividadeBase(BaseModel):
    titulo: str = Field(min_length=1)
    tipo: TipoAtividade
    data: date  # o Flutter envia AAAA-MM-DD
    descricao: Optional[str] = "Nenhuma descrição informada."


# Usado na hora de criar (POST) e editar (PUT)
class AtividadeCreate(AtividadeBase):
    pass


# Usado na hora de enviar para o Flutter (GET)
class AtividadeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    titulo: str
    tipo: str
    data: str
    descricao: Optional[str] = None
    # Para o aluno: se ELE concluiu a tarefa
    concluida: bool = False
    # Para o professor: quantos alunos concluíram a tarefa
    total_concluidas: int = 0


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


class UsuarioResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nome: str
    email: str
    perfil: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioResponse

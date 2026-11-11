from sqlalchemy import Column, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import relationship

from database import Base


class Atividade(Base):
    __tablename__ = "atividades"

    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String, index=True)
    tipo = Column(String)  # 'Tarefa' ou 'Evento'
    data = Column(String)  # formato ISO: AAAA-MM-DD
    descricao = Column(String, nullable=True)

    conclusoes = relationship("Conclusao", back_populates="atividade", cascade="all, delete-orphan")


class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String)
    email = Column(String, unique=True, index=True)
    senha = Column(String)  # hash PBKDF2, nunca a senha em texto puro
    perfil = Column(String)  # 'Professor' ou 'Aluno'

    conclusoes = relationship("Conclusao", back_populates="usuario", cascade="all, delete-orphan")


class Conclusao(Base):
    """Registra que um aluno concluiu uma tarefa (cada aluno tem o seu próprio progresso)."""

    __tablename__ = "conclusoes"
    __table_args__ = (UniqueConstraint("usuario_id", "atividade_id", name="uq_usuario_atividade"),)

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    atividade_id = Column(Integer, ForeignKey("atividades.id"), nullable=False)

    usuario = relationship("Usuario", back_populates="conclusoes")
    atividade = relationship("Atividade", back_populates="conclusoes")

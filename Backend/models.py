from sqlalchemy import Column, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import relationship

from database import Base


class Turma(Base):
    __tablename__ = "turmas"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String, unique=True, index=True)
    # Professor responsável pela turma (opcional)
    professor_id = Column(Integer, ForeignKey("usuarios.id", use_alter=True), nullable=True)

    professor = relationship("Usuario", foreign_keys=[professor_id], back_populates="turmas_lecionadas")
    # Ao excluir a turma, os alunos ficam sem turma (turma_id = NULL)
    alunos = relationship(
        "Usuario", foreign_keys="Usuario.turma_id", back_populates="turma", order_by="Usuario.nome",
    )
    # Ao excluir a turma, as atividades dela também são excluídas
    atividades = relationship("Atividade", back_populates="turma", cascade="all, delete-orphan")


class Atividade(Base):
    __tablename__ = "atividades"

    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String, index=True)
    tipo = Column(String)  # 'Tarefa' ou 'Evento'
    data = Column(String)  # formato ISO: AAAA-MM-DD
    descricao = Column(String, nullable=True)
    turma_id = Column(Integer, ForeignKey("turmas.id"), nullable=True)

    turma = relationship("Turma", back_populates="atividades")
    conclusoes = relationship("Conclusao", back_populates="atividade", cascade="all, delete-orphan")


class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String)
    email = Column(String, unique=True, index=True)
    senha = Column(String)  # hash PBKDF2, nunca a senha em texto puro
    perfil = Column(String)  # 'Coordenador', 'Professor' ou 'Aluno'
    # Turma do aluno (só usado quando perfil == 'Aluno')
    turma_id = Column(Integer, ForeignKey("turmas.id"), nullable=True)

    turma = relationship("Turma", foreign_keys=[turma_id], back_populates="alunos")
    # Turmas em que o professor leciona. Ao excluir o professor, as turmas ficam sem professor.
    turmas_lecionadas = relationship("Turma", foreign_keys="Turma.professor_id", back_populates="professor")
    conclusoes = relationship("Conclusao", back_populates="usuario", cascade="all, delete-orphan")

    @property
    def turma_nome(self):
        return self.turma.nome if self.turma else None


class Conclusao(Base):
    """Registra que um aluno concluiu uma tarefa (cada aluno tem o seu próprio progresso)."""

    __tablename__ = "conclusoes"
    __table_args__ = (UniqueConstraint("usuario_id", "atividade_id", name="uq_usuario_atividade"),)

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    atividade_id = Column(Integer, ForeignKey("atividades.id"), nullable=False)

    usuario = relationship("Usuario", back_populates="conclusoes")
    atividade = relationship("Atividade", back_populates="conclusoes")

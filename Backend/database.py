import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# Por padrão cria o arquivo agenda.db na pasta do backend.
# Pode ser trocado pela variável de ambiente DATABASE_URL (usado nos testes).
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./agenda.db")

# connect_args é necessário para o SQLite trabalhar bem com o FastAPI
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

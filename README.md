# 📚 Agenda Escolar - Full-Stack

Um sistema completo de agenda escolar digital desenvolvido para facilitar a organização acadêmica de alunos e professores, centralizando tarefas e rotinas.

## 🚀 Tecnologias Utilizadas

O projeto foi construído utilizando uma arquitetura moderna dividida entre Front-end e Back-end:

*   **Front-end:** Flutter & Dart (Multiplataforma)
*   **Back-end:** Python, FastAPI, Uvicorn
*   **Banco de Dados:** SQLite

## ⚙️ Funcionalidades

**Coordenador**
*   Gerenciar atividades de **todas** as turmas (aba **Atividades**).
*   Gerenciar turmas (aba **Turmas**): criar, renomear e excluir turmas, definir o professor responsável e escolher os alunos.
*   Gerenciar usuários (aba **Usuários**): listar, filtrar por perfil, criar (já escolhendo a turma do aluno) e excluir contas.
*   O coordenador padrão e a própria conta não podem ser excluídos.

**Professor**
*   Ver e gerenciar só as atividades das turmas em que leciona.
*   Criar, editar (toque no card) e excluir tarefas e eventos para as suas turmas.
*   Filtrar atividades por tipo (Todas / Tarefa / Evento) e por turma.
*   Ver quantos alunos da turma já concluíram cada tarefa (ex.: "3 de 25").

**Turmas**
*   Cada turma tem um nome, um professor responsável (opcional) e seus alunos.
*   Cada aluno pertence a uma turma; ao colocá-lo em outra, ele é transferido.
*   Toda atividade pertence a uma turma.
*   Excluir uma turma exclui as atividades dela; os alunos ficam sem turma.

**Aluno**
*   Ver as atividades da sua turma ordenadas por data, com destaque para tarefas atrasadas.
*   Marcar tarefas como concluídas — o progresso é **individual** de cada aluno.
*   Barra de progresso com o total de tarefas concluídas.
*   Ver os detalhes/descrição de uma atividade (toque no card).

**Geral**
*   Login por perfil (Aluno, Professor ou Coordenador).
*   Autenticação com **token JWT** (válido por 8 horas): toda rota da API exige o token e verifica o perfil de quem chama.
*   Senhas armazenadas com hash (PBKDF2 + salt), nunca em texto puro.
*   Puxar a lista para baixo para atualizar.

## 🛠️ Como rodar o projeto localmente

### Pré-requisitos
Certifique-se de ter instalado em sua máquina:
*   [Flutter SDK](https://flutter.dev/docs/get-started/install)
*   [Python 3.x](https://www.python.org/downloads/)

### 1. Iniciando o Back-end (API)
```bash
cd Backend

# Crie e ative o ambiente virtual (só na primeira vez)
python -m venv .venv
.\.venv\Scripts\activate        # Windows
# source .venv/bin/activate       # Linux / macOS

# Instale as dependências
pip install -r requirements.txt

# Inicie a API (use --host 0.0.0.0 para acessar de um celular físico)
uvicorn main:app --reload --host 0.0.0.0
```

A documentação interativa da API (Swagger) fica em http://127.0.0.1:8000/docs.

### 2. Iniciando o Front-end (App)
Com a API rodando, em outro terminal:
```bash
cd Frontend
flutter pub get
flutter run
```

O endereço da API é escolhido automaticamente:

| Onde o app roda          | Endereço usado            |
|--------------------------|---------------------------|
| Emulador Android         | `http://10.0.2.2:8000`    |
| Web, Desktop, iOS (sim.) | `http://127.0.0.1:8000`   |
| Celular físico           | informe o IP do computador: `flutter run --dart-define=API_URL=http://192.168.0.10:8000` |

### 3. Acesso inicial
Ao iniciar pela primeira vez, a API cria uma conta de cada perfil, todas com a senha **`teste`**,
e uma **Turma Exemplo** com o professor e o aluno abaixo:

| Perfil      | E-mail                    |
|-------------|---------------------------|
| Coordenador | `coordenador@example.com` |
| Professor   | `professor@example.com`   |
| Aluno       | `aluno@example.com`       |

Pelo painel do coordenador é possível cadastrar novas contas (aba **Usuários**) e turmas (aba **Turmas**).

> Bancos criados por versões anteriores são atualizados automaticamente ao iniciar a API (colunas de turma).
> Atividades antigas ficam "Sem turma" e só aparecem para o coordenador, que pode editá-las e escolher a turma.

> Em produção, defina a variável de ambiente `JWT_SECRET` com uma chave secreta para assinar os tokens.

## ✅ Testes do Back-end
```bash
cd Backend
pytest
```

## 🗂️ Estrutura

```
Backend/
├── main.py          # Rotas da API (login, usuários, atividades, conclusões)
├── models.py        # Tabelas do banco (Usuario, Turma, Atividade, Conclusao)
├── schemas.py       # Validação dos dados de entrada/saída (Pydantic)
├── seguranca.py     # Hash de senhas e geração/validação do token JWT
├── database.py      # Conexão com o SQLite
└── tests/           # Testes automatizados da API
Frontend/lib/
├── main.dart                 # Tema, idioma (pt-BR) e retorno ao login se a sessão expirar
├── api_config.dart           # Endereço da API, envio do token e tratamento de erros
├── sessao.dart               # Token e usuário logado
├── navegacao.dart            # Transições de tela e logout
├── mensagens.dart            # Avisos (SnackBar) de sucesso/erro
├── formatadores.dart         # Formatação de datas
├── atividade_repository.dart # Chamadas HTTP de atividades
├── usuario_repository.dart   # Chamadas HTTP de login/cadastro
├── turma_repository.dart     # Chamadas HTTP de turmas
├── Screens/                  # Telas (login, painéis, formulários)
└── widgets/                  # Painéis reutilizáveis (atividades, turmas, usuários)
```

## 📡 Rotas da API

Todas as rotas, exceto `/login/`, exigem o cabeçalho `Authorization: Bearer <token>`.
No Swagger (`/docs`), faça login em `/login/`, copie o `access_token` e clique em **Authorize**.

| Método | Rota                          | Quem pode                | Descrição                                  |
|--------|-------------------------------|--------------------------|--------------------------------------------|
| POST   | `/login/`                     | Público                  | Autentica e retorna o token JWT            |
| GET    | `/usuarios/me`                | Qualquer usuário logado  | Dados do usuário logado                    |
| GET    | `/usuarios/`                  | Coordenador              | Lista usuários                             |
| POST   | `/usuarios/`                  | Coordenador              | Cria usuário                               |
| DELETE | `/usuarios/{id}`              | Coordenador              | Exclui usuário                             |
| GET    | `/turmas/`                    | Qualquer usuário logado  | Lista turmas (coord.: todas; prof.: as suas; aluno: a sua) |
| POST   | `/turmas/`                    | Coordenador              | Cria turma (nome, professor, alunos)       |
| PUT    | `/turmas/{id}`                | Coordenador              | Edita turma                                |
| DELETE | `/turmas/{id}`                | Coordenador              | Exclui turma e suas atividades             |
| GET    | `/atividades/`                | Qualquer usuário logado  | Lista atividades (coord.: todas; prof.: das suas turmas; aluno: da sua turma) |
| POST   | `/atividades/`                | Professor¹, Coordenador  | Cria atividade                             |
| PUT    | `/atividades/{id}`            | Professor¹, Coordenador  | Edita atividade                            |
| DELETE | `/atividades/{id}`            | Professor¹, Coordenador  | Exclui atividade                           |
| PUT    | `/atividades/{id}/conclusao`  | Aluno²                   | Marca/desmarca tarefa como concluída       |

¹ Somente em turmas em que leciona. ² Somente tarefas da sua turma.

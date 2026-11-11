import models
from database import SessionLocal

TAREFA = {"titulo": "Lista de exercícios", "tipo": "Tarefa", "data": "2026-12-01", "descricao": "Cap. 3"}


def criar_usuario(client, coord, email, perfil="Aluno", senha="teste"):
    resp = client.post(
        "/usuarios/", headers=coord,
        json={"nome": "Fulano", "email": email, "senha": senha, "perfil": perfil},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


# --- LOGIN E TOKEN ---

def test_contas_iniciais_fazem_login(client, login):
    for email, perfil in [
        ("coordenador@example.com", "Coordenador"),
        ("professor@example.com", "Professor"),
        ("aluno@example.com", "Aluno"),
    ]:
        login(email, perfil)


def test_login_retorna_token_e_usuario(client):
    resp = client.post("/login/", json={"email": "aluno@example.com", "senha": "teste", "perfil": "Aluno"})
    corpo = resp.json()
    assert corpo["token_type"] == "bearer" and corpo["access_token"]
    assert corpo["usuario"]["perfil"] == "Aluno"


def test_login_com_perfil_ou_senha_errados(client):
    assert client.post("/login/", json={"email": "aluno@example.com", "senha": "teste", "perfil": "Professor"}).status_code == 401
    assert client.post("/login/", json={"email": "aluno@example.com", "senha": "x", "perfil": "Aluno"}).status_code == 401


def test_rotas_exigem_token(client):
    assert client.get("/atividades/").status_code == 401
    assert client.get("/usuarios/").status_code == 401
    assert client.get("/atividades/", headers={"Authorization": "Bearer token-falso"}).status_code == 401


def test_usuarios_me(client, prof):
    assert client.get("/usuarios/me", headers=prof).json()["email"] == "professor@example.com"


def test_token_de_usuario_excluido_deixa_de_valer(client, coord, login):
    novo = criar_usuario(client, coord, "temp@escola.com")
    headers = login("temp@escola.com", "Aluno")
    client.delete(f"/usuarios/{novo['id']}", headers=coord)
    assert client.get("/atividades/", headers=headers).status_code == 401


# --- SENHAS ---

def test_senha_salva_com_hash(client, coord, login):
    novo = criar_usuario(client, coord, "a1@escola.com", senha="abc")
    with SessionLocal() as db:
        senha = db.get(models.Usuario, novo["id"]).senha
    assert senha != "abc" and senha.startswith("pbkdf2_sha256$")
    login("a1@escola.com", "Aluno", "abc")


def test_senha_antiga_em_texto_puro_continua_funcionando(client, login):
    with SessionLocal() as db:
        db.add(models.Usuario(nome="Antigo", email="antigo@escola.com", senha="velha", perfil="Aluno"))
        db.commit()
    login("antigo@escola.com", "Aluno", "velha")
    with SessionLocal() as db:
        assert db.query(models.Usuario).filter_by(email="antigo@escola.com").one().senha.startswith("pbkdf2_sha256$")


# --- GESTÃO DE USUÁRIOS (Coordenador) ---

def test_coordenador_cria_lista_e_exclui_usuarios(client, coord):
    for perfil in ("Aluno", "Professor", "Coordenador"):
        criar_usuario(client, coord, f"{perfil.lower()}2@escola.com", perfil)
    usuarios = client.get("/usuarios/", headers=coord).json()
    assert len(usuarios) == 6

    alvo = next(u for u in usuarios if u["email"] == "aluno2@escola.com")
    assert client.delete(f"/usuarios/{alvo['id']}", headers=coord).status_code == 200
    assert len(client.get("/usuarios/", headers=coord).json()) == 5


def test_professor_e_aluno_nao_gerenciam_usuarios(client, prof, aluno):
    novo = {"nome": "X", "email": "x@escola.com", "senha": "teste", "perfil": "Aluno"}
    for headers in (prof, aluno):
        assert client.get("/usuarios/", headers=headers).status_code == 403
        assert client.post("/usuarios/", headers=headers, json=novo).status_code == 403
        assert client.delete("/usuarios/1", headers=headers).status_code == 403


def test_email_duplicado(client, coord):
    criar_usuario(client, coord, "dup@escola.com")
    resp = client.post("/usuarios/", headers=coord, json={"nome": "X", "email": "DUP@escola.com ", "senha": "abc", "perfil": "Aluno"})
    assert resp.status_code == 400


def test_nao_exclui_coordenador_padrao(client, coord, login):
    criar_usuario(client, coord, "coord2@escola.com", "Coordenador")
    outro_coord = login("coord2@escola.com", "Coordenador")
    padrao = next(u for u in client.get("/usuarios/", headers=coord).json() if u["email"] == "coordenador@example.com")
    assert client.delete(f"/usuarios/{padrao['id']}", headers=outro_coord).status_code == 400


def test_coordenador_nao_exclui_a_si_mesmo(client, coord, login):
    novo = criar_usuario(client, coord, "coord3@escola.com", "Coordenador")
    headers = login("coord3@escola.com", "Coordenador")
    assert client.delete(f"/usuarios/{novo['id']}", headers=headers).status_code == 400


def test_perfil_invalido(client, coord):
    resp = client.post("/usuarios/", headers=coord, json={"nome": "X", "email": "x@escola.com", "senha": "abc", "perfil": "Diretor"})
    assert resp.status_code == 422


# --- ATIVIDADES ---

def test_professor_e_coordenador_gerenciam_atividades(client, prof, coord):
    for headers in (prof, coord):
        criada = client.post("/atividades/", headers=headers, json=TAREFA).json()
        editada = client.put(f"/atividades/{criada['id']}", headers=headers, json={**TAREFA, "titulo": "Novo"}).json()
        assert editada["titulo"] == "Novo"
        assert client.delete(f"/atividades/{criada['id']}", headers=headers).status_code == 200
    assert client.get("/atividades/", headers=prof).json() == []


def test_aluno_nao_gerencia_atividades(client, prof, aluno):
    criada = client.post("/atividades/", headers=prof, json=TAREFA).json()
    assert client.post("/atividades/", headers=aluno, json=TAREFA).status_code == 403
    assert client.put(f"/atividades/{criada['id']}", headers=aluno, json=TAREFA).status_code == 403
    assert client.delete(f"/atividades/{criada['id']}", headers=aluno).status_code == 403
    assert len(client.get("/atividades/", headers=aluno).json()) == 1


def test_atividades_ordenadas_por_data(client, prof):
    client.post("/atividades/", headers=prof, json={**TAREFA, "titulo": "B", "data": "2026-12-20"})
    client.post("/atividades/", headers=prof, json={**TAREFA, "titulo": "A", "data": "2026-12-05"})
    assert [a["titulo"] for a in client.get("/atividades/", headers=prof).json()] == ["A", "B"]


def test_dados_invalidos(client, prof):
    assert client.post("/atividades/", headers=prof, json={**TAREFA, "tipo": "Prova"}).status_code == 422
    assert client.post("/atividades/", headers=prof, json={**TAREFA, "data": "31/12"}).status_code == 422
    assert client.post("/atividades/", headers=prof, json={**TAREFA, "titulo": ""}).status_code == 422


# --- CONCLUSÃO DE TAREFAS (Aluno) ---

def test_conclusao_e_individual_por_aluno(client, prof, coord, aluno, login):
    criar_usuario(client, coord, "a2@escola.com")
    aluno2 = login("a2@escola.com", "Aluno")
    tarefa = client.post("/atividades/", headers=prof, json=TAREFA).json()

    resp = client.put(f"/atividades/{tarefa['id']}/conclusao", headers=aluno, json={"concluida": True})
    assert resp.status_code == 200

    assert client.get("/atividades/", headers=aluno).json()[0]["concluida"] is True
    assert client.get("/atividades/", headers=aluno2).json()[0]["concluida"] is False
    assert client.get("/atividades/", headers=prof).json()[0]["total_concluidas"] == 1

    client.put(f"/atividades/{tarefa['id']}/conclusao", headers=aluno, json={"concluida": False})
    assert client.get("/atividades/", headers=aluno).json()[0]["concluida"] is False


def test_somente_aluno_conclui_tarefa(client, prof, coord):
    tarefa = client.post("/atividades/", headers=prof, json=TAREFA).json()
    for headers in (prof, coord):
        assert client.put(f"/atividades/{tarefa['id']}/conclusao", headers=headers, json={"concluida": True}).status_code == 403


def test_evento_nao_pode_ser_concluido(client, prof, aluno):
    evento = client.post("/atividades/", headers=prof, json={**TAREFA, "tipo": "Evento"}).json()
    resp = client.put(f"/atividades/{evento['id']}/conclusao", headers=aluno, json={"concluida": True})
    assert resp.status_code == 400


def test_excluir_aluno_ou_atividade_remove_conclusoes(client, prof, coord, login):
    novo = criar_usuario(client, coord, "a3@escola.com")
    headers = login("a3@escola.com", "Aluno")
    t1 = client.post("/atividades/", headers=prof, json=TAREFA).json()
    t2 = client.post("/atividades/", headers=prof, json=TAREFA).json()
    client.put(f"/atividades/{t1['id']}/conclusao", headers=headers, json={"concluida": True})
    client.put(f"/atividades/{t2['id']}/conclusao", headers=headers, json={"concluida": True})

    client.delete(f"/atividades/{t1['id']}", headers=prof)
    with SessionLocal() as db:
        assert db.query(models.Conclusao).count() == 1

    client.delete(f"/usuarios/{novo['id']}", headers=coord)
    with SessionLocal() as db:
        assert db.query(models.Conclusao).count() == 0

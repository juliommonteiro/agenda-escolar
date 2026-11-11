import models
from database import SessionLocal

TAREFA = {"titulo": "Lista de exercícios", "tipo": "Tarefa", "data": "2026-12-01", "descricao": "Cap. 3"}


def criar_usuario(client, coord, email, perfil="Aluno", senha="teste", **extra):
    resp = client.post(
        "/usuarios/", headers=coord,
        json={"nome": email.split("@")[0], "email": email, "senha": senha, "perfil": perfil, **extra},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def criar_turma(client, coord, nome, professor_id=None, aluno_ids=()):
    resp = client.post(
        "/turmas/", headers=coord,
        json={"nome": nome, "professor_id": professor_id, "aluno_ids": list(aluno_ids)},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def criar_tarefa(client, headers, turma_id, **campos):
    resp = client.post("/atividades/", headers=headers, json={**TAREFA, "turma_id": turma_id, **campos})
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


def test_login_retorna_token_e_usuario_com_turma(client):
    resp = client.post("/login/", json={"email": "aluno@example.com", "senha": "teste", "perfil": "Aluno"})
    corpo = resp.json()
    assert corpo["token_type"] == "bearer" and corpo["access_token"]
    assert corpo["usuario"]["perfil"] == "Aluno"
    assert corpo["usuario"]["turma_nome"] == "Turma Exemplo"


def test_login_com_perfil_ou_senha_errados(client):
    assert client.post("/login/", json={"email": "aluno@example.com", "senha": "teste", "perfil": "Professor"}).status_code == 401
    assert client.post("/login/", json={"email": "aluno@example.com", "senha": "x", "perfil": "Aluno"}).status_code == 401


def test_rotas_exigem_token(client):
    assert client.get("/atividades/").status_code == 401
    assert client.get("/usuarios/").status_code == 401
    assert client.get("/turmas/").status_code == 401
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


def test_criar_aluno_ja_em_uma_turma(client, coord, turma_id):
    novo = criar_usuario(client, coord, "novato@escola.com", turma_id=turma_id)
    assert novo["turma_nome"] == "Turma Exemplo"
    resp = client.post("/usuarios/", headers=coord, json={
        "nome": "P", "email": "p@escola.com", "senha": "teste", "perfil": "Professor", "turma_id": turma_id,
    })
    assert resp.status_code == 400


# --- TURMAS ---

def test_coordenador_cria_e_edita_turma(client, coord):
    prof2 = criar_usuario(client, coord, "prof2@escola.com", "Professor")
    a1 = criar_usuario(client, coord, "t1@escola.com")
    a2 = criar_usuario(client, coord, "t2@escola.com")

    turma = criar_turma(client, coord, "3º Ano A", prof2["id"], [a1["id"], a2["id"]])
    assert turma["professor"]["id"] == prof2["id"]
    assert {a["id"] for a in turma["alunos"]} == {a1["id"], a2["id"]}

    # Remove um aluno e tira o professor
    resp = client.put(f"/turmas/{turma['id']}", headers=coord, json={"nome": "3º Ano B", "professor_id": None, "aluno_ids": [a1["id"]]})
    editada = resp.json()
    assert editada["nome"] == "3º Ano B" and editada["professor"] is None
    assert [a["id"] for a in editada["alunos"]] == [a1["id"]]
    with SessionLocal() as db:
        assert db.get(models.Usuario, a2["id"]).turma_id is None


def test_aluno_transferido_de_turma(client, coord, turma_id):
    aluno = next(u for u in client.get("/usuarios/", headers=coord).json() if u["email"] == "aluno@example.com")
    nova = criar_turma(client, coord, "Outra", aluno_ids=[aluno["id"]])
    assert [a["id"] for a in nova["alunos"]] == [aluno["id"]]
    exemplo = next(t for t in client.get("/turmas/", headers=coord).json() if t["id"] == turma_id)
    assert exemplo["alunos"] == []


def test_validacoes_de_turma(client, coord):
    a1 = criar_usuario(client, coord, "v1@escola.com")
    prof = next(u for u in client.get("/usuarios/", headers=coord).json() if u["perfil"] == "Professor")
    # Nome repetido (sem diferenciar maiúsculas)
    assert client.post("/turmas/", headers=coord, json={"nome": "turma exemplo"}).status_code == 400
    # Aluno como professor e professor como aluno
    assert client.post("/turmas/", headers=coord, json={"nome": "X", "professor_id": a1["id"]}).status_code == 400
    assert client.post("/turmas/", headers=coord, json={"nome": "X", "aluno_ids": [prof["id"]]}).status_code == 400
    assert client.post("/turmas/", headers=coord, json={"nome": "X", "aluno_ids": [9999]}).status_code == 404


def test_somente_coordenador_gerencia_turmas(client, prof, aluno, turma_id):
    for headers in (prof, aluno):
        assert client.post("/turmas/", headers=headers, json={"nome": "X"}).status_code == 403
        assert client.put(f"/turmas/{turma_id}", headers=headers, json={"nome": "X"}).status_code == 403
        assert client.delete(f"/turmas/{turma_id}", headers=headers).status_code == 403


def test_cada_perfil_ve_suas_turmas(client, coord, prof, aluno, login):
    criar_turma(client, coord, "Sem relação")
    assert len(client.get("/turmas/", headers=coord).json()) == 2
    assert [t["nome"] for t in client.get("/turmas/", headers=prof).json()] == ["Turma Exemplo"]
    assert [t["nome"] for t in client.get("/turmas/", headers=aluno).json()] == ["Turma Exemplo"]
    criar_usuario(client, coord, "semturma@escola.com")
    assert client.get("/turmas/", headers=login("semturma@escola.com", "Aluno")).json() == []


def test_excluir_turma_apaga_atividades_e_libera_alunos(client, coord, prof, turma_id):
    criar_tarefa(client, prof, turma_id)
    assert client.delete(f"/turmas/{turma_id}", headers=coord).status_code == 200
    with SessionLocal() as db:
        assert db.query(models.Atividade).count() == 0
        assert db.query(models.Usuario).filter_by(email="aluno@example.com").one().turma_id is None


def test_excluir_professor_deixa_turma_sem_professor(client, coord):
    prof2 = criar_usuario(client, coord, "prof3@escola.com", "Professor")
    turma = criar_turma(client, coord, "Turma do prof3", prof2["id"])
    client.delete(f"/usuarios/{prof2['id']}", headers=coord)
    restante = next(t for t in client.get("/turmas/", headers=coord).json() if t["id"] == turma["id"])
    assert restante["professor"] is None


# --- ATIVIDADES ---

def test_professor_e_coordenador_gerenciam_atividades(client, prof, coord, turma_id):
    for headers in (prof, coord):
        criada = criar_tarefa(client, headers, turma_id)
        assert criada["turma_nome"] == "Turma Exemplo"
        editada = client.put(f"/atividades/{criada['id']}", headers=headers, json={**TAREFA, "turma_id": turma_id, "titulo": "Novo"}).json()
        assert editada["titulo"] == "Novo"
        assert client.delete(f"/atividades/{criada['id']}", headers=headers).status_code == 200
    assert client.get("/atividades/", headers=prof).json() == []


def test_atividade_exige_turma(client, prof, turma_id):
    assert client.post("/atividades/", headers=prof, json=TAREFA).status_code == 422
    assert client.post("/atividades/", headers=prof, json={**TAREFA, "turma_id": 9999}).status_code == 404


def test_professor_so_gerencia_atividades_das_suas_turmas(client, coord, prof):
    outro = criar_usuario(client, coord, "outroprof@escola.com", "Professor")
    turma_alheia = criar_turma(client, coord, "Turma alheia", outro["id"])
    atividade_alheia = criar_tarefa(client, coord, turma_alheia["id"])

    assert client.post("/atividades/", headers=prof, json={**TAREFA, "turma_id": turma_alheia["id"]}).status_code == 403
    assert client.put(f"/atividades/{atividade_alheia['id']}", headers=prof, json={**TAREFA, "turma_id": turma_alheia["id"]}).status_code == 403
    assert client.delete(f"/atividades/{atividade_alheia['id']}", headers=prof).status_code == 403
    assert client.get("/atividades/", headers=prof).json() == []


def test_professor_nao_move_atividade_para_turma_alheia(client, coord, prof, turma_id):
    turma_alheia = criar_turma(client, coord, "Alheia")
    minha = criar_tarefa(client, prof, turma_id)
    resp = client.put(f"/atividades/{minha['id']}", headers=prof, json={**TAREFA, "turma_id": turma_alheia["id"]})
    assert resp.status_code == 403


def test_aluno_ve_so_atividades_da_sua_turma(client, coord, prof, aluno, turma_id):
    outra = criar_turma(client, coord, "Outra turma")
    criar_tarefa(client, prof, turma_id, titulo="Minha")
    criar_tarefa(client, coord, outra["id"], titulo="De outra turma")
    assert [a["titulo"] for a in client.get("/atividades/", headers=aluno).json()] == ["Minha"]
    assert len(client.get("/atividades/", headers=coord).json()) == 2


def test_aluno_nao_gerencia_atividades(client, prof, aluno, turma_id):
    criada = criar_tarefa(client, prof, turma_id)
    corpo = {**TAREFA, "turma_id": turma_id}
    assert client.post("/atividades/", headers=aluno, json=corpo).status_code == 403
    assert client.put(f"/atividades/{criada['id']}", headers=aluno, json=corpo).status_code == 403
    assert client.delete(f"/atividades/{criada['id']}", headers=aluno).status_code == 403


def test_atividades_ordenadas_por_data(client, prof, turma_id):
    criar_tarefa(client, prof, turma_id, titulo="B", data="2026-12-20")
    criar_tarefa(client, prof, turma_id, titulo="A", data="2026-12-05")
    assert [a["titulo"] for a in client.get("/atividades/", headers=prof).json()] == ["A", "B"]


def test_dados_invalidos(client, prof, turma_id):
    corpo = {**TAREFA, "turma_id": turma_id}
    assert client.post("/atividades/", headers=prof, json={**corpo, "tipo": "Prova"}).status_code == 422
    assert client.post("/atividades/", headers=prof, json={**corpo, "data": "31/12"}).status_code == 422
    assert client.post("/atividades/", headers=prof, json={**corpo, "titulo": ""}).status_code == 422


# --- CONCLUSÃO DE TAREFAS (Aluno) ---

def test_conclusao_e_individual_e_contada_por_turma(client, prof, coord, aluno, login, turma_id):
    criar_usuario(client, coord, "a2@escola.com", turma_id=turma_id)
    aluno2 = login("a2@escola.com", "Aluno")
    tarefa = criar_tarefa(client, prof, turma_id)

    resp = client.put(f"/atividades/{tarefa['id']}/conclusao", headers=aluno, json={"concluida": True})
    assert resp.status_code == 200

    assert client.get("/atividades/", headers=aluno).json()[0]["concluida"] is True
    assert client.get("/atividades/", headers=aluno2).json()[0]["concluida"] is False
    visao_prof = client.get("/atividades/", headers=prof).json()[0]
    assert (visao_prof["total_concluidas"], visao_prof["total_alunos"]) == (1, 2)

    client.put(f"/atividades/{tarefa['id']}/conclusao", headers=aluno, json={"concluida": False})
    assert client.get("/atividades/", headers=aluno).json()[0]["concluida"] is False


def test_aluno_nao_conclui_tarefa_de_outra_turma(client, coord, aluno):
    outra = criar_turma(client, coord, "Outra")
    tarefa = criar_tarefa(client, coord, outra["id"])
    assert client.put(f"/atividades/{tarefa['id']}/conclusao", headers=aluno, json={"concluida": True}).status_code == 403


def test_aluno_transferido_nao_conta_na_turma_antiga(client, coord, prof, aluno, turma_id):
    tarefa = criar_tarefa(client, prof, turma_id)
    client.put(f"/atividades/{tarefa['id']}/conclusao", headers=aluno, json={"concluida": True})
    aluno_id = client.get("/usuarios/me", headers=aluno).json()["id"]
    criar_turma(client, coord, "Nova", aluno_ids=[aluno_id])
    visao = client.get("/atividades/", headers=prof).json()[0]
    assert (visao["total_concluidas"], visao["total_alunos"]) == (0, 0)


def test_somente_aluno_conclui_tarefa(client, prof, coord, turma_id):
    tarefa = criar_tarefa(client, prof, turma_id)
    for headers in (prof, coord):
        assert client.put(f"/atividades/{tarefa['id']}/conclusao", headers=headers, json={"concluida": True}).status_code == 403


def test_evento_nao_pode_ser_concluido(client, prof, aluno, turma_id):
    evento = criar_tarefa(client, prof, turma_id, tipo="Evento")
    resp = client.put(f"/atividades/{evento['id']}/conclusao", headers=aluno, json={"concluida": True})
    assert resp.status_code == 400


def test_excluir_aluno_ou_atividade_remove_conclusoes(client, prof, coord, login, turma_id):
    novo = criar_usuario(client, coord, "a3@escola.com", turma_id=turma_id)
    headers = login("a3@escola.com", "Aluno")
    t1 = criar_tarefa(client, prof, turma_id)
    t2 = criar_tarefa(client, prof, turma_id)
    client.put(f"/atividades/{t1['id']}/conclusao", headers=headers, json={"concluida": True})
    client.put(f"/atividades/{t2['id']}/conclusao", headers=headers, json={"concluida": True})

    client.delete(f"/atividades/{t1['id']}", headers=prof)
    with SessionLocal() as db:
        assert db.query(models.Conclusao).count() == 1

    client.delete(f"/usuarios/{novo['id']}", headers=coord)
    with SessionLocal() as db:
        assert db.query(models.Conclusao).count() == 0

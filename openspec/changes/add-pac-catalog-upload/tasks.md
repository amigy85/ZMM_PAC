# Tasks

Cada tarefa é marcada `- [x]` **depois** de o objecto activar no SAP e o teste
passar (o utilizador confirma a activação). Referência de commit:
`[refs: add-pac-catalog-upload <n.º>]`.

## 0. Preparação

- [x] 0.1 Decisões D-01, D-02, D-03, D-06, D-07 registadas como decididas em `proposal.md` (bloqueiam o apply) — D-06 fechada 2026-10-13 (só PAC; regex validada; cp1252; sem aspas)
- [x] 0.2 Nível de SP do SAP_BASIS confirmado via MCP (CVERS: SAP_BASIS 740 SP0022) e registado no `CLAUDE.md` — 2026-10-14; `FILTER`/`REDUCE`/`FOR` permitidos (SP22 ≥ SP08)
- [x] 0.3 Data elements standard da §5.2 confirmados via MCP (DD04L) — 2026-10-14: `MANDT`, `DATAB`, `DATBI`, `ERNAM`, `ERDAT`, `ERZET`, `AENAM`, `AEDAT`, `AEZET` existem todos; `AEZET` presente (TIMS 6), sem fallback para `UZEIT`
- [ ] 0.4 `rec/client` em QAS/PRD confirmado com Basis (registo de alterações) [REQ-14 / segurança]
- [x] 0.5 Packages `ZMM_PAC`, `_DATA`, `_CORE`, `_UI` criados no DEV; repositório abapGit ligado (online, branch `change/add-pac-catalog-upload`, PREFIX); pull sem diffs fantasma; ordem `CBDK918074` registada em `proposal.md` — 2026-10-14
- [x] 0.6 `.abapgit.xml`, `.gitattributes` e os `package.devc.xml` gerados; `abapgit_meta.py check` sem erros — 2026-10-14 (`check` exit 0; `.abapgit.xml` com `MASTER_LANGUAGE=P`, `/src/`, `PREFIX`); git inicializado no ramo `change/add-pac-catalog-upload`

## 1. Dicionário de dados

- [x] 1.1 Domínios e data elements `ZMM_PAC_*` corrigidos no local e movidos para `ZMM_PAC_DATA`; serializados em `/src/data/` (2026-10-16) [modelo de dados]
- [x] 1.2 Tabelas `ZMM_PAC_CATG` e `ZMM_PAC_SUBCATG` (chave MANDT+PAC_YEAR+PAC_SUBCAT, validade BEGDA/ENDDA, auditoria com ERZET, descrições CHAR 72); serializadas (2026-10-16) [ADR-02]
- [x] 1.3 Foreign key `ZMM_PAC_SUBCATG-PAC_CAT` → `ZMM_PAC_CATG` criada, verificada via MCP e serializada no `.tabl.xml` (2026-10-16) [REQ-06]
- [x] 1.4 Classe de mensagens `ZMM_PAC` com as 42 mensagens da §8.1 (MASTERLANG P) serializada (2026-10-16) [todos os REQ]

## 2. Núcleo

- [x] 2.1 `ZCX_MM_PAC` criada no SE24 (CX_STATIC_CHECK + IF_T100_MESSAGE; textos 050/051/063) e serializada (2026-10-16) — atributos para `&1/&2` a acrescentar quando as classes de raise (AUTH/repository) forem escritas
- [x] 2.2 `ZIF_MM_PAC_TYPES` e `ZIF_MM_PAC_REPOSITORY` geradas, pull e activação sem erro (2026-10-16; `.abap` sem BOM)
- [x] 2.3 `ZCL_MM_PAC_PARSER` + testes (7 ABAP Unit verdes) — activo no DEV (2026-10-16) [REQ-02, REQ-05 normalização]
- [x] 2.4 `ZCL_MM_PAC_LOG` + testes (4 ABAP Unit verdes) — activo no DEV (2026-10-16) [REQ-16]
- [x] 2.5 `ZCL_MM_PAC_VALIDATOR` + testes (12 ABAP Unit verdes) — activo no DEV (2026-10-16) [REQ-03..REQ-09]
- [x] 2.6 `ZCL_MM_PAC_CHANGESET` + testes (5 ABAP Unit verdes) — activo no DEV (2026-10-17) [REQ-14]
- [x] 2.7 `ZCL_MM_PAC_REPOSITORY` activo no DEV (2026-10-17); Open SQL por ano, `ENQUEUE/DEQUEUE_E_TABLE` `_scope 1`, `insert_new` sem commit (cat antes de subcat, `cx_sy_open_sql_db`→063), `commit` sem `AND WAIT`. Verificação do bloqueio em SM12 fica para QAS (§14.3) [REQ-13, REQ-11]
- [x] 2.8 `ZCL_MM_PAC_AUTH` (2 ABAP Unit verdes, duplo por herança) + objecto de autorização `ZMM_PAC` (SU21, classe de objecto `ZPAC`) serializado — activo no DEV (2026-10-17) [REQ-15]
- [x] 2.9 `ZCL_MM_PAC_UPLOAD` + testes com duplos (6 ABAP Unit verdes) — activo no DEV (2026-10-17) [REQ-10, REQ-11, REQ-12, REQ-13, REQ-15]

## 3. Interface

- [x] 3.1 `ZMM_PAC_UPLOAD` (ecrã de selecção, ALV `CL_SALV_TABLE`, popup 066, REQ-17) + `ZCL_MM_PAC_FILE` (F4 + gui_upload cp1252) — activos no DEV (2026-10-17); textos de selecção/símbolos por criar no SE38 [REQ-01, REQ-16, REQ-17]
- [x] 3.2 `ZMM_PAC_MENU` activo no DEV + transacções `ZMM_PAC` / `ZMM_PAC_UPLOAD` criadas em SE93 e serializadas (2026-10-17) [ADR-05] — nota: os `.tran.xml` ficaram em `src/core` (package `ZMM_PAC_CORE`); mover para `ZMM_PAC_UI` é opcional

## 4. Verificação

- [x] 4.1 Todos os testes ABAP Unit verdes — 36/36 no package `ZMM_PAC_CORE` (parser 7, log 4, validator 12, changeset 5, auth 2, upload 6), 2026-10-17 [REQ-01..REQ-17]
- [x] 4.2 ATC sem findings de prioridade 1 e 2 (2026-10-21) — P1 do `ENQUEUE/DEQUEUE_E_TABLE` (VARKEY tipo) corrigido com `lv_varkey TYPE rstable-varkey`
- [ ] 4.3 Testes manuais em QAS da §14.3 executados e evidenciados (SE16N, SCU3, SM12, SU53, SM37)
- [ ] 4.4 REQ-18 medido em QAS com ficheiro de 10 000 linhas (< 60 s)
- [ ] 4.5 `abapgit_meta.py check` sem erros; pull limpo (sem diffs fantasma) no DEV
- [x] 4.6 **(follow-up de segurança)** `AUTHORITY-CHECK '03'` movido para **antes** da leitura do ficheiro (REQ-15 / §4.6): o programa faz `lo_auth->check( c_actvt_display )` antes de `zcl_mm_pac_file->read` e reutiliza o `lo_auth` no orquestrador; falha → `MESSAGE e050` e sai. 2026-10-21

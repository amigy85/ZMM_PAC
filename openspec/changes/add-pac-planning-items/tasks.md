# Tasks

Cada tarefa é marcada `- [x]` **depois** de o objecto activar no SAP e o teste passar (o
utilizador confirma). Referência de commit: `[refs: add-pac-planning-items <n.º>]`.
Depende da mudança 1 (catálogo activo). Não transportar antes da 1.

## 0. Preparação
- [x] 0.1 Decisões D5-01..D5-07 registadas em `proposal.md`; proposta revista e aprovada (2026-10-23)
- [x] 0.2 Objecto de intervalo de números `ZMM_PAC` (nrob) criado e serializado (2026-10-23)
- [x] 0.3 `ZMM_PAC_ITEM` esvaziada antes da conversão (2026-10-23)

## 1. Dicionário de dados (correcção da `ZMM_PAC_ITEM`)
- [x] 1.1 Domínio/data element `ZMM_PAC_VALOR` (CURR 15,2) + status `ZMM_PACITEM_STATUS` (D/A/B/C/F); activados e serializados (2026-10-23) [D5-05, D5-03]
- [x] 1.2 `ZMM_PAC_ITEM`: `VALOR`→CURR (ref. `MOEDA`), `QUANTIDADE` QUAN (ref. `MEINS`), `KOSTL` removido, `CENTRO`/`SAKNR` opcionais; activado + BD ajustada; confirmado via MCP (2026-10-23) [D5-04, D5-05]
- [x] 1.3 Foreign keys `PAC_CAT`→`ZMM_PAC_CATG` e `PAC_SUBCAT`→`ZMM_PAC_SUBCATG`; `.tabl.xml` reserializado (2026-10-23) [REQ-24]
- [x] 1.4 Mensagens 080–087 na classe `ZMM_PAC` serializadas (2026-10-23) [todos os REQ]

## 2. Núcleo
- [x] 2.1 `ZIF_MM_PAC_TYPES`: `ty_item_row`/`tt_item_row`/`tt_item` acrescentados; activo (2026-10-26) [modelo de dados]
- [x] 2.2 `ZIF_MM_PAC_ITEM_REPOSITORY` (read_categories/subcategories, lock/unlock, next_item_number, insert_new, commit, rollback); activo (2026-10-26)
- [x] 2.3 `ZCL_MM_PAC_ITEM_PARSER` + testes (7 ABAP Unit verdes) — activo (2026-10-26) [REQ-21, normalização]
- [x] 2.4 `ZCL_MM_PAC_ITEM_VALIDATOR` + testes (8 ABAP Unit verdes; msg 088 na MSAG) — activo (2026-10-26) [REQ-22..25]
- [x] 2.5 `ZCL_MM_PAC_ITEM_CHANGESET` + testes (4 ABAP Unit verdes; carimbo único, status `D`) — activo (2026-10-26) [REQ-26]
- [x] 2.6 `ZCL_MM_PAC_ITEM_REPOSITORY` (Open SQL, `NUMBER_GET_NEXT`, bloqueio por ano) — activo (2026-10-26) [REQ-26, REQ-20]
- [x] 2.7 `ZCL_MM_PAC_ITEM_UPLOAD` + testes com duplos (6 ABAP Unit verdes; nº só na escrita) — activo (2026-10-26) [REQ-20, REQ-26, REQ-27]

## 3. Interface
- [x] 3.1 `ZMM_PAC_ITEM_UPLOAD` (ecrã de selecção, ALV, popup, REQ-27 fundo→erro); textos no SE38; msg 089 criada — activo (2026-10-26) [REQ-20, REQ-27]
- [x] 3.2 Transacção `ZMM_PAC_ITEM_UPLOAD` (SE93) e 2.º botão no `ZMM_PAC_MENU` (P02); `.tran.xml` + TPOOL serializados (2026-10-27) [ADR-05]

## 5. Adenda D5-08 — validação de dados-mestre (moeda/unidade/centro/conta)
- [x] 5.1 DDIC: foreign keys `MOEDA→TCURC`, `MEINS→T006`, `CENTRO→T001W` activas e correctas; `.tabl.xml` reserializado (2026-10-28) [D5-08]
- [x] 5.2 Mensagens `090`–`095` na classe `ZMM_PAC` serializadas (confirmado via MCP) (2026-10-27) [D5-08]
- [x] 5.3 `ZIF/ZCL_MM_PAC_ITEM_REPOSITORY`: `read_currencies`/`read_plants`/`read_gl_accounts(iv_bukrs)`/`normalize_uom` — activo (2026-10-27) [D5-08]
- [x] 5.4 `ZCL_MM_PAC_ITEM_VALIDATOR`: centro/conta obrigatórios + existência (bloqueante); 14 testes verdes (2026-10-27) [D5-08]
- [x] 5.5 `ZCL_MM_PAC_ITEM_UPLOAD` + programa: `P_BUKRS` (default `HCB`); `resolve_uom`; injecção dos conjuntos; testes verdes (2026-10-27) [D5-08]
- [x] 5.6 Fixtures regenerados: happy-path/volume reais gitignored; `item_erros.csv` versionado cobre 082–095 (2026-10-27) [D5-08]

## 4. Verificação
- [x] 4.1 Todos os ABAP Unit verdes (61/61: 36 catálogo + 25 item; sem regressão) (2026-10-27)
- [x] 4.2 ATC sem findings P1/P2 (só P3: instruções críticas LUW/bloqueio/nº-range + SLIN, esperados) (2026-10-27)
- [ ] 4.3 Testes manuais em **DEV** (SE16N, SCU3, SM12, SU53, SM37; numeração sequencial; conversão CURR). QAS fica como gate formal no transporte.
- [ ] 4.4 Volume (10 000 itens < 60 s) em **DEV**
- [x] 4.5 `abapgit_meta.py check` sem erros; disco alinhado com SAP (menu c/ P02 re-serializado) (2026-10-27)

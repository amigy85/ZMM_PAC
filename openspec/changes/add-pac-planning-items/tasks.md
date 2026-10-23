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
- [ ] 2.1 `ZIF_MM_PAC_TYPES`: acrescentar `ty_item_row` e `tt_item` [modelo de dados]
- [ ] 2.2 `ZIF_MM_PAC_ITEM_REPOSITORY` (`read_catalog`, `lock_year`, `unlock_year`, `next_item_number`, `insert_new`, `commit`, `rollback`)
- [ ] 2.3 `ZCL_MM_PAC_ITEM_PARSER` + testes [REQ-21, normalização]
- [ ] 2.4 `ZCL_MM_PAC_ITEM_VALIDATOR` + testes (iv_today; catálogo em memória por duplo) [REQ-22..25]
- [ ] 2.5 `ZCL_MM_PAC_ITEM_CHANGESET` + testes (carimbo único, status `D`) [REQ-26]
- [ ] 2.6 `ZCL_MM_PAC_ITEM_REPOSITORY` (Open SQL, `NUMBER_GET_NEXT`, bloqueio por ano) [REQ-26, REQ-20]
- [ ] 2.7 `ZCL_MM_PAC_ITEM_UPLOAD` + testes com duplos (REQ-20 sem COMMIT em simulação; número só na escrita) [REQ-20, REQ-26, REQ-27]

## 3. Interface
- [ ] 3.1 `ZMM_PAC_ITEM_UPLOAD` (ecrã de selecção, ALV, popup, REQ-27 fundo→erro); textos no SE38 [REQ-20, REQ-27]
- [ ] 3.2 Transacção `ZMM_PAC_ITEM_UPLOAD` (SE93) e botão no `ZMM_PAC_MENU`; serializar [ADR-05]

## 4. Verificação
- [ ] 4.1 Todos os ABAP Unit verdes
- [ ] 4.2 ATC sem findings P1/P2
- [ ] 4.3 Testes manuais em QAS (SE16N, SCU3, SM12, SU53, SM37; numeração sequencial; conversão CURR)
- [ ] 4.4 Volume (10 000 itens < 60 s) em QAS
- [ ] 4.5 `abapgit_meta.py check` sem erros; pull limpo no DEV

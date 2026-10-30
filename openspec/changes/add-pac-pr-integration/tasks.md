# Tasks

Cada tarefa marca-se `- [x]` **depois** de activar no SAP e o teste passar (o utilizador
confirma). Referência de commit: `[refs: add-pac-pr-integration <n.º>]`. **Depende das
mudanças 1 e 5** (catálogo e itens activos). Não transportar antes delas.

## 0. Preparação
- [ ] 0.1 Decisões D4-00..D4-06 registadas (D4-05 = `ZMANB ∈ {CP,CL,AD,DF}` + item não eliminado; D4-06 = sem autorização adicional); proposta revista e aprovada
- [ ] 0.2 Nº da ordem de transporte registado em `proposal.md`

## 1. Mensagens (classe `ZMM_PAC`)
- [x] 1.1 Mensagens `100`–`106` criadas e serializadas (SE91); search helps `ZMM_PAC_CATG`/`SUBCATG` versionadas (2026-10-30) [REQ-30..REQ-34]
      (`100` item inexistente, `101` incoerência ano/cat/subcat, `102` categoria inactiva,
      `103` estado não utilizável, `104` atribuição obrigatória em falta, `105`/`106` subtela)

## 2. Núcleo (pacote `ZMM_PAC_CORE`, abapGit)
- [ ] 2.1 `ZCL_MM_PAC_REQ_VALIDATOR`: valida existência/coerência/estado/obrigatoriedade de um item de RC; leitura com buffer `HASHED`; devolve veredicto + nº de mensagem `ZMM_PAC` — activo [REQ-30..REQ-33]
- [ ] 2.2 ABAP Unit do validador (item inexistente, subcat/ano trocados, categoria inactiva, estado ≠ A, obrigatório sem atribuição, opcional sem atribuição, caso válido) — verdes [REQ-30..REQ-33]

## 3. Ganchos (pacote `ZMM`, entrega por transporte; só chamam o validador)
- [ ] 3.1 Bloco PAC no `IF_EX_ME_PROCESS_REQ_CUST~CHECK` (`ZCL_IM_ME_PROCESS_REQ_CUST`): lê o cabeçalho (`ZMANB`), calcula a obrigatoriedade (`∈ {CP,CL,AD,DF}`), por item não eliminado chama `ZCL_MM_PAC_REQ_VALIDATOR` e emite `mmpur_message 'E' 'ZMM_PAC' …`; não grava — activo [REQ-30, REQ-33, REQ-35]
- [ ] 3.2 Subtela 0111 (`ZXM02F01` `LCL_PAC~selecionar_item`): substituir os `MESSAGE` com texto literal por mensagens `ZMM_PAC` (`105`/`106`); popup `REUSE_ALV` mantido [REQ-34, REQ-03/D4-03]

## 4. Verificação
- [ ] 4.1 ABAP Unit do validador verdes (com os do catálogo/itens, sem regressão)
- [ ] 4.2 ATC sem findings P1/P2 nos objectos novos/alterados
- [ ] 4.3 Testes manuais em DEV (ME51N/ME52N): item inexistente→erro; subcat/ano trocados→erro; categoria inactiva→erro; item em `D`→erro; `KNTTP='K'` sem PAC→erro; item opcional sem PAC→grava; atribuição válida→grava; legado `AFNAM`/`BEDNR` intacto [REQ-30..REQ-35]
- [ ] 4.4 `abapgit_meta.py check` sem erros; pull limpo no DEV (validador + `MSAG`)

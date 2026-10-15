# Project Context — ZMM_PAC (Plano Anual de Compras)

Contexto que os agentes **não** conseguem inferir lendo o código. A fonte operacional
completa é o `CLAUDE.md` na raiz; aqui ficam só as restrições que moldam os artefactos
OpenSpec. Comunicação em português; código, nomes de objectos e comentários em inglês
(Clean ABAP); textos de utilizador apenas na classe de mensagens `ZMM_PAC`.

## Stack e ambiente

- SAP ECC 6.0 EHP7 · **SAP_BASIS 7.40 SP22** (confirmado via MCP/CVERS, 2026-10-14) · CBD/010.
- Entrega **exclusivamente** por abapGit pull: Git push → pull no DEV → transporte DEV → QAS → PRD.
- Acesso de Claude Code ao SAP é por **MCP só de leitura** — consultar, nunca escrever.
- `MASTER_LANGUAGE` do repositório abapGit = **`P`** (D-01), **irreversível** após o primeiro pull.

## Sintaxe ABAP permitida (7.40 SP22)

- Permitido: declarações inline, `VALUE #`, `NEW #`, `CONV #`, `CORRESPONDING #`,
  expressões de tabela, templates de string, Open SQL com `@` e vírgulas, **e
  `FILTER`/`REDUCE`/`FOR` em expressões** (disponíveis desde SP08; SP22 ≥ SP08).
- Proibido sempre: `WITH HEADER LINE`, `OCCURS`, `RANGES`, `REUSE_ALV_*`, `SELECT *`,
  Open SQL dentro de ciclos, `FOR ALL ENTRIES`, CDS, RAP, `CL_OSQL_TEST_ENVIRONMENT`
  (só 7.51+). ALV apenas com `CL_SALV_TABLE`. Apenas tabelas Z (preparação S/4HANA).

## Processo SDD (o portão que não se salta)

`propose → [REVISÃO HUMANA] → apply → verify → archive`. Não escrever código ABAP sem
o plano aprovado pelo utilizador. Uma tarefa de `tasks.md` só é marcada depois de o
objecto activar no SAP e o teste passar (o utilizador confirma a activação). Nunca
editar `openspec/specs/` à mão — só muda via `openspec archive`.

## Regras invioláveis da mudança 1

Nunca gravar com erros nem parcialmente; o upload **só cria** (`INSERT`, nunca
`MODIFY`/`UPDATE`); `COMMIT WORK` só no repositório, sem `AND WAIT`; zona sem diálogos
entre o primeiro `INSERT` e o `COMMIT`/`ROLLBACK`; bloqueio por ano antes de ler a BD
em modo Gravação; autorização antes de ler o ficheiro; mensagens só pela classe
`ZMM_PAC`; códigos normalizados (trim + maiúsculas), descrições > 72 caracteres são
erro (nunca truncar). Detalhe no `CLAUDE.md` §4 e no `design.md`.

## Fora de âmbito por princípio (mudança 1)

Alterar/eliminar registos existentes por upload, ficheiros do servidor (AL11), execução
em fundo, `.xlsx`, consulta, manutenção, integração com PR, `ZMM_PAC_ITEM`, relatório
de execução, Power BI. Estes pertencem às mudanças 2–6.

## Objectos criados no SAP (não serializar à mão)

`ZCX_MM_PAC`, FK de `ZMM_PAC_SUBCATG-PAC_CAT`, objecto de autorização `ZMM_PAC` (SUSO),
transacções, textos de selecção/símbolos de texto, objecto de bloqueio `EZ_MM_PAC`
(condicional). São criados no SAP pelo utilizador e depois serializados para o Git.

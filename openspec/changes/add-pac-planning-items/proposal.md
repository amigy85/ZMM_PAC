# Proposal

## Why

Com o catálogo PAC (categorias/subcategorias) criado e carregável (mudança 1), falta
registar o **plano** propriamente dito: os **itens de planeamento** de cada ano —
quanto se pretende adquirir por subcategoria (quantidade, unidade, valor, moeda) e a
que planta/conta. Sem itens, o PAC não pode ser acompanhado contra a execução real
(PR → PO → GR → factura), que é o objectivo das mudanças 4 e 6.

Esta é a **mudança 5 de 6** e **depende da mudança 1** (o catálogo tem de existir: cada
item pertence a uma subcategoria válida do ano). Reutiliza a arquitectura já provada da
mudança 1 (parser → validador → changeset → repositório → orquestrador, com autorização,
log, ALV, simulação + gravação atómica e bloqueio por ano).

## What Changes

- **Correcção de DDIC da `ZMM_PAC_ITEM`** (tabela já existe, criada cedo):
  - `VALOR` passa de `CHAR 16` (rollname `VALUE`) para **`CURR`** com referência de moeda a `MOEDA`.
  - `QUANTIDADE` mantém-se `QUAN` com referência de unidade a `MEINS`.
  - **Remover `KOSTL`** (centro de custo): um item de planeamento não deve ficar amarrado a uma UO/centro de custo específico.
  - `PAC_ITEM` (NUMC 5) **numerado por objecto de intervalo de números** (não vem no ficheiro).
  - **Foreign keys** de `PAC_CAT`→`ZMM_PAC_CATG` e `PAC_SUBCAT`→`ZMM_PAC_SUBCATG`;
    e (D5-08) `MOEDA`→`TCURC`, `MEINS`→`T006`, `CENTRO`→`T001W`.
  - Domínio de status do item `ZMM_PACITEM_STATUS` com ciclo de vida **`D/A/B/C/F`** (D-02/D-03) e matriz de transições.
- **Upload de itens por ficheiro CSV** (simulação por omissão / gravação atómica após confirmação), layout:
  `ANO;COD_SUBCATEGORIA;DESCRICAO;QUANTIDADE;UNIDADE;VALOR;MOEDA;CENTRO;CONTA_RAZAO`
  (cp1252, `;`, máximo de 10 000 linhas; **todas as colunas obrigatórias** — ver D5-08).
- **Validação completa antes de gravar**: estrutura do ficheiro; ano único e no intervalo;
  campos obrigatórios (subcategoria, descrição, quantidade, unidade, valor, moeda);
  **a subcategoria tem de existir e ser utilizável no catálogo do ano** (a categoria é
  derivada dela); quantidade/valor numéricos ≥ 0; **moeda (TCURC), unidade (T006),
  centro (T001W) e conta-razão (SKB1 na empresa `P_BUKRS`) existentes no sistema** (D5-08).
- **Só cria** (`INSERT`), nunca altera itens existentes; cada linha = um item novo
  (numeração automática); auditoria com carimbo único; status inicial **`D` (Rascunho)**.
- **Entrega**: novas classes `ZCL_MM_PAC_ITEM_*` (parser/validador/changeset/repositório/
  orquestrador) reutilizando `ZIF_MM_PAC_TYPES`/`ZCL_MM_PAC_LOG`/`ZCL_MM_PAC_AUTH`/`ZCX_MM_PAC`;
  programa `ZMM_PAC_ITEM_UPLOAD` + transacção; botão no menu `ZMM_PAC_MENU`; novas mensagens
  na classe `ZMM_PAC` (080–099).

## Capabilities

### Modified Capabilities
- `plano-anual-compras`: acrescenta os requisitos dos **itens de planeamento** (carregamento,
  validação, numeração, status inicial) à capacidade que já detém o catálogo e o seu upload.
  (O delta está em `## ADDED Requirements` porque a spec principal ainda não foi publicada —
  a mudança 1 ainda não foi arquivada.)

## Impact

- **DDIC alterado**: `ZMM_PAC_ITEM` (tipo de `VALOR`, remoção de `KOSTL`, FKs), novo objecto
  de **intervalo de números** para `PAC_ITEM`, domínio/data element de status do item.
  ⚠️ A `ZMM_PAC_ITEM` tem dados de amostra (4 linhas) — esvaziar antes da conversão.
- **Objectos novos**: ~5 classes `ZCL_MM_PAC_ITEM_*` (+ testes), 1 programa, 1 transacção.
- **Reutiliza** (sem alterar): `ZIF_MM_PAC_TYPES`, `ZCL_MM_PAC_LOG`, `ZCL_MM_PAC_AUTH`,
  `ZCX_MM_PAC`, `ZMM_PAC_MENU` (acrescenta botão).
- **Depende da mudança 1** (catálogo e infra). Não transportar antes da 1.
- **Fora de impacto**: consulta (2), manutenção de status com motivo (3), uso em PR (4),
  relatório de execução (6).

## Âmbito e faseamento

Mudança **5 de 6**. Depende de 1. Ver quadro de faseamento no `proposal.md` da mudança 1.

### Fora de âmbito da mudança 5
- Consulta de itens (mudança 2).
- Manutenção/alteração de itens e transições de status com motivo (mudança 3, alargada ao item).
- Verificação de uso em PR (mudança 4) e relatório de execução (mudança 6).
- Ficheiros `.xlsx` (D-08).
- Autorização do utilizador sobre o **centro** (`M_*`): valida-se só a existência em T001W, não o acesso.
- Validação da conta por **plano de contas** (`SKA1`/`KTOPL`): usa-se a empresa (`SKB1`/`P_BUKRS`).

## Riscos

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Conversão de `VALOR` CHAR→CURR com dados de amostra | Média | Médio | Esvaziar a tabela antes da activação; só 4 linhas |
| Moeda/unidade inválidas provocam dump na gravação CURR/QUAN | Média | Alto | Validar `MOEDA` (TCURC) e `UNIDADE` (T006) antes de gravar |
| Intervalo de números mal configurado / esgotado | Baixa | Médio | Objecto próprio com intervalo amplo; `NUMBER_GET_NEXT` com tratamento de erro |
| Subcategoria do ficheiro não existe/estado não utilizável | Média | Médio | Validação obrigatória contra o catálogo do ano (REQ) |

## Decisões

| ID | Decisão | Estado |
|---|---|---|
| D5-01 | Layout do CSV = `ANO;COD_SUBCATEGORIA;DESCRICAO;QUANTIDADE;UNIDADE;VALOR;MOEDA;CENTRO;CONTA_RAZAO` (categoria derivada da subcategoria) | **decidida (2026-10-23)** |
| D5-02 | `PAC_ITEM` por **intervalo de números** (não no ficheiro); numeração contínua | **decidida** |
| D5-03 | Status inicial do item = **`D` (Rascunho)** | **decidida** |
| D5-04 | **Remover `KOSTL`**. `CENTRO`/`CONTA_RAZAO` eram opcionais sem validação — **revisto pela D5-08**: passam a obrigatórios e validados | **revista (2026-10-27)** |
| D5-05 | `VALOR` → `CURR` (ref. `MOEDA`); validar `MOEDA`/`UNIDADE` (evitar dump); `VALOR`/`QUANTIDADE` ≥ 0 | **decidida** |
| D5-06 | Cada linha do ficheiro = **um item novo**; sem detecção de duplicados; vários itens por subcategoria | **decidida** |
| D5-07 | Reutilizar infra da mudança 1 (log/auth/excepção/tipos); classes próprias `ZCL_MM_PAC_ITEM_*` | **decidida** |
| D5-08 | **Validação de dados-mestre dos itens (bloqueante)**: `MOEDA`→TCURC (`090`), `UNIDADE`→T006 c/ conversão externa→interna (`091`), `CENTRO` obrigatório→T001W (`092`/`093`), `CONTA_RAZAO` obrigatório→`SKB1 WHERE BUKRS = P_BUKRS` semântica de `C_SAKNR` (`094`/`095`). `P_BUKRS` parâmetro de ecrã obrigatório, default **`HCB`**. DDIC: foreign keys `MOEDA→TCURC`, `MEINS→T006`, `CENTRO→T001W` na `ZMM_PAC_ITEM`. Reverte a parte "opcionais" da D5-04. | **decidida (2026-10-27)** |

## Ordem de transporte

- **Nº da ordem de transporte**: _a registar no DEV antes do primeiro pull da mudança 5_.
  Commits seguem `feat(pac): … [refs: add-pac-planning-items <n.º>]`.

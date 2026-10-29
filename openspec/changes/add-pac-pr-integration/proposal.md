# Proposal

## Why

O catálogo (mudança 1) e os itens de planeamento (mudança 5) já existem, e a Requisição de
Compra (RC) já consegue **guardar** a que item do PAC se refere (campos `PAC_*` na `EBAN`,
subtela 0111 da enhancement MEREQ001). Mas **nada valida essa atribuição na gravação**: é
possível gravar uma RC com um item PAC inexistente, de ano errado, de subcategoria trocada,
de categoria inactiva ou ainda em rascunho. Sem esta validação, o plano e a execução
divergem logo na origem (RC), inviabilizando o acompanhamento das mudanças 4/6.

Esta é a **mudança 4 de 6** e **depende das mudanças 1 (catálogo) e 5 (itens)**.

## What Changes

- **Validação bloqueante da atribuição PAC na gravação da RC**, no método **`CHECK`** da BAdI
  `ME_PROCESS_REQ_CUST` (classe existente `ZCL_IM_ME_PROCESS_REQ_CUST`), via a macro
  `mmpur_message` (classe de mensagens `ZMM_PAC`). Por item **não eliminado** da RC:
  - o item tem de existir em `ZMM_PAC_ITEM` para `PAC_YEAR + PAC_SUBCAT + PAC_ITEM`;
  - a categoria/subcategoria do item têm de ser coerentes (a `PAC_CAT` deriva do item);
  - a categoria-mãe tem de estar **activa** no catálogo do ano;
  - o item tem de estar no estado **`A` (Activo)** — rascunho (`D`), bloqueado (`B`),
    cancelado (`C`) e fechado (`F`) são recusados.
- **Obrigatoriedade condicional** da atribuição (D4-05): obrigatória para itens não eliminados
  cuja **categoria de imputação** seja centro de custo (`KNTTP = 'K'`); opcional nos restantes.
  *(Condição a confirmar na revisão.)*
- **Alinhamento mínimo às regras** (D4-03): substituir os `MESSAGE` com **texto literal** da
  subtela 0111 (`ZXM02I01`/`ZXM02F01`) por mensagens da classe `ZMM_PAC`. O popup de selecção
  de itens (`REUSE_ALV_POPUP_TO_SELECT`) **mantém-se** (produtivo e estável).
- **Novas mensagens** na classe `ZMM_PAC` para os erros de validação da RC.

Fora de âmbito: relatório/consumo acumulado vs plano (mudança 6); manutenção de estado do
item (mudança 3); alteração do modelo de persistência (os campos `PAC_*` na `EBAN` ficam);
refactor do popup para `CL_SALV`; o exit legado `EXIT_SAPLMEREQ_005` (`AFNAM`/`BEDNR`).

## Capabilities

### New Capabilities
<!-- nenhuma; estende a capacidade existente -->

### Modified Capabilities
- `plano-anual-compras`: acrescenta os requisitos de **validação da atribuição PAC na
  Requisição de Compra** à capacidade que já detém o catálogo, o upload e os itens. (O delta
  está em `## ADDED Requirements` porque a spec principal ainda não foi publicada — as
  mudanças 1 e 5 ainda não foram arquivadas.)

## Impact

- **Alterado**: método `IF_EX_ME_PROCESS_REQ_CUST~CHECK` em `ZCL_IM_ME_PROCESS_REQ_CUST`
  (acrescenta bloco de validação PAC, isolado numa classe/validador próprio); mensagens
  literais da subtela 0111 (`ZXM02I01`, `ZXM02F01`) → classe `ZMM_PAC`.
- **Novo**: validador de atribuição PAC reutilizável (classe Z própria, com ABAP Unit) e
  mensagens `ZMM_PAC` para a RC.
- **Reutiliza** (sem alterar): `ZMM_PAC_ITEM`/`ZMM_PAC_CATG`/`ZMM_PAC_SUBCATG`, campos `PAC_*`
  da `EBAN`, subtela 0111 (UI e transporte `EXIT_SAPLMEREQ_001`/`003`).
- **Não toca**: `EXIT_SAPLMEREQ_005` (legado `AFNAM`/`BEDNR` vs `ZREQ`/`ZACOMP`), persistência.
- **Depende de 1 e 5.** Não transportar antes delas.
- **Fora de impacto**: relatório (6), manutenção de estado (3), modelo de persistência.

## Decisões

| ID | Decisão | Estado |
|---|---|---|
| D4-00 | Validar no método `CHECK` da BAdI `ME_PROCESS_REQ_CUST` (`ZCL_IM_ME_PROCESS_REQ_CUST`), não no `EXIT_SAPLMEREQ_005` legado | **decidida (2026-10-29)** |
| D4-01 | Validação **bloqueante** (erro) via `mmpur_message` | **decidida (2026-10-29)** |
| D4-02 | Item utilizável só com `STATUS = 'A'` (recusa D/B/C/F) | **decidida (2026-10-29)** |
| D4-03 | Refactor **só das mensagens** da subtela 0111 (→ classe `ZMM_PAC`); manter o popup `REUSE_ALV` | **decidida (2026-10-29)** |
| D4-04 | Âmbito **só atribuição + validação**; consumo vs plano fica na mudança 6 | **decidida (2026-10-29)** |
| D4-05 | Atribuição **obrigatória por condição** — proposta: `KNTTP = 'K'` e item não eliminado | pendente (confirmar a condição) |
| D4-06 | Autorização para atribuir/validar: reutilizar objecto `ZMM_PAC` (`ACTVT 03`) ou nova | pendente |

## Ordem de transporte

- **Nº da ordem**: _a registar no DEV antes do primeiro pull da mudança 4_. Depende de 1 e 5.
  Commits seguem `feat(pac): … [refs: add-pac-pr-integration <n.º>]`.

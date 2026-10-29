# Design — integração PAC ↔ Requisição de Compra (mudança 4)

Baseado no levantamento `docs/analise/mudanca4_integracao_pr.md` (ler para o estado actual).

## Contexto e premissas

- A RC já guarda a atribuição PAC em campos *append* da `EBAN` (`PAC_YEAR/PAC_CAT/PAC_SUBCAT/
  PAC_ITEM`); a subtela 0111 (enhancement MEREQ001, FG `XM02`) faz a escolha e o transporte.
- A validação na gravação faz-se no método **`CHECK`** da BAdI `ME_PROCESS_REQ_CUST`
  (classe `ZCL_IM_ME_PROCESS_REQ_CUST`), que já é a casa das validações de RC e usa a macro
  `mmpur_message` (`INCLUDE mm_messages_mac`) — erro no `CHECK` impede a gravação.
- Depende das mudanças 1 e 5 (catálogo e itens activos). Não transportar antes delas.

## Modelo de dados

Sem novo DDIC. Reutiliza:
- `EBAN` (append `CI_EBANDB`: `PAC_YEAR/PAC_CAT/PAC_SUBCAT/PAC_ITEM`) — a atribuição na RC.
- `ZMM_PAC_ITEM` (existência/estado do item), `ZMM_PAC_CATG` (estado da categoria-mãe),
  `ZMM_PAC_SUBCATG` (coerência da subcategoria).

## Arquitectura

**Lógica reutilizável e testável no nosso pacote; ganchos finos nos objectos standard.**

```text
ZCL_IM_ME_PROCESS_REQ_CUST~CHECK  (pacote ZMM, standard-enhancement)
        │  por item não eliminado: lê MEREQ_ITEM (campos PAC_*)
        └─► ZCL_MM_PAC_REQ_VALIDATOR  (pacote ZMM_PAC_CORE, abapGit)
                 ├─ valida existência/coerência/estado/obrigatoriedade
                 └─ devolve mensagens (nº da classe ZMM_PAC) → mmpur_message no CHECK
subtela 0111 (ZXM02F01 LCL_PAC)  → mensagens literais substituídas por ZMM_PAC
```

- **`ZCL_MM_PAC_REQ_VALIDATOR`** (novo, `ZMM_PAC_CORE`): recebe os dados PAC de um item de RC
  (ano/cat/subcat/item, knttp, loekz) e devolve o veredicto + nº de mensagem `ZMM_PAC`.
  Lê o catálogo/itens via `SELECT SINGLE` com **buffer `HASHED`** por chamada de `CHECK`
  (o `CHECK` pode iterar muitos itens; evita `SELECT` repetido — padrão já usado por `LCL_PAC`).
  Testável com ABAP Unit (dados-mestre injectados por duplo, à semelhança da mudança 5).
- **`CHECK`** (gancho fino): percorre `im_header->get_items( )`; por item não eliminado chama
  o validador e, havendo erro, `mmpur_message 'E' 'ZMM_PAC' '<nnn>' …`. Não grava nada.
- **Subtela 0111** (`LCL_PAC~selecionar_item`): trocar os 2 `MESSAGE` com texto literal
  ("Indique primeiro a subcategoria…", "Sem itens PAC para…") por mensagens `ZMM_PAC`. O
  popup `REUSE_ALV_POPUP_TO_SELECT` mantém-se (D4-03).

## LUW e atomicidade

O `CHECK` é **só leitura** (validação) — sem `COMMIT`/`ROLLBACK`, sem bloqueio. A gravação da
RC é do standard; o nosso papel é vetá-la com erro quando a atribuição PAC é inválida.

## Mensagens (classe `ZMM_PAC`, RC = 100–109)

Propostas: `100` item PAC inexistente; `101` ano/categoria/subcategoria incoerentes; `102`
categoria-mãe inactiva; `103` item em estado não utilizável (só `A`); `104` atribuição PAC
obrigatória em falta. A subtela reutiliza/!acrescenta: `105` indicar primeiro a subcategoria;
`106` sem itens PAC para a subcategoria/ano. (`s001`/`s002` da subtela já são `ZMM_PAC`.)

## Autorização

D4-06 em aberto: validar sempre (o `CHECK` corre para todos) e, se necessário, exigir
`ACTVT 03` do objecto `ZMM_PAC` para *atribuir* na subtela. Decidir antes do `apply`.

## Entrega (abapGit vs transporte) — importante

Os objectos de gancho — `ZCL_IM_ME_PROCESS_REQ_CUST` e os includes do `XM02` — estão no
pacote **`ZMM`** (standard-enhancement), **fora** do repo abapGit (`ZMM_PAC`/`_DATA`/`_CORE`/
`_UI`). Estratégia:
- O **validador `ZCL_MM_PAC_REQ_VALIDATOR`** (+ testes) vive em `ZMM_PAC_CORE` e entrega-se por
  **abapGit pull** como o resto da solução.
- As **edições de gancho** (bloco no `CHECK`; mensagens da subtela) são alterações *in loco*
  em objectos do `ZMM`, entregues por **transporte** (não por abapGit) — mantêm-se finas e
  apenas **chamam** o validador. As novas mensagens entram na `MSAG ZMM_PAC` (abapGit).

## ADRs

- **ADR-R1 — Validar no `CHECK` da BAdI, não no exit legado.** Mecanismo moderno, já é a casa
  das validações de RC; erro no `CHECK` bloqueia a gravação. Rejeitado: `EXIT_SAPLMEREQ_005`
  (legado `AFNAM`/`BEDNR`, não relacionado).
- **ADR-R2 — Lógica no validador `ZMM_PAC_CORE`, gancho fino no `ZMM`.** Mantém a regra
  testável e versionada por abapGit; o objecto standard-enhancement só chama. Rejeitado:
  escrever a regra toda dentro do `CHECK` (não testável, fora do repo).
- **ADR-R3 — Manter o popup `REUSE_ALV`; só alinhar mensagens.** Custo/risco equilibrado num
  exit produtivo (D4-03). Rejeitado: refactor para `CL_SALV` agora (risco de regressão).

## Segurança

Validação reforça a integridade do plano na origem (RC). Sem dados pessoais novos; leitura de
dados-mestre (ZMM_PAC_*). Não altera persistência nem o fluxo de autorização standard da RC.

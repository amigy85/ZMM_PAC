# Design — itens de planeamento PAC (mudança 5)

## Contexto e premissas

Reutiliza toda a infra da mudança 1 (SAP_BASIS 7.40 SP22; sem `SELECT *`, sem Open SQL em
ciclos, sem `FOR ALL ENTRIES`; ALV com `CL_SALV_TABLE`; `.abap` sem BOM; `RAISE EXCEPTION
TYPE … EXPORTING textid`; sem offset/length em `string`; etc.). Depende do catálogo
(`ZMM_PAC_CATG`/`ZMM_PAC_SUBCATG`) já activo.

## Modelo de dados — correcção da `ZMM_PAC_ITEM`

A tabela existe; esta mudança corrige-a (esvaziar antes de activar — tem dados de amostra):

- Chave: `MANDT + PAC_YEAR + PAC_ITEM` (`PAC_ITEM` NUMC 5). `PAC_CAT`/`PAC_SUBCAT` passam a
  campos não-chave com **foreign key** para `ZMM_PAC_CATG`/`ZMM_PAC_SUBCATG`.
- `VALOR`: de `CHAR 16` (rollname `VALUE`) → **`CURR`** (data element próprio, ex.
  `ZMM_PAC_VALOR`, dom. tipo CURR len 15 dec 2) com **referência de moeda** ao campo `MOEDA`.
- `QUANTIDADE`: `QUAN` (ref. unidade `MEINS`); `MEINS` `UNIT`; `MOEDA` `CUKY`.
- **Remover `KOSTL`.** `CENTRO` (`WERKS_D`, centro/fábrica) e `SAKNR` (conta-razão) passam a
  **obrigatórios e validados** (D5-08). Foreign keys (D5-08): `MOEDA→TCURC`, `MEINS→T006`,
  `CENTRO→T001W` (a conta fica só por validação ABAP, por depender da empresa).
- `STATUS`: data element `ZMM_PACITEM_STATUS` (dom. `ZMM_PACITEM_D_STATUS`, CHAR 1) com
  valores fixos `D`=Rascunho, `A`=Activo, `B`=Bloqueado, `C`=Cancelado, `F`=Fechado.
- Auditoria: `ERNAM/ERDAT/ERZET` (criação) + `AENAM/AEDAT` (alteração, mudança 3).
- Classe de entrega `A`, registo de alterações activo (SCU3), sem buffering.

**Numeração** — objecto de intervalo de números (SNRO), ex. `ZMM_PAC` / intervalo `01`,
domínio NUMC 5; `NUMBER_GET_NEXT` no repositório. Numeração contínua (não reinicia por ano).

**Matriz de transições (D-03)** — registada para a mudança 3 (a mudança 5 só cria em `D`):
`D→A`, `D→C`, `A→B`, `B→A`, `A→C`, `A→F`, `B→C`, `D→D`.

## Arquitectura

Conjunto paralelo ao da mudança 1, **reutilizando** `ZIF_MM_PAC_TYPES` (acrescenta tipos de
item), `ZCL_MM_PAC_LOG`, `ZCL_MM_PAC_AUTH`, `ZCX_MM_PAC`, `MSAG ZMM_PAC`:

```text
ZMM_PAC_ITEM_UPLOAD (PROG) ─► ZCL_MM_PAC_ITEM_UPLOAD ─► ZCL_MM_PAC_ITEM_PARSER
        │                           │          ├─► ZCL_MM_PAC_ITEM_VALIDATOR ─► ZCL_MM_PAC_LOG
        │                           │          ├─► ZCL_MM_PAC_ITEM_CHANGESET
        │                           │          └─► ZIF_MM_PAC_ITEM_REPOSITORY ◄─ ZCL_MM_PAC_ITEM_REPOSITORY
        ├─► ZCL_MM_PAC_FILE (reuso)  └─► ZCL_MM_PAC_AUTH (reuso)
        └─► CL_SALV_TABLE
```

- **PARSER**: lê CSV cru (tudo `string`), normaliza (trim; subcat em maiúsculas), valida
  estrutura (REQ-21). Tipo de linha de item `ty_item_row` em `ZIF_MM_PAC_TYPES`.
- **VALIDATOR**: REQ-22..25; lê o catálogo do ano (subcategorias+categorias, via o
  repositório do catálogo da mudança 1 ou leitura própria) para validar pertença e estado;
  converte valores validados; devolve itens a criar. `iv_today` injectada.
- **CHANGESET**: carimbo único + status `D`; **não** atribui `PAC_ITEM` (fica para o
  repositório, que consome o intervalo de números na gravação).
- **REPOSITORY** (`ZIF_MM_PAC_ITEM_REPOSITORY`): `read_categories`/`read_subcategories` (do
  ano), `lock_year`/`unlock_year` (mesmo bloqueio por ano), `next_item_number`, `insert_new`
  (sem COMMIT), `commit`, `rollback`. **D5-08:** `read_currencies` (TCURC), `read_units`/
  `normalize_uom` (T006/T006A, conversão externa→interna via `CONVERSION_EXIT_CUNIT_INPUT`),
  `read_plants` (T001W), `read_gl_accounts( iv_bukrs )` (`SKB1 WHERE bukrs`). Uma leitura por
  conjunto, para tabela `HASHED`; zero Open SQL em ciclo. Duplos contam/servem os conjuntos.
- **UPLOAD** (orquestrador): `prepare`/`write`/`release` como na mudança 1; a atribuição do
  número acontece na **zona de escrita** (`write`), imediatamente antes do `INSERT`. Recebe
  `iv_bukrs` (do parâmetro de ecrã `P_BUKRS`, default `HCB`) e injecta-o na validação da conta.
- **PROGRAMA** `ZMM_PAC_ITEM_UPLOAD` + transacção; botão no `ZMM_PAC_MENU`.

## LUW e atomicidade

Igual à mudança 1: autorização → ler ficheiro → parser → (Gravação) `lock_year` → ler
catálogo → validar → changeset → **zona sem diálogos** (`next_item_number` + `INSERT` +
`COMMIT`) → `unlock` (sempre) → ALV. Sem diálogos entre o primeiro `INSERT` e o `COMMIT`.

## Mensagens (classe `ZMM_PAC`, 080–099)

Novas, ex.: `080` subcategoria inexistente no ano; `081` categoria-mãe inactiva; `082`
quantidade inválida; `083` valor inválido; `084` moeda inválida (formato); `085` unidade
inválida (formato); `086` itens gravados (contagem); `087` nada a gravar; `088` descrição
em falta; `089` confirmação de gravação. **D5-08:** `090` moeda inexistente (TCURC); `091`
unidade inexistente (T006); `092` centro obrigatório; `093` centro inexistente (T001W);
`094` conta obrigatória; `095` conta inexistente na empresa (SKB1). Reutiliza 001–011/016
(estrutura/ano) e 050/051/052/060..063 (auth/lock/fundo/simulação) por analogia.

## ADRs

- **ADR-I1 — Reutilizar a infra, classes próprias para o item.** Tipos/log/auth/excepção
  partilhados; parser/validador/changeset/repositório/orquestrador próprios do item (layout
  e validações diferentes). Rejeitado: generalizar as classes do catálogo (acoplamento).
- **ADR-I2 — `PAC_ITEM` por intervalo de números, atribuído na zona de escrita.** Evita
  buracos por simulações; o número só é consumido na gravação real.
- **ADR-I3 — `VALOR` como `CURR` com ref. a `MOEDA`.** Correcto para montantes; exige validar
  a moeda antes de gravar (evita dump).
- **ADR-I4 — Validação de dados-mestre bloqueante com contexto de empresa (D5-08).** Moeda
  (TCURC), unidade (T006, externa→interna), centro (T001W) e conta-razão (SKB1 por `P_BUKRS`,
  semântica de `C_SAKNR`) validados como **erro**; `CENTRO`/`CONTA` tornam-se obrigatórios.
  A conta valida-se ao nível da **empresa** (SKB1), não do plano de contas (SKA1/KTOPL),
  por ser o que reflecte "conta criada e utilizável na empresa". Conjuntos lidos uma vez
  para `HASHED` (sem Open SQL em ciclo). Rejeitado: só-formato (não evita dados inválidos).

## Open Questions

- Nome exacto do objecto de intervalo de números (SNRO) e do data element/ domínio de `VALOR`
  — a confirmar na tarefa 1 (criar no SAP).
- Reutilizar `ZCL_MM_PAC_REPOSITORY` para ler o catálogo, ou leitura própria no repositório
  do item — decidir na implementação (preferência: leitura própria, para não acoplar).

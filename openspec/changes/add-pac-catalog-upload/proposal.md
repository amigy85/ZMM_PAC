# Proposal

## Why

O Plano Anual de Compras (PAC) é hoje mantido fora do SAP: não existe catálogo de
categorias/subcategorias PAC no sistema, pelo que as requisições de compra não
podem ser classificadas nem o PAC acompanhado contra a execução real (PR → PO →
GR → factura → pagamento). Esta mudança cria o modelo de dados e o carregamento
do catálogo de um ano a partir de ficheiro, de forma que o Aprovisionamento possa
ver antecipadamente todos os problemas do ficheiro sem risco e gravar o catálogo
de forma atómica, auditada e repetível.

Esta é a **mudança 1 de 6** (ver âmbito e faseamento). Corrige quatro defeitos
críticos da v1 (`ZMM_PAC_ABAP_Desenvolvimento.md`):

- **C1** — `MODIFY ... FROM TABLE` sobre registos existentes sobrescrevia a
  auditoria de criação (`ERNAM/ERDAT/ERZET`) e a descrição. O upload passa a ser
  **só de criação** (`INSERT`).
- **C2** — a chave `MANDT+PAC_YEAR+PAC_CAT+PAC_SUBCAT` permitia a mesma
  subcategoria em duas categorias. A chave da subcategoria passa a
  `MANDT+PAC_YEAR+PAC_SUBCAT`.
- **C3** — ausência de bloqueio (enqueue): duas gravações simultâneas do mesmo
  ano corrompiam ou colidiam. Passa a haver bloqueio exclusivo por mandante+ano.
- **C4** — diálogos entre a escrita e o `COMMIT` provocavam commit implícito e
  gravação parcial. Passa a existir uma zona explícita sem diálogos.

> **Regra principal:** o sistema NUNCA grava dados quando existem erros de
> validação — e nunca grava parcialmente (INV-6).

## What Changes

- **Modelo de dados**: domínios `ZDO_PAC_*`, data elements `ZDE_PAC_*` e tabelas
  `ZMM_PAC_CATG` / `ZMM_PAC_SUBCATG` (dependentes de mandante, classe de entrega A,
  registo de alterações activo), com foreign key de `ZMM_PAC_SUBCATG-PAC_CAT`.
- **Upload com dois modos**: Simulação (por omissão, sem qualquer efeito na BD) e
  Gravação (atómica, após confirmação explícita). Ficheiro **CSV UTF-8** com `;`,
  layout oficial de 5 colunas, máximo de 10 000 linhas de dados.
- **Validação completa antes de gravar**: estrutura do ficheiro, ano único e no
  intervalo permitido, campos obrigatórios, formato/comprimento dos códigos e
  descrições, pertença da subcategoria à categoria, consistência interna do
  ficheiro e comparação com registos já existentes. O status não vem no ficheiro:
  a categoria nova nasce `A` (D-02); a subcategoria não tem status.
- **Upload só cria** (`INSERT`): registos existentes nunca são alterados; as
  diferenças são reportadas (**BREAKING** face ao comportamento de *upsert* da v1).
- **Atomicidade e concorrência**: `COMMIT WORK` único no repositório, bloqueio
  exclusivo por mandante+ano durante validação e gravação, idempotência.
- **Autorização** pelo objecto `ZMM_PAC` (`ACTVT 03` simular, `01` gravar),
  verificada dentro do programa antes de ler o ficheiro.
- **Rejeição de execução em fundo** (o ficheiro é lido do posto de trabalho).
- **Resultado em ALV** (`CL_SALV_TABLE`) com estatísticas e lista de mensagens;
  por omissão só erros e avisos.
- **Entrega**: classe de mensagens `ZMM_PAC`, transacções `ZMM_PAC` e
  `ZMM_PAC_UPLOAD`, programa lançador `ZMM_PAC_MENU`.

## Capabilities

### New Capabilities
- `plano-anual-compras`: catálogo PAC (categorias e subcategorias por ano) e o
  seu carregamento por ficheiro com simulação, validação, gravação atómica,
  autorização e auditoria. É a capacidade durável que detém os requisitos do PAC;
  as mudanças 2–6 (consulta, manutenção, uso em PR, itens de planeamento,
  relatório de execução) acrescentarão requisitos a esta mesma capacidade ou a
  capacidades vizinhas conforme o seu âmbito.

### Modified Capabilities
<!-- Nenhuma: não existem specs publicadas em openspec/specs/. Esta é a primeira capacidade. -->

## Impact

- **Objectos SAP novos** (package `ZMM_PAC` e subpackages `_DATA`, `_CORE`, `_UI`):
  4 domínios, 7 data elements, 2 tabelas transparentes + FK, 1 classe de mensagens,
  2 interfaces, 8 classes, 1 excepção, 1 objecto de autorização (SUSO), 2 programas,
  2 transacções. Inventário completo em `design.md` (§11.2 da spec v2).
- **Entrega**: Git push → abapGit pull no DEV → transporte DEV → QAS → PRD.
  Objectos não serializáveis à mão (`ZCX_MM_PAC`, FK, SUSO, TRAN, textos de
  selecção, ENQU condicional) são criados no SAP e serializados.
- **MASTER_LANGUAGE do repositório abapGit** é irreversível após o primeiro pull
  (D-01).
- **Sem impacto** em objectos existentes do sistema: só objectos Z novos. Sem
  integração com PR, itens de planeamento ou relatório de execução (mudanças 4–6).
- **Base**: todas as mudanças 2–6 dependem desta.

## Âmbito e faseamento

| # | Mudança OpenSpec | Entrega | Depende de |
|---|---|---|---|
| 1 | `add-pac-catalog-upload` | Modelo de dados, upload com simulação/gravação, autorização, lançador | — |
| 2 | `add-pac-catalog-query` | Consulta de categorias e subcategorias | 1 |
| 3 | `add-pac-catalog-maintenance` | Manutenção de descrições e status, com motivo e transições | 1 |
| 4 | `add-pac-usage-check-requisition` | Impedir uso de categoria/subcategoria não utilizável em novas PRs | 1, 3 |
| 5 | `add-pac-planning-items` | Itens de planeamento (`ZMM_PAC_ITEM`) | 1 |
| 6 | `add-pac-execution-report` | Relatório planeado × comprometido × executado × saldo | 4, 5 |

### Fora de âmbito da mudança 1

- Alteração de registos existentes por upload (descrições ou status) — é
  manutenção (mudança 3).
- Eliminação de categorias ou subcategorias.
- Leitura de ficheiros do servidor de aplicação (AL11) e execução em fundo.
- Ficheiros `.xlsx` (D-08).
- Integração com PR, itens de planeamento, relatório de execução e Power BI.
- Textos multilíngues das descrições (o catálogo opera apenas em português).

## Riscos

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Convenção de códigos PAC tem excepções não conhecidas | Média | Alto | Validar a regex com o ficheiro real de 303 linhas antes do `apply` (D-06) |
| Excel grava CSV em ANSI em vez de UTF-8 | Alta | Médio | Modelo de ficheiro oficial + detecção de caracteres inválidos (REQ-02) |
| Manutenção futura (SM30/programa) colide com upload em curso | Baixa | Médio | Mesmo bloqueio por ano nas duas funções (mudança 3) |
| Língua principal do repositório abapGit mal escolhida | Média | Alto | Decidir antes do primeiro pull — não é alterável depois (D-01) |

## Decisões

Nenhuma bloqueia a escrita da proposta. **D-01, D-02, D-03, D-06 e D-07 bloqueavam
o `apply`** — todas estão agora **decididas** (D-06 fechada em 2026-10-13). Não há
decisões bloqueadoras do `apply` por resolver.

| ID | Decisão | Recomendação | Quem decide | Estado |
|---|---|---|---|---|
| D-01 | `MASTER_LANGUAGE` do repositório: `P` ou `E`? (irreversível no abapGit) | `P` se o português estiver instalado no CBD (SMLT) e for a língua de logon; `E` por coerência com outros repositórios Z | Equipa SAP | **decidida (2026-10-12): `P`** |
| D-02 | A quem se aplica a coluna `STATUS` | `STATUS` aplica-se **só à categoria** (`A`/`I`); a subcategoria **não tem status**; o Item PAC (mudança 5) terá coluna própria `STATUS_PACITEM` (`D/A/B/C/F`) | Aprovisionamento | **decidida (2026-10-12) — ver §Decisões fechadas** |
| D-03 | Matrizes de transição do ciclo de vida | Categoria PAC: `A`/`I`; Item PAC (mudança 5): `D/A/B/C/F` — ver matrizes em §Decisões fechadas | Aprovisionamento | **decidida (2026-10-12) — ver §Decisões fechadas** |
| D-04 | Manutenção: SM30 (gerador + evento) ou programa próprio | SM30 + evento 01 a chamar o validador | Equipa SAP | pendente (mudança 3) |
| D-05 | Upload só cria (ADR-01) | Confirmar que o negócio aceita corrigir descrições pela manutenção | Aprovisionamento | **decidida (2026-10-14): aceite — correcções via manutenção (mudança 3)** |
| D-06 | Formato dos códigos (REQ-05) validado contra o ficheiro real | Âmbito = **só PAC**; regex `^PAC-[A-Z][0-9]{3}$` / subcat `…\.[1-9][0-9]{0,2}$` validada (0 falhas em 215 cat. + 303 subcat.) | Aprovisionamento + SAP | **decidida (2026-10-13) — ver §Decisões fechadas e docs/testes/D06_achados.md** |
| D-07 | Intervalo de anos permitido | Ano corrente e seguinte | Aprovisionamento | **decidida (2026-10-12): ano corrente a corrente+1** |
| D-08 | Suporte `.xlsx` (`CL_FDT_XL_SPREADSHEET` no CBD?) | Verificar via MCP; se existir, mudança própria | Equipa SAP | pendente |
| D-09 | Classe do objecto de autorização e segregação de funções | Classe `MM_E`; perfis §8.2 | Segurança SAP | **decidida (2026-10-14): classe `MM_E`; Consulta `03`, Gestor `01/02/03`; segregação carregar-vs-fechar fica em aberto** |
| D-10 | Existe fecho do PAC ao nível do ano? | Se sim, tabela de cabeçalho do ano numa mudança própria | Aprovisionamento | **decidida (2026-10-14): não existe fecho anual global — sem tabela de cabeçalho do ano** |

### Decisões fechadas (2026-10-12)

**D-01 — MASTER_LANGUAGE = `P`.** O repositório abapGit usa português como língua
principal. Irreversível após o primeiro pull. Consequência: `LANGU`/`DDLANGUAGE`/
`MASTERLANG`/`SPRSL` = `P` em todos os metafiles; confirmar que `P` está instalado no
CBD (SMLT) e é língua de logon antes do primeiro pull (tarefa 0.5).

**D-02 — `STATUS` aplica-se só à categoria.** A coluna `STATUS` passa a pertencer à
**categoria** (tabela `ZMM_PAC_CATG`), com valores `A` (Activa) / `I` (Inactiva). A
**subcategoria deixa de ter status** (`ZMM_PAC_SUBCATG` sem campo de status). O **Item
PAC** (mudança 5, `ZMM_PAC_ITEM`) terá uma coluna própria `STATUS_PACITEM` com o
ciclo de vida `D/A/B/C/F`. Isto substitui a premissa anterior da spec (status na
subcategoria com `D/A/B/C/F`) e obriga a actualizar REQ-08, REQ-09, o domínio de
status, a tabela e o layout do ficheiro (ver §What Changes e o design).

**D-03 — Matrizes de transição.**

*Categoria PAC* — estados `A` = Activa, `I` = Inactiva (aplicável já na mudança 1):

| De | Para | Permitido? | Condição |
|---|---|---|---|
| A | I | Sim | Desactivação justificada |
| I | A | Sim | Reactivação autorizada |
| A | A | Sim | Mantém-se activa |
| I | I | Sim | Mantém-se inactiva |

*Item PAC* — estados `D` = Rascunho, `A` = Activo, `B` = Bloqueado, `C` = Cancelado,
`F` = Fechado (realizado na **mudança 5**; registado aqui como decisão de arquitectura):

| De | Para | Permitido? | Condição |
|---|---|---|---|
| D | A | Sim | Item validado e aprovado |
| D | C | Sim | Item cancelado antes da aprovação |
| A | B | Sim | Motivo obrigatório |
| B | A | Sim | Bloqueio removido |
| A | C | Sim | Cancelamento justificado |
| A | F | Sim | Ciclo concluído |
| B | C | Sim | Cancelamento justificado |
| D | D | Sim | Continua em preparação |

> As transições das categorias por upload são limitadas: o upload **só cria**
> (ADR-01); a mudança de estado de uma categoria existente é manutenção (mudança 3).

**D-06 — Formato dos códigos validado; âmbito = só PAC.** A validação contra o ficheiro
real (`docs/testes/valido.csv`, achados em `docs/testes/D06_achados.md`) fechou com
três decisões:

- **Âmbito (A2):** a mudança 1 carrega **apenas a família `PAC`**. As restantes 5
  famílias do ficheiro real (STK, CTR, FOR, GRA, PLA) estão **fora de âmbito** e são
  rejeitadas como formato inválido (`ZMM_PAC/016`/`017`). O nome da capacidade e das
  tabelas mantém-se.
- **Regex (A3) — validada, 0 falhas:** categoria `^PAC-[A-Z][0-9]{3}$`; subcategoria
  `^PAC-[A-Z][0-9]{3}\.[1-9][0-9]{0,2}$` (0/215 categorias e 0/303 subcategorias do
  ficheiro real falham; REQ-06 pertença 0 falhas).
- **Domínios (A4):** `ZDO_PAC_CAT` CHAR 10 e `ZDO_PAC_SUBCAT` CHAR 12 **mantêm-se**
  (PAC: cat máx 8, subcat máx 11).
- **Codificação (A1):** o parser **suporta cp1252** na leitura (Excel exporta ANSI) —
  revê a ADR-03.
- **Aspas (A5):** mantém-se "linha física = registo"; aspas/registos multi-linha são
  **erro a limpar na origem** (coerente com A6/A7/A8).

A6/A7/A8 permaneciam decididos (limpar na origem, regras estritas REQ-05/06/07
mantidas). **D-06 deixa de bloquear o `apply`.**

### Decisões fechadas (2026-10-14)

**D-05 — Upload só cria (aceite).** O negócio aceita que o upload apenas crie
(`INSERT`); registos existentes nunca são alterados por upload. Correcções de
descrição/status fazem-se pela manutenção (mudança 3). Coerente com ADR-01 e
REQ-09; não altera o âmbito da mudança 1.

**D-09 — Objecto de autorização.** Classe `MM_E`; perfis Aprovisionamento-Consulta
(`ACTVT 03`) e Aprovisionamento-Gestor (`01`/`02`/`03`), conforme §8.2. A
segregação entre quem carrega (`01`) e quem fecha/bloqueia (manutenção, mudança 3)
**fica em aberto** e será decidida com Segurança SAP nessa altura — não afecta a
mudança 1, que só usa `03` (simular) e `01` (gravar).

**D-10 — Sem fecho anual global.** Não existe fecho do PAC ao nível do ano inteiro;
o fecho dá-se ao nível de categoria/item. Consequência: **não** se cria tabela de
cabeçalho do ano, nem na mudança 1 nem como mudança própria.

Com estas, as únicas decisões ainda pendentes são **D-04** e **D-08**, ambas de
mudanças futuras (manutenção e `.xlsx`) e fora do âmbito da mudança 1.

## Ordem de transporte

- **Nº da ordem de transporte**: **`CBDK918074`** (Workbench, DEV/CBD — registada
  2026-10-14). Packages `ZMM_PAC`, `ZMM_PAC_DATA`, `ZMM_PAC_CORE`, `ZMM_PAC_UI`
  criados. Commits seguem `feat(pac): … [refs: add-pac-catalog-upload <n.º>]`.

# Design

## Context

Ver `proposal.md` para motivação e âmbito. Este documento cobre o **como**: modelo
de dados, arquitectura ABAP, fluxo LUW, mensagens, autorizações e entrega abapGit.

Restrições que moldam a abordagem:

| Premissa | Consequência |
|---|---|
| SAP_BASIS 7.40 **SP22** (confirmado via MCP/CVERS, 2026-10-14, tarefa 0.2) | Declarações inline, `VALUE #`, `NEW #`, `CONV #`, `CORRESPONDING #`, expressões de tabela, templates de string, Open SQL com `@` e vírgulas — **e `FILTER`, `REDUCE` e `FOR` em expressões**, disponíveis desde o 7.40 SP08. |
| Sem `CL_OSQL_TEST_ENVIRONMENT` (só 7.51+) | Acesso à BD atrás de interface; duplos de teste em ABAP Unit (ADR-04). |
| ECC com migração S/4HANA prevista | Apenas tabelas Z, `CL_SALV_TABLE`; sem `WITH HEADER LINE`, `OCCURS`, `RANGES`, `REUSE_ALV_*`, CDS, RAP. |
| MCP de leitura para o SAP; entrega só por abapGit pull | Claude Code escreve objectos fora do SAP; objectos não serializáveis à mão são criados no SAP e serializados. |
| Volumes: centenas a poucos milhares de linhas por ano | Uma leitura por ano, sem `FOR ALL ENTRIES`, sem processamento em pacotes. |

## Goals / Non-Goals

**Goals:**
- Lógica de validação e transformação testável em ABAP Unit sem base de dados real,
  através de uma interface de repositório com duplos que contam `COMMIT`/`rollback`.
- Atomicidade garantida por desenho: uma única zona de escrita sem diálogos e um
  único `COMMIT WORK` encapsulado no repositório.
- UI fina: só o programa conhece ecrãs; a orquestração (`prepare`/`write`/`release`)
  não abre diálogos.

**Non-Goals (nível de design):**
- Framework genérico de upload reutilizável — o parser é específico do layout PAC.
- Índice secundário sobre `PAC_CAT` na subcategoria — só se medido necessário.
- Abstracção de frontend para leitura de ficheiro — `CL_GUI_FRONTEND_SERVICES`
  directamente em `ZCL_MM_PAC_FILE` (não testável, aceite).

## Decisions

### Modelo de dados

**Domínios** (§5.1): `ZDO_PAC_CAT` (CHAR 10), `ZDO_PAC_SUBCAT` (CHAR 12),
`ZDO_PAC_DESC` (CHAR 100, **LOWERCASE**), `ZDO_PAC_STATUS` (CHAR 1, valores fixos
**`A` = Activa / `I` = Inactiva**, D-02/D-03). O ano usa o domínio standard `GJAHR`
(NUMC 4). O ciclo de vida alargado `D/A/B/C/F` pertence ao **Item PAC** (mudança 5);
nessa altura nasce um domínio próprio para `STATUS_PACITEM` — não é usado aqui.

**Data elements** (§5.2): `ZDE_PAC_YEAR`, `ZDE_PAC_CAT`, `ZDE_PAC_CAT_DESC`,
`ZDE_PAC_SUBCAT`, `ZDE_PAC_SUBCAT_DESC`, `ZDE_PAC_STATUS` (status da **categoria**),
`ZDE_PAC_STATUS_REASON` (motivo de mudança de status — usado na manutenção, mudança 3).
Standard reutilizados: `MANDT`, `DATAB`, `DATBI`, `ERNAM`, `ERDAT`, `ERZET`,
`AENAM`, `AEDAT`, `AEZET` — existência confirmada via MCP no CBD (tarefa 0.3,
2026-10-14): todos existem; `AEZET` está presente (TIMS 6), pelo que **não** é
necessário o fallback para `UZEIT`.

**Tabelas** (§5.3): `ZMM_PAC_CAT` e `ZMM_PAC_SUBCAT`, transparentes, dependentes de
mandante, classe de entrega **A** (dados de aplicação, carregados por upload em cada
mandante), classe de dados `APPL0`, categoria de tamanho 0, sem buffering, **registo
de alterações activo** (`PROTOKOLL = X`, histórico via SCU3). Chaves:

- `ZMM_PAC_CAT`: chave `MANDT + PAC_YEAR + PAC_CAT`; campos `PAC_CAT_DESC`, **`STATUS`**
  (`ZDE_PAC_STATUS`, `A`/`I`), validade e auditoria. O status vive **na categoria**
  (D-02); no upload nasce sempre `A` (a coluna de status não existe no ficheiro).
- `ZMM_PAC_SUBCAT`: chave `MANDT + PAC_YEAR + PAC_SUBCAT` (sem `PAC_CAT` na chave — ADR-02);
  campos `PAC_SUBCAT_DESC`, `PAC_CAT` (não-chave, não nulo, com foreign key para
  `ZMM_PAC_CAT`, cardinalidade 1:CN, tipo campos-chave), validade e auditoria.
  A subcategoria **não tem status** (D-02).

A FK de ABAP não é aplicada pela BD em `INSERT`; a garantia vem do validador (INV-3);
a FK serve documentação, ajuda F4 e manutenção.

**Layout do ficheiro (§5.4):** CSV UTF-8 (BOM opcional removido na leitura) **ou
Windows-1252/cp1252** (D-06/A1), separador `;`, **sem aspas nem quebras de linha
dentro de um campo — linha física = registo** (D-06/A5); 5 colunas `ANO; COD_CATEGORIA; DESC_CATEGORIA;
COD_SUBCATEGORIA; DESC_SUBCATEGORIA` (sem coluna de status — D-02); cabeçalho comparado sem distinção de
maiúsculas/espaços; linhas totalmente vazias ignoradas; numeração de linha do log =
linha física (cabeçalho = 1); máximo 10 000 linhas; extensão `.csv`.

### Arquitectura ABAP (§6)

Camadas sem ciclos; a UI é a única que conhece ecrãs:

```text
ZMM_PAC_UPLOAD (PROG) ──► ZCL_MM_PAC_UPLOAD ──► ZCL_MM_PAC_PARSER
        │                        │          ├──► ZCL_MM_PAC_VALIDATOR ──► ZCL_MM_PAC_LOG
        │                        │          ├──► ZCL_MM_PAC_CHANGESET
        │                        │          └──► ZIF_MM_PAC_REPOSITORY ◄── ZCL_MM_PAC_REPOSITORY
        ├──► ZCL_MM_PAC_FILE     └──► ZCL_MM_PAC_AUTH
        └──► CL_SALV_TABLE
Todos ──► ZIF_MM_PAC_TYPES, ZCX_MM_PAC, MSAG ZMM_PAC
```

| Objecto | Tipo | Responsabilidade | ABAP Unit |
|---|---|---|---|
| `ZIF_MM_PAC_TYPES` | INTF | Tipos e constantes partilhados | — |
| `ZIF_MM_PAC_REPOSITORY` | INTF | Contrato de dados: ler ano, bloquear, inserir, commit, rollback | — |
| `ZCL_MM_PAC_REPOSITORY` | CLAS | Implementação real (Open SQL, `ENQUEUE_E_TABLE`) | Não (integração) |
| `ZCL_MM_PAC_FILE` | CLAS | F4 e leitura do posto de trabalho | Não (frontend) |
| `ZCL_MM_PAC_PARSER` | CLAS | Tabela de strings → linhas tipadas; cabeçalho, colunas, BOM, normalização | **Sim** |
| `ZCL_MM_PAC_VALIDATOR` | CLAS | REQ-03..09 sobre linhas + estado da BD por parâmetro | **Sim** |
| `ZCL_MM_PAC_CHANGESET` | CLAS | Linhas válidas novas → registos com auditoria e validade | **Sim** |
| `ZCL_MM_PAC_LOG` | CLAS | Mensagens T100, estatísticas, filtro E/W | **Sim** |
| `ZCL_MM_PAC_AUTH` | CLAS | `AUTHORITY-CHECK` do objecto `ZMM_PAC`; **não** `FINAL` (duplo por herança) | Não (duplo) |
| `ZCL_MM_PAC_UPLOAD` | CLAS | Orquestração `prepare`/`write`/`release`; confirmação fica no programa | **Sim** (duplos) |
| `ZCX_MM_PAC` | CLAS | Excepção verificada com mensagem T100 | — |
| `ZMM_PAC_UPLOAD` | PROG | Ecrã de selecção, ALV, popup de confirmação | Não (fino) |
| `ZMM_PAC_MENU` | PROG | Lançador das transacções PAC | Não |

**Contratos chave:** `ZIF_MM_PAC_REPOSITORY` expõe `read_categories`,
`read_subcategories`, `lock_year`, `unlock_year`, `insert_new` (não faz COMMIT),
`commit`, `rollback`. `commit`/`rollback` fazem parte do contrato de propósito: o
duplo de teste conta as chamadas, tornando REQ-10 ("sem COMMIT") verificável.
O `ZCL_MM_PAC_VALIDATOR` recebe `iv_today` no construtor para testar o intervalo de
anos (REQ-03) de forma determinística.

**Performance (§6.4):** uma leitura por tabela filtrada por `PAC_YEAR` (prefixo da
chave → índice primário); estado da BD em tabelas locais `SORTED`; duplicados do
ficheiro numa tabela `HASHED` por subcategoria; `INSERT ... FROM TABLE` uma vez por
tabela. Sem `SELECT *`, sem Open SQL em ciclos.

### Fluxo de execução e LUW (§7) — a decisão mais crítica

Sequência: validar modo de fundo (REQ-17) → autorização (REQ-15) → ler ficheiro →
parser (estrutura) → se Gravação `lock_year` (REQ-13) → ler estado da BD → validar →
estatísticas → ramo Simulação/erros/sem-novidades/confirmação → changeset →
**zona de escrita** → `unlock` (sempre) → mensagem final.

**Zona sem diálogos (regra INV-6 / C4):** entre o primeiro `INSERT` e o
`COMMIT`/`ROLLBACK` é proibido `CALL SCREEN`, popup, `CL_SALV_TABLE->display`,
`MESSAGE` tipo I/W/E/A, `CALL TRANSACTION`, RFC síncrono e `WAIT` — todos provocam
commit implícito e anulam o rollback.

Regras adicionais: categorias inseridas antes das subcategorias (coerência FK);
`CX_SY_OPEN_SQL_DB` por chave duplicada é capturada no repositório e convertida em
`ZCX_MM_PAC` (`063`), sem `ACCEPTING DUPLICATE KEYS`; `COMMIT WORK` sem `AND WAIT`
(não há update task); bloqueio com `_SCOPE = '1'` e libertação explícita.

### Mensagens, autorizações, UI (§8)

Classe de mensagens `ZMM_PAC`, textos ≤ 73 caracteres, `&1`–`&4` em tempo de
execução (inventário completo na §8.1 da spec v2). Nenhum texto literal para o
utilizador. Objecto de autorização `ZMM_PAC` (campo `ACTVT`): `03` simular/consultar,
`01` gravar, `02` manutenção (mudança 3); verificado no programa antes de qualquer
leitura. Ecrã de selecção com ficheiro, botões de rádio Simulação/Gravação e
checkbox "só erros e avisos". ALV `CL_SALV_TABLE` em ecrã completo com estatísticas
no `set_top_of_list`.

### ADRs (§9)

- **ADR-01 — Upload só cria; nunca altera.** Registos existentes são comparados e
  reportados, nunca actualizados. Rejeitado *upsert* com `MODIFY` (perde auditoria,
  contorna motivo de mudança de status, torna a regra de fecho frágil). Consequência:
  correcções passam pela manutenção (mudança 3).
- **ADR-02 — Chave da subcategoria sem a categoria.** `MANDT+PAC_YEAR+PAC_SUBCAT` +
  `PAC_CAT` não-chave com FK. Rejeitados: chave da v1 + índice único (mais um objecto
  frágil no abapGit); validação só em código (não protege outros canais).
- **ADR-03 — CSV UTF-8 ou cp1252 com `;` (D-06/A1).** `GUI_UPLOAD` com detecção de
  codificação: UTF-8 (página 4110, BOM opcional) e Windows-1252 (página 1160, ANSI do
  Excel). Sem suporte a aspas/registos multi-linha (D-06/A5). Rejeitados:
  `ALSM_EXCEL_TO_INTERNAL_TABLE` (trunca a 50 car., exige Excel, OLE lento),
  `TEXT_CONVERT_XLS_TO_SAP` (OLE/Windows), abap2xlsx (dependência de terceiros).
  `CL_FDT_XL_SPREADSHEET` fica para avaliação (D-08).
- **ADR-04 — Testabilidade por interface em 7.40.** BD atrás de
  `ZIF_MM_PAC_REPOSITORY`, duplos locais, data injectada, orquestrador dividido em
  `prepare`/`write`/`release`. Rejeitados: `CL_OSQL_TEST_ENVIRONMENT` (inexistente em
  7.40), testes contra dados reais (não repetíveis).
- **ADR-05 — Menu por programa lançador.** Transacções individuais + `ZMM_PAC_MENU`.
  Rejeitado *area menu* SE43 (objecto `SHI3` frágil no abapGit, sem verificação de
  autorização por opção).

> As ADRs podem ser extraídas na íntegra para `docs/adr/0001…0005-*.md` durante o
> `apply`; o resumo acima é a fonte para essa extracção.

### Entrega abapGit (§11)

Estrutura: `.abapgit.xml` na raiz (sem wrapper `<abapGit>`, `MASTER_LANGUAGE` D-01,
`STARTING_FOLDER=/src/`, `FOLDER_LOGIC=PREFIX`); packages `ZMM_PAC` → `_DATA`
(DOMA, DTEL, TABL, MSAG) / `_CORE` (INTF, CLAS, SUSO) / `_UI` (PROG, TRAN). Metafiles
em UTF-8 com BOM, LF, newline final, 2 espaços; gerados com `abapgit_meta.py` quando
suportado; `python abapgit_meta.py check --root .` sem erros antes de cada commit.
Inventário completo e moldes XML na §11.2–11.5 da spec v2.

**Objectos criados no SAP e serializados (não gerar à mão):** `ZCX_MM_PAC` (SE24,
antes do pull das classes core), FK de `ZMM_PAC_SUBCAT-PAC_CAT` (SE11), `ZMM_PAC`
SUSO (SU21), transacções (SE93), textos de selecção (SE38) e, condicionalmente,
objecto de bloqueio `EZ_MM_PAC` (SE11) se a verificação de `ENQUEUE_E_TABLE` em SM12
falhar.

## Risks / Trade-offs

- **Regex dos códigos com excepções desconhecidas (D-06)** → **resolvido (2026-10-13)**:
  validado contra o ficheiro real; âmbito reduzido à família PAC (0 falhas em 215
  categorias e 303 subcategorias). Ver `docs/testes/D06_achados.md` e a §Decisões
  fechadas em `proposal.md`.
- **Excel grava CSV em ANSI em vez de UTF-8** → modelo oficial + detecção de
  caracteres inválidos (REQ-02); aviso `024` para descrições iniciadas por `= + - @`
  (risco de fórmula ao exportar).
- **Bloqueio por `ENQUEUE_E_TABLE` pode não cobrir todas as linhas do ano** → verificar
  em SM12; criar `EZ_MM_PAC` se necessário.
- **SM30/programa de manutenção pode ignorar o bloqueio por ano até à mudança 3** →
  risco aceite explicitamente na revisão.
- **`PAC_CAT` fora da chave torna o acesso por categoria num campo não-chave** →
  aceitável no volume previsto; índice secundário só se medido.
- **Registo de alterações depende de `rec/client` em QAS/PRD** → confirmar com Basis
  (tarefa 0.4).

## Migration Plan

- **Deploy:** criar packages `ZMM_PAC*` no DEV com a camada de transporte correcta →
  ligar o repositório abapGit → criar `ZCX_MM_PAC` no SAP e serializar → pull dos
  objectos G (DOMA → DTEL → TABL → MSAG → INTF → CLAS → PROG) → criar FK, SUSO, TRAN,
  textos de selecção no SAP e serializar → transporte DEV → QAS → PRD.
- **Dados:** tabelas de classe de entrega A — não transportadas; o catálogo é
  carregado por upload em cada mandante.
- **Rollback:** objectos revertidos por transporte; registos de um ano eliminados por
  programa de apoio autorizado, se necessário (não há eliminação pela aplicação).

## Open Questions

- ~~Confirmar o nível de SP do SAP_BASIS (tarefa 0.2).~~ **Fechado 2026-10-14: 7.40
  SP22** — `FILTER`/`REDUCE`/`FOR` passam a permitidos. Não altera specs nem a
  divisão de tarefas; afecta apenas detalhe de implementação.
- ~~Confirmar existência de `AEZET` no CBD (tarefa 0.3).~~ **Fechado 2026-10-14:
  `AEZET` existe** (TIMS 6); sem fallback para `UZEIT`.

> Decisões que **bloqueiam o `apply`** (D-01, D-02, D-03, D-06, D-07) não são
> "open questions" — têm de ser resolvidas no `proposal.md` antes da implementação.

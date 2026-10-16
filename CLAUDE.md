# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# ZMM_PAC — Plano Anual de Compras · instruções para Claude Code

Comunicar em português (Moçambique/Portugal). Código, nomes de objectos e comentários técnicos em inglês, conforme Clean ABAP; textos para o utilizador só na classe de mensagens.

## 1. O que é este repositório

Solução SAP ECC para carregar e gerir o catálogo do Plano Anual de Compras (categorias e subcategorias PAC por ano). Desenvolvido com Spec-Driven Development (OpenSpec) e entregue ao SAP exclusivamente por **abapGit pull**.

- Especificação completa: `docs/especificacao/ZMM_PAC_Especificacao_v2.md` — fonte de detalhe; os artefactos OpenSpec já existem e são a referência operacional.
- Mudança activa: `openspec/changes/add-pac-catalog-upload/` (mudança 1 de 6, §1.3 da spec) — `proposal.md`, `design.md`, `tasks.md` e `specs/plano-anual-compras/spec.md` criados; `openspec validate --strict` verde.
- Estado actual: **proposta válida — aguarda revisão humana para a secção 1 (código)**. Não há código ABAP aprovado para escrever. Preparação 0.1/0.2/0.3/0.5/0.6 concluídas (**5/26**); falta a 0.4 (Basis). Tabelas renomeadas para `ZMM_PAC_CATG`/`ZMM_PAC_SUBCATG` (2026-10-14).
- **Em disco neste momento**: `CLAUDE.md`, `abapgit_meta.py`, `docs/` (spec v2, `testes/`, `setup/`; os ADRs estão inline no `design.md`, ainda sem `docs/adr/`), `openspec/` (inicializado, com `project.md` e a mudança activa) e `src/` (apenas os `package.devc.xml` da raiz e de `_DATA`/`_CORE`/`_UI`, ainda **sem objectos**). **Git inicializado** no ramo `change/add-pac-catalog-upload`, remoto `github.com/amigy85/ZMM_PAC` (**público**).

### Ordem de leitura no início de cada sessão

1. Este ficheiro.
2. `openspec/project.md` (se existir).
3. `openspec list` e `openspec status` — saber em que fase estamos.
4. Da mudança activa: `proposal.md` → `specs/plano-anual-compras/spec.md` → `design.md` → `tasks.md`.
5. A spec v2 só para detalhe que ainda não esteja nos artefactos.

## 2. Ambiente SAP

| Item | Valor |
|---|---|
| Sistema | SAP ECC 6.0 EHP7 · SAP_BASIS 7.40 · CBD/010 |
| Nível de SP do SAP_BASIS | **0022 — confirmado via MCP (CVERS): SAP_BASIS 740 SP0022, 2026-10-14** |
| MASTER_LANGUAGE (abapGit) |P · **irreversível depois do primeiro pull** |
| Acesso de Claude Code ao SAP | MCP **só de leitura** — consultar, nunca escrever |
| Entrega | Git push → abapGit pull no DEV → transporte DEV → QAS → PRD |

### Sintaxe ABAP permitida

SP confirmado via MCP: **7.40 SP22** (2026-10-14). Como SP22 ≥ SP08, todo o conjunto de expressões do 7.40 está disponível.

- Permitido: declarações inline, `VALUE #`, `NEW #`, `CONV #`, `CORRESPONDING #`, expressões de tabela, templates de string, Open SQL com `@` e listas separadas por vírgulas, **e também `FILTER`, `REDUCE` e `FOR` em expressões** (disponíveis desde o 7.40 SP08).
- **Proibido sempre:** `WITH HEADER LINE`, `OCCURS`, `RANGES`, `REUSE_ALV_*`, `SELECT *`, Open SQL dentro de ciclos, `FOR ALL ENTRIES` (volumes não o justificam), CDS, RAP, `CL_OSQL_TEST_ENVIRONMENT` (só existe a partir de 7.51 — o CBD é 7.40, logo indisponível independentemente do SP).
- ALV só com `CL_SALV_TABLE`. Apenas tabelas Z (preparação S/4HANA).

## 3. Processo SDD — o portão que não se salta

```
propose ──► [REVISÃO HUMANA] ──► apply ──► verify ──► archive
```

- **Não escrever código ABAP sem o plano aprovado pelo utilizador.** Ao terminar os artefactos, apresentar, validar e **parar**.
- **Decisões que bloqueiam o `apply`:** D-01, D-02, D-03, D-06, D-07 (§12 da spec). Se alguma não estiver registada em `proposal.md`, não avançar — perguntar.
- Não acrescentar funcionalidade fora da spec. O que está fora da mudança 1 (§1.3): alterar registos existentes por upload, eliminar registos, ficheiros do servidor (AL11), execução em fundo, `.xlsx`, consulta, manutenção, integração com PR, `ZMM_PAC_ITEM`, relatório de execução, Power BI.
- Se o design não funcionar durante a implementação: **actualizar o artefacto e avisar** — nunca divergir em silêncio.
- Marcar uma tarefa em `tasks.md` só **depois** de o objecto activar no SAP e o teste passar (o utilizador confirma a activação).
- Nunca editar `openspec/specs/` à mão; só muda via `openspec archive`, e só depois de aceite em PRD.

### Mapeamento spec v2 → artefactos OpenSpec

| Artefacto | Conteúdo da spec v2 |
|---|---|
| `proposal.md` | §0 (achados da v1), §1 (contexto, intenção, âmbito, riscos), decisões D-01…D-10 com o estado de cada uma, nº da ordem de transporte |
| `specs/plano-anual-compras/spec.md` | §2 (glossário, invariantes, ciclo de vida) e §3 (REQ-01 a REQ-18) como `## ADDED Requirements` |
| `design.md` | §4 a §9 e §11 (premissas, modelo de dados, arquitectura, LUW, mensagens, autorizações, ADRs, segurança, abapGit) |
| `tasks.md` | §13, com as referências REQ de cada tarefa |
| `docs/adr/0001…0005-*.md` | ADR-01 a ADR-05 completas |

Formato obrigatório do delta spec (o validador exige os cabeçalhos em inglês; o conteúdo fica em português):

```markdown
## ADDED Requirements

### Requirement: REQ-01 — Modo de execução
O sistema DEVE executar o upload em exactamente um de dois modos…

#### Scenario: modo por omissão
- GIVEN …
- WHEN …
- THEN …
```

Se `openspec validate --strict` exigir SHALL/MUST no texto, acrescentar a palavra inglesa a seguir ao termo português (`DEVE (MUST)`, `NÃO DEVE (MUST NOT)`), sem traduzir o resto.

## 4. Regras invioláveis da mudança 1

Estas regras vêm de defeitos encontrados na v1. Violar qualquer uma é bloqueador de revisão.

1. **Nunca gravar com erros, nunca gravar parcialmente** (INV-6, REQ-11).
2. **O upload só cria** — `INSERT`, nunca `MODIFY`/`UPDATE` sobre registos existentes (ADR-01). Existentes são comparados e reportados conforme a tabela do REQ-09.
3. **`COMMIT WORK` só dentro de `ZIF_MM_PAC_REPOSITORY~commit`**, sem `AND WAIT` (não há update task).
4. **Zona sem diálogos** entre o primeiro `INSERT` e o `COMMIT`/`ROLLBACK`: proibido `CALL SCREEN`, popup, `display` de ALV, `MESSAGE` tipo I/W/E/A, `CALL TRANSACTION`, RFC síncrono, `WAIT`. Todos provocam commit implícito (§7.2).
5. **Bloqueio antes de ler a BD** em modo Gravação (`lock_year`, `_SCOPE = '1'`); libertar sempre, também em excepção. A simulação não bloqueia.
6. **Autorização antes de ler o ficheiro**, dentro do programa (`ZCL_MM_PAC_AUTH`): `ACTVT 03` para simular, `01` para gravar. Qualquer `sy-subrc <> 0` nega.
7. `sy-batch = 'X'` → mensagem `052` e fim (REQ-17).
8. Um único carimbo `ERDAT/ERZET` por execução; `AE*` vazios na criação; validade `01.01.AAAA–31.12.AAAA` (REQ-14).
9. Categorias inseridas antes das subcategorias. `CX_SY_OPEN_SQL_DB` convertida em `ZCX_MM_PAC` (`063`). Sem `ACCEPTING DUPLICATE KEYS`.
10. Mensagens só pela classe `ZMM_PAC` (`MESSAGE ID … INTO` para o log). Nenhum texto literal para o utilizador; textos ≤ 73 caracteres.
11. Códigos normalizados (trim + maiúsculas); descrições > 72 caracteres são erro, **nunca truncar** (domínios `ZMM_PAC_CAT_DESC`/`ZMM_PAC_SUBCAT_DESC` CHAR 72).

## 5. Arquitectura (resumo — detalhe em `design.md`)

```text
ZMM_PAC_UPLOAD (PROG) ──► ZCL_MM_PAC_UPLOAD ──► ZCL_MM_PAC_PARSER
        │                        │          ├──► ZCL_MM_PAC_VALIDATOR ──► ZCL_MM_PAC_LOG
        │                        │          ├──► ZCL_MM_PAC_CHANGESET
        │                        │          └──► ZIF_MM_PAC_REPOSITORY ◄── ZCL_MM_PAC_REPOSITORY
        ├──► ZCL_MM_PAC_FILE     └──► ZCL_MM_PAC_AUTH
        └──► CL_SALV_TABLE
Todos ──► ZIF_MM_PAC_TYPES, ZCX_MM_PAC, MSAG ZMM_PAC
```

- Só o programa `ZMM_PAC_UPLOAD` conhece ecrãs. `ZCL_MM_PAC_UPLOAD` expõe `prepare` / `write` / `release`; a confirmação acontece no programa, entre `prepare` e `write`.
- Data de hoje injectada no validador (`iv_today`); BD sempre atrás de `ZIF_MM_PAC_REPOSITORY`.
- `ZCL_MM_PAC_AUTH` **não** é `FINAL` (duplo por herança nos testes).
- Performance: uma leitura por tabela filtrada por `PAC_YEAR`; tabelas locais `SORTED`; duplicados do ficheiro em tabela `HASHED`; `INSERT … FROM TABLE` uma vez por tabela.

### Convenções de código

- Clean ABAP; métodos ≤ 50 linhas; sem variáveis globais fora do programa de UI.
- Prefixos: `iv_/it_/io_` importação, `rv_/rt_/ro_` retorno, `lv_/lt_/ls_/lo_` locais, `mv_/mt_/mo_` atributos.
- DDIC: o modelo PAC **adoptado** usa domínios e data elements `ZMM_PAC_*` (objectos existentes corrigidos no local em `ZMM_PAC_DATA`, não greenfield) e tabelas `ZMM_PAC_CATG`/`ZMM_PAC_SUBCATG`/`ZMM_PAC_ITEM`.
- Antes de usar qualquer data element, classe ou módulo de função standard, **confirmar via MCP que existe no CBD** (ex.: `AEZET`; se ausente, usar `UZEIT`).

## 6. abapGit

### Estrutura

```text
/.abapgit.xml          ← raiz, SEM elemento <abapGit>
/src/                  ← STARTING_FOLDER, FOLDER_LOGIC = PREFIX
  package.devc.xml     ← ZMM_PAC
  data/  ← ZMM_PAC_DATA  (DOMA, DTEL, TABL, MSAG)
  core/  ← ZMM_PAC_CORE  (INTF, CLAS, SUSO)
  ui/    ← ZMM_PAC_UI    (PROG, TRAN)
/docs/, /openspec/     ← fora de /src/, ignorados pelo abapGit
```

### Regras de ficheiro

- **UTF-8, LF, quebra de linha final, indentação de 2 espaços.** **BOM só nos metafiles XML; os ficheiros de fonte `.abap` NÃO levam BOM** — o abapGit do CBD não remove o BOM do fonte na importação e o compilador rejeita (`﻿INTERFACE não previsto`). Sem LF/newline, cada pull gera diffs fantasma. (`abapgit_meta.py check` aplica esta regra: BOM obrigatório em XML, proibido em `.abap`.)
- Metafiles de objecto **com** `<abapGit version="v1.0.0" …>`; `.abapgit.xml` **sem**.
- Nomes de ficheiro em minúsculas (`zcl_mm_pac_parser.clas.abap`); nomes dentro do XML em maiúsculas.
- Todos os ficheiros de um objecto na mesma pasta. Não criar ficheiros de partes vazias (`locals_def`, `locals_imp`, `testclasses` só se tiverem conteúdo).
- `LANGU` / `DDLANGUAGE` / `MASTERLANG` / `SPRSL` = MASTER_LANGUAGE (D-01).
- Campos numéricos DDIC como strings com zeros à esquerda (`LENG` 6 dígitos, `MSGNR` 3 dígitos). `&` no XML como `&amp;`.
- Gerar com `abapgit_meta.py` quando suportado (`dot`, `devc`, `clas`, `intf`, `prog`, `doma`, `dtel`). `TABL` e `MSAG` seguem os moldes da §11.4 da spec.
- **Antes de cada commit:** `python3 abapgit_meta.py check --root .` sem erros (em Windows, `python` em vez de `python3`).

### Comandos do `abapgit_meta.py` (Python 3.8+, sem dependências)

> Executável: nos comandos abaixo usa-se `python3`; em Windows o executável é normalmente `python` (o `python3` pode não estar no PATH). Usar o que existir — `python abapgit_meta.py …` ou `python3 abapgit_meta.py …`.

Validar o repositório inteiro (gate de commit — sai com código 1 se houver erros, 0 só com avisos):

```bash
python3 abapgit_meta.py check --root .
python3 abapgit_meta.py check --root . --fix   # corrige BOM/EOL/newline final em todos os ficheiros
```

Gerar metafiles (todos aceitam `--lang`, `--out`; defaults `--lang E`, `--out .`):

```bash
python3 abapgit_meta.py dot  --starting-folder /src/ --folder-logic PREFIX [--ignore <padrões>]
python3 abapgit_meta.py devc --description "<texto>"
python3 abapgit_meta.py clas --name ZCL_... --description "<texto>" [--skeleton]
python3 abapgit_meta.py intf --name ZIF_... --description "<texto>" [--skeleton]
python3 abapgit_meta.py prog --name Z...    [--description "<texto>"] [--subc 1|I|M|F|K|J|S] [--skeleton]
python3 abapgit_meta.py doma --name ZDO_... --description "<texto>" [--datatype CHAR] [--length 10] [--decimals 0]
python3 abapgit_meta.py dtel --name ZDE_... --description "<texto>" --domain ZDO_...
```

- `dot` gera o `.abapgit.xml` **sem** wrapper `<abapGit>` e sempre na raiz; os restantes geram metafiles de objecto **com** o wrapper.
- `doma` com valores fixos (`VALEXI`/`DD07V_TAB`) e os tipos `TABL`/`MSAG` **não** são gerados pela ferramenta — seguir os moldes da §11.4 da spec.
- `clas` avisa quando o nome começa por `ZCX_`/`YCX_`: a `VSEOCLASS` de uma excepção precisa de `CATEGORY`/`EXPOSURE` próprios — serializar um exemplo do SAP e comparar (coerente com "não gerar `ZCX_MM_PAC` à mão", abaixo).

### NÃO gerar à mão — pedir ao utilizador para criar no SAP e serializar

| Objecto | Onde | Nota |
|---|---|---|
| `ZCX_MM_PAC` | SE24 | `CX_STATIC_CHECK` + `IF_T100_MESSAGE`; textos `NO_AUTHORIZATION` (050), `YEAR_LOCKED` (051), `DB_INSERT_FAILED` (063). Tem de existir **antes** do pull das classes `core`. Depois de serializada, o `.clas.abap` é editado no Git. |
| FK `ZMM_PAC_SUBCATG-PAC_CAT` | SE11 | Nunca escrever nós `DD05M`/`DD08V` à mão |
| Objecto de autorização `ZMM_PAC` (SUSO) | SU21 | Classe a confirmar (D-09) |
| Transacções `ZMM_PAC`, `ZMM_PAC_UPLOAD` (TRAN) | SE93 | Report → ecrã 1000 |
| Textos de selecção e símbolos de texto | SE38 | Nunca reconstruir `TPOOL` à mão |
| Objecto de bloqueio `EZ_MM_PAC` (ENQU) | SE11 | Só se a verificação em SM12 da §7.2 falhar |
| Qualquer FUGR, TOBJ, índice de tabela | — | Idem |

Quando uma tarefa depende de um destes, parar e dar ao utilizador as instruções exactas de criação no SAP.

## 7. Testes

- ABAP Unit em `<classe>.clas.testclasses.abap`, `FOR TESTING RISK LEVEL HARMLESS DURATION SHORT`. **Não precisa de `.xml` próprio** (é o include CCAU da classe).
- **Gotcha abapGit (CBD):** no **primeiro pull** de uma classe nova, o include de testes (`*.clas.testclasses.abap`) **pode não ser criado**. Se a classe activar mas o ABAP Unit disser *"no executable unit tests"* (SABP_UNIT100) ou o editor de *Local Test Classes* estiver vazio: fazer **pull outra vez** (traz o include) ou, em último caso, colar o conteúdo em SE24 → *Goto → Local Test Classes* e activar. Verificar sempre que a `ltc_*` está presente antes de correr os testes.
- Duplo `ltd_repository` implementa `ZIF_MM_PAC_REPOSITORY` em memória e **conta** chamadas a `insert_new`, `commit`, `rollback` — é assim que REQ-10 ("sem COMMIT") e REQ-11 se provam.
- Cada cenário Given/When/Then tem um método de teste antes de a tarefa ser marcada. Usar os nomes de método da §14.1 da spec. GIVEN → setup com duplos; WHEN → chamada ao método; THEN → `cl_abap_unit_assert`.
- Dados de teste em `docs/testes/` (fora de `/src/`). Testes manuais em QAS: §14.3.
- Verificação final: ABAP Unit verde, ATC sem findings P1/P2 novos, `check` sem erros, pull no DEV sem diffs fantasma.

## 8. Git

- Um ramo por mudança: `change/add-pac-catalog-upload`.
- Commits atómicos por tarefa: `feat(pac): <o que mudou> [refs: add-pac-catalog-upload 2.3]`.
- Artefactos OpenSpec entram nos commits — fazem parte do código.
- Nunca fazer commit de credenciais, dados reais não anonimizados ou ficheiros `.csv` de produção.

## 9. Skills a usar

| Momento | Skill |
|---|---|
| Qualquer trabalho de planeamento, proposta ou alteração | `sdd-openspec` |
| Ao gerar qualquer objecto ABAP ou metafile | `abapgit-metafiles` |
| Durante o `apply` e antes de cada commit de código | `abap-code-review` |
| Ao escrever `design.md` e antes do `archive` (autorização, ficheiros de entrada, auditoria) | `security-review` |

## 10. Primeira sessão — o que fazer

1. Verificar o ambiente: `node --version` (≥ 20.19), `openspec --version`, `git status`.
2. Se `openspec/` não existir: `openspec init --tools claude`; escrever `openspec/project.md` **com** o utilizador (stack, restrições desta página, fora de âmbito por princípio).
3. Mover a spec para `docs/especificacao/` se ainda não estiver lá.
4. Criar `change/add-pac-catalog-upload` e decompor a spec nos artefactos da §3 deste ficheiro. Extrair as ADRs para `docs/adr/`.
5. `openspec validate add-pac-catalog-upload --strict` e `openspec show add-pac-catalog-upload`.
6. Apresentar ao utilizador: resumo da proposta, decisões pendentes (destacando as que bloqueiam o `apply`) e a Definition of Ready. **Parar e aguardar aprovação.**

## 11. Registo de decisões (actualizar à medida que forem tomadas)

| ID | Decisão | Estado | Data |
|---|---|---|---|
| D-01 | MASTER_LANGUAGE `P` | **decidida: `P`** | 2026-10-12 |
| D-02 | `STATUS` só na categoria (`A`/`I`); subcategoria sem status; Item PAC terá `STATUS_PACITEM` (`D/A/B/C/F`, mudança 5) | **decidida** | 2026-10-12 |
| D-03 | Matrizes de transição: categoria `A`/`I`; Item PAC `D/A/B/C/F` (mudança 5) | **decidida** | 2026-10-12 |
| D-04 | Manutenção: SM30 ou programa próprio | pendente (mudança 3) | |
| D-05 | Upload só cria (ADR-01); correcções de descrição/status pela manutenção (mudança 3) | **decidida: aceite** | 2026-10-14 |
| D-06 | Regex dos códigos validada com o ficheiro real | **decidida: só PAC; regex `^PAC-[A-Z][0-9]{3}$` / subcat `…\.[1-9][0-9]{0,2}$` validada (0 falhas); domínios cat CHAR 8 / subcat CHAR 12 (reais); parser suporta cp1252; aspas proibidas** — ver `docs/testes/D06_achados.md` | 2026-10-13 |
| D-07 | Intervalo de anos: corrente a corrente + 1 | **decidida** | 2026-10-12 |
| D-08 | Suporte `.xlsx` (`CL_FDT_XL_SPREADSHEET` no CBD?) | pendente | |
| D-09 | Classe do objecto de autorização e segregação de funções | **decidida: classe `MM_E`; perfis Consulta `03`, Gestor `01/02/03`; segregação carregar-vs-fechar fica em aberto** | 2026-10-14 |
| D-10 | Fecho do PAC ao nível do ano | **decidida: não existe fecho anual global (fecha-se ao nível de categoria/item); sem tabela de cabeçalho do ano** | 2026-10-14 |

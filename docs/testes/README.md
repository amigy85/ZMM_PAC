# Dados de teste — ZMM_PAC upload

Ficheiros de entrada para os testes (ABAP Unit do `ZCL_MM_PAC_PARSER`/`VALIDATOR` e
testes manuais em QAS, §14). Todos usam o layout oficial de 5 colunas separadas por `;`
(`ANO;COD_CATEGORIA;DESC_CATEGORIA;COD_SUBCATEGORIA;DESC_SUBCATEGORIA`, sem coluna de
status — D-02), terminador CRLF, uma linha física por registo (sem aspas — D-06/A5).

Codificação: UTF-8 (sem BOM), **excepto** `ansi_1252.csv` e `valido_303.csv` que estão em
Windows-1252 (cp1252) para exercitar o caminho ANSI (D-06/A1). O `valido.csv` (ficheiro
real em bruto) **não é versionado** — ver Notas.

## Ficheiro válido (caso feliz)

| Ficheiro | Conteúdo | Uso |
|---|---|---|
| `valido.csv` | Ficheiro real em bruto (cp1252, 6 famílias). **Local-only / gitignored** (dados reais, §8). | Fonte; não é fixture de teste directo. |
| `valido_303.csv` | **Anonimizado** (dados fictícios): 303 linhas (215 categorias, 303 subcategorias), 0 erros, cp1252 com acentos. O real fica local em `valido_303.real.csv` (gitignored). | M1/M2 QAS; base do caso feliz. |
| `modelo_pac.csv` | Modelo/template do layout oficial. | Referência de formato. |

## Fixtures de erro

Linha física: cabeçalho = 1, primeira linha de dados = 2.

| Ficheiro | Erro esperado | Msg | REQ | Método de teste (§14.1) |
|---|---|---|---|---|
| `so_cabecalho.csv` | Ficheiro só com cabeçalho, sem dados. | `006` | REQ-02 | `header_only_is_rejected` |
| `cabecalho_errado.csv` | 4.ª coluna do cabeçalho é `SUBCAT` (esperado `COD_SUBCATEGORIA` na posição 4). | `004` | REQ-02 | `wrong_header_reports_column` |
| `colunas_erradas.csv` | Linha 3 com 7 campos (esperados 5). | `005` | REQ-02 | `wrong_column_count_is_error` |
| `dois_anos.csv` | Linhas com ano 2026 e 2027. | `008` | REQ-03 | `mixed_years_rejected` |
| `relacao_invalida.csv` | Subcategoria `PAC-E065.1` sob categoria `PAC-G155` (prefixo divergente). | `018` | REQ-06 | `subcat_prefix_mismatch` |
| `duplicados.csv` | Linha 3: subcat `PAC-G155.3` duplicada (ref. linha 2). Linha 5: categoria `PAC-G139` com descrição divergente da linha 4. | `019`, `021` | REQ-07 | `duplicate_subcat_in_file`, `cat_desc_divergent_in_file` |
| `formato_invalido.csv` | Linha 2: `STK-E001` família fora de âmbito (formato cat.). Linha 3: subcat `PAC-G155-3` formato inválido. Linha 4: descrição de subcategoria com 101 caracteres. | `016`, `017`, `022` | REQ-05 | `invalid_subcat_format`, `description_too_long` |
| `ansi_1252.csv` | Ficheiro **válido** em cp1252 com acentos; verifica que os acentos são preservados na leitura ANSI. | — (sem erro) | REQ-02 | cenário "acentos preservados num ficheiro cp1252" |
| `10001_linhas.csv` | 10 001 linhas de dados (excede o limite de 10 000). Linhas válidas; só o volume é erro. | `007` | REQ-02 | `more_than_max_rows_rejected` |

## Fixtures de ITEM (mudança 5 — `ZMM_PAC_ITEM`)

Layout de 9 colunas `ANO;COD_SUBCATEGORIA;DESCRICAO;QUANTIDADE;UNIDADE;VALOR;MOEDA;CENTRO;CONTA_RAZAO`
(CENTRO/CONTA_RAZAO opcionais, sem validação — D5). Referenciam subcategorias reais
(anonimizadas) do `valido_303.csv` (`PAC-E001.1`…), pelo que **o catálogo tem de estar
carregado no ano 2026** antes de os usar. Gerados por `scratchpad/gen_item_fixtures.py`.

Com a D5-08 o `CENTRO` e a `CONTA_RAZAO` passaram a **obrigatórios e validados** (centro em
T001W, conta em SKB1 pela empresa `P_BUKRS`). O happy-path precisa de centros e contas
**reais** da `HCB`, por isso fica **gitignored** (`*.real.csv`, CLAUDE.md §8); versiona-se
apenas os fixtures de erro, com valores propositadamente inválidos (sem contas reais).

| Ficheiro | Versionado? | Conteúdo | Msg esperada | Uso |
|---|---|---|---|---|
| `item_valido.real.csv` | **não** (gitignored) | 15 itens válidos (cp1252, 1 descrição com acentos); centros `MPM/CHIM/SONG/RSUL` e contas reais da `HCB`. | — (086 na gravação) | Caso feliz 4.3 |
| `item_10000.real.csv` | **não** (gitignored) | 10 000 itens válidos (centros/contas reais). | — | Volume 4.4 |
| `item_so_cabecalho.csv` | sim | Só cabeçalho. | `006` | Estrutural |
| `item_cabecalho_errado.csv` | sim | 3.ª coluna `DESC` (esperado `DESCRICAO`). | `004` | Estrutural |
| `item_colunas_erradas.csv` | sim | Linha 3 com 7 campos (esperados 9). | `005` | Estrutural |
| `item_dois_anos.csv` | sim | Linhas 2026 e 2027. | `008` | REQ-03 |
| `item_erros.csv` | sim | 12 linhas, uma por erro: `082/083/088/085/084` (formato), `092` centro vazio, `094` conta vazia, `080` subcat inexistente, `090` moeda `XYZ`, `091` unidade `XX`, `093` centro `ZZZZ`, `095` conta `9999999999`. Bloqueia a gravação toda (061/INV-6). | `082/083/088/085/084/092/094/080/090/091/093/095`, `061` | REQ-22..25, D5-08, INV-6 |

Notas sobre o `item_erros.csv`: os erros ao nível de `collect` (`080/090/091/093/095`) só são
alcançados se a linha passar os obrigatórios (centro+conta preenchidos), por isso essas linhas
trazem `MPM` + `9999999999` (conta inexistente) — o que faz algumas acusarem também `095`; o
importante é que cada mensagem-alvo aparece e o ficheiro é rejeitado.

Para o cenário **categoria-mãe inactiva (081)**: pôr manualmente uma categoria a `STATUS='I'`
(SE16N em DEV) e carregar um item dessa família.

## Notas

- **`status_invalido.csv` não existe** (estava no §14.2 da spec v2): com a D-02 o
  ficheiro deixou de ter coluna de status, pelo que não há status a validar no upload.
  Os testes `invalid_status` / `new_record_blocked_rejected` (REQ-08) ficaram
  obsoletos — a inactivação de categorias é manutenção (mudança 3).
- Os cenários da BD (REQ-06 `subcat_exists_in_other_cat`/`023`, REQ-09 existentes) não
  têm fixture CSV: testam-se com o duplo `ltd_repository` em memória, não por ficheiro.
- **Dados reais do catálogo (§8 do CLAUDE.md):** os ficheiros com dados reais —
  `valido.csv` e `valido_303.real.csv` — estão em `.gitignore` e ficam **só locais**.
  O `valido_303.csv` versionado é **anonimizado** (nomes/códigos fictícios), mantendo
  estrutura, contagens (215/303) e casos de validação. Nunca versionar CSV de produção.

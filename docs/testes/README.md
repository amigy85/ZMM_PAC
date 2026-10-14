# Dados de teste — ZMM_PAC upload

Ficheiros de entrada para os testes (ABAP Unit do `ZCL_MM_PAC_PARSER`/`VALIDATOR` e
testes manuais em QAS, §14). Todos usam o layout oficial de 5 colunas separadas por `;`
(`ANO;COD_CATEGORIA;DESC_CATEGORIA;COD_SUBCATEGORIA;DESC_SUBCATEGORIA`, sem coluna de
status — D-02), terminador CRLF, uma linha física por registo (sem aspas — D-06/A5).

Codificação: UTF-8 (sem BOM), **excepto** `valido.csv` e `ansi_1252.csv` que estão em
Windows-1252 (cp1252) para exercitar o caminho ANSI (D-06/A1). `valido_303.csv` está em
cp1252 por ter sido derivado do ficheiro real.

## Ficheiro válido (caso feliz)

| Ficheiro | Conteúdo | Uso |
|---|---|---|
| `valido.csv` | Ficheiro real em bruto (cp1252, 6 famílias, com anomalias A6/A7/A8). | Fonte; não é fixture de teste directo. |
| `valido_303.csv` | Subconjunto só PAC, limpo: 303 linhas (215 categorias, 303 subcategorias), 0 erros. cp1252. | M1/M2 QAS; base do caso feliz. |
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

## Notas

- **`status_invalido.csv` não existe** (estava no §14.2 da spec v2): com a D-02 o
  ficheiro deixou de ter coluna de status, pelo que não há status a validar no upload.
  Os testes `invalid_status` / `new_record_blocked_rejected` (REQ-08) ficaram
  obsoletos — a inactivação de categorias é manutenção (mudança 3).
- Os cenários da BD (REQ-06 `subcat_exists_in_other_cat`/`023`, REQ-09 existentes) não
  têm fixture CSV: testam-se com o duplo `ltd_repository` em memória, não por ficheiro.
- `valido.csv` e `valido_303.csv` contêm dados do catálogo real; não fazer commit de
  dados reais não anonimizados em produção (§8 do CLAUDE.md).

# D-06 — Achados da validação contra o ficheiro real

**Data:** 2026-10-12 · **Ficheiro:** `docs/testes/valido.csv` · **Registos:** 963 dados (964 com cabeçalho; 975 linhas físicas por causa de campos multi-linha).

**Resultado: a regex proposta FALHOU.** `^PAC-[A-Z][0-9]{3}$` casou apenas **313/963** códigos
(a família `PAC`). O catálogo real tem **6 famílias** e várias surpresas estruturais que
afectam o modelo de dados, o parser e as regras REQ-05/06/07 e a ADR-03.

## A1 — Codificação: cp1252 (ANSI), não UTF-8
O ficheiro está em **Windows-1252**, não UTF-8. Todos os acentos (`ã`, `ç`, `é`, `º`)
estão em ANSI. A leitura prevista com página de códigos 4110/UTF-8 (ADR-03) corromperia
todas as descrições acentuadas. → Suportar cp1252 na leitura, ou exigir export "CSV UTF-8".

## A2 — Seis famílias de código, não só `PAC`
| Família | Nº | Exemplo | Provável significado |
|---|---|---|---|
| STK | 450 | `STK-E001` | Stock / armazém |
| PAC | 313 | `PAC-E001` | Plano Anual de Compras |
| CTR | 140 | `CTR-E005/2023` | Contratos (com ano) |
| PLA | 24 | `PLA-G001` | Planeamento |
| FOR | 23 | `FOR-G001` | Formação |
| GRA | 13 | `GRA-E001` | — |

O nome "catálogo PAC" e a regex `^PAC-…` cobrem **um terço** do universo real.

## A3 — Quatro formatos de código (A=letra, 9=dígito)
| Forma | Nº | Exemplo |
|---|---|---|
| `AAA-A999` | 823 | `PAC-E065`, `STK-E001`, `FOR-G001` |
| `AAA-A999/9999` | 117 | `CTR-E005/2023` (sufixo de ano do contrato) |
| `AAA-AAAA-99` | 22 | `CTR-PLAN-01` (balde de planeamento) |
| `AAA-A9999/9999` | 1 | `CTR-G0010/2021` (4 dígitos) |

**Regex candidata** (cobre 963/963 categorias e 961/963 subcategorias):
- Categoria: `^(PAC|STK|CTR|FOR|GRA|PLA)-(?:[A-Z]{1,4}[0-9]{3,4}(?:/[0-9]{4})?|PLAN-[0-9]{2})$`
- Subcategoria: a mesma + `\.[0-9]{1,3}$`

## A4 — Comprimentos excedem os domínios DDIC
- Categoria: máx. **14 car.** → `ZDO_PAC_CAT` (CHAR **10**) estoura em **115 registos**.
- Subcategoria: máx. **16 car.** → `ZDO_PAC_SUBCAT` (CHAR **12**) estoura em **124 registos**.
→ Alargar domínios (sugestão com folga: CAT CHAR 20, SUBCAT CHAR 24).

## A5 — Campos multi-linha com aspas (8)
Há descrições com quebras de linha internas delimitadas por `"` (ex.: linhas 117-119,
148-150). Contradiz a ADR-03/§5.4 ("sem aspas; linha física = registo"). O parser tem
de suportar aspas RFC-4180 e registos multi-linha — não pode dividir por linha física.

## A6 — Regra de pertença (REQ-06) violada em 27 registos
Categorias de planeamento (`CTR-PLAN-01…`) agrupam subcategorias com códigos **não
relacionados** (ex.: cat `CTR-PLAN-01` → sub `CTR-G114/2025`). A regra "a subcategoria
começa pelo código da categoria + `.`" é **falsa** para estes baldes. Além disso, 2
subcategorias não têm sufixo `.N` nenhum (`CTR-G114/2025`, `CTR-G115/2025`).
→ Decisão de negócio: como modelar a relação categoria↔subcategoria nestes casos.

## A7 — Subcategoria repetida (REQ-07) em 21 códigos
Ex.: `CTR-G044/2025.1` nas linhas 68/69/70 com **descrições diferentes**;
`CTR-G096/2018.1` em 102/103/104. Pela REQ-07 actual seriam **todos erros** (duplicado
no ficheiro). Mas parecem intencionais na origem (uma subcategoria com vários itens).
→ Decisão de negócio: são erros de dados a corrigir, ou um padrão legítimo?

## A8 — Descrições > 100 caracteres em 19 registos
`ZDO_PAC_DESC` é CHAR 100; pela REQ-05 estes são erros (nunca truncar).
→ Alargar o domínio ou limpar a origem.

## Conclusão
D-06 **não pode ser fechada como "validada"**. Os achados A2/A4/A5 obrigam a rever o
modelo de dados (domínios, nome da capacidade) e o parser; A1 obriga a rever a ADR-03;
A6/A7/A8 são decisões de Aprovisionamento.

## Decisões sobre os achados (2026-10-12)

- **A6/A7/A8 — DECIDIDO: os dados devem ser limpos na origem.** As regras estritas
  mantêm-se (REQ-05 descrições ≤ 100, REQ-06 pertença por prefixo, REQ-07 sem
  subcategorias repetidas). O ficheiro de origem é corrigido **antes** do carregamento;
  é desejável que o upload **rejeite** o que não cumprir. → Sem alterações a
  REQ-05/06/07 por causa destes achados.
- **A2 — DECIDIDO (2026-10-13): só a família `PAC`.** A mudança 1 carrega apenas
  `PAC-*`; as outras 5 famílias (STK, CTR, FOR, GRA, PLA) ficam fora de âmbito e são
  **rejeitadas** como formato inválido (`ZMM_PAC/016`/`017`). O nome da capacidade
  (`plano-anual-compras`) e das tabelas mantêm-se.
  - **A3 (regex final):** categoria `^PAC-[A-Z][0-9]{3}$`; subcategoria
    `^PAC-[A-Z][0-9]{3}\.[1-9][0-9]{0,2}$`. **Validada contra o ficheiro real: 0/215
    categorias e 0/303 subcategorias falham.**
  - **A4 (domínios):** os actuais `ZDO_PAC_CAT` CHAR 10 e `ZDO_PAC_SUBCAT` CHAR 12
    **chegam** (PAC: cat máx 8, subcat máx 11). **Sem alargamento.**
- **A1 — DECIDIDO (2026-10-13): suportar cp1252 na leitura.** O parser lê
  Windows-1252 (como o Excel exporta) e converte; mitiga o risco "Excel grava CSV em
  ANSI" (prob. Alta). Revê a ADR-03 (página de códigos) — ver nota no `design.md`.
- **A5 — DECIDIDO (2026-10-13): proibir aspas / registos multi-linha.** Mantém-se
  "linha física = registo" (ADR-03/§5.4); aspas e quebras internas são erro a limpar
  na origem, coerente com A6/A7/A8. No subconjunto PAC real não há nenhum caso.

## D-06 FECHADA — 2026-10-13

Com o âmbito reduzido a **só PAC**, a regex proposta foi **validada contra o ficheiro
real** (`valido.csv`, 313 linhas PAC, 215 categorias e 303 subcategorias distintas):

| Verificação | Resultado |
|---|---|
| Categoria `^PAC-[A-Z][0-9]{3}$` | 0/215 falham |
| Subcategoria `^PAC-[A-Z][0-9]{3}\.[1-9][0-9]{0,2}$` | 0/303 falham |
| REQ-06 pertença (subcat começa por cat+`.`) | 0 falham |
| Comprimentos vs. domínios CHAR 10/12 | cabem (máx 8 / 11) |
| Aspas/quebras internas (A5) | 0 |
| Descrições > 100 car. (A8) | 2 (109 car.) — limpar na origem |

**D-06 = decidida.** Deixa de bloquear o `apply`. Permanecem como tarefas de
implementação (não bloqueadoras): parser cp1252 (A1), rejeição de aspas (A5),
rejeição das 5 famílias fora de âmbito (A2).

> O `valido.csv` continua a ser o **ficheiro real em bruto** (ANSI, 6 famílias, com
> anomalias A6/A7/A8).

## Fixture `valido_303.csv` — criada 2026-10-13

Gerada a partir do `valido.csv` (subconjunto **só PAC**), em **cp1252 + CRLF**, com
**303 linhas de dados** (215 categorias, 303 subcategorias distintas) e **0 erros** de
validação (regex, pertença, duplicados, descrições ≤ 100). Limpezas aplicadas na
geração (decisões do utilizador, 2026-10-13):

- **6 subcategorias repetidas** (A7) colapsadas numa linha com descrição **genérica**
  (sufixo de departamento removido): `PAC-E086.2` → "Telefones IP"; `PAC-G138.4` →
  "Cartões de Visita"; `PAC-G139.3` → "Acessórios de Computador"; `PAC-G139.5` →
  "Telemóveis"; `PAC-G141.2` → "Porta Paletes"; `PAC-G149.1` → "Utensílios de Cozinha".
- **1 descrição > 100 car.** (A8, `PAC-G007`) encurtada para "Fornecimento e Montagem
  de equipamentos de desinfecção da água por Cloro Gás na **ETA**" (83 car.).

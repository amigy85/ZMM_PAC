# Especificação — ZMM_PAC · Plano Anual de Compras (v2.0)

| Item | Valor |
|---|---|
| Repositório Git | `ZMM_PAC` (sincronizado por abapGit) |
| Sistema | SAP ECC 6.0 EHP7 · SAP_BASIS 7.40 · CBD/010 |
| Método | Spec-Driven Development (OpenSpec) + Claude Code |
| Estado | **Proposta — aguarda revisão humana** (ver §12, decisões pendentes) |
| Versão anterior | v1 — `ZMM_PAC_ABAP_Desenvolvimento.md` |

Este documento substitui a v1. Está organizado para ser decomposto directamente nos artefactos OpenSpec (§10): a Parte A é o **o quê** (proposta e requisitos verificáveis), a Parte B é o **como** (design), a Parte C é a **entrega em Git** (abapGit), a Parte D é o **plano e a prova** (tarefas e testes).

> **Regra principal (inalterada):** o sistema NUNCA grava dados quando existem erros de validação — e nunca grava parcialmente.

---

## Índice

- [0. Revisão da v1 — achados](#0-revisão-da-v1--achados)
- **Parte A — Proposta e requisitos**
  - [1. Contexto, intenção e âmbito](#1-contexto-intenção-e-âmbito)
  - [2. Modelo de domínio](#2-modelo-de-domínio)
  - [3. Requisitos e cenários](#3-requisitos-e-cenários)
- **Parte B — Design técnico**
  - [4. Premissas técnicas](#4-premissas-técnicas)
  - [5. Modelo de dados](#5-modelo-de-dados)
  - [6. Arquitectura ABAP](#6-arquitectura-abap)
  - [7. Fluxo de execução e LUW](#7-fluxo-de-execução-e-luw)
  - [8. Mensagens, autorizações, ALV, transacções](#8-mensagens-autorizações-alv-transacções)
  - [9. Decisões de arquitectura (ADR) e segurança](#9-decisões-de-arquitectura-adr-e-segurança)
- **Parte C — Repositório e abapGit**
  - [10. Estrutura do repositório e mapeamento OpenSpec](#10-estrutura-do-repositório-e-mapeamento-openspec)
  - [11. Metafiles abapGit](#11-metafiles-abapgit)
- **Parte D — Decisões, plano e verificação**
  - [12. Decisões pendentes](#12-decisões-pendentes)
  - [13. Plano de tarefas (mudança 1)](#13-plano-de-tarefas-mudança-1)
  - [14. Estratégia de testes](#14-estratégia-de-testes)
  - [15. Definition of Done](#15-definition-of-done)
  - [16. Instruções para Claude Code](#16-instruções-para-claude-code)
  - [17. Evolução futura](#17-evolução-futura)

---

## 0. Revisão da v1 — achados

A v1 tem uma boa base: fluxo simulação → gravação, validação antes de persistir, preocupação com auditoria, performance e separação de responsabilidades. Os problemas estão sobretudo no que ficou **por decidir** e em três pontos que, implementados à letra, produziriam defeitos em produção.

### Críticos — implementados como na v1, geram defeitos

| ID | Secção v1 | Problema | Correcção na v2 |
|---|---|---|---|
| C1 | §18 | `MODIFY ... FROM TABLE` sobre registos existentes **sobrescreve `ERNAM/ERDAT/ERZET`** (a auditoria de criação perde-se) e sobrescreve a descrição — contradizendo a própria recomendação do §8.6 de não sobrescrever. | Upload passa a ser **só de criação** (`INSERT`); registos existentes nunca são alterados pelo upload (REQ-09, ADR-01). |
| C2 | §12 | A chave `MANDT+PAC_YEAR+PAC_CAT+PAC_SUBCAT` **permite a mesma subcategoria em duas categorias** (`PAC-G155.3` sob `PAC-G155` e sob `PAC-E065`). A regra "pertence à categoria" não fica garantida pela base de dados. | Chave da subcategoria passa a `MANDT+PAC_YEAR+PAC_SUBCAT`; `PAC_CAT` é campo não-chave com foreign key (ADR-02). |
| C3 | §15–18 | **Sem bloqueio (enqueue).** Dois utilizadores a gravar o mesmo ano em simultâneo validam contra o mesmo estado e ambos gravam — ou um rebenta com chave duplicada. | Bloqueio exclusivo por mandante+ano durante validação e gravação (REQ-13). |
| C4 | §17 | A v1 não proíbe diálogos entre a escrita e o `COMMIT`. Qualquer popup, ALV ou `MESSAGE` tipo I/W nesse intervalo provoca **commit implícito da base de dados** — gravação parcial sem rollback possível. | Regra explícita: nenhum ecrã entre o primeiro `INSERT` e o `COMMIT WORK` (§7.2). |

### Altos — ambiguidades que impedem implementação ou teste

| ID | Secção v1 | Problema | Correcção na v2 |
|---|---|---|---|
| A1 | §5 | Uma única coluna `STATUS` para categoria **e** subcategoria — não se sabe a qual se aplica. | `STATUS` aplica-se à subcategoria; categoria nova nasce `A`; status de categoria só muda por manutenção (D-02). |
| A2 | §8.8 | "Subcategoria pertence à categoria" sem regra definida. | Regra por prefixo de código + formato validado por expressão regular (REQ-05, REQ-06, D-06). |
| A3 | §9 | Regra de fecho codificada para `PAC_YEAR = 2026`; sem máquina de estados; `STATUS_REASON` sem regra. | Máquina de estados com matriz de transições (§2.3); motivo obrigatório para `B/C/F`. |
| A4 | §8.6–8.7 | "Categoria existe?" e "Subcategoria duplicada?" misturam duplicado **no ficheiro** (erro) com registo **já existente na BD** (reprocessamento normal). Reprocessar o mesmo ficheiro não tem comportamento definido. | Separação explícita (REQ-07 vs REQ-09) e idempotência (REQ-12). |
| A5 | §3 | Modos como caixas de selecção "mutuamente exclusivas", com dois cenários de erro para as tratar. | Botões de rádio: o ecrã torna o estado inválido impossível (REQ-01). |
| A6 | §4 | Formato "a definir pelo projecto". `ALSM_EXCEL_TO_INTERNAL_TABLE` trunca células a 50 caracteres e exige Excel no PC; acentos dependem da página de códigos. | CSV UTF-8 com `;` como formato da v1 (ADR-03); `.xlsx` como decisão pendente (D-08). |
| A7 | §23 | Autorizações "distintas" sem objecto definido. Programas Z executam-se via SA38 sem passar pela transacção. | Objecto `ZMM_PAC` com `ACTVT`, verificado dentro do programa (§8.2). |
| A8 | §25 | Testes não verificáveis: o Teste 7 (PRs) está fora do âmbito do upload; o Teste 6 não diz se o ficheiro cria ou altera; o Teste 8 depende de inspecção manual. | Cenários Given/When/Then mapeados para ABAP Unit, com repositório de teste que conta `COMMIT`s (§14). |
| A9 | §4, §21 | "ECC 6.0" genérico. O sistema é 7.40: permite sintaxe moderna, mas **não** tem `CL_OSQL_TEST_ENVIRONMENT` (só a partir de 7.51). | Premissas técnicas explícitas (§4); testabilidade por interface (ADR-04). |

### Médios e baixos

| ID | Problema | Correcção |
|---|---|---|
| M1 | `ZMM_PAC_ITEM` "preparada" sem numeração, sem campos de referência para `CURR`/`QUAN`, sem requisitos — especulação (YAGNI). | Fora de âmbito da mudança 1; mudança própria (§1.3). |
| M2 | `VALID_FROM`/`VALID_TO` sem regra de preenchimento. | Derivados do ano no upload (REQ-14). |
| M3 | Mensagens escritas em código, em várias linhas, sem classe de mensagens — não traduzíveis, excedem 73 caracteres. | Classe de mensagens `ZMM_PAC` (§8.1). |
| M4 | Comprimentos de campo indefinidos → truncagem silenciosa. | Domínios com comprimento definido; excesso é erro (REQ-05). |
| M5 | Linha "S — Registo válido" por cada linha: 303 linhas de ruído no ALV. | ALV mostra só E/W por omissão (REQ-16). |
| M6 | `GUI_UPLOAD` não funciona em fundo; a v1 não o trata. | Execução em fundo rejeitada (REQ-17). |
| M7 | Menu como *area menu* (SE43) — objecto `SHI3` frágil de serializar no abapGit. | Transacções individuais + programa lançador (ADR-05). |
| M8 | Tipos `ZPAC_*` sem prefixo de tipo de objecto; metafiles abapGit não especificados. | Convenção `ZDO_`/`ZDE_`; Parte C completa. |
| B1 | `SELECT ... FOR ALL ENTRIES` sugerido para ~10³ linhas: sobre-engenharia. | Uma leitura por ano, pesquisa em tabela ordenada (§6.4). |
| B2 | `COMMIT WORK AND WAIT` só tem efeito com update task. | `COMMIT WORK` (sem update task nesta mudança). |
| B3 | Requisitos, design e código misturados no mesmo nível — impossível rever o "o quê" sem discutir o "como". | Estrutura SDD (Partes A–D). |

---

# Parte A — Proposta e requisitos

## 1. Contexto, intenção e âmbito

### 1.1 Contexto

O Plano Anual de Compras (PAC) é hoje mantido fora do SAP. Não existe catálogo de categorias/subcategorias PAC no sistema, pelo que as requisições de compra não podem ser classificadas nem o PAC pode ser acompanhado contra a execução real (PR → PO → GR → factura → pagamento).

### 1.2 Intenção

Depois desta entrega, o Aprovisionamento consegue carregar o catálogo PAC de um ano a partir de ficheiro, ver antecipadamente todos os problemas do ficheiro sem risco, e gravar o catálogo de forma atómica, auditada e repetível.

### 1.3 Âmbito e faseamento

O âmbito da v1 é decomposto em mudanças OpenSpec independentes, cada uma entregável e revisável por si. **Este documento especifica em detalhe a mudança 1**; as restantes ficam com requisitos preliminares.

| # | Mudança OpenSpec | Entrega | Depende de |
|---|---|---|---|
| 1 | `add-pac-catalog-upload` | Modelo de dados, upload com simulação/gravação, autorização, lançador | — |
| 2 | `add-pac-catalog-query` | Consulta de categorias e subcategorias | 1 |
| 3 | `add-pac-catalog-maintenance` | Manutenção de descrições e status, com motivo e transições | 1 |
| 4 | `add-pac-usage-check-requisition` | Impedir uso de categoria/subcategoria não utilizável em novas PRs | 1, 3 |
| 5 | `add-pac-planning-items` | Itens de planeamento (`ZMM_PAC_ITEM`) | 1 |
| 6 | `add-pac-execution-report` | Relatório planeado × comprometido × executado × saldo | 4, 5 |

**Fora de âmbito da mudança 1:**

- Alteração de registos existentes por upload (descrições ou status) — é manutenção (mudança 3).
- Eliminação de categorias ou subcategorias.
- Leitura de ficheiros do servidor de aplicação (AL11) e execução em fundo.
- Ficheiros `.xlsx` (D-08).
- Integração com PR, itens de planeamento, relatório de execução e Power BI.
- Textos multilíngues das descrições (a empresa opera o catálogo apenas em português).

### 1.4 Riscos

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Convenção de códigos PAC tem excepções não conhecidas | Média | Alto | Validar a regex com o ficheiro real de 303 linhas antes do `apply` (D-06) |
| Excel grava CSV em ANSI em vez de UTF-8 | Alta | Médio | Modelo de ficheiro oficial + detecção de caracteres inválidos (REQ-02) |
| Manutenção futura (SM30/programa) colide com upload em curso | Baixa | Médio | Mesmo bloqueio por ano nas duas funções (mudança 3) |
| Língua principal do repositório abapGit mal escolhida | Média | Alto | Decidir antes do primeiro pull — não é alterável depois (D-01) |

---

## 2. Modelo de domínio

### 2.1 Glossário

| Termo | Definição |
|---|---|
| **PAC** | Plano Anual de Compras de um ano civil. |
| **Categoria PAC** | Agrupamento de primeiro nível, único por ano. Ex.: `PAC-G155` — Materiais e Equipamentos de Segurança. |
| **Subcategoria PAC** | Agrupamento de segundo nível, único por ano, pertencente a exactamente uma categoria. Ex.: `PAC-G155.3`. |
| **Simulação** | Execução completa de leitura e validação, sem qualquer efeito na base de dados. |
| **Gravação** | Execução que, sem erros e com confirmação, cria de forma atómica os registos novos. |
| **Registo utilizável** | Subcategoria que pode ser atribuída a uma nova PR (ver §2.3). |

### 2.2 Invariantes

1. **INV-1** — Um código de subcategoria é único dentro do ano.
2. **INV-2** — Uma subcategoria pertence a uma e uma só categoria do mesmo ano, e o seu código começa pelo código dessa categoria seguido de `.`.
3. **INV-3** — Não existe subcategoria sem categoria (foreign key).
4. **INV-4** — Um registo `F` (Fechado) ou `C` (Cancelado) não sofre qualquer alteração, nem recebe novas subcategorias.
5. **INV-5** — Os campos de criação (`ERNAM/ERDAT/ERZET`) nunca são alterados depois da criação.
6. **INV-6** — O catálogo de um ano nunca fica parcialmente gravado por uma execução de upload.

### 2.3 Ciclo de vida do status

| Código | Status | Utilizável em nova PR | Editável |
|---|---|---|---|
| `D` | Rascunho | Não | Sim |
| `A` | Activo | **Sim** | Sim |
| `B` | Bloqueado | Não | Sim (status) |
| `C` | Cancelado | Não | Não (terminal) |
| `F` | Fechado | Não | Não (terminal) |

Uma subcategoria só é utilizável se **ela e a sua categoria** estiverem em `A`. O status da categoria não é propagado por escrita às subcategorias; é avaliado no momento do uso.

**Matriz de transições** (proposta — confirmar com o Aprovisionamento, D-03). `—` = registo inexistente.

| De \ Para | D | A | B | C | F | Canal |
|---|---|---|---|---|---|---|
| — (novo) | ✅ | ✅ | ❌ | ❌ | ❌ | Upload ou manutenção |
| D | ✅ | ✅ | ❌ | ✅ | ❌ | Manutenção |
| A | ❌ | ✅ | ✅ | ✅ | ✅ | Manutenção |
| B | ❌ | ✅ | ✅ | ✅ | ✅ | Manutenção |
| C | ❌ | ❌ | ❌ | ✅ | ❌ | — |
| F | ❌ | ❌ | ❌ | ❌ | ✅ | — |

Transições para `B`, `C` e `F` exigem `STATUS_REASON` preenchido. Como o ficheiro de upload não tem motivo, **o upload só cria registos em `D` ou `A`**.

---

## 3. Requisitos e cenários

Domínio OpenSpec: `plano-anual-compras`. Palavras RFC 2119: DEVE / NÃO DEVE / DEVERIA / PODE. Os requisitos descrevem comportamento observável; nomes de objectos pertencem à Parte B.

### REQ-01 — Modo de execução

O sistema DEVE executar o upload em exactamente um de dois modos, Simulação ou Gravação, sendo Simulação o modo proposto por omissão.

#### Cenário: modo por omissão
- GIVEN o utilizador abre o upload do PAC
- WHEN o ecrã de selecção é apresentado
- THEN o modo Simulação está seleccionado
- AND não é possível seleccionar os dois modos em simultâneo

### REQ-02 — Leitura e estrutura do ficheiro

O sistema DEVE rejeitar o ficheiro inteiro, sem validar linhas, quando a sua estrutura não corresponder ao layout oficial (§5.4).

#### Cenário: ficheiro sem linhas de dados
- GIVEN um ficheiro apenas com o cabeçalho
- WHEN o upload é executado em qualquer modo
- THEN é apresentada a mensagem `ZMM_PAC/006` e nada é processado

#### Cenário: cabeçalho inválido
- GIVEN um ficheiro cuja 4.ª coluna do cabeçalho é `SUBCAT`
- WHEN o upload é executado
- THEN é apresentada a mensagem `ZMM_PAC/004` indicando a coluna esperada `COD_SUBCATEGORIA` e a posição 4

#### Cenário: número de colunas errado numa linha
- GIVEN a linha 12 com 7 campos
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/005` para a linha 12 e a gravação fica impedida

#### Cenário: acentos preservados
- GIVEN um ficheiro UTF-8 (com ou sem BOM) com a descrição "Equipamento de Proteção Individual"
- WHEN o upload é executado em simulação
- THEN a descrição é apresentada no ALV exactamente com os mesmos caracteres

#### Cenário: limite de volume
- GIVEN um ficheiro com 10 001 linhas de dados
- WHEN o upload é executado
- THEN é apresentada a mensagem `ZMM_PAC/007` e nada é processado

### REQ-03 — Ano único e válido

O sistema DEVE exigir que todas as linhas do ficheiro tenham o mesmo ano, e que esse ano esteja no intervalo permitido (D-07: ano corrente a ano corrente + 1).

#### Cenário: dois anos no ficheiro
- GIVEN linhas com ano 2026 e linhas com ano 2027
- WHEN o upload é executado
- THEN é apresentada a mensagem `ZMM_PAC/008` e nada é processado

#### Cenário: ano fora do intervalo
- GIVEN a data do sistema em 2026 e um ficheiro com ano 2024
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/011` com o intervalo permitido 2026–2027

#### Cenário: ano não numérico
- GIVEN a linha 3 com ano `20X6`
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/011` para a linha 3

### REQ-04 — Campos obrigatórios

O sistema DEVE registar um erro por cada campo obrigatório vazio, reportando todos os erros de uma linha e não apenas o primeiro.

#### Cenário: categoria e descrição vazias na mesma linha
- GIVEN a linha 9 com código e descrição de categoria vazios
- WHEN o upload é executado
- THEN são registados, para a linha 9, os erros `ZMM_PAC/012` e `ZMM_PAC/013`
- AND as validações dependentes do código de categoria (formato, pertença) não são executadas para essa linha

### REQ-05 — Formato e comprimento

O sistema DEVE normalizar os códigos (remover espaços nas extremidades, converter para maiúsculas) e rejeitar códigos fora do formato oficial e descrições com mais de 100 caracteres, sem truncar.

Formato (D-06, **validado 2026-10-13** contra o ficheiro real — âmbito só PAC, 0 falhas em 215 categorias e 303 subcategorias): categoria `^PAC-[A-Z][0-9]{3}$`; subcategoria `^PAC-[A-Z][0-9]{3}\.[1-9][0-9]{0,2}$`. Códigos de outras famílias (STK, CTR, FOR, GRA, PLA) estão fora de âmbito e são erro de formato. Leitura em cp1252; aspas/registos multi-linha não são suportados (linha física = registo).

#### Cenário: código em minúsculas
- GIVEN a linha 4 com categoria ` pac-g155 `
- WHEN o upload é executado
- THEN a categoria é tratada como `PAC-G155` sem erro

#### Cenário: formato inválido
- GIVEN a linha 5 com subcategoria `PAC-G155-3`
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/017`

#### Cenário: descrição longa
- GIVEN uma descrição de subcategoria com 101 caracteres
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/022` e a descrição não é truncada

### REQ-06 — Pertença da subcategoria à categoria

O sistema DEVE rejeitar uma subcategoria cujo código não comece pelo código da categoria da mesma linha seguido de `.`, ou que já exista na base de dados sob outra categoria do mesmo ano.

#### Cenário: prefixo divergente (Teste 4 da v1)
- GIVEN a linha 27 com categoria `PAC-G155` e subcategoria `PAC-E065.1`
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/018`: "A subcategoria PAC-E065.1 não pertence à categoria PAC-G155."

#### Cenário: subcategoria existente noutra categoria
- GIVEN a subcategoria `PAC-G155.3` gravada em 2026 sob `PAC-G155`
- AND um ficheiro de 2026 com `PAC-G155.3` sob outra categoria
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/023`

### REQ-07 — Consistência interna do ficheiro

O sistema DEVE rejeitar subcategorias repetidas no ficheiro e categorias repetidas com descrições diferentes.

#### Cenário: subcategoria duplicada
- GIVEN as linhas 20 e 87 com `PAC-G155 / PAC-G155.3`
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/019` na linha 87 referindo a linha 20

#### Cenário: categoria repetida com descrição divergente
- GIVEN a linha 30 com `PAC-G139 / Material de Informática` e a linha 31 com `PAC-G139 / Material Informático`
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/021` na linha 31

#### Cenário: categoria repetida com a mesma descrição
- GIVEN 7 linhas com `PAC-G139` e descrição idêntica
- WHEN o upload é executado
- THEN não é registado erro e a categoria é contada uma única vez nas estatísticas

### REQ-08 — Status na criação

O sistema DEVE aceitar apenas `D` ou `A` como status de subcategorias novas, e DEVE rejeitar qualquer outro valor.

#### Cenário: status inexistente (Teste 5 da v1)
- GIVEN a linha 14 com status `X`
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/020` indicando os valores D, A, B, C, F

#### Cenário: criação directa em Bloqueado
- GIVEN uma subcategoria nova com status `B`
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/031` (transição de "—" para B não permitida no upload)

### REQ-09 — Registos já existentes

O upload NÃO DEVE alterar categorias ou subcategorias já existentes. As diferenças entre o ficheiro e a base de dados DEVEM ser reportadas conforme a tabela:

| Situação | Tipo | Mensagem |
|---|---|---|
| Existe e é idêntico | I | `033` |
| Existe, difere, status D/A/B | W | `032` (diferença ignorada) |
| Existe, difere, status F | **E** | `030` |
| Subcategoria nova em categoria existente `B` | W | `035` |
| Subcategoria nova em categoria existente `C` ou `F` | **E** | `034` |

#### Cenário: registo fechado (Teste 6 da v1, clarificado)
- GIVEN a subcategoria `PAC-G155.3` de 2026 gravada com status `F`
- AND um ficheiro de 2026 com `PAC-G155.3` e descrição diferente
- WHEN o upload é executado
- THEN é registado erro `ZMM_PAC/030`: "O registo PAC PAC-G155.3 está FECHADO e não pode ser alterado."
- AND a gravação fica impedida

#### Cenário: descrição divergente em registo activo
- GIVEN a categoria `PAC-G139` de 2026 gravada com status `A` e outra descrição
- WHEN o upload é executado
- THEN é registado aviso `ZMM_PAC/032` e a descrição gravada mantém-se

### REQ-10 — Simulação sem efeitos

A simulação NÃO DEVE inserir, alterar ou eliminar registos, nem confirmar qualquer unidade lógica de trabalho.

#### Cenário: simulação sem erros (Teste 8 da v1)
- GIVEN um ficheiro válido com 303 linhas
- WHEN o upload é executado em Simulação
- THEN as estatísticas e o ALV são apresentados
- AND é apresentada a mensagem `ZMM_PAC/060`
- AND o número de registos das tabelas PAC mantém-se
- AND não é executado `COMMIT WORK`

### REQ-11 — Gravação atómica

O sistema DEVE gravar apenas quando não existirem erros, depois de confirmação explícita do utilizador, e DEVE gravar todos os registos novos ou nenhum.

#### Cenário: gravação com sucesso (Teste 1 da v1)
- GIVEN um ficheiro válido, sem erros, com categorias e subcategorias novas
- WHEN o upload é executado em Gravação e o utilizador confirma
- THEN todos os registos novos são criados numa única unidade lógica de trabalho
- AND é apresentada a mensagem `ZMM_PAC/062` com o número de categorias e subcategorias criadas

#### Cenário: existem erros
- GIVEN um ficheiro com pelo menos um erro
- WHEN o upload é executado em Gravação
- THEN não é pedida confirmação, não é gravado nenhum registo e é apresentada a mensagem `ZMM_PAC/061`

#### Cenário: utilizador cancela
- GIVEN um ficheiro válido em Gravação
- WHEN o utilizador responde "Não" à confirmação
- THEN nada é gravado e é apresentada a mensagem `ZMM_PAC/064`

#### Cenário: falha da base de dados a meio
- GIVEN a inserção de categorias concluída e uma falha na inserção de subcategorias
- WHEN a falha ocorre
- THEN a unidade de trabalho é revertida, nenhuma categoria fica gravada, e é apresentada a mensagem `ZMM_PAC/063`

### REQ-12 — Idempotência

Reexecutar a gravação com um ficheiro já gravado NÃO DEVE criar, alterar nem duplicar registos.

#### Cenário: mesmo ficheiro duas vezes
- GIVEN um ficheiro gravado com sucesso
- WHEN o mesmo ficheiro é gravado novamente
- THEN todas as linhas são classificadas como existentes e idênticas
- AND é apresentada a mensagem `ZMM_PAC/065` sem pedir confirmação

### REQ-13 — Exclusão mútua por ano

O sistema DEVE impedir que duas gravações do mesmo ano decorram em simultâneo, obtendo o bloqueio antes de ler o estado actual da base de dados.

#### Cenário: ano bloqueado por outro utilizador
- GIVEN o utilizador `JSILVA` em gravação do PAC 2026
- WHEN outro utilizador inicia gravação do PAC 2026
- THEN é apresentada a mensagem `ZMM_PAC/051` com o nome `JSILVA` e nada é processado

#### Cenário: simulação não bloqueia
- GIVEN o utilizador `JSILVA` em gravação do PAC 2026
- WHEN outro utilizador executa simulação do PAC 2026
- THEN a simulação é executada normalmente

### REQ-14 — Dados de auditoria e validade

Em cada registo criado, o sistema DEVE preencher utilizador, data e hora de criação com o executor e com um único instante por execução, deixar os campos de alteração vazios, e derivar a validade do ano (`01.01.AAAA` a `31.12.AAAA`).

#### Cenário: carimbo único
- GIVEN uma gravação de 303 subcategorias que atravessa a mudança de minuto
- WHEN a gravação termina
- THEN todos os registos criados têm o mesmo `ERDAT` e `ERZET`

### REQ-15 — Autorização

O sistema DEVE exigir autorização de visualização para simular e autorização de criação para gravar, verificadas dentro do programa e antes de ler o ficheiro.

#### Cenário: utilizador só com consulta tenta gravar
- GIVEN um utilizador com `ACTVT 03` e sem `ACTVT 01`
- WHEN executa o upload em Gravação (pela transacção ou pela SA38)
- THEN é apresentada a mensagem `ZMM_PAC/050` e o ficheiro não é lido

### REQ-16 — Resultado apresentado

O sistema DEVE apresentar estatísticas calculadas a partir dos dados e uma lista com linha, tipo, categoria, subcategoria e mensagem; por omissão a lista mostra apenas erros e avisos.

| Estatística | Definição |
|---|---|
| Total de linhas | Linhas de dados lidas (sem cabeçalho nem linhas totalmente vazias) |
| Categorias novas / existentes | Códigos **distintos** de categoria sem/com registo na BD para o ano |
| Subcategorias novas / existentes | Códigos distintos de subcategoria sem/com registo na BD |
| Linhas com erro | Linhas com pelo menos uma mensagem E |
| Erros / Avisos | Total de mensagens E / W |

#### Cenário: estatísticas coerentes
- GIVEN um ficheiro de 303 linhas com 215 categorias distintas, todas novas, e 0 erros
- WHEN o upload é executado em Simulação
- THEN as estatísticas mostram 303 linhas, 215 categorias novas, 303 subcategorias novas, 0 erros

### REQ-17 — Execução em fundo

O sistema NÃO DEVE executar o upload em fundo, porque o ficheiro é lido do posto de trabalho.

#### Cenário: job agendado
- GIVEN o programa agendado como job
- WHEN o job executa
- THEN termina com a mensagem `ZMM_PAC/052` sem processar

### REQ-18 — Desempenho

O sistema DEVERIA concluir a simulação de um ficheiro de 10 000 linhas em menos de 60 segundos em QAS.

### Requisitos preliminares das mudanças 2–4 (não implementar na mudança 1)

- **Consulta (2):** O sistema DEVE listar categorias e subcategorias por ano, código e status, exigindo autorização de visualização.
- **Manutenção (3):** O sistema NÃO DEVE permitir alterar registos `F` ou `C`; DEVE aplicar a matriz de transições do §2.3; DEVE exigir motivo para `B/C/F`; DEVE preencher `AENAM/AEDAT/AEZET`; DEVE usar o mesmo bloqueio por ano do upload.
- **Uso em PR (4):** O sistema NÃO DEVE permitir gravar uma nova PR com subcategoria não utilizável (§2.3), apresentando `ZMM_PAC/070`. Nota: articular com o ecrã personalizado já existente na requisição de compra.

---

# Parte B — Design técnico

## 4. Premissas técnicas

| Premissa | Consequência |
|---|---|
| SAP_BASIS 7.40, **nível de SP a confirmar** (Sistema → Status) | Até SP05: declarações inline, `VALUE #`, `NEW #`, expressões de tabela, templates de string, Open SQL com `@` e vírgulas. `FILTER`, `REDUCE` e `FOR` só com SP08+ confirmado. |
| Sem `CL_OSQL_TEST_ENVIRONMENT` (7.51+) | Acesso à BD atrás de interface; duplos de teste em ABAP Unit (ADR-04). |
| ECC com migração S/4HANA prevista | Apenas tabelas Z, `CL_SALV_TABLE`, sem `WITH HEADER LINE`, `OCCURS`, `RANGES`, `REUSE_ALV_*`. |
| MCP de leitura para o SAP; entrega exclusiva por abapGit pull | Claude Code escreve objectos fora do SAP; objectos não serializáveis à mão são criados no SAP e serializados (§11.6). |
| Volumes: centenas a poucos milhares de linhas por ano | Uma leitura por ano, sem `FOR ALL ENTRIES`, sem processamento em pacotes. |

---

## 5. Modelo de dados

### 5.1 Domínios

| Domínio | Tipo | Compr. | Minúsculas | Valores fixos |
|---|---|---|---|---|
| `ZDO_PAC_CAT` | CHAR | 10 | Não | — |
| `ZDO_PAC_SUBCAT` | CHAR | 12 | Não | — |
| `ZDO_PAC_DESC` | CHAR | 100 | **Sim** | — |
| `ZDO_PAC_STATUS` | CHAR | 1 | Não | D, A, B, C, F |

O ano usa o domínio standard `GJAHR` (NUMC 4).

### 5.2 Data elements

| Data element | Domínio | Texto breve | Rótulos S / M / L | Cabeçalho |
|---|---|---|---|---|
| `ZDE_PAC_YEAR` | `GJAHR` | Ano do Plano Anual de Compras | Ano PAC / Ano do PAC / Ano do Plano Anual de Compras | Ano PAC (10) |
| `ZDE_PAC_CAT` | `ZDO_PAC_CAT` | Código da categoria PAC | Categoria / Categoria PAC / Código da categoria PAC | Categoria (10) |
| `ZDE_PAC_CAT_DESC` | `ZDO_PAC_DESC` | Descrição da categoria PAC | Desc.Cat. / Desc. categoria / Descrição da categoria PAC | Desc. categoria (20) |
| `ZDE_PAC_SUBCAT` | `ZDO_PAC_SUBCAT` | Código da subcategoria PAC | Subcat. / Subcategoria PAC / Código da subcategoria PAC | Subcategoria (15) |
| `ZDE_PAC_SUBCAT_DESC` | `ZDO_PAC_DESC` | Descrição da subcategoria PAC | Desc.Subc. / Desc. subcategoria / Descrição da subcategoria PAC | Desc. subcategoria (20) |
| `ZDE_PAC_STATUS` | `ZDO_PAC_STATUS` | Status do registo PAC | Status / Status PAC / Status do registo PAC | Status (10) |
| `ZDE_PAC_STATUS_REASON` | `ZDO_PAC_DESC` | Motivo da alteração de status PAC | Motivo / Motivo do status / Motivo da alteração de status | Motivo (20) |

Data elements standard reutilizados: `MANDT`, `DATAB`, `DATBI`, `ERNAM`, `ERDAT`, `ERZET`, `AENAM`, `AEDAT`, `AEZET`. **Tarefa 0.3:** confirmar via MCP que todos existem no CBD; `AEZET`, se ausente, é substituído por `UZEIT`.

### 5.3 Tabelas

Ambas: transparentes, dependentes de mandante, classe de entrega **A** (dados de aplicação — não transportadas, carregadas por upload em cada mandante), classe de dados `APPL0` (dados-mestre), categoria de tamanho 0, sem buffering, **registo de alterações activo** (histórico antes/depois via SCU3, complementar aos campos `AE*`, que só guardam a última alteração).

#### `ZMM_PAC_CAT` — Categoria PAC

| Campo | Chave | Data element | Obs. |
|---|---|---|---|
| `MANDT` | ✔ | `MANDT` | |
| `PAC_YEAR` | ✔ | `ZDE_PAC_YEAR` | |
| `PAC_CAT` | ✔ | `ZDE_PAC_CAT` | |
| `PAC_CAT_DESC` | | `ZDE_PAC_CAT_DESC` | |
| `STATUS` | | `ZDE_PAC_STATUS` | Valores fixos no domínio |
| `STATUS_REASON` | | `ZDE_PAC_STATUS_REASON` | Obrigatório para B/C/F (mudança 3) |
| `VALID_FROM` | | `DATAB` | Derivado do ano |
| `VALID_TO` | | `DATBI` | Derivado do ano |
| `ERNAM` `ERDAT` `ERZET` | | standard | Criação — imutáveis |
| `AENAM` `AEDAT` `AEZET` | | standard | Última alteração |

#### `ZMM_PAC_SUBCAT` — Subcategoria PAC

| Campo | Chave | Data element | Obs. |
|---|---|---|---|
| `MANDT` | ✔ | `MANDT` | |
| `PAC_YEAR` | ✔ | `ZDE_PAC_YEAR` | |
| `PAC_SUBCAT` | ✔ | `ZDE_PAC_SUBCAT` | **Chave sem `PAC_CAT`** (ADR-02) |
| `PAC_CAT` | | `ZDE_PAC_CAT` | Não nulo; foreign key → `ZMM_PAC_CAT` |
| `PAC_SUBCAT_DESC` | | `ZDE_PAC_SUBCAT_DESC` | |
| `STATUS` … `AEZET` | | igual à categoria | |

**Foreign key** em `ZMM_PAC_SUBCAT-PAC_CAT`, tabela de verificação `ZMM_PAC_CAT`, cardinalidade 1:CN, tipo "campos-chave":

| Campo verificado | Campo da tabela de verificação |
|---|---|
| `ZMM_PAC_SUBCAT-MANDT` | `ZMM_PAC_CAT-MANDT` |
| `ZMM_PAC_SUBCAT-PAC_YEAR` | `ZMM_PAC_CAT-PAC_YEAR` |
| `ZMM_PAC_SUBCAT-PAC_CAT` | `ZMM_PAC_CAT-PAC_CAT` |

A foreign key de ABAP não é aplicada pela base de dados em `INSERT`; a garantia é dada pelo validador (INV-3) e a FK serve documentação, ajuda F4 e manutenção. Criação da FK: §11.6.

#### `ZMM_PAC_ITEM`

Fora da mudança 1 (mudança 5). Notas para essa mudança: `VALUE` como `CURR` com referência a `WAERS`, `QTY` como `QUAN` com referência a `MEINS`, `PAC_ITEM` numerado por objecto de intervalo de números, e `PAC_SUBCAT` com FK para `ZMM_PAC_SUBCAT`.

### 5.4 Layout do ficheiro (CSV)

| Pos. | Cabeçalho (exacto) | Campo | Obrigatório | Regra |
|---|---|---|---|---|
| 1 | `ANO` | `PAC_YEAR` | Sim | 4 dígitos, REQ-03 |
| 2 | `COD_CATEGORIA` | `PAC_CAT` | Sim | REQ-05 |
| 3 | `DESC_CATEGORIA` | `PAC_CAT_DESC` | Sim | ≤ 100 |
| 4 | `COD_SUBCATEGORIA` | `PAC_SUBCAT` | Sim | REQ-05, REQ-06 |
| 5 | `DESC_SUBCATEGORIA` | `PAC_SUBCAT_DESC` | Sim | ≤ 100 |
| 6 | `STATUS` | `STATUS` da subcategoria | Sim | REQ-08 |

Regras do formato:

- Codificação **UTF-8** (BOM opcional, removido na leitura); separador `;` (as descrições contêm vírgulas); sem aspas — um `;` dentro de uma descrição resulta em número de colunas errado e erro `005`.
- Primeira linha é o cabeçalho, comparado sem distinção de maiúsculas e sem espaços nas extremidades.
- Linhas totalmente vazias são ignoradas e não contam como linhas.
- Numeração de linha no log = número físico da linha no ficheiro (cabeçalho = 1), para o utilizador a encontrar no Excel.
- Máximo de 10 000 linhas de dados.
- Extensão aceite: `.csv`.

```text
ANO;COD_CATEGORIA;DESC_CATEGORIA;COD_SUBCATEGORIA;DESC_SUBCATEGORIA;STATUS
2026;PAC-E065;Ferramentas Manuais e Eléctricas;PAC-E065.1;Ferramentas Manuais de Fixação e Aperto;A
2026;PAC-G139;Material de Informática e Telecomunicações;PAC-G139.7;Equipamentos e Acessórios de Rede;A
2026;PAC-G155;Materiais e Equipamentos de Segurança;PAC-G155.3;Equipamento de Proteção Individual;A
```

O modelo oficial `docs/modelo/PAC_upload_modelo.csv` fica no repositório (fora de `/src/`).

---

## 6. Arquitectura ABAP

### 6.1 Componentes

| Objecto | Tipo | Responsabilidade | Testável em ABAP Unit |
|---|---|---|---|
| `ZIF_MM_PAC_TYPES` | INTF | Tipos e constantes partilhados (linhas, log, estatísticas, status) | — |
| `ZIF_MM_PAC_REPOSITORY` | INTF | Contrato de acesso a dados: ler ano, bloquear, inserir, commit, rollback | — |
| `ZCL_MM_PAC_REPOSITORY` | CLAS | Implementação real (Open SQL, `ENQUEUE_E_TABLE`) | Não (integração) |
| `ZCL_MM_PAC_FILE` | CLAS | Diálogo F4 e leitura do posto de trabalho (`CL_GUI_FRONTEND_SERVICES`) | Não (frontend) |
| `ZCL_MM_PAC_PARSER` | CLAS | Tabela de strings → linhas tipadas; cabeçalho, colunas, BOM, normalização | **Sim** |
| `ZCL_MM_PAC_VALIDATOR` | CLAS | REQ-03 a REQ-09 sobre linhas + estado actual da BD recebido por parâmetro | **Sim** |
| `ZCL_MM_PAC_CHANGESET` | CLAS | Linhas válidas novas → registos das tabelas com auditoria e validade | **Sim** |
| `ZCL_MM_PAC_LOG` | CLAS | Mensagens T100, estatísticas, filtro E/W | **Sim** |
| `ZCL_MM_PAC_AUTH` | CLAS | `AUTHORITY-CHECK` do objecto `ZMM_PAC` (reutilizado nas mudanças 2–3); **não** `FINAL`, para permitir duplo por herança | Não (substituída por duplo) |
| `ZCL_MM_PAC_UPLOAD` | CLAS | Orquestração do fluxo §7 sem ecrãs: `prepare` (autorização, parse, lock, leitura, validação, estatísticas), `write` (changeset, insert, commit/rollback) e `release` (unlock). A confirmação acontece no programa, entre `prepare` e `write` | **Sim**, com duplos |
| `ZCX_MM_PAC` | CLAS | Excepção verificada com mensagem T100 | — |
| `ZMM_PAC_UPLOAD` | PROG | Ecrã de selecção, ALV (`CL_SALV_TABLE`), popup de confirmação | Não (fino) |
| `ZMM_PAC_MENU` | PROG | Lançador das transacções PAC | Não |

Dependências (sem ciclos; a UI é a única camada que conhece ecrãs):

```text
ZMM_PAC_UPLOAD (PROG) ──► ZCL_MM_PAC_UPLOAD ──► ZCL_MM_PAC_PARSER
        │                        │          ├──► ZCL_MM_PAC_VALIDATOR ──► ZCL_MM_PAC_LOG
        │                        │          ├──► ZCL_MM_PAC_CHANGESET
        │                        │          └──► ZIF_MM_PAC_REPOSITORY ◄── ZCL_MM_PAC_REPOSITORY
        ├──► ZCL_MM_PAC_FILE     └──► ZCL_MM_PAC_AUTH
        └──► CL_SALV_TABLE
Todos ──► ZIF_MM_PAC_TYPES, ZCX_MM_PAC, MSAG ZMM_PAC
```

### 6.2 Contratos

```abap
INTERFACE zif_mm_pac_types PUBLIC.

  CONSTANTS:
    BEGIN OF gc_status,
      draft     TYPE zde_pac_status VALUE 'D',
      active    TYPE zde_pac_status VALUE 'A',
      blocked   TYPE zde_pac_status VALUE 'B',
      cancelled TYPE zde_pac_status VALUE 'C',
      closed    TYPE zde_pac_status VALUE 'F',
    END OF gc_status,
    gc_msgid     TYPE symsgid VALUE 'ZMM_PAC',
    gc_max_rows  TYPE i       VALUE 10000,
    gc_separator TYPE char1   VALUE ';'.

  TYPES:
    BEGIN OF ty_row,
      row_no          TYPE i,
      pac_year        TYPE zde_pac_year,
      pac_cat         TYPE zde_pac_cat,
      pac_cat_desc    TYPE zde_pac_cat_desc,
      pac_subcat      TYPE zde_pac_subcat,
      pac_subcat_desc TYPE zde_pac_subcat_desc,
      status          TYPE zde_pac_status,
    END OF ty_row,
    tt_row TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY,

    BEGIN OF ty_log,
      row_no     TYPE i,
      msgty      TYPE symsgty,
      pac_cat    TYPE zde_pac_cat,
      pac_subcat TYPE zde_pac_subcat,
      msgno      TYPE symsgno,
      message    TYPE bapi_msg,
    END OF ty_log,
    tt_log TYPE STANDARD TABLE OF ty_log WITH DEFAULT KEY,

    BEGIN OF ty_stats,
      total_rows      TYPE i,
      cat_new         TYPE i,
      cat_existing    TYPE i,
      subcat_new      TYPE i,
      subcat_existing TYPE i,
      rows_with_error TYPE i,
      errors          TYPE i,
      warnings        TYPE i,
    END OF ty_stats,

    tt_cat    TYPE STANDARD TABLE OF zmm_pac_cat    WITH DEFAULT KEY,
    tt_subcat TYPE STANDARD TABLE OF zmm_pac_subcat WITH DEFAULT KEY.

ENDINTERFACE.
```

```abap
INTERFACE zif_mm_pac_repository PUBLIC.

  METHODS read_categories
    IMPORTING iv_year       TYPE zde_pac_year
    RETURNING VALUE(rt_cat) TYPE zif_mm_pac_types=>tt_cat.

  METHODS read_subcategories
    IMPORTING iv_year          TYPE zde_pac_year
    RETURNING VALUE(rt_subcat) TYPE zif_mm_pac_types=>tt_subcat.

  "! Bloqueio exclusivo de mandante+ano nas duas tabelas
  METHODS lock_year
    IMPORTING iv_year TYPE zde_pac_year
    RAISING   zcx_mm_pac.

  METHODS unlock_year
    IMPORTING iv_year TYPE zde_pac_year.

  "! INSERT em massa; não faz COMMIT
  METHODS insert_new
    IMPORTING it_cat    TYPE zif_mm_pac_types=>tt_cat
              it_subcat TYPE zif_mm_pac_types=>tt_subcat
    RAISING   zcx_mm_pac.

  METHODS commit.
  METHODS rollback.

ENDINTERFACE.
```

`commit`/`rollback` fazem parte do contrato de propósito: o duplo de teste conta as chamadas, o que torna REQ-10 ("sem COMMIT") verificável automaticamente.

```abap
CLASS zcl_mm_pac_validator DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    "! iv_today injectado para testar o intervalo de anos (REQ-03)
    METHODS constructor
      IMPORTING it_db_cat    TYPE zif_mm_pac_types=>tt_cat
                it_db_subcat TYPE zif_mm_pac_types=>tt_subcat
                io_log       TYPE REF TO zcl_mm_pac_log
                iv_today     TYPE d.
    "! Devolve apenas as linhas válidas e novas; o resto fica no log
    METHODS validate
      IMPORTING it_rows       TYPE zif_mm_pac_types=>tt_row
      RETURNING VALUE(rt_new) TYPE zif_mm_pac_types=>tt_row.
ENDCLASS.
```

### 6.3 Convenções de código

- Clean ABAP; métodos ≤ 50 linhas; sem variáveis globais fora do programa de UI.
- Prefixos: `iv_/it_/io_` importação, `rv_/rt_/ro_` retorno, `lv_/lt_/ls_/lo_` locais, `mv_/mt_/mo_` atributos.
- Mensagens sempre por `MESSAGE ID ... INTO` para o log — nunca texto literal.
- Sem `SELECT *`; sem Open SQL dentro de ciclos; sem `COMMIT` fora de `ZIF_MM_PAC_REPOSITORY~commit`.

### 6.4 Performance

- Uma leitura por tabela, filtrada por `PAC_YEAR` (prefixo da chave primária → acesso por índice).
- Estado da BD copiado para tabelas locais `SORTED` pela chave; pesquisas com expressões de tabela ou `READ TABLE ... BINARY SEARCH`.
- Detecção de duplicados no ficheiro: tabela `HASHED` por código de subcategoria com o primeiro número de linha.
- `INSERT ... FROM TABLE` uma vez por tabela.

```abap
METHOD zif_mm_pac_repository~read_subcategories.
  SELECT mandt, pac_year, pac_subcat, pac_cat, pac_subcat_desc, status
    FROM zmm_pac_subcat
    WHERE pac_year = @iv_year
    ORDER BY PRIMARY KEY
    INTO CORRESPONDING FIELDS OF TABLE @rt_subcat.
ENDMETHOD.
```

---

## 7. Fluxo de execução e LUW

### 7.1 Sequência

```text
 1. INITIALIZATION / AT SELECTION-SCREEN     Radio buttons, F4 do ficheiro
 2. START-OF-SELECTION
    2.1 sy-batch = X?                         → 052 e fim                     (REQ-17)
    2.2 Autorização: 03 (sim.) ou 01 (grav.)  → 050 e fim                     (REQ-15)
    2.3 Ler ficheiro (GUI_UPLOAD, 4110)       → 001/002/003 e fim             (REQ-02)
    2.4 Parser: cabeçalho, colunas, limites   → 004–008 e fim se estrutural   (REQ-02/03)
    2.5 Se Gravação: lock_year                → 051 e fim                     (REQ-13)
    2.6 Ler estado da BD do ano (depois do lock)
    2.7 Validator → linhas novas + log                                         (REQ-03..09)
    2.8 Estatísticas
    2.9 Simulação → ALV + 060 → fim, sem commit                                (REQ-10)
    2.10 Gravação com erros → ALV + 061 → unlock → fim                         (REQ-11)
    2.11 Gravação sem novidades → ALV + 065 → unlock → fim                     (REQ-12)
    2.12 ALV; ao sair, popup de confirmação   → "Não" → 064 → unlock → fim
    2.13 Changeset: auditoria (1 carimbo), validade                            (REQ-14)
    ─── início da zona sem diálogos ───────────────────────────────────────
    2.14 insert_new (categorias, depois subcategorias)
    2.15 Sucesso → commit          Falha (ZCX_MM_PAC) → rollback
    ─── fim da zona sem diálogos ──────────────────────────────────────────
    2.16 unlock_year (sempre, também em excepção — bloco CLEANUP/finalização)
    2.17 062 ou 063
```

### 7.2 Regras da unidade lógica de trabalho

1. **Zona sem diálogos (2.14–2.15).** Nenhum `CALL SCREEN`, popup, `CL_SALV_TABLE->display`, `MESSAGE` do tipo I/W/E/A, `CALL TRANSACTION`, RFC síncrono nem `WAIT` — todos provocam commit implícito da base de dados e anulam o rollback.
2. Categorias inseridas antes das subcategorias (coerência da FK).
3. `INSERT ... FROM TABLE` com chave duplicada dispara `CX_SY_OPEN_SQL_DB`; é capturada no repositório e convertida em `ZCX_MM_PAC` (`063`). Não se usa `ACCEPTING DUPLICATE KEYS` — um duplicado aqui é defeito, não caso normal.
4. `COMMIT WORK` (sem `AND WAIT`: não há update task).
5. Bloqueio com `_SCOPE = '1'` e libertação explícita, para não depender do commit implícito do popup (2.12).

```abap
METHOD zif_mm_pac_repository~insert_new.
  TRY.
      IF it_cat IS NOT INITIAL.
        INSERT zmm_pac_cat FROM TABLE @it_cat.
      ENDIF.
      IF it_subcat IS NOT INITIAL.
        INSERT zmm_pac_subcat FROM TABLE @it_subcat.
      ENDIF.
    CATCH cx_sy_open_sql_db INTO DATA(lx_db).
      RAISE EXCEPTION TYPE zcx_mm_pac
        EXPORTING textid   = zcx_mm_pac=>db_insert_failed
                  previous = lx_db.
  ENDTRY.
ENDMETHOD.
```

```abap
" ZCL_MM_PAC_UPLOAD — núcleo da gravação
TRY.
    mo_repository->insert_new( it_cat = lt_cat  it_subcat = lt_subcat ).
    mo_repository->commit( ).
    mo_log->add_message( iv_msgty = 'S' iv_msgno = '062' ... ).
  CATCH zcx_mm_pac INTO DATA(lx_pac).
    mo_repository->rollback( ).
    mo_log->add_exception( lx_pac ).
ENDTRY.
mo_repository->unlock_year( lv_year ).
```

**Tarefa de verificação:** confirmar em SM12 que `ENQUEUE_E_TABLE` com `VARKEY` = mandante + ano produz bloqueio genérico sobre todas as linhas do ano; se não, criar objecto de bloqueio `EZ_MM_PAC` no SAP (§11.6).

---

## 8. Mensagens, autorizações, ALV, transacções

### 8.1 Classe de mensagens `ZMM_PAC`

Textos com ≤ 73 caracteres; `&1`–`&4` substituídos em tempo de execução.

| Nº | Tipo | Texto | Requisito |
|---|---|---|---|
| `001` | E | Ficheiro não informado. | REQ-02 |
| `002` | E | Não foi possível ler o ficheiro &1. | REQ-02 |
| `003` | E | Formato &1 não suportado. Utilize um ficheiro .csv. | REQ-02 |
| `004` | E | Cabeçalho inválido: esperada a coluna &1 na posição &2. | REQ-02 |
| `005` | E | Número de colunas inválido: esperadas &1, encontradas &2. | REQ-02 |
| `006` | E | O ficheiro não contém linhas de dados. | REQ-02 |
| `007` | E | O ficheiro excede o limite de &1 linhas de dados. | REQ-02 |
| `008` | E | O ficheiro contém mais do que um ano PAC (&1 e &2). | REQ-03 |
| `010` | E | Ano PAC não informado. | REQ-03 |
| `011` | E | Ano PAC &1 inválido. Permitido de &2 a &3. | REQ-03 |
| `012` | E | Código Categoria PAC não informado. | REQ-04 |
| `013` | E | Descrição da Categoria PAC não informada. | REQ-04 |
| `014` | E | Código Subcategoria PAC não informado. | REQ-04 |
| `015` | E | Descrição da Subcategoria PAC não informada. | REQ-04 |
| `016` | E | Código de categoria &1 com formato inválido. | REQ-05 |
| `017` | E | Código de subcategoria &1 com formato inválido. | REQ-05 |
| `018` | E | A subcategoria &1 não pertence à categoria &2. | REQ-06 |
| `019` | E | Subcategoria &1 duplicada no ficheiro (ver linha &2). | REQ-07 |
| `020` | E | Status PAC &1 inválido. Valores permitidos: D, A, B, C, F. | REQ-08 |
| `021` | E | Categoria &1 com descrição diferente da linha &2. | REQ-07 |
| `022` | E | A descrição excede &1 caracteres. | REQ-05 |
| `023` | E | A subcategoria &1 já existe na categoria &2 no ano &3. | REQ-06 |
| `024` | W | Descrição começa por &1: risco de fórmula ao exportar para Excel. | Segurança |
| `030` | E | O registo PAC &1 está FECHADO e não pode ser alterado. | REQ-09 |
| `031` | E | Transição de status de &1 para &2 não permitida (&3). | REQ-08 |
| `032` | W | &1 já existe com dados diferentes; o upload não o altera. | REQ-09 |
| `033` | I | &1 já existe e é idêntico; será ignorado. | REQ-09, 12 |
| `034` | E | Categoria &1 com status &2 não aceita novas subcategorias. | REQ-09 |
| `035` | W | Categoria &1 está BLOQUEADA; a subcategoria &2 não será utilizável. | REQ-09 |
| `036` | S | Registo novo válido. | REQ-16 |
| `050` | E | Sem autorização (objecto ZMM_PAC, actividade &1). | REQ-15 |
| `051` | E | O PAC &1 está a ser gravado pelo utilizador &2. Tente mais tarde. | REQ-13 |
| `052` | E | O upload do PAC não pode ser executado em fundo. | REQ-17 |
| `060` | S | Simulação concluída. Nenhum dado foi gravado no SAP. | REQ-10 |
| `061` | E | Existem &1 erros de validação. O PAC não foi gravado. | REQ-11 |
| `062` | S | PAC &1 gravado: &2 categorias e &3 subcategorias criadas. | REQ-11 |
| `063` | E | Erro ao gravar na base de dados. Nenhuma alteração foi aplicada. | REQ-11 |
| `064` | S | Gravação cancelada pelo utilizador. Nenhum dado foi gravado. | REQ-11 |
| `065` | S | Nada a gravar: todos os registos do ficheiro já existem. | REQ-12 |
| `066` | I | Gravar &1 categorias e &2 subcategorias no PAC &3? | REQ-11 |
| `070` | E | A subcategoria PAC &1 está BLOQUEADA: não utilizável em novas PR. | Mudança 4 |
| `071` | E | A subcategoria PAC &1 (status &2) não pode ser usada em novas PR. | Mudança 4 |

### 8.2 Autorizações

Objecto `ZMM_PAC` (classe `MM_E`, a confirmar), campo `ACTVT`:

| ACTVT | Permite | Mudança |
|---|---|---|
| `03` | Simulação, consulta, relatório | 1, 2, 6 |
| `01` | Gravação do upload | 1 |
| `02` | Manutenção de descrições e status | 3 |

Verificação no programa, antes de qualquer leitura (a transacção sozinha não protege: SA38/SE38 contornam-na). Falha em fechado: qualquer `sy-subrc <> 0` nega.

```abap
METHOD check.   " ZCL_MM_PAC_AUTH
  AUTHORITY-CHECK OBJECT 'ZMM_PAC' ID 'ACTVT' FIELD iv_actvt.
  IF sy-subrc <> 0.
    RAISE EXCEPTION TYPE zcx_mm_pac
      EXPORTING textid = zcx_mm_pac=>no_authorization.
  ENDIF.
ENDMETHOD.
```

Perfis (D-09): Aprovisionamento-Consulta `03`; Aprovisionamento-Gestor `01`, `02`, `03`. A segregação entre quem carrega e quem fecha/bloqueia fica em aberto.

### 8.3 Ecrã de selecção e ALV

```abap
SELECTION-SCREEN BEGIN OF BLOCK b_file WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_file TYPE rlgrap-filename LOWER CASE.
SELECTION-SCREEN END OF BLOCK b_file.

SELECTION-SCREEN BEGIN OF BLOCK b_mode WITH FRAME TITLE TEXT-b02.
  PARAMETERS: p_sim RADIOBUTTON GROUP mode DEFAULT 'X',
              p_upd RADIOBUTTON GROUP mode.
SELECTION-SCREEN END OF BLOCK b_mode.

SELECTION-SCREEN BEGIN OF BLOCK b_out WITH FRAME TITLE TEXT-b03.
  PARAMETERS p_ewonly AS CHECKBOX DEFAULT 'X'.   " só erros e avisos
SELECTION-SCREEN END OF BLOCK b_out.
```

ALV `CL_SALV_TABLE` em ecrã completo: colunas Linha, Tipo (ícone), Categoria, Subcategoria, Nº, Mensagem; ordenação Linha ↑, Tipo (E, W, I, S); cabeçalho com as estatísticas (REQ-16) via `set_top_of_list`; funções standard activas (exportação incluída).

### 8.4 Transacções e menu

| Transacção | Programa | Tipo | Mudança |
|---|---|---|---|
| `ZMM_PAC` | `ZMM_PAC_MENU` | Report (ecrã 1000) | 1 |
| `ZMM_PAC_UPLOAD` | `ZMM_PAC_UPLOAD` | Report (ecrã 1000) | 1 |
| `ZMM_PAC_CONSULT` | `ZMM_PAC_CONSULT` | Report | 2 |
| `ZMM_PAC_CAT_MAINT` | a decidir (D-04) | — | 3 |
| `ZMM_PAC_SUBCAT_MAINT` | a decidir (D-04) | — | 3 |
| `ZMM_PAC_EXEC` | `ZMM_PAC_EXEC` | Report | 6 |

`ZMM_PAC_MENU` apresenta apenas as opções já entregues e chama-as com `CALL TRANSACTION ... WITH AUTHORITY-CHECK` (verificação de `S_TCODE`).

---

## 9. Decisões de arquitectura (ADR) e segurança

As ADRs completas ficam em `docs/adr/`. Resumo:

**ADR-01 — Upload só cria; nunca altera.**
Decisão: registos existentes são comparados e reportados, nunca actualizados.
Alternativa rejeitada: *upsert* com `MODIFY` — perde auditoria de criação, contorna o motivo obrigatório de mudança de status, e torna a regra de fecho dependente de comparação campo a campo.
Consequência: correcções de descrição e status passam pela manutenção (mudança 3).

**ADR-02 — Chave da subcategoria sem a categoria.**
Decisão: chave `MANDT+PAC_YEAR+PAC_SUBCAT`; `PAC_CAT` não-chave com FK.
Alternativas rejeitadas: chave da v1 + índice único secundário (mais um objecto, índice mais frágil de serializar no abapGit); chave da v1 com validação só em código (não protege contra inserções por outros canais).
Consequência: listar subcategorias de uma categoria usa campo não-chave — aceitável com o volume previsto; índice secundário só se medido necessário.

**ADR-03 — CSV UTF-8 com `;` na mudança 1.**
Decisão: `GUI_UPLOAD` com página de códigos 4110.
Alternativas rejeitadas: `ALSM_EXCEL_TO_INTERNAL_TABLE` (células truncadas a 50 caracteres, depende de Excel no PC, OLE lento); `TEXT_CONVERT_XLS_TO_SAP` (OLE, Windows); abap2xlsx (dependência de terceiros a manter no sistema). `CL_FDT_XL_SPREADSHEET` fica para avaliação (D-08).

**ADR-04 — Testabilidade por interface em 7.40.**
Decisão: acesso à BD atrás de `ZIF_MM_PAC_REPOSITORY`, duplos locais nas classes de teste, data de hoje injectada, e orquestrador dividido em `prepare`/`write`/`release` para que a confirmação fique fora da lógica testável.
Alternativa rejeitada: framework de duplos SQL (`CL_OSQL_TEST_ENVIRONMENT`, inexistente em 7.40); testes contra dados reais (não repetíveis, poluem QAS).

**ADR-05 — Menu por programa lançador.**
Decisão: transacções individuais + `ZMM_PAC_MENU`.
Alternativa rejeitada: *area menu* SE43 — objecto `SHI3` com identificadores gerados, frágil no abapGit, e não verifica autorização por opção.

### Análise de segurança — `add-pac-catalog-upload`

**Âmbito verificado:** autorização, validação de ficheiro de entrada, integridade e auditoria de dados, concorrência.
**Não aplicável:** autenticação (SAP GUI), dados pessoais além do nome de utilizador técnico, segredos, integrações externas, valores monetários (só na mudança 5).

| Tipo | Item | Tratamento |
|---|---|---|
| Bloqueador resolvido | Programa executável sem verificação interna de autorização | REQ-15, §8.2 |
| Bloqueador resolvido | Gravação parcial por commit implícito | §7.2 |
| Bloqueador resolvido | Perda da auditoria de criação | ADR-01 |
| Recomendação | Descrições iniciadas por `=`, `+`, `-`, `@` podem executar fórmulas quando o ALV é exportado para Excel/Power BI | Aviso `024` na mudança 1 |
| Recomendação | Registo de alterações de tabela depende do parâmetro `rec/client` em PRD | Confirmar com Basis (tarefa 0.4) |
| Risco a aceitar | SM30/programa de manutenção pode não respeitar o bloqueio por ano até à mudança 3 | Aceitar explicitamente na revisão |

---

# Parte C — Repositório e abapGit

## 10. Estrutura do repositório e mapeamento OpenSpec

### 10.1 Árvore

```text
ZMM_PAC/                                   ← raiz do repositório Git
├── .abapgit.xml                           ← configuração abapGit (raiz!)
├── .gitattributes                         ← força LF
├── CLAUDE.md                              ← instruções para Claude Code (§16)
├── README.md
├── docs/
│   ├── especificacao/ZMM_PAC_Especificacao_v2.md   ← este documento
│   ├── adr/0001-upload-so-cria.md … 0005-menu-lancador.md
│   └── modelo/PAC_upload_modelo.csv
├── openspec/
│   ├── project.md
│   ├── specs/plano-anual-compras/spec.md  ← verdade actual (após archive)
│   └── changes/add-pac-catalog-upload/
│       ├── proposal.md                    ← §0, §1
│       ├── specs/plano-anual-compras/spec.md  ← §2, §3 (ADDED Requirements)
│       ├── design.md                      ← §4–§9, §11
│       └── tasks.md                       ← §13
└── src/                                   ← STARTING_FOLDER — só objectos ABAP
    ├── package.devc.xml                   ← ZMM_PAC
    ├── data/                              ← ZMM_PAC_DATA
    ├── core/                              ← ZMM_PAC_CORE
    └── ui/                                ← ZMM_PAC_UI
```

Tudo fora de `/src/` é ignorado automaticamente pelo abapGit — não é preciso listá-lo em `IGNORE`.

### 10.2 Packages (FOLDER_LOGIC = PREFIX)

| Package | Pasta | Descrição | Conteúdo |
|---|---|---|---|
| `ZMM_PAC` | `/src/` | Plano Anual de Compras | só subpackages |
| `ZMM_PAC_DATA` | `/src/data/` | PAC — dicionário de dados | DOMA, DTEL, TABL, MSAG |
| `ZMM_PAC_CORE` | `/src/core/` | PAC — lógica de negócio | INTF, CLAS, SUSO |
| `ZMM_PAC_UI` | `/src/ui/` | PAC — programas e transacções | PROG, TRAN |

Com `PREFIX`, o nome de cada subpackage começa pelo do pai, permitindo instalar o repositório num package local `$ZMM_PAC` para testes sem ordem de transporte. Os packages `ZMM_PAC*` devem ser criados no DEV (SE21) com a camada de transporte correcta **antes** do primeiro pull; o abapGit cria os subpackages a partir das pastas.

### 10.3 Ciclo Git ↔ SAP

```text
Claude Code (local)                     SAP DEV (abapGit)
  escreve src/** + check  ──push──►  GitHub/GitLab ──pull──►  objectos activados
                                                              │
  ◄──pull── Git ◄──stage/commit (abapGit) ── objectos criados no SAP (§11.6)
```

Um ramo por mudança (`change/add-pac-catalog-upload`); commits `feat(pac): … [refs: add-pac-catalog-upload 2.3]`; o número da ordem de transporte é registado em `proposal.md`. O Git é a memória; o transporte DEV → QAS → PRD continua a ser o mecanismo de entrega.

---

## 11. Metafiles abapGit

### 11.1 Regras obrigatórias

- **UTF-8 com BOM, LF, quebra de linha final, indentação de 2 espaços** — sem isto, cada pull mostra todos os objectos como modificados.
- `.abapgit.xml` **sem** o elemento `<abapGit>`; todos os metafiles de objecto **com** ele (`version="v1.0.0"`).
- Nomes de ficheiro em minúsculas: `<objecto>.<tipo>.<ext>`; nomes dentro do XML em maiúsculas.
- Todos os ficheiros de um objecto na mesma pasta; nenhum ficheiro de parte vazia (`locals_def`, `locals_imp`, `testclasses` só se existirem).
- `LANGU` / `DDLANGUAGE` / `MASTERLANG` / `SPRSL` = `MASTER_LANGUAGE` (**`P` nos modelos abaixo — confirmar D-01 antes do primeiro pull; não é alterável depois**).
- Campos numéricos DDIC como strings com zeros à esquerda (`LENG` 6 dígitos, `MSGNR` 3 dígitos).
- Gerar com `abapgit_meta.py` sempre que o tipo for suportado; terminar com `python3 abapgit_meta.py check --root .` sem erros.

### 11.2 Inventário completo (mudança 1)

| Pasta | Ficheiro(s) | Objecto | Tipo | Origem | Nota |
|---|---|---|---|---|---|
| `/` | `.abapgit.xml` | `—` | config | G | Configuração do repositório |
| `/src/` | `package.devc.xml` | `ZMM_PAC` | DEVC | G | Package raiz |
| `/src/data/` | `package.devc.xml` | `ZMM_PAC_DATA` | DEVC | G | Dicionário de dados |
| `/src/data/` | `zdo_pac_cat.doma.xml` | `ZDO_PAC_CAT` | DOMA | G |  |
| `/src/data/` | `zdo_pac_subcat.doma.xml` | `ZDO_PAC_SUBCAT` | DOMA | G |  |
| `/src/data/` | `zdo_pac_desc.doma.xml` | `ZDO_PAC_DESC` | DOMA | G |  |
| `/src/data/` | `zdo_pac_status.doma.xml` | `ZDO_PAC_STATUS` | DOMA | G |  |
| `/src/data/` | `zde_pac_year.dtel.xml` | `ZDE_PAC_YEAR` | DTEL | G |  |
| `/src/data/` | `zde_pac_cat.dtel.xml` | `ZDE_PAC_CAT` | DTEL | G |  |
| `/src/data/` | `zde_pac_cat_desc.dtel.xml` | `ZDE_PAC_CAT_DESC` | DTEL | G |  |
| `/src/data/` | `zde_pac_subcat.dtel.xml` | `ZDE_PAC_SUBCAT` | DTEL | G |  |
| `/src/data/` | `zde_pac_subcat_desc.dtel.xml` | `ZDE_PAC_SUBCAT_DESC` | DTEL | G |  |
| `/src/data/` | `zde_pac_status.dtel.xml` | `ZDE_PAC_STATUS` | DTEL | G |  |
| `/src/data/` | `zde_pac_status_reason.dtel.xml` | `ZDE_PAC_STATUS_REASON` | DTEL | G |  |
| `/src/data/` | `zmm_pac_cat.tabl.xml` | `ZMM_PAC_CAT` | TABL | G |  |
| `/src/data/` | `zmm_pac_subcat.tabl.xml` | `ZMM_PAC_SUBCAT` | TABL | G → S | FK adicionada no SE11 e reserializada |
| `/src/data/` | `zmm_pac.msag.xml` | `ZMM_PAC` | MSAG | G | Todas as mensagens da §8.1 |
| `/src/core/` | `package.devc.xml` | `ZMM_PAC_CORE` | DEVC | G | Lógica de negócio |
| `/src/core/` | `zif_mm_pac_types.intf.xml · .intf.abap` | `ZIF_MM_PAC_TYPES` | INTF | G |  |
| `/src/core/` | `zif_mm_pac_repository.intf.xml · .intf.abap` | `ZIF_MM_PAC_REPOSITORY` | INTF | G |  |
| `/src/core/` | `zcl_mm_pac_repository.clas.xml · .clas.abap` | `ZCL_MM_PAC_REPOSITORY` | CLAS | G |  |
| `/src/core/` | `zcl_mm_pac_file.clas.xml · .clas.abap` | `ZCL_MM_PAC_FILE` | CLAS | G |  |
| `/src/core/` | `zcl_mm_pac_parser.clas.xml · .clas.abap · .clas.testclasses.abap` | `ZCL_MM_PAC_PARSER` | CLAS | G | Com testes ABAP Unit |
| `/src/core/` | `zcl_mm_pac_validator.clas.xml · .clas.abap · .clas.testclasses.abap` | `ZCL_MM_PAC_VALIDATOR` | CLAS | G | Com testes ABAP Unit |
| `/src/core/` | `zcl_mm_pac_changeset.clas.xml · .clas.abap · .clas.testclasses.abap` | `ZCL_MM_PAC_CHANGESET` | CLAS | G | Com testes ABAP Unit |
| `/src/core/` | `zcl_mm_pac_log.clas.xml · .clas.abap · .clas.testclasses.abap` | `ZCL_MM_PAC_LOG` | CLAS | G | Com testes ABAP Unit |
| `/src/core/` | `zcl_mm_pac_auth.clas.xml · .clas.abap` | `ZCL_MM_PAC_AUTH` | CLAS | G |  |
| `/src/core/` | `zcl_mm_pac_upload.clas.xml · .clas.abap · .clas.testclasses.abap` | `ZCL_MM_PAC_UPLOAD` | CLAS | G | Com testes ABAP Unit |
| `/src/core/` | `zcx_mm_pac.clas.xml · .clas.abap` | `ZCX_MM_PAC` | CLAS | S → G | Criada no SE24; depois editada no Git |
| `/src/core/` | `zmm_pac.suso.xml` | `ZMM_PAC` | SUSO | S | Objecto de autorização |
| `/src/ui/` | `package.devc.xml` | `ZMM_PAC_UI` | DEVC | G | Programas e transacções |
| `/src/ui/` | `zmm_pac_upload.prog.xml · .prog.abap` | `ZMM_PAC_UPLOAD` | PROG | G → S | Textos de selecção reserializados |
| `/src/ui/` | `zmm_pac_menu.prog.xml · .prog.abap` | `ZMM_PAC_MENU` | PROG | G → S | Lançador |
| `/src/ui/` | `zmm_pac_upload.tran.xml` | `ZMM_PAC_UPLOAD` | TRAN | S |  |
| `/src/ui/` | `zmm_pac.tran.xml` | `ZMM_PAC` | TRAN | S |  |

Legenda da coluna Origem: **G** = gerado por Claude Code e importado por pull; **S** = criado no SAP e serializado pelo abapGit (§11.6).

### 11.3 Configuração do repositório

`.abapgit.xml` (nome e versão do repositório definidos pela UI do abapGit, em *Repository Settings* — não à mão):

```xml
<?xml version="1.0" encoding="utf-8"?>
<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
 <asx:values>
  <DATA>
   <MASTER_LANGUAGE>P</MASTER_LANGUAGE>
   <STARTING_FOLDER>/src/</STARTING_FOLDER>
   <FOLDER_LOGIC>PREFIX</FOLDER_LOGIC>
  </DATA>
 </asx:values>
</asx:abap>
```

`.gitattributes`:

```text
* text=auto eol=lf
*.xml  text eol=lf
*.abap text eol=lf
*.md   text eol=lf
*.csv  text eol=lf
```

`src/package.devc.xml` (idem em `data/`, `core/`, `ui/` com a descrição da §10.2):

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_DEVC" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DEVC>
    <CTEXT>Plano Anual de Compras (PAC)</CTEXT>
   </DEVC>
  </asx:values>
 </asx:abap>
</abapGit>
```

### 11.4 Dicionário de dados

`src/data/zdo_pac_status.doma.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_DOMA" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DD01V>
    <DOMNAME>ZDO_PAC_STATUS</DOMNAME>
    <DDLANGUAGE>P</DDLANGUAGE>
    <DATATYPE>CHAR</DATATYPE>
    <LENG>000001</LENG>
    <OUTPUTLEN>000001</OUTPUTLEN>
    <VALEXI>X</VALEXI>
    <DDTEXT>Status do registo PAC</DDTEXT>
   </DD01V>
   <DD07V_TAB>
    <DD07V>
     <VALPOS>0001</VALPOS>
     <DDLANGUAGE>P</DDLANGUAGE>
     <DOMVALUE_L>D</DOMVALUE_L>
     <DDTEXT>Rascunho</DDTEXT>
    </DD07V>
    <DD07V>
     <VALPOS>0002</VALPOS>
     <DDLANGUAGE>P</DDLANGUAGE>
     <DOMVALUE_L>A</DOMVALUE_L>
     <DDTEXT>Activo</DDTEXT>
    </DD07V>
    <DD07V>
     <VALPOS>0003</VALPOS>
     <DDLANGUAGE>P</DDLANGUAGE>
     <DOMVALUE_L>B</DOMVALUE_L>
     <DDTEXT>Bloqueado</DDTEXT>
    </DD07V>
    <DD07V>
     <VALPOS>0004</VALPOS>
     <DDLANGUAGE>P</DDLANGUAGE>
     <DOMVALUE_L>C</DOMVALUE_L>
     <DDTEXT>Cancelado</DDTEXT>
    </DD07V>
    <DD07V>
     <VALPOS>0005</VALPOS>
     <DDLANGUAGE>P</DDLANGUAGE>
     <DOMVALUE_L>F</DOMVALUE_L>
     <DDTEXT>Fechado</DDTEXT>
    </DD07V>
   </DD07V_TAB>
  </asx:values>
 </asx:abap>
</abapGit>
```

`src/data/zdo_pac_desc.doma.xml` (domínio com minúsculas)

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_DOMA" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DD01V>
    <DOMNAME>ZDO_PAC_DESC</DOMNAME>
    <DDLANGUAGE>P</DDLANGUAGE>
    <DATATYPE>CHAR</DATATYPE>
    <LENG>000100</LENG>
    <OUTPUTLEN>000100</OUTPUTLEN>
    <LOWERCASE>X</LOWERCASE>
    <DDTEXT>Descrição PAC (100 caracteres)</DDTEXT>
   </DD01V>
  </asx:values>
 </asx:abap>
</abapGit>
```

`src/data/zdo_pac_cat.doma.xml` e `zdo_pac_subcat.doma.xml` seguem o mesmo molde com `CHAR` 10 e 12, sem `LOWERCASE`.

`src/data/zde_pac_subcat.dtel.xml` (os restantes seguem a tabela da §5.2)

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_DTEL" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DD04V>
    <ROLLNAME>ZDE_PAC_SUBCAT</ROLLNAME>
    <DDLANGUAGE>P</DDLANGUAGE>
    <DOMNAME>ZDO_PAC_SUBCAT</DOMNAME>
    <HEADLEN>15</HEADLEN>
    <SCRLEN1>10</SCRLEN1>
    <SCRLEN2>20</SCRLEN2>
    <SCRLEN3>40</SCRLEN3>
    <DDTEXT>Código da subcategoria PAC</DDTEXT>
    <REPTEXT>Subcategoria</REPTEXT>
    <SCRTEXT_S>Subcat.</SCRTEXT_S>
    <SCRTEXT_M>Subcategoria PAC</SCRTEXT_M>
    <SCRTEXT_L>Código da subcategoria PAC</SCRTEXT_L>
   </DD04V>
  </asx:values>
 </asx:abap>
</abapGit>
```

`src/data/zmm_pac_cat.tabl.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_TABL" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DD02V>
    <TABNAME>ZMM_PAC_CAT</TABNAME>
    <DDLANGUAGE>P</DDLANGUAGE>
    <TABCLASS>TRANSP</TABCLASS>
    <CLIDEP>X</CLIDEP>
    <DDTEXT>Plano Anual de Compras: categorias</DDTEXT>
    <MASTERLANG>P</MASTERLANG>
    <CONTFLAG>A</CONTFLAG>
    <EXCLASS>1</EXCLASS>
   </DD02V>
   <DD09L>
    <TABNAME>ZMM_PAC_CAT</TABNAME>
    <AS4LOCAL>A</AS4LOCAL>
    <TABKAT>0</TABKAT>
    <TABART>APPL0</TABART>
    <PROTOKOLL>X</PROTOKOLL>
    <BUFALLOW>N</BUFALLOW>
   </DD09L>
   <DD03P_TABLE>
    <DD03P>
     <FIELDNAME>MANDT</FIELDNAME>
     <KEYFLAG>X</KEYFLAG>
     <ROLLNAME>MANDT</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <NOTNULL>X</NOTNULL>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>PAC_YEAR</FIELDNAME>
     <KEYFLAG>X</KEYFLAG>
     <ROLLNAME>ZDE_PAC_YEAR</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <NOTNULL>X</NOTNULL>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>PAC_CAT</FIELDNAME>
     <KEYFLAG>X</KEYFLAG>
     <ROLLNAME>ZDE_PAC_CAT</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <NOTNULL>X</NOTNULL>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>PAC_CAT_DESC</FIELDNAME>
     <ROLLNAME>ZDE_PAC_CAT_DESC</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>STATUS</FIELDNAME>
     <ROLLNAME>ZDE_PAC_STATUS</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>STATUS_REASON</FIELDNAME>
     <ROLLNAME>ZDE_PAC_STATUS_REASON</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>VALID_FROM</FIELDNAME>
     <ROLLNAME>DATAB</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>VALID_TO</FIELDNAME>
     <ROLLNAME>DATBI</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>ERNAM</FIELDNAME>
     <ROLLNAME>ERNAM</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>ERDAT</FIELDNAME>
     <ROLLNAME>ERDAT</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>ERZET</FIELDNAME>
     <ROLLNAME>ERZET</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>AENAM</FIELDNAME>
     <ROLLNAME>AENAM</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>AEDAT</FIELDNAME>
     <ROLLNAME>AEDAT</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>AEZET</FIELDNAME>
     <ROLLNAME>AEZET</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
   </DD03P_TABLE>
  </asx:values>
 </asx:abap>
</abapGit>
```

`src/data/zmm_pac_subcat.tabl.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_TABL" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DD02V>
    <TABNAME>ZMM_PAC_SUBCAT</TABNAME>
    <DDLANGUAGE>P</DDLANGUAGE>
    <TABCLASS>TRANSP</TABCLASS>
    <CLIDEP>X</CLIDEP>
    <DDTEXT>Plano Anual de Compras: subcategorias</DDTEXT>
    <MASTERLANG>P</MASTERLANG>
    <CONTFLAG>A</CONTFLAG>
    <EXCLASS>1</EXCLASS>
   </DD02V>
   <DD09L>
    <TABNAME>ZMM_PAC_SUBCAT</TABNAME>
    <AS4LOCAL>A</AS4LOCAL>
    <TABKAT>0</TABKAT>
    <TABART>APPL0</TABART>
    <PROTOKOLL>X</PROTOKOLL>
    <BUFALLOW>N</BUFALLOW>
   </DD09L>
   <DD03P_TABLE>
    <DD03P>
     <FIELDNAME>MANDT</FIELDNAME>
     <KEYFLAG>X</KEYFLAG>
     <ROLLNAME>MANDT</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <NOTNULL>X</NOTNULL>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>PAC_YEAR</FIELDNAME>
     <KEYFLAG>X</KEYFLAG>
     <ROLLNAME>ZDE_PAC_YEAR</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <NOTNULL>X</NOTNULL>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>PAC_SUBCAT</FIELDNAME>
     <KEYFLAG>X</KEYFLAG>
     <ROLLNAME>ZDE_PAC_SUBCAT</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <NOTNULL>X</NOTNULL>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>PAC_CAT</FIELDNAME>
     <ROLLNAME>ZDE_PAC_CAT</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <NOTNULL>X</NOTNULL>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>PAC_SUBCAT_DESC</FIELDNAME>
     <ROLLNAME>ZDE_PAC_SUBCAT_DESC</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>STATUS</FIELDNAME>
     <ROLLNAME>ZDE_PAC_STATUS</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>STATUS_REASON</FIELDNAME>
     <ROLLNAME>ZDE_PAC_STATUS_REASON</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>VALID_FROM</FIELDNAME>
     <ROLLNAME>DATAB</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>VALID_TO</FIELDNAME>
     <ROLLNAME>DATBI</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>ERNAM</FIELDNAME>
     <ROLLNAME>ERNAM</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>ERDAT</FIELDNAME>
     <ROLLNAME>ERDAT</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>ERZET</FIELDNAME>
     <ROLLNAME>ERZET</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>AENAM</FIELDNAME>
     <ROLLNAME>AENAM</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>AEDAT</FIELDNAME>
     <ROLLNAME>AEDAT</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
    <DD03P>
     <FIELDNAME>AEZET</FIELDNAME>
     <ROLLNAME>AEZET</ROLLNAME>
     <ADMINFIELD>0</ADMINFIELD>
     <COMPTYPE>E</COMPTYPE>
    </DD03P>
   </DD03P_TABLE>
  </asx:values>
 </asx:abap>
</abapGit>
```

> A foreign key de `PAC_CAT` **não** vai no XML inicial: os nós `DD05M`/`DD08V` não são reconstruídos à mão. É criada no SE11 após o primeiro pull e serializada (§11.6). `PROTOKOLL = X` activa o registo de alterações.

`src/data/zmm_pac.msag.xml` (excerto — incluir todas as mensagens da §8.1, com `&` escapado como `&amp;`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_MSAG" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <T100A>
    <ARBGB>ZMM_PAC</ARBGB>
    <STEXT>Plano Anual de Compras (PAC)</STEXT>
    <MASTERLANG>P</MASTERLANG>
   </T100A>
   <T100_TABLE>
    <T100>
     <SPRSL>P</SPRSL>
     <ARBGB>ZMM_PAC</ARBGB>
     <MSGNR>018</MSGNR>
     <TEXT>A subcategoria &amp;1 não pertence à categoria &amp;2.</TEXT>
    </T100>
    <T100>
     <SPRSL>P</SPRSL>
     <ARBGB>ZMM_PAC</ARBGB>
     <MSGNR>030</MSGNR>
     <TEXT>O registo PAC &amp;1 está FECHADO e não pode ser alterado.</TEXT>
    </T100>
   </T100_TABLE>
  </asx:values>
 </asx:abap>
</abapGit>
```

### 11.5 Código

`src/core/zif_mm_pac_repository.intf.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_INTF" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <VSEOINTERF>
    <CLSNAME>ZIF_MM_PAC_REPOSITORY</CLSNAME>
    <LANGU>P</LANGU>
    <DESCRIPT>PAC: acesso a dados do catálogo</DESCRIPT>
    <EXPOSURE>2</EXPOSURE>
    <STATE>1</STATE>
    <UNICODE>X</UNICODE>
   </VSEOINTERF>
  </asx:values>
 </asx:abap>
</abapGit>
```

`src/core/zcl_mm_pac_validator.clas.xml` (todas as classes `ZCL_*` seguem este molde, mudando `CLSNAME` e `DESCRIPT`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_CLAS" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <VSEOCLASS>
    <CLSNAME>ZCL_MM_PAC_VALIDATOR</CLSNAME>
    <LANGU>P</LANGU>
    <DESCRIPT>PAC: validação do ficheiro de upload</DESCRIPT>
    <STATE>1</STATE>
    <CLSCCINCL>X</CLSCCINCL>
    <FIXPT>X</FIXPT>
    <UNICODE>X</UNICODE>
   </VSEOCLASS>
  </asx:values>
 </asx:abap>
</abapGit>
```

`src/ui/zmm_pac_upload.prog.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_PROG" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <PROGDIR>
    <NAME>ZMM_PAC_UPLOAD</NAME>
    <SUBC>1</SUBC>
    <FIXPT>X</FIXPT>
    <VARCL>X</VARCL>
    <RSTAT>K</RSTAT>
    <UCCHECK>X</UCCHECK>
   </PROGDIR>
   <TPOOL>
    <item>
     <ID>R</ID>
     <ENTRY>PAC: Upload do Plano Anual de Compras</ENTRY>
     <LENGTH>37</LENGTH>
    </item>
   </TPOOL>
  </asx:values>
 </asx:abap>
</abapGit>
```

> Os textos de selecção (`P_FILE`, `P_SIM`, `P_UPD`, `P_EWONLY`) e símbolos de texto (`B01`–`B03`) são definidos em SE38 após o pull e serializados — o formato das entradas `S`/`I` do `TPOOL` não se reconstrói com segurança à mão.

### 11.6 Objectos criados no SAP e serializados

Estes tipos não se geram à mão: dependem de estrutura interna ou de nós cuja forma varia. Criam-se uma vez no DEV, com o abapGit *stage → commit* para o ramo, e a partir daí são versionados normalmente.

| Objecto | Tipo abapGit | Onde criar | Especificação |
|---|---|---|---|
| `ZCX_MM_PAC` | CLAS (excepção) | SE24 | Superclasse `CX_STATIC_CHECK`, interface `IF_T100_MESSAGE`, textos `NO_AUTHORIZATION` (050), `YEAR_LOCKED` (051), `DB_INSERT_FAILED` (063). Depois de serializada, o `.clas.abap` passa a ser editado no Git. |
| FK `ZMM_PAC_SUBCAT-PAC_CAT` | TABL (reserializada) | SE11 | §5.3. Após criar, o `.tabl.xml` ganha os nós da FK — commit. |
| `ZMM_PAC` | SUSO | SU21 | Classe `MM_E` (D-09), campo `ACTVT`, actividades 01, 02, 03 |
| `ZMM_PAC_UPLOAD`, `ZMM_PAC` | TRAN | SE93 | Transacção de report → programa, ecrã 1000; GUI: SAP GUI Windows/Java/HTML |
| Textos de selecção | PROG (reserializado) | SE38 | §11.5 |
| `EZ_MM_PAC` (condicional) | ENQU | SE11 | Só se a verificação da §7.2 falhar; argumentos `MANDT`, `PAC_YEAR` |

**Ordem do primeiro pull:** o abapGit ordena a desserialização por tipo (DOMA → DTEL → TABL → MSAG → INTF → CLAS → PROG), por isso todos os objectos **G** podem ir no mesmo pull. `ZCX_MM_PAC` tem de existir antes de activar as classes que a usam: criá-la e serializá-la **antes** do pull das classes `core`.

---

# Parte D — Decisões, plano e verificação

## 12. Decisões pendentes

Nenhuma bloqueia a escrita da proposta; **D-01, D-02, D-03, D-06 e D-07 bloqueiam o `apply`.**

| ID | Decisão | Recomendação | Quem decide |
|---|---|---|---|
| D-01 | `MASTER_LANGUAGE` do repositório: `P` ou `E`? | `P` se o português estiver instalado no CBD (SMLT) e for a língua de logon dos utilizadores — textos de ecrã e mensagens nascem na língua em que são lidos. Coerência com outros repositórios Z da HCB (ex.: `E`) é argumento válido para `E`. **Irreversível no abapGit.** | Equipa SAP |
| D-02 | Coluna `STATUS` aplica-se à subcategoria; categoria nova nasce `A`? | Sim. Alternativa: 7.ª coluna `STATUS_CATEGORIA` (mais explícita, mais uma validação de consistência). | Aprovisionamento |
| D-03 | Matriz de transições do §2.3 | Aprovar ou ajustar (ex.: permitir `C → A`?) | Aprovisionamento |
| D-04 | Manutenção: SM30 (gerador de manutenção com eventos) ou programa próprio | SM30 + evento 01 a chamar o validador — menos código; gerado no SAP e serializado. Decidir na mudança 3. | Equipa SAP |
| D-05 | Upload só cria (ADR-01) | Confirmar que o negócio aceita corrigir descrições pela manutenção | Aprovisionamento |
| D-06 | Formato dos códigos (REQ-05) | Validar a regex contra o ficheiro real das 303 linhas | Aprovisionamento + SAP |
| D-07 | Intervalo de anos permitido | Ano corrente e seguinte | Aprovisionamento |
| D-08 | Suporte `.xlsx` | Verificar via MCP se `CL_FDT_XL_SPREADSHEET` existe no CBD; se sim, mudança própria | Equipa SAP |
| D-09 | Classe do objecto de autorização e segregação de funções (quem carrega vs. quem fecha) | Classe `MM_E`; perfis §8.2 | Segurança SAP |
| D-10 | Existe fecho do PAC ao nível do ano (todo o 2026 fechado)? A v1 sugere-o | Se sim, tabela de cabeçalho do ano numa mudança própria | Aprovisionamento |

---

## 13. Plano de tarefas (mudança 1)

Cada tarefa é marcada **depois** de o objecto activar e o teste passar. Referência de commit: `[refs: add-pac-catalog-upload <n.º>]`.

### 0. Preparação
- [ ] 0.1 Decisões D-01, D-02, D-03, D-06, D-07 registadas em `proposal.md`
- [ ] 0.2 Nível de SP do SAP_BASIS confirmado e registado no `CLAUDE.md`
- [ ] 0.3 Data elements standard da §5.2 confirmados via MCP
- [ ] 0.4 `rec/client` em QAS/PRD confirmado com Basis
- [ ] 0.5 Packages `ZMM_PAC`, `_DATA`, `_CORE`, `_UI` criados no DEV; repositório abapGit ligado
- [ ] 0.6 `.abapgit.xml`, `.gitattributes`, `package.devc.xml` gerados; `check` sem erros

### 1. Dicionário de dados
- [ ] 1.1 Domínios e data elements; pull e activação
- [ ] 1.2 Tabelas `ZMM_PAC_CAT` e `ZMM_PAC_SUBCAT`; pull e activação
- [ ] 1.3 FK criada em SE11 e `.tabl.xml` reserializado
- [ ] 1.4 Classe de mensagens `ZMM_PAC` completa

### 2. Núcleo
- [ ] 2.1 `ZCX_MM_PAC` criada no SAP e serializada
- [ ] 2.2 `ZIF_MM_PAC_TYPES` e `ZIF_MM_PAC_REPOSITORY`
- [ ] 2.3 `ZCL_MM_PAC_PARSER` + testes (REQ-02, REQ-05 normalização)
- [ ] 2.4 `ZCL_MM_PAC_LOG` + testes (REQ-16)
- [ ] 2.5 `ZCL_MM_PAC_VALIDATOR` + testes (REQ-03 a REQ-09)
- [ ] 2.6 `ZCL_MM_PAC_CHANGESET` + testes (REQ-14)
- [ ] 2.7 `ZCL_MM_PAC_REPOSITORY`; bloqueio verificado em SM12 (§7.2)
- [ ] 2.8 `ZCL_MM_PAC_AUTH` e objecto `ZMM_PAC` (SU21) serializado
- [ ] 2.9 `ZCL_MM_PAC_UPLOAD` + testes com duplos (REQ-10, 11, 12, 13, 15)

### 3. Interface
- [ ] 3.1 `ZMM_PAC_UPLOAD` com ecrã, ALV e confirmação; textos serializados (REQ-01, 16, 17)
- [ ] 3.2 `ZMM_PAC_MENU`; transacções `ZMM_PAC` e `ZMM_PAC_UPLOAD` serializadas

### 4. Verificação
- [ ] 4.1 Todos os testes ABAP Unit verdes (SE80/`ABAP Unit Runner`)
- [ ] 4.2 ATC/Code Inspector sem findings de prioridade 1 e 2
- [ ] 4.3 Testes manuais em QAS da §14.3 executados e evidenciados
- [ ] 4.4 REQ-18 medido em QAS com ficheiro de 10 000 linhas
- [ ] 4.5 `abapgit_meta.py check` sem erros; pull limpo (sem diffs fantasma) no DEV

---

## 14. Estratégia de testes

### 14.1 ABAP Unit — mapeamento cenário → teste

Classes de teste `FOR TESTING RISK LEVEL HARMLESS DURATION SHORT`, em `<classe>.clas.testclasses.abap`. Duplo `ltd_repository` implementa `ZIF_MM_PAC_REPOSITORY` em memória e conta chamadas a `insert_new`, `commit`, `rollback`.

| Requisito / cenário | Classe sob teste | Método de teste |
|---|---|---|
| REQ-02 sem linhas de dados | PARSER | `header_only_is_rejected` |
| REQ-02 cabeçalho inválido | PARSER | `wrong_header_reports_column` |
| REQ-02 colunas erradas | PARSER | `wrong_column_count_is_error` |
| REQ-02 BOM / acentos | PARSER | `utf8_bom_is_stripped` |
| REQ-02 limite | PARSER | `more_than_max_rows_rejected` |
| REQ-03 dois anos / intervalo / não numérico | VALIDATOR | `mixed_years_rejected`, `year_out_of_range`, `year_not_numeric` |
| REQ-04 múltiplos obrigatórios | VALIDATOR | `all_missing_fields_reported` |
| REQ-05 normalização / formato / comprimento | PARSER, VALIDATOR | `codes_are_normalized`, `invalid_subcat_format`, `description_too_long` |
| REQ-06 prefixo / outra categoria na BD | VALIDATOR | `subcat_prefix_mismatch`, `subcat_exists_in_other_cat` |
| REQ-07 duplicados / descrição divergente | VALIDATOR | `duplicate_subcat_in_file`, `cat_desc_divergent_in_file` |
| REQ-08 status inválido / B na criação | VALIDATOR | `invalid_status`, `new_record_blocked_rejected` |
| REQ-09 tabela de existentes (5 casos) | VALIDATOR | `existing_identical_info`, `existing_diff_warning`, `existing_closed_error`, `new_subcat_in_blocked_cat`, `new_subcat_in_closed_cat` |
| REQ-10 simulação | UPLOAD | `simulation_never_commits` (insert 0, commit 0) |
| REQ-11 erros / cancelar / falha BD | UPLOAD | `errors_prevent_write`, `release_without_write_inserts_nothing`, `db_failure_rolls_back` |
| REQ-12 idempotência | UPLOAD | `same_file_twice_inserts_nothing` |
| REQ-13 bloqueio | UPLOAD | `foreign_lock_stops_processing` |
| REQ-14 carimbo único e validade | CHANGESET | `single_timestamp_for_all_rows`, `validity_derived_from_year` |
| REQ-15 autorização | UPLOAD (duplo de auth) | `write_requires_actvt_01` |
| REQ-16 estatísticas | LOG | `statistics_count_distinct_codes` |

### 14.2 Dados de teste

Ficheiros em `docs/testes/` (fora de `/src/`), mapeados em `docs/testes/README.md`: `valido_303.csv` (subconjunto só PAC, limpo), `so_cabecalho.csv`, `cabecalho_errado.csv`, `colunas_erradas.csv`, `dois_anos.csv`, `relacao_invalida.csv`, `duplicados.csv`, `formato_invalido.csv`, `ansi_1252.csv`, `10001_linhas.csv`. **`status_invalido.csv` foi removido:** com a D-02 o ficheiro deixou de ter coluna de status, pelo que não há status a validar no upload (REQ-08).

### 14.3 Testes manuais em QAS

| # | Teste | Evidência |
|---|---|---|
| M1 | Simulação com `valido_303.csv`: contagem SE16N antes = depois | Capturas SE16N + ALV |
| M2 | Gravação com sucesso; `ERNAM/ERDAT/ERZET` preenchidos; SCU3 regista inserções | SE16N, SCU3 |
| M3 | Segunda gravação do mesmo ficheiro → `065` | Captura |
| M4 | Dois utilizadores a gravar 2026 em simultâneo → `051` | Capturas + SM12 |
| M5 | Utilizador só com `03` grava pela SA38 → `050` | Captura + SU53 |
| M6 | Job em fundo → `052` | SM37 log |
| M7 | Ficheiro de 10 000 linhas: tempo de simulação | STAD / tempo medido |

---

## 15. Definition of Done

- [ ] Todos os REQ-01 a REQ-17 com teste verde; REQ-18 medido
- [ ] Tarefas do §13 marcadas depois de feitas
- [ ] ATC sem findings P1/P2 novos; sem `SELECT *`, sem SQL em ciclos, sem `COMMIT` fora do repositório
- [ ] Nenhuma funcionalidade fora de âmbito (§1.3) implementada
- [ ] Artefactos OpenSpec actualizados se o design mudou durante a implementação
- [ ] `abapgit_meta.py check` sem erros; pull no DEV sem diffs fantasma
- [ ] Ordem de transporte registada em `proposal.md`; dependências de transporte verificadas
- [ ] Verificado em QAS com a §14.3
- [ ] Plano de rollback: tabelas com dados de aplicação — eliminação dos registos do ano por programa de apoio autorizado, se necessário; objectos revertidos por transporte
- [ ] `openspec archive add-pac-catalog-upload --yes` só depois de aceite em PRD

---

## 16. Instruções para Claude Code

Excerto a incluir no `CLAUDE.md` do repositório:

```markdown
# ZMM_PAC — regras para Claude Code

## Contexto
- SAP ECC 6.0 EHP7, SAP_BASIS 7.40 SP<confirmar>. Sintaxe até SP05, salvo indicação.
- MCP ligado ao SAP é SÓ LEITURA. Entrega exclusivamente por abapGit pull.
- Especificação: docs/especificacao/ZMM_PAC_Especificacao_v2.md
- Mudança activa: openspec/changes/<nome>/ — ler proposal, spec, design e tasks antes de escrever código.

## Obrigatório
- Não implementar sem o plano aprovado. Não acrescentar funcionalidade fora da spec.
- Todo o objecto ABAP em /src/ tem metafile, gerado com abapgit_meta.py quando suportado.
- UTF-8 com BOM, LF, 2 espaços. Correr `python3 abapgit_meta.py check --root .` antes de cada commit.
- MASTER_LANGUAGE = <D-01>. Nunca alterar.
- NÃO gerar à mão: TRAN, SUSO, AUTH, ENQU, FUGR, TOBJ, classes ZCX_*, FKs e índices de tabelas,
  textos de selecção. Pedir ao utilizador para os criar no SAP e serializar.
- Antes de usar data element/classe standard, confirmar existência via MCP.
- Mensagens só pela classe ZMM_PAC. Sem textos literais para o utilizador.
- Sem COMMIT fora de ZIF_MM_PAC_REPOSITORY~commit. Nenhum diálogo entre INSERT e COMMIT.
- Cada cenário Given/When/Then tem teste ABAP Unit antes de marcar a tarefa.
```

---

## 17. Evolução futura

```text
PAC (ano)
 ├── Categoria
 │     └── Subcategoria ─────────────┐
 │           └── Item PAC (mud. 5)   │ classificação (mud. 4)
 │                                   ▼
 ├── PR ──► PO ──► GR ──► Factura ──► Pagamento
 │
 └── Execução PAC (mud. 6)
       ├── Planeado      (Item PAC)
       ├── Comprometido  (PR/PO abertas)
       ├── Executado     (GR/Factura/Pagamento — definição a acordar com Finanças)
       └── Saldo e % de execução por categoria, subcategoria, centro e centro de custo
```

A ligação a Power BI deve consumir uma vista/extractor estável sobre as tabelas PAC e a execução, e não as tabelas directamente — decisão a tomar na mudança 6. Em S/4HANA, a verificação em PR (mudança 4) deve ser reavaliada para as apps Fiori de requisição, que não passam pelos mesmos pontos de extensão do ECC.

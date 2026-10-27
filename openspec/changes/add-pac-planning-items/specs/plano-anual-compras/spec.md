# plano-anual-compras — itens de planeamento (mudança 5)

## ADDED Requirements

### Requirement: REQ-20 — Upload de itens com dois modos
O sistema DEVE (MUST) carregar os itens de planeamento a partir de um ficheiro do posto
de trabalho em exactamente um de dois modos: **Simulação** (por omissão, sem qualquer
efeito na base de dados) e **Gravação** (atómica, após confirmação explícita). O sistema
NÃO DEVE (MUST NOT) gravar quando existem erros de validação, nem gravar parcialmente.

#### Scenario: simulação não grava
- GIVEN um ficheiro de itens válido e o modo Simulação
- WHEN o upload é executado
- THEN nenhum registo é inserido em `ZMM_PAC_ITEM` e é apresentada a mensagem de simulação concluída

#### Scenario: gravação atómica após confirmação
- GIVEN um ficheiro de itens válido e o modo Gravação
- WHEN o utilizador confirma a gravação
- THEN todos os itens novos são inseridos numa única LUW com um único `COMMIT WORK`

### Requirement: REQ-21 — Estrutura do ficheiro de itens
O sistema DEVE (MUST) aceitar um ficheiro CSV (cp1252, separador `;`, uma linha física por
registo) com o cabeçalho e as colunas, por esta ordem:
`ANO;COD_SUBCATEGORIA;DESCRICAO;QUANTIDADE;UNIDADE;VALOR;MOEDA;CENTRO;CONTA_RAZAO`.
O sistema DEVE (MUST) rejeitar cabeçalho inválido, número de colunas diferente de 9,
ficheiro sem linhas de dados e ficheiro com mais de 10 000 linhas de dados.

#### Scenario: cabeçalho inválido
- GIVEN um ficheiro cujo cabeçalho não corresponde às 9 colunas esperadas
- WHEN o upload é executado
- THEN é registado o erro de cabeçalho e a gravação fica impedida

### Requirement: REQ-22 — Ano único e no intervalo permitido
O sistema DEVE (MUST) aceitar um único ano PAC por ficheiro, dentro do intervalo do ano
corrente a corrente + 1 (D-07). O `PAC_ITEM` **não** vem no ficheiro.

#### Scenario: mais do que um ano no ficheiro
- GIVEN linhas com anos diferentes no mesmo ficheiro
- WHEN o upload é executado
- THEN é registado erro de ano múltiplo e a gravação fica impedida

### Requirement: REQ-23 — Campos obrigatórios do item
O sistema DEVE (MUST) exigir, por linha, **todas as colunas**: `COD_SUBCATEGORIA`,
`DESCRICAO`, `QUANTIDADE`, `UNIDADE`, `VALOR`, `MOEDA`, `CENTRO` e `CONTA_RAZAO` (D5-08
tornou `CENTRO`/`CONTA_RAZAO` obrigatórios). Qualquer campo em falta é erro de linha e
impede a gravação.

#### Scenario: valor em falta
- GIVEN uma linha sem `VALOR`
- WHEN o upload é executado
- THEN é registado erro de campo obrigatório para essa linha

#### Scenario: centro em falta
- GIVEN uma linha sem `CENTRO`
- WHEN o upload é executado
- THEN é registado erro de campo obrigatório (`092`) e a gravação fica impedida

### Requirement: REQ-24 — A subcategoria tem de existir e ser utilizável no catálogo do ano
O sistema DEVE (MUST) rejeitar um item cuja `COD_SUBCATEGORIA` não exista em
`ZMM_PAC_SUBCATG` para o ano, ou cuja categoria-mãe (derivada da subcategoria) esteja
inactiva. A `PAC_CAT` do item é derivada da subcategoria do catálogo (não vem no ficheiro).

#### Scenario: subcategoria inexistente
- GIVEN um item com uma subcategoria que não existe no catálogo do ano
- WHEN o upload é executado
- THEN é registado erro de subcategoria inexistente e a gravação fica impedida

#### Scenario: categoria-mãe inactiva
- GIVEN um item cuja categoria (derivada da subcategoria) está inactiva no ano
- WHEN o upload é executado
- THEN é registado erro e o item não é criado

### Requirement: REQ-25 — Validação de quantidade, valor e dados-mestre
O sistema DEVE (MUST) rejeitar `QUANTIDADE` ou `VALOR` não numéricos ou negativos, e, de
forma **bloqueante** (D5-08), DEVE (MUST) rejeitar valores de dados-mestre inexistentes:
`MOEDA` em TCURC (`090`), `UNIDADE` em T006 após conversão externa→interna (`091`),
`CENTRO` em T001W (`093`) e `CONTA_RAZAO` em `SKB1` para a empresa `P_BUKRS` (`095`,
semântica da ajuda de pesquisa `C_SAKNR`). Isto evita também dump na gravação dos campos
`CURR`/`QUAN`.

#### Scenario: moeda inválida
- GIVEN um item com `MOEDA` inexistente em TCURC
- WHEN o upload é executado
- THEN é registado erro de moeda inválida e a gravação fica impedida

#### Scenario: conta-razão inexistente na empresa
- GIVEN um item com `CONTA_RAZAO` que não existe em `SKB1` para `P_BUKRS`
- WHEN o upload é executado
- THEN é registado erro de conta inexistente (`095`) e a gravação fica impedida

### Requirement: REQ-26 — Criação de itens numerados, auditados e em rascunho
O sistema DEVE (MUST) criar cada linha válida como um **item novo** com `PAC_ITEM` obtido
de um objecto de intervalo de números, status inicial **`D` (Rascunho)**, e um único
carimbo `ERNAM/ERDAT/ERZET` por execução (`AE*` vazios). Cada linha é um item distinto; o
sistema NÃO DEVE (MUST NOT) tratar linhas repetidas como erro. O upload **só cria** (`INSERT`),
nunca altera itens existentes.

#### Scenario: numeração e status na criação
- GIVEN duas linhas válidas para a mesma subcategoria
- WHEN a gravação é executada
- THEN são criados dois itens com `PAC_ITEM` distintos, ambos com status `D` e o mesmo `ERDAT/ERZET`

### Requirement: REQ-27 — Autorização e execução interactiva
O sistema DEVE (MUST) verificar a autorização (objecto `ZMM_PAC`, `ACTVT 03` para simular,
`01` para gravar) **antes de ler o ficheiro**, e DEVE (MUST) recusar a execução em fundo.

#### Scenario: sem autorização de gravação
- GIVEN um utilizador sem `ACTVT 01` no modo Gravação
- WHEN o upload é executado
- THEN é registado erro de autorização e o ficheiro não chega a ser gravado

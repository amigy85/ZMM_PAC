# Spec Delta

## Purpose

O catálogo do Plano Anual de Compras (PAC) organiza categorias e subcategorias de
compra por ano civil, e o seu carregamento por ficheiro permite simular, validar e
gravar o catálogo de um ano de forma atómica, autorizada, auditada e repetível.

## ADDED Requirements

### Requirement: REQ-01 — Modo de execução
O sistema DEVE (MUST) executar o upload em exactamente um de dois modos, Simulação
ou Gravação, sendo Simulação o modo proposto por omissão.

#### Scenario: modo por omissão
- **GIVEN** o utilizador abre o upload do PAC
- **WHEN** o ecrã de selecção é apresentado
- **THEN** o modo Simulação está seleccionado
- **AND** não é possível seleccionar os dois modos em simultâneo

### Requirement: REQ-02 — Leitura e estrutura do ficheiro
O sistema DEVE (MUST) rejeitar o ficheiro inteiro, sem validar linhas, quando a sua
estrutura não corresponder ao layout oficial de 5 colunas CSV separadas por `;`
(`ANO; COD_CATEGORIA; DESC_CATEGORIA; COD_SUBCATEGORIA; DESC_SUBCATEGORIA`; sem coluna
de status — D-02), em UTF-8 ou Windows-1252, com uma linha física por registo (D-06).

#### Scenario: ficheiro sem linhas de dados
- **GIVEN** um ficheiro apenas com o cabeçalho
- **WHEN** o upload é executado em qualquer modo
- **THEN** é apresentada a mensagem `ZMM_PAC/006` e nada é processado

#### Scenario: cabeçalho inválido
- **GIVEN** um ficheiro cuja 4.ª coluna do cabeçalho é `SUBCAT`
- **WHEN** o upload é executado
- **THEN** é apresentada a mensagem `ZMM_PAC/004` indicando a coluna esperada `COD_SUBCATEGORIA` e a posição 4

#### Scenario: número de colunas errado numa linha
- **GIVEN** a linha 12 com 7 campos
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/005` para a linha 12 e a gravação fica impedida

#### Scenario: acentos preservados
- **GIVEN** um ficheiro UTF-8 (com ou sem BOM) com a descrição "Equipamento de Proteção Individual"
- **WHEN** o upload é executado em simulação
- **THEN** a descrição é apresentada no ALV exactamente com os mesmos caracteres

#### Scenario: acentos preservados num ficheiro cp1252
- **GIVEN** um ficheiro Windows-1252 (ANSI, como exportado pelo Excel) com a descrição "Equipamento de Proteção Individual"
- **WHEN** o upload é executado em simulação
- **THEN** a descrição é apresentada no ALV exactamente com os mesmos caracteres

#### Scenario: limite de volume
- **GIVEN** um ficheiro com 10 001 linhas de dados
- **WHEN** o upload é executado
- **THEN** é apresentada a mensagem `ZMM_PAC/007` e nada é processado

### Requirement: REQ-03 — Ano único e válido
O sistema DEVE (MUST) exigir que todas as linhas do ficheiro tenham o mesmo ano, e
que esse ano esteja no intervalo permitido (ano corrente a ano corrente + 1, D-07).

#### Scenario: dois anos no ficheiro
- **GIVEN** linhas com ano 2026 e linhas com ano 2027
- **WHEN** o upload é executado
- **THEN** é apresentada a mensagem `ZMM_PAC/008` e nada é processado

#### Scenario: ano fora do intervalo
- **GIVEN** a data do sistema em 2026 e um ficheiro com ano 2024
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/011` com o intervalo permitido 2026–2027

#### Scenario: ano não numérico
- **GIVEN** a linha 3 com ano `20X6`
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/011` para a linha 3

### Requirement: REQ-04 — Campos obrigatórios
O sistema DEVE (MUST) registar um erro por cada campo obrigatório vazio, reportando
todos os erros de uma linha e não apenas o primeiro.

#### Scenario: categoria e descrição vazias na mesma linha
- **GIVEN** a linha 9 com código e descrição de categoria vazios
- **WHEN** o upload é executado
- **THEN** são registados, para a linha 9, os erros `ZMM_PAC/012` e `ZMM_PAC/013`
- **AND** as validações dependentes do código de categoria (formato, pertença) não são executadas para essa linha

### Requirement: REQ-05 — Formato e comprimento
O sistema DEVE (MUST) normalizar os códigos (remover espaços nas extremidades,
converter para maiúsculas) e rejeitar códigos fora do formato oficial e descrições
com mais de 100 caracteres, sem truncar. O formato oficial (D-06, validado contra o
ficheiro real — âmbito só família PAC) é: categoria `^PAC-[A-Z][0-9]{3}$`;
subcategoria `^PAC-[A-Z][0-9]{3}\.[1-9][0-9]{0,2}$`. Códigos de outras famílias
(STK, CTR, FOR, GRA, PLA) estão fora de âmbito da mudança 1 e são erro de formato.

#### Scenario: código em minúsculas
- **GIVEN** a linha 4 com categoria ` pac-g155 `
- **WHEN** o upload é executado
- **THEN** a categoria é tratada como `PAC-G155` sem erro

#### Scenario: formato inválido
- **GIVEN** a linha 5 com subcategoria `PAC-G155-3`
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/017`

#### Scenario: família fora de âmbito
- **GIVEN** a linha 6 com categoria `STK-E001`
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/016` (formato de categoria inválido) e a gravação fica impedida

#### Scenario: descrição longa
- **GIVEN** uma descrição de subcategoria com 101 caracteres
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/022` e a descrição não é truncada

### Requirement: REQ-06 — Pertença da subcategoria à categoria
O sistema DEVE (MUST) rejeitar uma subcategoria cujo código não comece pelo código
da categoria da mesma linha seguido de `.`, ou que já exista na base de dados sob
outra categoria do mesmo ano.

#### Scenario: prefixo divergente
- **GIVEN** a linha 27 com categoria `PAC-G155` e subcategoria `PAC-E065.1`
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/018`: "A subcategoria PAC-E065.1 não pertence à categoria PAC-G155."

#### Scenario: subcategoria existente noutra categoria
- **GIVEN** a subcategoria `PAC-G155.3` gravada em 2026 sob `PAC-G155`
- **AND** um ficheiro de 2026 com `PAC-G155.3` sob outra categoria
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/023`

### Requirement: REQ-07 — Consistência interna do ficheiro
O sistema DEVE (MUST) rejeitar subcategorias repetidas no ficheiro e categorias
repetidas com descrições diferentes.

#### Scenario: subcategoria duplicada
- **GIVEN** as linhas 20 e 87 com `PAC-G155 / PAC-G155.3`
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/019` na linha 87 referindo a linha 20

#### Scenario: categoria repetida com descrição divergente
- **GIVEN** a linha 30 com `PAC-G139 / Material de Informática` e a linha 31 com `PAC-G139 / Material Informático`
- **WHEN** o upload é executado
- **THEN** é registado erro `ZMM_PAC/021` na linha 31

#### Scenario: categoria repetida com a mesma descrição
- **GIVEN** 7 linhas com `PAC-G139` e descrição idêntica
- **WHEN** o upload é executado
- **THEN** não é registado erro e a categoria é contada uma única vez nas estatísticas

### Requirement: REQ-08 — Status na criação
O sistema DEVE (MUST) criar toda a categoria nova com status `A` (Activa) e DEVE (MUST)
criar as subcategorias sem status (o status aplica-se só à categoria — D-02). O
ficheiro não traz coluna de status: não há status a ler nem a validar no upload. A
inactivação de uma categoria (`A → I`) é manutenção (mudança 3), fora do âmbito aqui.

#### Scenario: categoria nova nasce activa
- **GIVEN** um ficheiro válido com categorias novas
- **WHEN** o upload é executado em Gravação e confirmado
- **THEN** cada categoria criada fica com status `A`

#### Scenario: subcategoria criada sem status
- **GIVEN** uma subcategoria nova no ficheiro
- **WHEN** o upload é executado
- **THEN** a subcategoria é criada sem campo de status

### Requirement: REQ-09 — Registos já existentes
O upload NÃO DEVE (MUST NOT) alterar categorias ou subcategorias já existentes; as
diferenças entre o ficheiro e a base de dados DEVEM (MUST) ser reportadas, mantendo
sempre o valor gravado: `I/033` existente idêntico, `W/032` categoria com descrição
divergente, `W/035` subcategoria com descrição divergente, `E/034` subcategoria nova
numa categoria inactiva.

#### Scenario: categoria existente com descrição divergente
- **GIVEN** a categoria `PAC-G139` de 2026 já gravada com outra descrição
- **WHEN** o upload é executado
- **THEN** é registado aviso `ZMM_PAC/032` e a descrição gravada mantém-se

#### Scenario: subcategoria existente com descrição divergente
- **GIVEN** a subcategoria `PAC-G155.3` de 2026 já gravada com outra descrição
- **WHEN** o upload é executado
- **THEN** é registado aviso `ZMM_PAC/035` e a descrição gravada mantém-se

#### Scenario: subcategoria nova numa categoria inactiva
- **GIVEN** uma categoria existente de 2026 com status `I` (Inactiva)
- **WHEN** o ficheiro traz uma subcategoria nova para essa categoria
- **THEN** é registado erro `ZMM_PAC/034` e a gravação fica impedida

#### Scenario: registo existente idêntico
- **GIVEN** uma categoria e uma subcategoria já gravadas, idênticas às do ficheiro
- **WHEN** o upload é executado
- **THEN** são classificadas como existentes idênticas e reportadas com `ZMM_PAC/033`

### Requirement: REQ-10 — Simulação sem efeitos
A simulação NÃO DEVE (MUST NOT) inserir, alterar ou eliminar registos, nem confirmar
qualquer unidade lógica de trabalho.

#### Scenario: simulação sem erros
- **GIVEN** um ficheiro válido com 303 linhas
- **WHEN** o upload é executado em Simulação
- **THEN** as estatísticas e o ALV são apresentados
- **AND** é apresentada a mensagem `ZMM_PAC/060`
- **AND** o número de registos das tabelas PAC mantém-se
- **AND** não é executado `COMMIT WORK`

### Requirement: REQ-11 — Gravação atómica
O sistema DEVE (MUST) gravar apenas quando não existirem erros, depois de confirmação
explícita do utilizador, e DEVE (MUST) gravar todos os registos novos ou nenhum.

#### Scenario: gravação com sucesso
- **GIVEN** um ficheiro válido, sem erros, com categorias e subcategorias novas
- **WHEN** o upload é executado em Gravação e o utilizador confirma
- **THEN** todos os registos novos são criados numa única unidade lógica de trabalho
- **AND** é apresentada a mensagem `ZMM_PAC/062` com o número de categorias e subcategorias criadas

#### Scenario: existem erros
- **GIVEN** um ficheiro com pelo menos um erro
- **WHEN** o upload é executado em Gravação
- **THEN** não é pedida confirmação, não é gravado nenhum registo e é apresentada a mensagem `ZMM_PAC/061`

#### Scenario: utilizador cancela
- **GIVEN** um ficheiro válido em Gravação
- **WHEN** o utilizador responde "Não" à confirmação
- **THEN** nada é gravado e é apresentada a mensagem `ZMM_PAC/064`

#### Scenario: falha da base de dados a meio
- **GIVEN** a inserção de categorias concluída e uma falha na inserção de subcategorias
- **WHEN** a falha ocorre
- **THEN** a unidade de trabalho é revertida, nenhuma categoria fica gravada, e é apresentada a mensagem `ZMM_PAC/063`

### Requirement: REQ-12 — Idempotência
Reexecutar a gravação com um ficheiro já gravado NÃO DEVE (MUST NOT) criar, alterar
nem duplicar registos.

#### Scenario: mesmo ficheiro duas vezes
- **GIVEN** um ficheiro gravado com sucesso
- **WHEN** o mesmo ficheiro é gravado novamente
- **THEN** todas as linhas são classificadas como existentes e idênticas
- **AND** é apresentada a mensagem `ZMM_PAC/065` sem pedir confirmação

### Requirement: REQ-13 — Exclusão mútua por ano
O sistema DEVE (MUST) impedir que duas gravações do mesmo ano decorram em simultâneo,
obtendo o bloqueio antes de ler o estado actual da base de dados.

#### Scenario: ano bloqueado por outro utilizador
- **GIVEN** o utilizador `JSILVA` em gravação do PAC 2026
- **WHEN** outro utilizador inicia gravação do PAC 2026
- **THEN** é apresentada a mensagem `ZMM_PAC/051` com o nome `JSILVA` e nada é processado

#### Scenario: simulação não bloqueia
- **GIVEN** o utilizador `JSILVA` em gravação do PAC 2026
- **WHEN** outro utilizador executa simulação do PAC 2026
- **THEN** a simulação é executada normalmente

### Requirement: REQ-14 — Dados de auditoria e validade
Em cada registo criado, o sistema DEVE (MUST) preencher utilizador, data e hora de
criação com o executor e um único instante por execução, deixar os campos de
alteração vazios, e derivar a validade do ano (`01.01.AAAA` a `31.12.AAAA`).

#### Scenario: carimbo único
- **GIVEN** uma gravação de 303 subcategorias que atravessa a mudança de minuto
- **WHEN** a gravação termina
- **THEN** todos os registos criados têm o mesmo `ERDAT` e `ERZET`

### Requirement: REQ-15 — Autorização
O sistema DEVE (MUST) exigir autorização de visualização para simular e autorização
de criação para gravar, verificadas dentro do programa e antes de ler o ficheiro.

#### Scenario: utilizador só com consulta tenta gravar
- **GIVEN** um utilizador com `ACTVT 03` e sem `ACTVT 01`
- **WHEN** executa o upload em Gravação (pela transacção ou pela SA38)
- **THEN** é apresentada a mensagem `ZMM_PAC/050` e o ficheiro não é lido

### Requirement: REQ-16 — Resultado apresentado
O sistema DEVE (MUST) apresentar estatísticas calculadas a partir dos dados e uma
lista com linha, tipo, categoria, subcategoria e mensagem; por omissão a lista mostra
apenas erros e avisos.

#### Scenario: estatísticas coerentes
- **GIVEN** um ficheiro de 303 linhas com 215 categorias distintas, todas novas, e 0 erros
- **WHEN** o upload é executado em Simulação
- **THEN** as estatísticas mostram 303 linhas, 215 categorias novas, 303 subcategorias novas, 0 erros

### Requirement: REQ-17 — Execução em fundo
O sistema NÃO DEVE (MUST NOT) executar o upload em fundo, porque o ficheiro é lido do
posto de trabalho.

#### Scenario: job agendado
- **GIVEN** o programa agendado como job
- **WHEN** o job executa
- **THEN** termina com a mensagem `ZMM_PAC/052` sem processar

### Requirement: REQ-18 — Desempenho
O sistema DEVE (MUST) concluir a simulação de um ficheiro de 10 000 linhas em menos
de 60 segundos em QAS (objectivo de desempenho verificado por medição, não por teste
ABAP Unit).

#### Scenario: simulação de ficheiro grande
- **GIVEN** um ficheiro de 10 000 linhas de dados em QAS
- **WHEN** o upload é executado em Simulação
- **THEN** a simulação conclui em menos de 60 segundos

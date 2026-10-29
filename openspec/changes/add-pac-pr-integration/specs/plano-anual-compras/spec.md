# plano-anual-compras (delta — mudança 4)

## ADDED Requirements

### Requirement: REQ-30 — Validação bloqueante da atribuição PAC na Requisição de Compra
O sistema DEVE (MUST) validar a atribuição PAC de cada item **não eliminado** da RC na
gravação (método `CHECK` da BAdI `ME_PROCESS_REQ_CUST`) e, havendo qualquer incoerência,
DEVE (MUST) **impedir a gravação** com mensagem de erro da classe `ZMM_PAC` (via
`mmpur_message`). A validação NÃO DEVE (MUST NOT) alterar dados nem gravar.

#### Scenario: item PAC inexistente bloqueia a gravação
- GIVEN um item de RC com `PAC_YEAR`/`PAC_SUBCAT`/`PAC_ITEM` que não existe em `ZMM_PAC_ITEM`
- WHEN a RC é gravada
- THEN é registada mensagem de erro e a gravação é impedida

#### Scenario: atribuição coerente não bloqueia
- GIVEN um item de RC cuja atribuição PAC existe, é coerente e está activa
- WHEN a RC é gravada
- THEN a validação não produz erro e a gravação prossegue

### Requirement: REQ-31 — Coerência de ano, categoria e subcategoria
O sistema DEVE (MUST) exigir que o item PAC atribuído exista para o par `PAC_YEAR` +
`PAC_SUBCAT` indicado, e que a `PAC_CAT` do item (derivada do catálogo) seja coerente com a
subcategoria. A categoria-mãe DEVE (MUST) estar **activa** (`STATUS = 'A'`) no ano.

#### Scenario: subcategoria trocada
- GIVEN um item de RC cujo `PAC_ITEM` pertence a outra subcategoria/ano
- WHEN a RC é gravada
- THEN é registado erro de incoerência e a gravação é impedida

#### Scenario: categoria-mãe inactiva
- GIVEN um item de RC cuja categoria PAC está inactiva no ano
- WHEN a RC é gravada
- THEN é registado erro e a gravação é impedida

### Requirement: REQ-32 — Estado do item utilizável
O sistema DEVE (MUST) aceitar na RC apenas itens PAC no estado **`A` (Activo)**. Itens em
`D` (Rascunho), `B` (Bloqueado), `C` (Cancelado) ou `F` (Fechado) NÃO DEVEM (MUST NOT) ser
atribuíveis e a gravação DEVE (MUST) ser impedida.

#### Scenario: item em rascunho recusado
- GIVEN um item de RC cujo item PAC está em estado `D`
- WHEN a RC é gravada
- THEN é registado erro de estado não utilizável e a gravação é impedida

### Requirement: REQ-33 — Obrigatoriedade condicional da atribuição
O sistema DEVE (MUST) exigir atribuição PAC (ano/categoria/subcategoria/item) nos itens de RC
**não eliminados** que cumpram a condição definida (proposta: categoria de imputação
`KNTTP = 'K'`). Nos restantes itens a atribuição é opcional; quando presente, é sempre
validada pelos REQ-30..REQ-32.

#### Scenario: item obrigatório sem atribuição
- GIVEN um item de RC que cumpre a condição de obrigatoriedade e não tem item PAC
- WHEN a RC é gravada
- THEN é registado erro de atribuição em falta e a gravação é impedida

#### Scenario: item opcional sem atribuição
- GIVEN um item de RC fora da condição e sem atribuição PAC
- WHEN a RC é gravada
- THEN não é produzido erro de atribuição PAC

### Requirement: REQ-34 — Mensagens pela classe ZMM_PAC
O sistema DEVE (MUST) emitir todos os textos de validação PAC da RC através da classe de
mensagens `ZMM_PAC` (sem texto literal). Os `MESSAGE` com texto literal existentes na subtela
0111 DEVEM (MUST) ser substituídos por mensagens da classe `ZMM_PAC`.

#### Scenario: sem texto literal
- GIVEN qualquer validação PAC na RC ou na subtela 0111
- WHEN uma mensagem é emitida ao utilizador
- THEN o texto provém da classe de mensagens `ZMM_PAC`

### Requirement: REQ-35 — Preservação do comportamento existente
O sistema NÃO DEVE (MUST NOT) alterar o modelo de persistência (campos `PAC_*` na `EBAN`),
o transporte de dados da subtela (`EXIT_SAPLMEREQ_001`/`003`), o popup de selecção de itens
(`REUSE_ALV_POPUP_TO_SELECT`), nem a validação legada não-PAC (`AFNAM`/`BEDNR` em
`EXIT_SAPLMEREQ_005`).

#### Scenario: legado intacto
- GIVEN uma RC sem relação com o PAC
- WHEN a RC é gravada
- THEN o comportamento existente (incl. validações legadas) mantém-se inalterado

# Análise brownfield — mudança 4 (integração PAC ↔ Requisição de Compra)

Levantamento do que **já existe** no sistema (enhancement `MEREQ001`, grupo de funções
`XM02`) para a integração entre o Plano Anual de Compras e a Requisição de Compra (RC/Banf),
e do que falta para a formalizar como mudança 4. Fonte: inspecção por MCP (só leitura),
2026-10-29. Esta análise **não é código**; alimenta a futura proposta OpenSpec.

## 1. Modelo de persistência (já existe)

O vínculo RC↔PAC é guardado **na própria RC**, em campos *append* da `EBAN`
(include de cliente `CI_EBANDB`), reutilizando os data elements da nossa solução:

| Campo `EBAN` | Data element | Significado |
|---|---|---|
| `PAC_YEAR` | `ZMM_PAC_YEAR` | Ano do plano |
| `PAC_CAT` | `ZMM_PAC_CAT` | Categoria PAC |
| `PAC_SUBCAT` | `ZMM_PAC_SUBCAT` | Subcategoria PAC |
| `PAC_ITEM` | `ZMM_E_PAC_ITEM` | Item do plano atribuído |

Não há tabela Z de ligação: a atribuição viaja no item da RC (`MEREQ_ITEM`) e é gravada com a
RC pelo standard. Isto também significa que o consumo (RC→PO→GR→factura) pode ser seguido a
partir da `EBAN` por estes campos — base para o relatório da mudança 6.

## 2. Lógica já implementada (enhancement `MEREQ001`, FG `XM02`)

Subtela de cliente **0111** em `SAPLXM02`; código de cliente no include `ZXM02ZZZ`:

- **`LCL_PAC`** (`zxm02f01`):
  - `texto_categoria` / `texto_subcategoria` — `SELECT SINGLE` em `ZMM_PAC_CATG`/`SUBCATG` com buffer `HASHED` (guarda mesmo inexistentes);
  - `selecionar_item` — popup `REUSE_ALV_POPUP_TO_SELECT` com os `ZMM_PAC_ITEM` do ano+subcategoria; devolve o escolhido.
- **PBO 0111** (`zxm02o01`): preenche descrições; mostra `PAC_ITEM` com `ALPHA = OUT`; activa o botão `ASSIG_PAC` só com subcategoria preenchida e fora do modo exibição (`gv_aktyp <> 'A'`).
- **PAI 0111** (`zxm02i01`): F4 de categoria (filtra `STATUS='A'` + ano corrente), F4 de subcategoria, validações de existência (`s001`/`s002` de `ZMM_PAC`), e `ZPAC_ITEM` → `selecionar_item`.
- **Function exits** (includes de cliente):
  - `EXIT_SAPLMEREQ_001` / `ZXM02U01` — **RC → subtela**: lê `MEREQ_ITEM`, copia `PAC_*` para os campos de ecrã; se houver `PAC_ITEM`, `SELECT SINGLE` do `ZMM_PAC_ITEM`.
  - `EXIT_SAPLMEREQ_003` / `ZXM02U03` — **subtela → RC**: deteta mudança de subcategoria/ano (limpa o item), escreve `PAC_*` de volta via `im_req_item->set_data( )`, marca `ex_changed`.
  - `EXIT_SAPLMEREQ_002` / `_004` — vazios.
  - `EXIT_SAPLMEREQ_005` / `ZXM02U05` — **legado não-PAC**: validação de `AFNAM` (vs `ZREQ`) e `BEDNR` (vs `ZACOMP`), mensagens `e001`/`e019` da classe `ZMM` (autor Suely Pereira, 2013). **Não mexer.**

### BAdI `ME_PROCESS_REQ_CUST` — `ZCL_IM_ME_PROCESS_REQ_CUST` (mecanismo moderno, já activo no `ZMM`)

Implementa `IF_EX_ME_PROCESS_REQ_CUST`. Métodos relevantes já implementados:
- **`CHECK`** — validações de item que **bloqueiam a gravação** (knttp/pstyp/werks, centro de
  custo `ZRQCCUSTO`, requisitante `ZREQ`, grupo de mercadorias, RC-vs-PO em ME22N). Lança erros
  via a macro `mmpur_message` (`INCLUDE mm_messages_mac`) contra a classe `ZMM`. Percorre
  `im_header->get_items( )` → `ref->get_data( )` (`MEREQ_ITEM` com os campos `PAC_*`).
- `PROCESS_ITEM` — defaults (`werks='MPM'`, `lgort='GM'`), ordem de investimento (`knttp='A'`).
- `POST` — email HTML em ME51N; `OPEN` — `ZPR_OPEN` (tab de cabeçalho); restantes vazios.

**Decisão de arquitectura (confirmada com o utilizador):** a validação PAC na gravação da RC
fica no método **`CHECK` desta BAdI**, não no `EXIT_SAPLMEREQ_005`. A subtela 0111 (UI +
transporte `001`/`003`) mantém-se no `XM02`. Mensagens pela classe `ZMM_PAC` via `mmpur_message`.

## 3. Lacunas face às regras da solução (a resolver na mudança 4)

1. **Sem validação na gravação da RC.** Nenhum dos exits/BAdI valida hoje o PAC. É possível
   gravar uma RC com `PAC_ITEM` inexistente, de ano errado, subcategoria trocada ou de
   categoria inactiva. A mudança 4 deve validar no **método `CHECK` da BAdI
   `ME_PROCESS_REQ_CUST` (`ZCL_IM_ME_PROCESS_REQ_CUST`)** — ver §2:
   - o item existe em `ZMM_PAC_ITEM` para `PAC_YEAR + PAC_SUBCAT + PAC_ITEM`;
   - a subcategoria/categoria batem certo com o item e a categoria está activa;
   - **estado do item** utilizável (ver ponto 3) — bloquear itens em `D` (Rascunho)/`B`/`C`/`F`.
2. **Gating por estado do item (D/A/B/C/F).** Só itens **`A` (Activo)** deverão ser
   atribuíveis a uma RC. Liga-se à mudança 3 (manutenção de estado). Decisão a tomar.
3. **Clean ABAP / regras internas.** O protótipo usa `REUSE_ALV_POPUP_TO_SELECT` e `MESSAGE`
   com **texto literal** ("Indique primeiro a subcategoria…"), contra as regras da solução
   (só `CL_SALV*`, textos só pela classe de mensagens). Decidir: **manter** o exit produtivo
   como está (pragmático) ou **refactorizar** para as regras (popup via `CL_SALV_TABLE`,
   mensagens `ZMM_PAC`). Recomenda-se refactor mínimo das mensagens; o popup pode ficar.
4. **Consumo vs plano.** Definir se a mudança 4 só *regista/valida* a atribuição ou também
   *verifica disponibilidade* (ex.: somatório de RCs/POs por item vs valor planeado) — isto
   pode pertencer à mudança 6 (relatório). Delimitar.

## 4. Decisões a tomar antes da proposta (candidatas a D4-xx)

| ID | Questão |
|---|---|
| D4-00 | Mecanismo: validação no método `CHECK` da BAdI `ME_PROCESS_REQ_CUST` (`ZCL_IM_ME_PROCESS_REQ_CUST`), não no `EXIT_SAPLMEREQ_005`. **Decidida (2026-10-29)**. |
| D4-01 | Validação na gravação da RC: **bloquear (erro)** via `mmpur_message`. **Decidida (2026-10-29)**. |
| D4-02 | Estado mínimo do item: **só `A` (Activo)**. Recusa D/B/C/F. **Decidida (2026-10-29)**. |
| D4-03 | Protótipo: **refactor só das mensagens** (MESSAGE literais → classe `ZMM_PAC`); manter o popup `REUSE_ALV`. **Decidida (2026-10-29)**. |
| D4-04 | Âmbito: **só atribuição + validação**; consumo vs plano fica na mud. 6. **Decidida (2026-10-29)**. |
| D4-05 | Atribuição **obrigatória por condição** (ex. por `knttp`/categoria de imputação). **Condição a definir** na proposta. |
| D4-06 | Autorização: reutilizar objecto `ZMM_PAC` (`ACTVT 03` para atribuir?) ou nova. Em aberto. |

## 5. Âmbito proposto (rascunho)

- **Dentro:** validação bloqueante da atribuição PAC na RC (existência, coerência
  ano/categoria/subcategoria, estado do item); mensagens pela classe `ZMM_PAC`; alinhamento
  mínimo do exit às regras; testes (ABAP Unit do validador de atribuição + manuais ME51N/ME52N).
- **Fora:** relatório de execução/consumo (mudança 6); manutenção de estado do item
  (mudança 3); alteração do modelo de persistência (os campos `EBAN` ficam).

## 6. Objectos envolvidos (referência)

- Enhancement `MEREQ001`, FG `XM02` (`SAPLXM02`), subtela `0111`.
- Includes de cliente: `ZXM02ZZZ`, `ZXM02F01` (`LCL_PAC`), `ZXM02O01` (PBO), `ZXM02I01`
  (PAI), `ZXM02U01` (RC→subtela), `ZXM02U03` (subtela→RC), `ZXM02U05` (legado não-PAC).
- `EBAN` (append `CI_EBANDB`: `PAC_YEAR/PAC_CAT/PAC_SUBCAT/PAC_ITEM`), `ZMM_PAC_ITEM`,
  `ZMM_PAC_CATG`, `ZMM_PAC_SUBCATG`.
- Legado não-PAC a não tocar: `ZREQ`, `ZACOMP`, mensagens `ZMM e001/e019`.

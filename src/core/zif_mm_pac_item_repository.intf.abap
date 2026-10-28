INTERFACE zif_mm_pac_item_repository
  PUBLIC .

  "! Lê as categorias do ano (para validar o estado da categoria-mãe).
  METHODS read_categories
    IMPORTING iv_year       TYPE zmm_pac_year
    RETURNING VALUE(rt_cat) TYPE zif_mm_pac_types=>tt_catg.

  "! Lê as subcategorias do ano (para validar a pertença do item).
  METHODS read_subcategories
    IMPORTING iv_year          TYPE zmm_pac_year
    RETURNING VALUE(rt_subcat) TYPE zif_mm_pac_types=>tt_subcatg.

  "! Bloqueio exclusivo por mandante+ano (modo Gravação). Falha -> ZCX_MM_PAC (051).
  METHODS lock_year
    IMPORTING iv_year TYPE zmm_pac_year
    RAISING   zcx_mm_pac.

  "! Liberta o bloqueio do ano. Deve ser sempre chamado, também em excepção.
  METHODS unlock_year
    IMPORTING iv_year TYPE zmm_pac_year.

  "! Obtém o próximo número de item do intervalo de números ZMM_PAC.
  "! Chamado na zona de escrita, um por item. Falha -> ZCX_MM_PAC.
  METHODS next_item_number
    RETURNING VALUE(rv_item) TYPE zmm_e_pac_item
    RAISING   zcx_mm_pac.

  "! Insere os itens (já numerados). NÃO faz COMMIT. Falha de BD -> ZCX_MM_PAC (063).
  METHODS insert_new
    IMPORTING it_item TYPE zif_mm_pac_types=>tt_item
    RAISING   zcx_mm_pac.

  "! Dados-mestre para validação (D5-08). Cada conjunto lido uma vez para HASHED.
  "! Moedas existentes (TCURC).
  METHODS read_currencies
    RETURNING VALUE(rt_waers) TYPE zif_mm_pac_types=>tt_waers.

  "! Centros/fábricas existentes (T001W).
  METHODS read_plants
    RETURNING VALUE(rt_werks) TYPE zif_mm_pac_types=>tt_werks.

  "! Contas-razão criadas na empresa (SKB1), semântica da ajuda de pesquisa C_SAKNR.
  METHODS read_gl_accounts
    IMPORTING iv_bukrs        TYPE bukrs
    RETURNING VALUE(rt_saknr) TYPE zif_mm_pac_types=>tt_saknr.

  "! Converte uma unidade externa na interna (CONVERSION_EXIT_CUNIT_INPUT). Devolve
  "! vazio se não existir no sistema (T006) — o validador trata como erro 091.
  METHODS normalize_uom
    IMPORTING iv_external        TYPE clike
    RETURNING VALUE(rv_internal) TYPE meins.

  "! Único ponto de COMMIT WORK (sem AND WAIT).
  METHODS commit.

  "! ROLLBACK WORK.
  METHODS rollback.

ENDINTERFACE.

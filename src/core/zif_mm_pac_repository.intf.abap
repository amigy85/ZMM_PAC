INTERFACE zif_mm_pac_repository
  PUBLIC .

  "! Lê as categorias existentes de um ano (uma leitura filtrada por PAC_YEAR).
  METHODS read_categories
    IMPORTING iv_year       TYPE zmm_pac_year
    RETURNING VALUE(rt_cat) TYPE zif_mm_pac_types=>tt_catg.

  "! Lê as subcategorias existentes de um ano.
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

  "! Insere apenas registos novos. NÃO faz COMMIT (ver commit/rollback).
  "! Categorias antes das subcategorias. Falha de BD -> ZCX_MM_PAC (063).
  METHODS insert_new
    IMPORTING it_cat    TYPE zif_mm_pac_types=>tt_catg
              it_subcat TYPE zif_mm_pac_types=>tt_subcatg
    RAISING   zcx_mm_pac.

  "! Único ponto de COMMIT WORK (sem AND WAIT) da solução.
  METHODS commit.

  "! ROLLBACK WORK.
  METHODS rollback.

ENDINTERFACE.

INTERFACE zif_mm_pac_req_reader
  PUBLIC .

  "! Lê um item do PAC pela chave ano+subcategoria+item (leitura pontual; a
  "! implementação guarda em buffer, inclusive os não encontrados).
  METHODS read_item
    IMPORTING iv_year   TYPE zmm_pac_year
              iv_subcat TYPE zmm_pac_subcat
              iv_item   TYPE zmm_e_pac_item
    EXPORTING es_item   TYPE zmm_pac_item
              ev_found  TYPE abap_bool.

  "! Lê o estado da categoria pela chave ano+categoria.
  METHODS read_category
    IMPORTING iv_year   TYPE zmm_pac_year
              iv_cat    TYPE zmm_pac_cat
    EXPORTING ev_status TYPE zmm_pac_status
              ev_found  TYPE abap_bool.

ENDINTERFACE.

CLASS zcl_mm_pac_req_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_mm_pac_req_reader .

  PRIVATE SECTION.
    "! Buffer de itens já lidos (guarda também os não encontrados, para não repetir o SELECT).
    TYPES: BEGIN OF ty_item_buf,
             year   TYPE zmm_pac_year,
             subcat TYPE zmm_pac_subcat,
             item   TYPE zmm_e_pac_item,
             found  TYPE abap_bool,
             data   TYPE zmm_pac_item,
           END OF ty_item_buf,
           BEGIN OF ty_cat_buf,
             year   TYPE zmm_pac_year,
             cat    TYPE zmm_pac_cat,
             found  TYPE abap_bool,
             status TYPE zmm_pac_status,
           END OF ty_cat_buf.

    DATA: mt_item TYPE HASHED TABLE OF ty_item_buf WITH UNIQUE KEY year subcat item,
          mt_cat  TYPE HASHED TABLE OF ty_cat_buf  WITH UNIQUE KEY year cat.
ENDCLASS.



CLASS zcl_mm_pac_req_reader IMPLEMENTATION.

  METHOD zif_mm_pac_req_reader~read_item.
    READ TABLE mt_item INTO DATA(ls_buf)
         WITH TABLE KEY year = iv_year subcat = iv_subcat item = iv_item.
    IF sy-subrc <> 0.
      CLEAR ls_buf.
      ls_buf-year = iv_year. ls_buf-subcat = iv_subcat. ls_buf-item = iv_item.
      SELECT SINGLE * FROM zmm_pac_item INTO @ls_buf-data
        WHERE pac_year   = @iv_year
          AND pac_subcat = @iv_subcat
          AND pac_item   = @iv_item.
      ls_buf-found = xsdbool( sy-subrc = 0 ).
      INSERT ls_buf INTO TABLE mt_item.
    ENDIF.
    es_item  = ls_buf-data.
    ev_found = ls_buf-found.
  ENDMETHOD.


  METHOD zif_mm_pac_req_reader~read_category.
    READ TABLE mt_cat INTO DATA(ls_buf)
         WITH TABLE KEY year = iv_year cat = iv_cat.
    IF sy-subrc <> 0.
      CLEAR ls_buf.
      ls_buf-year = iv_year. ls_buf-cat = iv_cat.
      SELECT SINGLE status FROM zmm_pac_catg INTO @ls_buf-status
        WHERE pac_year = @iv_year
          AND pac_cat  = @iv_cat.
      ls_buf-found = xsdbool( sy-subrc = 0 ).
      INSERT ls_buf INTO TABLE mt_cat.
    ENDIF.
    ev_status = ls_buf-status.
    ev_found  = ls_buf-found.
  ENDMETHOD.

ENDCLASS.

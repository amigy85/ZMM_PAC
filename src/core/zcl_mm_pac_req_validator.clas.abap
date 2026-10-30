CLASS zcl_mm_pac_req_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    "! Veredicto de um item da RC: ok, ou nº de mensagem ZMM_PAC + variáveis a preencher.
    TYPES: BEGIN OF ty_verdict,
             ok    TYPE abap_bool,
             msgno TYPE symsgno,
             msgv1 TYPE symsgv,
             msgv2 TYPE symsgv,
             msgv3 TYPE symsgv,
           END OF ty_verdict.

    METHODS constructor
      IMPORTING io_reader TYPE REF TO zif_mm_pac_req_reader.

    "! Valida a atribuição PAC de um item da RC (REQ-30..REQ-33). iv_mandatory já traduz a
    "! condição do cabeçalho (ZMANB ∈ {CP,CL,AD,DF}), resolvida pelo chamador (CHECK).
    METHODS validate_item
      IMPORTING iv_year      TYPE zmm_pac_year
                iv_cat       TYPE zmm_pac_cat
                iv_subcat    TYPE zmm_pac_subcat
                iv_item      TYPE zmm_e_pac_item
                iv_mandatory TYPE abap_bool
      RETURNING VALUE(rs)    TYPE ty_verdict.

  PRIVATE SECTION.
    CONSTANTS c_active TYPE c LENGTH 1 VALUE 'A'.
    DATA mo_reader TYPE REF TO zif_mm_pac_req_reader.
ENDCLASS.



CLASS zcl_mm_pac_req_validator IMPLEMENTATION.

  METHOD constructor.
    mo_reader = io_reader.
  ENDMETHOD.


  METHOD validate_item.
    rs-ok = abap_true.

    " Sem item PAC atribuído: só é erro quando obrigatório (REQ-33)
    IF iv_item IS INITIAL.
      IF iv_mandatory = abap_true.
        rs = VALUE #( ok = abap_false msgno = '104' ).
      ENDIF.
      RETURN.
    ENDIF.

    " Existência do item (REQ-30)
    mo_reader->read_item( EXPORTING iv_year   = iv_year
                                    iv_subcat = iv_subcat
                                    iv_item   = iv_item
                          IMPORTING es_item   = DATA(ls_item)
                                    ev_found  = DATA(lv_found) ).
    IF lv_found = abap_false.
      rs = VALUE #( ok = abap_false msgno = '100'
                    msgv1 = |{ iv_item ALPHA = OUT }| msgv2 = iv_year msgv3 = iv_subcat ).
      RETURN.
    ENDIF.

    " Coerência de categoria (REQ-31)
    IF iv_cat IS NOT INITIAL AND ls_item-pac_cat <> iv_cat.
      rs = VALUE #( ok = abap_false msgno = '101'
                    msgv1 = |{ iv_item ALPHA = OUT }| msgv2 = iv_subcat msgv3 = iv_year ).
      RETURN.
    ENDIF.

    " Categoria-mãe activa (REQ-31)
    mo_reader->read_category( EXPORTING iv_year   = iv_year
                                        iv_cat    = ls_item-pac_cat
                              IMPORTING ev_status = DATA(lv_status)
                                        ev_found  = DATA(lv_cat_found) ).
    IF lv_cat_found = abap_true AND lv_status <> c_active.
      rs = VALUE #( ok = abap_false msgno = '102'
                    msgv1 = ls_item-pac_cat msgv2 = iv_year ).
      RETURN.
    ENDIF.

    " Estado do item utilizável = 'A' (REQ-32)
    IF ls_item-status <> c_active.
      rs = VALUE #( ok = abap_false msgno = '103'
                    msgv1 = |{ iv_item ALPHA = OUT }| msgv2 = ls_item-status ).
      RETURN.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

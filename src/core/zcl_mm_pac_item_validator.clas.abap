CLASS zcl_mm_pac_item_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_today TYPE dats
                io_log   TYPE REF TO zcl_mm_pac_log.

    "! Valida as linhas de itens (REQ-22..25), regista no log e devolve os itens
    "! novos a criar (PAC_CAT derivado da subcategoria; STATUS='D'; PAC_ITEM e
    "! auditoria ficam para o repositório/changeset).
    METHODS validate
      IMPORTING it_rows            TYPE zif_mm_pac_types=>tt_item_row
                it_existing_cat    TYPE zif_mm_pac_types=>tt_catg
                it_existing_subcat TYPE zif_mm_pac_types=>tt_subcatg
      EXPORTING et_item            TYPE zif_mm_pac_types=>tt_item
      RETURNING VALUE(rv_ok)       TYPE abap_bool.

  PRIVATE SECTION.
    CONSTANTS:
      c_re_num      TYPE string             VALUE `^[0-9]+(\.[0-9]+)?$`,
      c_status_draft TYPE zmm_pacitem_status VALUE 'D',
      c_unidade_len TYPE i                  VALUE 3,
      c_moeda_len   TYPE i                  VALUE 5.

    DATA:
      mv_today   TYPE dats,
      mo_log     TYPE REF TO zcl_mm_pac_log,
      mv_year_n  TYPE zmm_pac_year,
      mv_year_ok TYPE abap_bool.

    METHODS resolve_year
      IMPORTING it_rows TYPE zif_mm_pac_types=>tt_item_row.

    METHODS validate_row
      IMPORTING is_row       TYPE zif_mm_pac_types=>ty_item_row
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS collect
      IMPORTING is_row             TYPE zif_mm_pac_types=>ty_item_row
                it_existing_cat    TYPE zif_mm_pac_types=>tt_catg
                it_existing_subcat TYPE zif_mm_pac_types=>tt_subcatg
      CHANGING  ct_item            TYPE zif_mm_pac_types=>tt_item.
ENDCLASS.



CLASS zcl_mm_pac_item_validator IMPLEMENTATION.

  METHOD constructor.
    mv_today = iv_today.
    mo_log   = io_log.
  ENDMETHOD.


  METHOD validate.
    CLEAR et_item.
    resolve_year( it_rows ).

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<r>).
      IF validate_row( <r> ) = abap_false OR mv_year_ok = abap_false.
        CONTINUE.
      ENDIF.
      collect( EXPORTING is_row             = <r>
                         it_existing_cat    = it_existing_cat
                         it_existing_subcat = it_existing_subcat
               CHANGING  ct_item            = et_item ).
    ENDLOOP.

    rv_ok = xsdbool( mo_log->num_errors( ) = 0 ).
  ENDMETHOD.


  METHOD resolve_year.
    DATA lt_years TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lv_empty TYPE abap_bool.

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<r>).
      IF <r>-pac_year IS INITIAL.
        lv_empty = abap_true.
      ELSE.
        INSERT <r>-pac_year INTO TABLE lt_years.
      ENDIF.
    ENDLOOP.

    IF lv_empty = abap_true.
      mo_log->add( iv_type = 'E' iv_no = '010' ).
    ENDIF.
    IF lines( lt_years ) > 1.
      mo_log->add( iv_type = 'E' iv_no = '008' iv_v1 = lt_years[ 1 ] iv_v2 = lt_years[ 2 ] ).
      RETURN.
    ENDIF.
    IF lines( lt_years ) = 0.
      RETURN.
    ENDIF.

    DATA(lv_year) = lt_years[ 1 ].
    DATA(lv_cur)  = CONV i( mv_today(4) ).
    IF NOT matches( val = lv_year regex = `^[0-9]{4}$` ).
      mo_log->add( iv_type = 'E' iv_no = '011' iv_v1 = lv_year iv_v2 = |{ lv_cur }| iv_v3 = |{ lv_cur + 1 }| ).
      RETURN.
    ENDIF.
    DATA(lv_y) = CONV i( lv_year ).
    IF lv_y < lv_cur OR lv_y > lv_cur + 1.
      mo_log->add( iv_type = 'E' iv_no = '011' iv_v1 = lv_year iv_v2 = |{ lv_cur }| iv_v3 = |{ lv_cur + 1 }| ).
      RETURN.
    ENDIF.

    mv_year_n  = lv_year.
    mv_year_ok = abap_true.
  ENDMETHOD.


  METHOD validate_row.
    rv_ok = abap_true.

    IF is_row-pac_subcat IS INITIAL.
      mo_log->add( iv_type = 'E' iv_no = '014' iv_row = is_row-row ).
      rv_ok = abap_false.
    ENDIF.
    IF is_row-description IS INITIAL.
      mo_log->add( iv_type = 'E' iv_no = '088' iv_row = is_row-row ).
      rv_ok = abap_false.
    ENDIF.
    IF NOT matches( val = is_row-quantidade regex = c_re_num ).
      mo_log->add( iv_type = 'E' iv_no = '082' iv_row = is_row-row iv_v1 = is_row-quantidade ).
      rv_ok = abap_false.
    ENDIF.
    IF NOT matches( val = is_row-valor regex = c_re_num ).
      mo_log->add( iv_type = 'E' iv_no = '083' iv_row = is_row-row iv_v1 = is_row-valor ).
      rv_ok = abap_false.
    ENDIF.
    IF is_row-unidade IS INITIAL OR strlen( is_row-unidade ) > c_unidade_len.
      mo_log->add( iv_type = 'E' iv_no = '085' iv_row = is_row-row iv_v1 = is_row-unidade ).
      rv_ok = abap_false.
    ENDIF.
    IF is_row-moeda IS INITIAL OR strlen( is_row-moeda ) > c_moeda_len.
      mo_log->add( iv_type = 'E' iv_no = '084' iv_row = is_row-row iv_v1 = is_row-moeda ).
      rv_ok = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD collect.
    " pertença: a subcategoria tem de existir no catálogo do ano (REQ-24)
    READ TABLE it_existing_subcat INTO DATA(ls_sub)
         WITH KEY pac_year = mv_year_n pac_subcat = is_row-pac_subcat.
    IF sy-subrc <> 0.
      mo_log->add( iv_type = 'E' iv_no = '080' iv_row = is_row-row
                   iv_v1 = is_row-pac_subcat iv_v2 = |{ mv_year_n }| ).
      RETURN.
    ENDIF.

    " categoria-mãe (derivada da subcategoria) não pode estar inactiva
    READ TABLE it_existing_cat INTO DATA(ls_cat)
         WITH KEY pac_year = mv_year_n pac_cat = ls_sub-pac_cat.
    IF sy-subrc = 0 AND ls_cat-status = zif_mm_pac_types=>c_status_inactive.
      mo_log->add( iv_type = 'E' iv_no = '081' iv_row = is_row-row iv_v1 = is_row-pac_subcat ).
      RETURN.
    ENDIF.

    APPEND VALUE #( pac_year    = mv_year_n
                    pac_cat     = ls_sub-pac_cat
                    pac_subcat  = is_row-pac_subcat
                    description = is_row-description
                    quantidade  = is_row-quantidade
                    meins       = is_row-unidade
                    valor       = is_row-valor
                    moeda       = is_row-moeda
                    centro      = is_row-centro
                    saknr       = is_row-conta
                    status      = c_status_draft ) TO ct_item.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_mm_pac_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_today TYPE dats
                io_log   TYPE REF TO zcl_mm_pac_log.

    "! Valida as linhas do ficheiro (REQ-03..09), regista no log e devolve os
    "! registos novos e válidos a criar (auditoria/validade ficam para o changeset).
    METHODS validate
      IMPORTING it_rows            TYPE zif_mm_pac_types=>tt_file_row
                it_existing_cat    TYPE zif_mm_pac_types=>tt_catg
                it_existing_subcat TYPE zif_mm_pac_types=>tt_subcatg
      EXPORTING et_cat             TYPE zif_mm_pac_types=>tt_catg
                et_subcat          TYPE zif_mm_pac_types=>tt_subcatg
      RETURNING VALUE(rv_ok)       TYPE abap_bool.

  PRIVATE SECTION.
    CONSTANTS:
      c_re_cat    TYPE string VALUE `^PAC-[A-Z][0-9]{3}$`,
      c_re_subcat TYPE string VALUE `^PAC-[A-Z][0-9]{3}\.[1-9][0-9]{0,2}$`,
      c_desc_len  TYPE i      VALUE 72.

    DATA:
      mv_today   TYPE dats,
      mo_log     TYPE REF TO zcl_mm_pac_log,
      mv_year_n  TYPE zmm_pac_year,
      mv_year_ok TYPE abap_bool.

    METHODS resolve_year
      IMPORTING it_rows TYPE zif_mm_pac_types=>tt_file_row.

    METHODS validate_row
      IMPORTING is_row       TYPE zif_mm_pac_types=>ty_file_row
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS classify_and_collect
      IMPORTING is_row             TYPE zif_mm_pac_types=>ty_file_row
                it_existing_cat    TYPE zif_mm_pac_types=>tt_catg
                it_existing_subcat TYPE zif_mm_pac_types=>tt_subcatg
      CHANGING  ct_cat             TYPE zif_mm_pac_types=>tt_catg
                ct_subcat          TYPE zif_mm_pac_types=>tt_subcatg.
ENDCLASS.



CLASS zcl_mm_pac_validator IMPLEMENTATION.

  METHOD constructor.
    mv_today = iv_today.
    mo_log   = io_log.
  ENDMETHOD.


  METHOD validate.
    CLEAR: et_cat, et_subcat.

    resolve_year( it_rows ).

    TYPES: BEGIN OF ty_seen_cat,
             cat  TYPE string,
             desc TYPE string,
             row  TYPE i,
           END OF ty_seen_cat.
    TYPES: BEGIN OF ty_seen_sub,
             subcat TYPE string,
             row    TYPE i,
           END OF ty_seen_sub.
    DATA lt_seen_cat TYPE HASHED TABLE OF ty_seen_cat WITH UNIQUE KEY cat.
    DATA lt_seen_sub TYPE HASHED TABLE OF ty_seen_sub WITH UNIQUE KEY subcat.

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<r>).
      IF validate_row( <r> ) = abap_false.
        CONTINUE.
      ENDIF.

      DATA(lv_ok) = abap_true.

      " REQ-07: categoria com descrição divergente entre linhas
      IF <r>-pac_cat IS NOT INITIAL.
        READ TABLE lt_seen_cat ASSIGNING FIELD-SYMBOL(<sc>) WITH KEY cat = <r>-pac_cat.
        IF sy-subrc = 0.
          IF <sc>-desc <> <r>-cat_desc.
            mo_log->add( iv_type = 'E' iv_no = '021' iv_row = <r>-row
                         iv_v1 = <r>-pac_cat iv_v2 = |{ <sc>-row }| ).
            lv_ok = abap_false.
          ENDIF.
        ELSE.
          INSERT VALUE #( cat = <r>-pac_cat desc = <r>-cat_desc row = <r>-row ) INTO TABLE lt_seen_cat.
        ENDIF.
      ENDIF.

      " REQ-07: subcategoria duplicada no ficheiro
      IF <r>-pac_subcat IS NOT INITIAL.
        READ TABLE lt_seen_sub ASSIGNING FIELD-SYMBOL(<ss>) WITH KEY subcat = <r>-pac_subcat.
        IF sy-subrc = 0.
          mo_log->add( iv_type = 'E' iv_no = '019' iv_row = <r>-row
                       iv_v1 = <r>-pac_subcat iv_v2 = |{ <ss>-row }| ).
          lv_ok = abap_false.
        ELSE.
          INSERT VALUE #( subcat = <r>-pac_subcat row = <r>-row ) INTO TABLE lt_seen_sub.
        ENDIF.
      ENDIF.

      IF lv_ok = abap_false OR mv_year_ok = abap_false.
        CONTINUE.
      ENDIF.

      classify_and_collect(
        EXPORTING is_row = <r>
                  it_existing_cat = it_existing_cat
                  it_existing_subcat = it_existing_subcat
        CHANGING  ct_cat = et_cat ct_subcat = et_subcat ).
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
      mo_log->add( iv_type = 'E' iv_no = '008'
                   iv_v1 = lt_years[ 1 ] iv_v2 = lt_years[ 2 ] ).
      RETURN.
    ENDIF.
    IF lines( lt_years ) = 0.
      RETURN.
    ENDIF.

    DATA(lv_year) = lt_years[ 1 ].
    DATA(lv_cur)  = CONV i( mv_today(4) ).

    IF NOT matches( val = lv_year regex = `^[0-9]{4}$` ).
      mo_log->add( iv_type = 'E' iv_no = '011'
                   iv_v1 = lv_year iv_v2 = |{ lv_cur }| iv_v3 = |{ lv_cur + 1 }| ).
      RETURN.
    ENDIF.

    DATA(lv_y) = CONV i( lv_year ).
    IF lv_y < lv_cur OR lv_y > lv_cur + 1.
      mo_log->add( iv_type = 'E' iv_no = '011'
                   iv_v1 = lv_year iv_v2 = |{ lv_cur }| iv_v3 = |{ lv_cur + 1 }| ).
      RETURN.
    ENDIF.

    mv_year_n  = lv_year.
    mv_year_ok = abap_true.
  ENDMETHOD.


  METHOD validate_row.
    rv_ok = abap_true.

    " REQ-04: obrigatórios
    IF is_row-pac_cat IS INITIAL.
      mo_log->add( iv_type = 'E' iv_no = '012' iv_row = is_row-row ).
      rv_ok = abap_false.
    ENDIF.
    IF is_row-cat_desc IS INITIAL.
      mo_log->add( iv_type = 'E' iv_no = '013' iv_row = is_row-row ).
      rv_ok = abap_false.
    ENDIF.
    IF is_row-pac_subcat IS INITIAL.
      mo_log->add( iv_type = 'E' iv_no = '014' iv_row = is_row-row ).
      rv_ok = abap_false.
    ENDIF.
    IF is_row-subcat_desc IS INITIAL.
      mo_log->add( iv_type = 'E' iv_no = '015' iv_row = is_row-row ).
      rv_ok = abap_false.
    ENDIF.

    " REQ-05: formato
    IF is_row-pac_cat IS NOT INITIAL AND NOT matches( val = is_row-pac_cat regex = c_re_cat ).
      mo_log->add( iv_type = 'E' iv_no = '016' iv_row = is_row-row iv_v1 = is_row-pac_cat ).
      rv_ok = abap_false.
    ENDIF.
    IF is_row-pac_subcat IS NOT INITIAL AND NOT matches( val = is_row-pac_subcat regex = c_re_subcat ).
      mo_log->add( iv_type = 'E' iv_no = '017' iv_row = is_row-row iv_v1 = is_row-pac_subcat ).
      rv_ok = abap_false.
    ENDIF.

    " REQ-05: comprimento das descrições (nunca trunca)
    IF strlen( is_row-cat_desc ) > c_desc_len OR strlen( is_row-subcat_desc ) > c_desc_len.
      mo_log->add( iv_type = 'E' iv_no = '022' iv_row = is_row-row iv_v1 = |{ c_desc_len }| ).
      rv_ok = abap_false.
    ENDIF.

    " REQ-06: pertença (prefixo) — só se ambos presentes e com formato
    IF is_row-pac_cat IS NOT INITIAL AND is_row-pac_subcat IS NOT INITIAL.
      DATA(lv_pref) = |{ is_row-pac_cat }.|.
      IF strlen( is_row-pac_subcat ) < strlen( lv_pref )
         OR substring( val = is_row-pac_subcat len = strlen( lv_pref ) ) <> lv_pref.
        mo_log->add( iv_type = 'E' iv_no = '018' iv_row = is_row-row
                     iv_v1 = is_row-pac_subcat iv_v2 = is_row-pac_cat ).
        rv_ok = abap_false.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD classify_and_collect.
    " --- categoria ---
    READ TABLE it_existing_cat INTO DATA(ls_ex_cat)
         WITH KEY pac_year = mv_year_n pac_cat = is_row-pac_cat.
    IF sy-subrc = 0.
      IF ls_ex_cat-pac_cat_desc = is_row-cat_desc.
        mo_log->add( iv_type = 'I' iv_no = '033' iv_row = is_row-row iv_v1 = is_row-pac_cat ).
      ELSE.
        mo_log->add( iv_type = 'W' iv_no = '032' iv_row = is_row-row iv_v1 = is_row-pac_cat ).
      ENDIF.
    ELSE.
      READ TABLE ct_cat TRANSPORTING NO FIELDS
           WITH KEY pac_year = mv_year_n pac_cat = is_row-pac_cat.
      IF sy-subrc <> 0.
        INSERT VALUE #( pac_year     = mv_year_n
                        pac_cat      = is_row-pac_cat
                        pac_cat_desc = is_row-cat_desc
                        status       = zif_mm_pac_types=>c_status_active ) INTO TABLE ct_cat.
      ENDIF.
    ENDIF.

    " --- subcategoria ---
    READ TABLE it_existing_subcat INTO DATA(ls_ex_sub)
         WITH KEY pac_year = mv_year_n pac_subcat = is_row-pac_subcat.
    IF sy-subrc = 0.
      IF ls_ex_sub-pac_cat <> is_row-pac_cat.
        mo_log->add( iv_type = 'E' iv_no = '023' iv_row = is_row-row
                     iv_v1 = is_row-pac_subcat iv_v2 = ls_ex_sub-pac_cat iv_v3 = |{ mv_year_n }| ).
      ELSEIF ls_ex_sub-pac_subcat_desc = is_row-subcat_desc.
        mo_log->add( iv_type = 'I' iv_no = '033' iv_row = is_row-row iv_v1 = is_row-pac_subcat ).
      ELSE.
        mo_log->add( iv_type = 'W' iv_no = '032' iv_row = is_row-row iv_v1 = is_row-pac_subcat ).
      ENDIF.
      RETURN.
    ENDIF.

    " subcategoria nova: categoria-mãe existente inactiva não aceita novas (REQ-09)
    READ TABLE it_existing_cat INTO DATA(ls_pcat)
         WITH KEY pac_year = mv_year_n pac_cat = is_row-pac_cat.
    IF sy-subrc = 0 AND ls_pcat-status = zif_mm_pac_types=>c_status_inactive.
      mo_log->add( iv_type = 'E' iv_no = '034' iv_row = is_row-row
                   iv_v1 = is_row-pac_cat iv_v2 = ls_pcat-status ).
      RETURN.
    ENDIF.

    READ TABLE ct_subcat TRANSPORTING NO FIELDS
         WITH KEY pac_year = mv_year_n pac_subcat = is_row-pac_subcat.
    IF sy-subrc <> 0.
      INSERT VALUE #( pac_year        = mv_year_n
                      pac_subcat      = is_row-pac_subcat
                      pac_cat         = is_row-pac_cat
                      pac_subcat_desc = is_row-subcat_desc ) INTO TABLE ct_subcat.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

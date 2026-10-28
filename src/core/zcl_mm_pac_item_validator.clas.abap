class ZCL_MM_PAC_ITEM_VALIDATOR definition
  public
  final
  create public .

public section.

  methods CONSTRUCTOR
    importing
      !IV_TODAY type DATS
      !IO_LOG type ref to ZCL_MM_PAC_LOG .
    "! Valida as linhas de itens (REQ-22..25), regista no log e devolve os itens
    "! novos a criar (PAC_CAT derivado da subcategoria; STATUS='D'; PAC_ITEM e
    "! auditoria ficam para o repositório/changeset).
  methods VALIDATE
    importing
      !IT_ROWS type ZIF_MM_PAC_TYPES=>TT_ITEM_ROW
      !IT_EXISTING_CAT type ZIF_MM_PAC_TYPES=>TT_CATG
      !IT_EXISTING_SUBCAT type ZIF_MM_PAC_TYPES=>TT_SUBCATG
      !IT_CURRENCIES type ZIF_MM_PAC_TYPES=>TT_WAERS optional
      !IT_PLANTS type ZIF_MM_PAC_TYPES=>TT_WERKS optional
      !IT_GL_ACCOUNTS type ZIF_MM_PAC_TYPES=>TT_SAKNR optional
      !IT_UOM type ZIF_MM_PAC_TYPES=>TT_UOM optional
    exporting
      !ET_ITEM type ZIF_MM_PAC_TYPES=>TT_ITEM
    returning
      value(RV_OK) type ABAP_BOOL .
protected section.
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
                it_currencies      TYPE zif_mm_pac_types=>tt_waers
                it_plants          TYPE zif_mm_pac_types=>tt_werks
                it_gl_accounts     TYPE zif_mm_pac_types=>tt_saknr
                it_uom             TYPE zif_mm_pac_types=>tt_uom
      CHANGING  ct_item            TYPE zif_mm_pac_types=>tt_item.
ENDCLASS.



CLASS ZCL_MM_PAC_ITEM_VALIDATOR IMPLEMENTATION.


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

    " dados-mestre (D5-08), bloqueante
    DATA(lv_ok) = abap_true.

    IF NOT line_exists( it_currencies[ table_line = CONV waers( is_row-moeda ) ] ).
      mo_log->add( iv_type = 'E' iv_no = '090' iv_row = is_row-row iv_v1 = is_row-moeda ).
      lv_ok = abap_false.
    ENDIF.

    READ TABLE it_uom INTO DATA(ls_uom) WITH KEY external = is_row-unidade.
    IF sy-subrc <> 0.
      mo_log->add( iv_type = 'E' iv_no = '091' iv_row = is_row-row iv_v1 = is_row-unidade ).
      lv_ok = abap_false.
    ENDIF.

    IF NOT line_exists( it_plants[ table_line = CONV werks_d( is_row-centro ) ] ).
      mo_log->add( iv_type = 'E' iv_no = '093' iv_row = is_row-row iv_v1 = is_row-centro ).
      lv_ok = abap_false.
    ENDIF.

    " conta-razão com conversão ALPHA (zeros à esquerda), como é guardada na SKB1
    DATA(lv_conta) = CONV saknr( |{ is_row-conta ALPHA = IN }| ).
    IF NOT line_exists( it_gl_accounts[ table_line = lv_conta ] ).
      mo_log->add( iv_type = 'E' iv_no = '095' iv_row = is_row-row iv_v1 = is_row-conta ).
      lv_ok = abap_false.
    ENDIF.

    IF lv_ok = abap_false.
      RETURN.
    ENDIF.

    APPEND VALUE #( pac_year    = mv_year_n
                    pac_cat     = ls_sub-pac_cat
                    pac_subcat  = is_row-pac_subcat
                    description = is_row-description
                    quantidade  = is_row-quantidade
                    meins       = ls_uom-internal
                    valor       = is_row-valor
                    moeda       = is_row-moeda
                    centro      = is_row-centro
                    saknr       = lv_conta
                    status      = c_status_draft ) TO ct_item.
  ENDMETHOD.


  METHOD constructor.
    mv_today = iv_today.
    mo_log   = io_log.
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
                         it_currencies      = it_currencies
                         it_plants          = it_plants
                         it_gl_accounts     = it_gl_accounts
                         it_uom             = it_uom
               CHANGING  ct_item            = et_item ).
    ENDLOOP.

    rv_ok = xsdbool( mo_log->num_errors( ) = 0 ).
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
    IF is_row-centro IS INITIAL.
      mo_log->add( iv_type = 'E' iv_no = '092' iv_row = is_row-row ).
      rv_ok = abap_false.
    ENDIF.
    IF is_row-conta IS INITIAL.
      mo_log->add( iv_type = 'E' iv_no = '094' iv_row = is_row-row ).
      rv_ok = abap_false.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

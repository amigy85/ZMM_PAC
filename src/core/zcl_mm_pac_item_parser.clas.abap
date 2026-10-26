CLASS zcl_mm_pac_item_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS:
      c_separator TYPE c LENGTH 1 VALUE ';',
      c_max_rows  TYPE i          VALUE 10000.

    "! Lê as linhas físicas do ficheiro de itens e produz as linhas tipadas (cruas)
    "! + mensagens estruturais (REQ-21), com códigos normalizados.
    METHODS parse
      IMPORTING it_raw  TYPE string_table
      EXPORTING et_rows TYPE zif_mm_pac_types=>tt_item_row
                et_msg  TYPE zif_mm_pac_types=>tt_msg.

  PRIVATE SECTION.
    CONSTANTS:
      c_h1 TYPE string VALUE 'ANO',
      c_h2 TYPE string VALUE 'COD_SUBCATEGORIA',
      c_h3 TYPE string VALUE 'DESCRICAO',
      c_h4 TYPE string VALUE 'QUANTIDADE',
      c_h5 TYPE string VALUE 'UNIDADE',
      c_h6 TYPE string VALUE 'VALOR',
      c_h7 TYPE string VALUE 'MOEDA',
      c_h8 TYPE string VALUE 'CENTRO',
      c_h9 TYPE string VALUE 'CONTA_RAZAO'.

    METHODS add_msg
      IMPORTING iv_type TYPE symsgty
                iv_no   TYPE symsgno
                iv_row  TYPE i     DEFAULT 0
                iv_v1   TYPE clike OPTIONAL
                iv_v2   TYPE clike OPTIONAL
      CHANGING  ct_msg  TYPE zif_mm_pac_types=>tt_msg.

    METHODS check_header
      IMPORTING iv_header    TYPE string
      CHANGING  ct_msg       TYPE zif_mm_pac_types=>tt_msg
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS get_field
      IMPORTING it_field      TYPE string_table
                iv_pos        TYPE i
      RETURNING VALUE(rv_val) TYPE string.

    METHODS norm
      IMPORTING iv_in         TYPE clike
      RETURNING VALUE(rv_out) TYPE string.

    METHODS trim_desc
      IMPORTING iv_in         TYPE clike
      RETURNING VALUE(rv_out) TYPE string.

    METHODS is_formula_risk
      IMPORTING iv_text      TYPE clike
      RETURNING VALUE(rv_ok) TYPE abap_bool.
ENDCLASS.



CLASS zcl_mm_pac_item_parser IMPLEMENTATION.

  METHOD parse.
    CLEAR: et_rows, et_msg.

    IF lines( it_raw ) <= 1.
      add_msg( EXPORTING iv_type = 'E' iv_no = '006' CHANGING ct_msg = et_msg ).
      RETURN.
    ENDIF.

    IF check_header( EXPORTING iv_header = it_raw[ 1 ] CHANGING ct_msg = et_msg ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_data_count) = lines( it_raw ) - 1.
    IF lv_data_count > c_max_rows.
      add_msg( EXPORTING iv_type = 'E' iv_no = '007'
                         iv_v1 = |{ c_max_rows }| CHANGING ct_msg = et_msg ).
      RETURN.
    ENDIF.

    LOOP AT it_raw ASSIGNING FIELD-SYMBOL(<raw>) FROM 2.
      DATA(lv_row) = sy-tabix.

      " nº de campos = nº de separadores + 1 (robusto a campos finais vazios,
      " que o SPLIT INTO TABLE não materializa)
      DATA(lv_fields) = count( val = <raw> sub = c_separator ) + 1.
      IF lv_fields <> 9.
        add_msg( EXPORTING iv_type = 'E' iv_no = '005' iv_row = lv_row
                           iv_v1 = '9' iv_v2 = |{ lv_fields }|
                 CHANGING ct_msg = et_msg ).
        CONTINUE.
      ENDIF.

      SPLIT <raw> AT c_separator INTO TABLE DATA(lt_field).
      DATA(ls_row) = VALUE zif_mm_pac_types=>ty_item_row(
        row         = lv_row
        pac_year    = norm( get_field( it_field = lt_field iv_pos = 1 ) )
        pac_subcat  = norm( get_field( it_field = lt_field iv_pos = 2 ) )
        description = trim_desc( get_field( it_field = lt_field iv_pos = 3 ) )
        quantidade  = condense( get_field( it_field = lt_field iv_pos = 4 ) )
        unidade     = norm( get_field( it_field = lt_field iv_pos = 5 ) )
        valor       = condense( get_field( it_field = lt_field iv_pos = 6 ) )
        moeda       = norm( get_field( it_field = lt_field iv_pos = 7 ) )
        centro      = norm( get_field( it_field = lt_field iv_pos = 8 ) )
        conta       = norm( get_field( it_field = lt_field iv_pos = 9 ) ) ).
      APPEND ls_row TO et_rows.

      IF is_formula_risk( ls_row-description ) = abap_true.
        add_msg( EXPORTING iv_type = 'W' iv_no = '024' iv_row = lv_row
                           iv_v1 = substring( val = ls_row-description len = 1 )
                 CHANGING ct_msg = et_msg ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_header.
    rv_ok = abap_true.
    SPLIT iv_header AT c_separator INTO TABLE DATA(lt_col).

    DATA(lt_exp) = VALUE string_table(
      ( c_h1 ) ( c_h2 ) ( c_h3 ) ( c_h4 ) ( c_h5 )
      ( c_h6 ) ( c_h7 ) ( c_h8 ) ( c_h9 ) ).

    LOOP AT lt_exp ASSIGNING FIELD-SYMBOL(<exp>).
      DATA(lv_pos) = sy-tabix.
      DATA(lv_got) = COND string( WHEN line_exists( lt_col[ lv_pos ] )
                                  THEN to_upper( condense( lt_col[ lv_pos ] ) )
                                  ELSE space ).
      IF lv_got <> <exp>.
        add_msg( EXPORTING iv_type = 'E' iv_no = '004'
                           iv_v1 = <exp> iv_v2 = |{ lv_pos }| CHANGING ct_msg = ct_msg ).
        rv_ok = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_field.
    IF line_exists( it_field[ iv_pos ] ).
      rv_val = it_field[ iv_pos ].
    ENDIF.
  ENDMETHOD.


  METHOD norm.
    rv_out = to_upper( condense( iv_in ) ).
  ENDMETHOD.


  METHOD trim_desc.
    rv_out = iv_in.
    SHIFT rv_out LEFT DELETING LEADING space.
  ENDMETHOD.


  METHOD is_formula_risk.
    DATA(lv) = condense( iv_text ).
    IF lv IS INITIAL.
      rv_ok = abap_false.
      RETURN.
    ENDIF.
    rv_ok = xsdbool( substring( val = lv len = 1 ) CA '=+-@' ).
  ENDMETHOD.


  METHOD add_msg.
    DATA lv_text TYPE string.
    MESSAGE ID 'ZMM_PAC' TYPE iv_type NUMBER iv_no
            WITH iv_v1 iv_v2 INTO lv_text.
    APPEND VALUE #( msgty = iv_type msgno = iv_no row = iv_row text = lv_text ) TO ct_msg.
  ENDMETHOD.

ENDCLASS.

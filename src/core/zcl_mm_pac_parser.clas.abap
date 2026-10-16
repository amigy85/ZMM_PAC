CLASS zcl_mm_pac_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS:
      c_separator TYPE c LENGTH 1 VALUE ';',
      c_max_rows  TYPE i          VALUE 10000.

    "! Lê as linhas físicas do ficheiro e produz as linhas tipadas + mensagens
    "! estruturais (REQ-02) com os códigos normalizados (REQ-05 normalização).
    METHODS parse
      IMPORTING it_raw  TYPE string_table
      EXPORTING et_rows TYPE zif_mm_pac_types=>tt_file_row
                et_msg  TYPE zif_mm_pac_types=>tt_msg.

  PRIVATE SECTION.
    CONSTANTS:
      c_h1 TYPE string VALUE 'ANO',
      c_h2 TYPE string VALUE 'COD_CATEGORIA',
      c_h3 TYPE string VALUE 'DESC_CATEGORIA',
      c_h4 TYPE string VALUE 'COD_SUBCATEGORIA',
      c_h5 TYPE string VALUE 'DESC_SUBCATEGORIA'.

    METHODS add_msg
      IMPORTING iv_type TYPE symsgty
                iv_no   TYPE symsgno
                iv_row  TYPE i       DEFAULT 0
                iv_v1   TYPE clike   OPTIONAL
                iv_v2   TYPE clike   OPTIONAL
                iv_v3   TYPE clike   OPTIONAL
                iv_v4   TYPE clike   OPTIONAL
      CHANGING  ct_msg  TYPE zif_mm_pac_types=>tt_msg.

    METHODS check_header
      IMPORTING iv_header    TYPE string
      CHANGING  ct_msg       TYPE zif_mm_pac_types=>tt_msg
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS norm_code
      IMPORTING iv_in        TYPE clike
      RETURNING VALUE(rv_out) TYPE string.

    METHODS trim_desc
      IMPORTING iv_in        TYPE clike
      RETURNING VALUE(rv_out) TYPE string.

    METHODS is_formula_risk
      IMPORTING iv_text      TYPE clike
      RETURNING VALUE(rv_ok) TYPE abap_bool.
ENDCLASS.



CLASS zcl_mm_pac_parser IMPLEMENTATION.

  METHOD parse.
    CLEAR: et_rows, et_msg.

    " ficheiro vazio ou só com cabeçalho -> sem linhas de dados
    IF lines( it_raw ) <= 1.
      add_msg( EXPORTING iv_type = 'E' iv_no = '006' CHANGING ct_msg = et_msg ).
      RETURN.
    ENDIF.

    " cabeçalho (linha física 1)
    IF check_header( EXPORTING iv_header = it_raw[ 1 ] CHANGING ct_msg = et_msg ) = abap_false.
      RETURN.
    ENDIF.

    " limite de volume (linhas de dados = total - cabeçalho)
    DATA(lv_data_count) = lines( it_raw ) - 1.
    IF lv_data_count > c_max_rows.
      add_msg( EXPORTING iv_type = 'E' iv_no = '007'
                         iv_v1 = |{ c_max_rows }| CHANGING ct_msg = et_msg ).
      RETURN.
    ENDIF.

    LOOP AT it_raw ASSIGNING FIELD-SYMBOL(<raw>) FROM 2.
      DATA(lv_row) = sy-tabix.             " nº da linha física

      SPLIT <raw> AT c_separator INTO TABLE DATA(lt_field).
      IF lines( lt_field ) <> 5.
        add_msg( EXPORTING iv_type = 'E' iv_no = '005' iv_row = lv_row
                           iv_v1 = '5' iv_v2 = |{ lines( lt_field ) }|
                 CHANGING ct_msg = et_msg ).
        CONTINUE.
      ENDIF.

      DATA(ls_row) = VALUE zif_mm_pac_types=>ty_file_row(
        row         = lv_row
        pac_year    = norm_code( lt_field[ 1 ] )
        pac_cat     = norm_code( lt_field[ 2 ] )
        cat_desc    = trim_desc( lt_field[ 3 ] )
        pac_subcat  = norm_code( lt_field[ 4 ] )
        subcat_desc = trim_desc( lt_field[ 5 ] ) ).
      APPEND ls_row TO et_rows.

      " aviso de risco de fórmula ao exportar para Excel (descrições)
      IF is_formula_risk( ls_row-cat_desc ) = abap_true.
        add_msg( EXPORTING iv_type = 'W' iv_no = '024' iv_row = lv_row
                           iv_v1 = ls_row-cat_desc(1) CHANGING ct_msg = et_msg ).
      ENDIF.
      IF is_formula_risk( ls_row-subcat_desc ) = abap_true.
        add_msg( EXPORTING iv_type = 'W' iv_no = '024' iv_row = lv_row
                           iv_v1 = ls_row-subcat_desc(1) CHANGING ct_msg = et_msg ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_header.
    rv_ok = abap_true.
    SPLIT iv_header AT c_separator INTO TABLE DATA(lt_col).

    DATA(lt_exp) = VALUE string_table( ( c_h1 ) ( c_h2 ) ( c_h3 ) ( c_h4 ) ( c_h5 ) ).

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


  METHOD norm_code.
    rv_out = to_upper( condense( iv_in ) ).
  ENDMETHOD.


  METHOD trim_desc.
    rv_out = iv_in.
    SHIFT rv_out LEFT DELETING LEADING space.
    " espaços à direita são irrelevantes nos campos CHAR de destino
  ENDMETHOD.


  METHOD is_formula_risk.
    DATA(lv_first) = condense( iv_text ).
    rv_ok = xsdbool( lv_first IS NOT INITIAL AND lv_first(1) CA '=+-@' ).
  ENDMETHOD.


  METHOD add_msg.
    DATA lv_text TYPE string.
    MESSAGE ID 'ZMM_PAC' TYPE iv_type NUMBER iv_no
            WITH iv_v1 iv_v2 iv_v3 iv_v4 INTO lv_text.
    APPEND VALUE #( msgty = iv_type msgno = iv_no row = iv_row text = lv_text ) TO ct_msg.
  ENDMETHOD.

ENDCLASS.

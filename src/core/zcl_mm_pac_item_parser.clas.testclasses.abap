CLASS ltc_item_parser DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_mm_pac_item_parser.

    METHODS setup.
    METHODS header_line RETURNING VALUE(rv) TYPE string.
    METHODS has_msg
      IMPORTING it_msg       TYPE zif_mm_pac_types=>tt_msg
                iv_no        TYPE symsgno
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS header_only_is_rejected     FOR TESTING.
    METHODS wrong_header_reports_column FOR TESTING.
    METHODS wrong_column_count_is_error FOR TESTING.
    METHODS more_than_max_rows_rejected FOR TESTING.
    METHODS subcat_is_normalized        FOR TESTING.
    METHODS accents_preserved           FOR TESTING.
    METHODS formula_risk_warns          FOR TESTING.
ENDCLASS.


CLASS ltc_item_parser IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.

  METHOD header_line.
    rv = 'ANO;COD_SUBCATEGORIA;DESCRICAO;QUANTIDADE;UNIDADE;VALOR;MOEDA;CENTRO;CONTA_RAZAO'.
  ENDMETHOD.

  METHOD has_msg.
    rv_ok = xsdbool( line_exists( it_msg[ msgno = iv_no ] ) ).
  ENDMETHOD.

  METHOD header_only_is_rejected.
    mo_cut->parse( EXPORTING it_raw  = VALUE string_table( ( header_line( ) ) )
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '006' ) ).
    cl_abap_unit_assert=>assert_initial( lt_rows ).
  ENDMETHOD.

  METHOD wrong_header_reports_column.
    DATA(lt_raw) = VALUE string_table(
      ( `ANO;SUBCAT;DESCRICAO;QUANTIDADE;UNIDADE;VALOR;MOEDA;CENTRO;CONTA_RAZAO` )
      ( `2026;PAC-E001.1;Item;10;UN;100;MZN;1000;21100000` ) ).
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '004' ) ).
  ENDMETHOD.

  METHOD wrong_column_count_is_error.
    DATA(lt_raw) = VALUE string_table(
      ( header_line( ) )
      ( `2026;PAC-E001.1;Item;10;UN;100;MZN;1000` ) ).   " 8 campos
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '005' ) ).
    cl_abap_unit_assert=>assert_initial( lt_rows ).
  ENDMETHOD.

  METHOD more_than_max_rows_rejected.
    DATA(lt_raw) = VALUE string_table( ( header_line( ) ) ).
    DATA(lv_n) = zcl_mm_pac_item_parser=>c_max_rows + 1.
    DO lv_n TIMES.
      APPEND `2026;PAC-E001.1;Item;10;UN;100;MZN;1000;21100000` TO lt_raw.
    ENDDO.
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '007' ) ).
  ENDMETHOD.

  METHOD subcat_is_normalized.
    DATA(lt_raw) = VALUE string_table(
      ( header_line( ) )
      ( ` 2026 ; pac-e001.1 ;Assessoria; 10 ;un;100;mzn; 1000 ;21100000` ) ).
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-pac_subcat exp = 'PAC-E001.1' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-unidade    exp = 'UN' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-moeda      exp = 'MZN' ).
  ENDMETHOD.

  METHOD accents_preserved.
    DATA(lt_raw) = VALUE string_table(
      ( header_line( ) )
      ( `2026;PAC-E001.1;Aquisição de equipamento de protecção;5;UN;2500;MZN;;` ) ).
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-description
                                        exp = 'Aquisição de equipamento de protecção' ).
  ENDMETHOD.

  METHOD formula_risk_warns.
    DATA(lt_raw) = VALUE string_table(
      ( header_line( ) )
      ( `2026;PAC-E001.1;=SOMA(A1);10;UN;100;MZN;;` ) ).
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '024' ) ).
  ENDMETHOD.

ENDCLASS.

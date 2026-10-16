CLASS ltc_parser DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_mm_pac_parser.

    METHODS setup.

    METHODS header_line RETURNING VALUE(rv) TYPE string.
    METHODS has_msg
      IMPORTING it_msg       TYPE zif_mm_pac_types=>tt_msg
                iv_no        TYPE symsgno
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS header_only_is_rejected    FOR TESTING.
    METHODS wrong_header_reports_column FOR TESTING.
    METHODS wrong_column_count_is_error FOR TESTING.
    METHODS more_than_max_rows_rejected FOR TESTING.
    METHODS lowercase_code_is_normalized FOR TESTING.
    METHODS accents_preserved           FOR TESTING.
    METHODS formula_risk_warns          FOR TESTING.
ENDCLASS.


CLASS ltc_parser IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.

  METHOD header_line.
    rv = 'ANO;COD_CATEGORIA;DESC_CATEGORIA;COD_SUBCATEGORIA;DESC_SUBCATEGORIA'.
  ENDMETHOD.

  METHOD has_msg.
    rv_ok = xsdbool( line_exists( it_msg[ msgno = iv_no ] ) ).
  ENDMETHOD.

  METHOD header_only_is_rejected.
    mo_cut->parse( EXPORTING it_raw  = VALUE string_table( ( header_line( ) ) )
                   IMPORTING et_rows = DATA(lt_rows)
                             et_msg  = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '006' ) ).
    cl_abap_unit_assert=>assert_initial( lt_rows ).
  ENDMETHOD.

  METHOD wrong_header_reports_column.
    DATA(lt_raw) = VALUE string_table(
      ( `ANO;COD_CATEGORIA;DESC_CATEGORIA;SUBCAT;DESC_SUBCATEGORIA` )
      ( `2026;PAC-E001;Assessoria;PAC-E001.1;Assessoria` ) ).
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '004' ) ).
  ENDMETHOD.

  METHOD wrong_column_count_is_error.
    DATA(lt_raw) = VALUE string_table(
      ( header_line( ) )
      ( `2026;PAC-E001;Assessoria;PAC-E001.1;Assessoria;extra6;extra7` ) ).
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '005' ) ).
    cl_abap_unit_assert=>assert_initial( lt_rows ).
  ENDMETHOD.

  METHOD more_than_max_rows_rejected.
    DATA(lt_raw) = VALUE string_table( ( header_line( ) ) ).
    DATA(lv_n) = zcl_mm_pac_parser=>c_max_rows + 1.
    DO lv_n TIMES.
      APPEND `2026;PAC-E001;Assessoria;PAC-E001.1;Assessoria` TO lt_raw.
    ENDDO.
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '007' ) ).
  ENDMETHOD.

  METHOD lowercase_code_is_normalized.
    DATA(lt_raw) = VALUE string_table(
      ( header_line( ) )
      ( ` 2026 ; pac-e001 ;Assessoria tecnica; pac-e001.1 ;Assessoria` ) ).
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-pac_cat    exp = 'PAC-E001' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-pac_subcat exp = 'PAC-E001.1' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-pac_year   exp = '2026' ).
  ENDMETHOD.

  METHOD accents_preserved.
    DATA(lt_raw) = VALUE string_table(
      ( header_line( ) )
      ( `2026;PAC-E001;Construção da Estação;PAC-E001.1;Manutenção e protecção` ) ).
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-cat_desc    exp = 'Construção da Estação' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-subcat_desc exp = 'Manutenção e protecção' ).
  ENDMETHOD.

  METHOD formula_risk_warns.
    DATA(lt_raw) = VALUE string_table(
      ( header_line( ) )
      ( `2026;PAC-E001;=SOMA(A1);PAC-E001.1;Assessoria` ) ).
    mo_cut->parse( EXPORTING it_raw = lt_raw
                   IMPORTING et_rows = DATA(lt_rows) et_msg = DATA(lt_msg) ).
    cl_abap_unit_assert=>assert_true( has_msg( it_msg = lt_msg iv_no = '024' ) ).
  ENDMETHOD.

ENDCLASS.

CLASS ltc_log DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_mm_pac_log.
    METHODS setup.
    METHODS add_builds_text      FOR TESTING.
    METHODS add_many_merges      FOR TESTING.
    METHODS counts_by_severity   FOR TESTING.
    METHODS has_errors_true_false FOR TESTING.
ENDCLASS.


CLASS ltc_log IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.

  METHOD add_builds_text.
    mo_cut->add( iv_type = 'E' iv_no = '001' ).
    DATA(lt) = mo_cut->get_messages( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt )      exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 1 ]-msgno    exp = '001' ).
    cl_abap_unit_assert=>assert_not_initial( act = lt[ 1 ]-text ).
  ENDMETHOD.

  METHOD add_many_merges.
    DATA(lt_in) = VALUE zif_mm_pac_types=>tt_msg(
      ( msgty = 'E' msgno = '012' row = 2 text = `erro cat` )
      ( msgty = 'W' msgno = '024' row = 3 text = `aviso formula` ) ).
    mo_cut->add_many( lt_in ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_messages( ) ) exp = 2 ).
  ENDMETHOD.

  METHOD counts_by_severity.
    mo_cut->add( iv_type = 'E' iv_no = '061' iv_v1 = `1` ).
    mo_cut->add( iv_type = 'W' iv_no = '024' iv_v1 = `=` ).
    mo_cut->add( iv_type = 'I' iv_no = '033' iv_v1 = `PAC-E001` ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->num_errors( )   exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->num_warnings( ) exp = 1 ).
  ENDMETHOD.

  METHOD has_errors_true_false.
    DATA(lo_warn) = NEW zcl_mm_pac_log( ).
    lo_warn->add( iv_type = 'W' iv_no = '024' iv_v1 = `=` ).
    cl_abap_unit_assert=>assert_false( lo_warn->has_errors( ) ).

    DATA(lo_err) = NEW zcl_mm_pac_log( ).
    lo_err->add( iv_type = 'E' iv_no = '063' ).
    cl_abap_unit_assert=>assert_true( lo_err->has_errors( ) ).
  ENDMETHOD.

ENDCLASS.
*"* use this source file for your ABAP unit test classes

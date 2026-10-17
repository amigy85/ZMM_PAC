CLASS ltd_auth DEFINITION INHERITING FROM zcl_mm_pac_auth.
  PUBLIC SECTION.
    DATA mv_subrc TYPE i.
  PROTECTED SECTION.
    METHODS authority_check REDEFINITION.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD authority_check.
    rv_subrc = mv_subrc.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_auth DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS authorized_passes FOR TESTING.
    METHODS denied_raises_050 FOR TESTING.
ENDCLASS.

CLASS ltc_auth IMPLEMENTATION.

  METHOD authorized_passes.
    DATA(lo) = NEW ltd_auth( ).
    lo->mv_subrc = 0.
    TRY.
        lo->check( zcl_mm_pac_auth=>c_actvt_display ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'nao devia levantar excepcao' ).
    ENDTRY.
  ENDMETHOD.

  METHOD denied_raises_050.
    DATA(lo) = NEW ltd_auth( ).
    lo->mv_subrc = 4.
    TRY.
        lo->check( zcl_mm_pac_auth=>c_actvt_create ).
        cl_abap_unit_assert=>fail( 'devia levantar excepcao' ).
      CATCH zcx_mm_pac INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals( act = lx->if_t100_message~t100key-msgno exp = '050' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

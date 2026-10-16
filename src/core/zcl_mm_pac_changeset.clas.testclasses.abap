CLASS ltc_changeset DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS:
      c_erdat TYPE dats    VALUE '20260115',
      c_erzet TYPE tims    VALUE '101500',
      c_ernam TYPE syuname VALUE 'TESTER'.

    DATA mo_cut TYPE REF TO zcl_mm_pac_changeset.

    METHODS setup.
    METHODS in_cat RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_catg.
    METHODS in_sub RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_subcatg.

    METHODS stamps_audit        FOR TESTING.
    METHODS single_stamp        FOR TESTING.
    METHODS validity_from_year  FOR TESTING.
    METHODS subcat_also_stamped FOR TESTING.
    METHODS empty_input_ok      FOR TESTING.
ENDCLASS.


CLASS ltc_changeset IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( iv_erdat = c_erdat iv_erzet = c_erzet iv_ernam = c_ernam ).
  ENDMETHOD.

  METHOD in_cat.
    rt = VALUE #(
      ( pac_year = '2026' pac_cat = 'PAC-E001' pac_cat_desc = 'A' status = 'A' )
      ( pac_year = '2026' pac_cat = 'PAC-E002' pac_cat_desc = 'B' status = 'A' ) ).
  ENDMETHOD.

  METHOD in_sub.
    rt = VALUE #(
      ( pac_year = '2026' pac_subcat = 'PAC-E001.1' pac_cat = 'PAC-E001' pac_subcat_desc = 'S1' )
      ( pac_year = '2026' pac_subcat = 'PAC-E002.1' pac_cat = 'PAC-E002' pac_subcat_desc = 'S2' ) ).
  ENDMETHOD.

  METHOD stamps_audit.
    mo_cut->build( EXPORTING it_cat = in_cat( ) it_subcat = in_sub( )
                   IMPORTING et_cat = DATA(lt_cat) et_subcat = DATA(lt_sub) ).
    LOOP AT lt_cat ASSIGNING FIELD-SYMBOL(<c>).
      cl_abap_unit_assert=>assert_equals( act = <c>-ernam exp = c_ernam ).
      cl_abap_unit_assert=>assert_equals( act = <c>-erdat exp = c_erdat ).
      cl_abap_unit_assert=>assert_equals( act = <c>-erzet exp = c_erzet ).
      cl_abap_unit_assert=>assert_initial( <c>-aenam ).
      cl_abap_unit_assert=>assert_initial( <c>-aedat ).
    ENDLOOP.
  ENDMETHOD.

  METHOD single_stamp.
    mo_cut->build( EXPORTING it_cat = in_cat( ) it_subcat = in_sub( )
                   IMPORTING et_cat = DATA(lt_cat) et_subcat = DATA(lt_sub) ).
    cl_abap_unit_assert=>assert_equals( act = lt_cat[ 2 ]-erdat exp = lt_cat[ 1 ]-erdat ).
    cl_abap_unit_assert=>assert_equals( act = lt_cat[ 2 ]-erzet exp = lt_cat[ 1 ]-erzet ).
  ENDMETHOD.

  METHOD validity_from_year.
    mo_cut->build( EXPORTING it_cat = in_cat( ) it_subcat = in_sub( )
                   IMPORTING et_cat = DATA(lt_cat) et_subcat = DATA(lt_sub) ).
    cl_abap_unit_assert=>assert_equals( act = lt_cat[ 1 ]-valid_from exp = '20260101' ).
    cl_abap_unit_assert=>assert_equals( act = lt_cat[ 1 ]-valid_to   exp = '20261231' ).
  ENDMETHOD.

  METHOD subcat_also_stamped.
    mo_cut->build( EXPORTING it_cat = in_cat( ) it_subcat = in_sub( )
                   IMPORTING et_cat = DATA(lt_cat) et_subcat = DATA(lt_sub) ).
    cl_abap_unit_assert=>assert_equals( act = lt_sub[ 1 ]-ernam      exp = c_ernam ).
    cl_abap_unit_assert=>assert_equals( act = lt_sub[ 1 ]-valid_from exp = '20260101' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sub[ 1 ]-valid_to   exp = '20261231' ).
  ENDMETHOD.

  METHOD empty_input_ok.
    mo_cut->build( EXPORTING it_cat = VALUE #( ) it_subcat = VALUE #( )
                   IMPORTING et_cat = DATA(lt_cat) et_subcat = DATA(lt_sub) ).
    cl_abap_unit_assert=>assert_initial( lt_cat ).
    cl_abap_unit_assert=>assert_initial( lt_sub ).
  ENDMETHOD.

ENDCLASS.

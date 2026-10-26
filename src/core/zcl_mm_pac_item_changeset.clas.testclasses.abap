CLASS ltc_item_changeset DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS:
      c_erdat TYPE dats    VALUE '20260115',
      c_erzet TYPE tims    VALUE '101500',
      c_ernam TYPE syuname VALUE 'TESTER'.

    DATA mo_cut TYPE REF TO zcl_mm_pac_item_changeset.

    METHODS setup.
    METHODS in_item RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_item.

    METHODS stamps_audit      FOR TESTING.
    METHODS single_stamp      FOR TESTING.
    METHODS status_preserved  FOR TESTING.
    METHODS empty_input_ok    FOR TESTING.
ENDCLASS.


CLASS ltc_item_changeset IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( iv_erdat = c_erdat iv_erzet = c_erzet iv_ernam = c_ernam ).
  ENDMETHOD.

  METHOD in_item.
    rt = VALUE #(
      ( pac_year = '2026' pac_cat = 'PAC-E001' pac_subcat = 'PAC-E001.1'
        description = 'Item 1' quantidade = 10 meins = 'UN' valor = 100 moeda = 'MZN' status = 'D' )
      ( pac_year = '2026' pac_cat = 'PAC-E001' pac_subcat = 'PAC-E001.2'
        description = 'Item 2' quantidade = 5  meins = 'UN' valor = 50  moeda = 'MZN' status = 'D' ) ).
  ENDMETHOD.

  METHOD stamps_audit.
    mo_cut->build( EXPORTING it_item = in_item( ) IMPORTING et_item = DATA(lt) ).
    LOOP AT lt ASSIGNING FIELD-SYMBOL(<i>).
      cl_abap_unit_assert=>assert_equals( act = <i>-ernam exp = c_ernam ).
      cl_abap_unit_assert=>assert_equals( act = <i>-erdat exp = c_erdat ).
      cl_abap_unit_assert=>assert_equals( act = <i>-erzet exp = c_erzet ).
      cl_abap_unit_assert=>assert_initial( <i>-aenam ).
      cl_abap_unit_assert=>assert_initial( <i>-aedat ).
    ENDLOOP.
  ENDMETHOD.

  METHOD single_stamp.
    mo_cut->build( EXPORTING it_item = in_item( ) IMPORTING et_item = DATA(lt) ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 2 ]-erdat exp = lt[ 1 ]-erdat ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 2 ]-erzet exp = lt[ 1 ]-erzet ).
  ENDMETHOD.

  METHOD status_preserved.
    mo_cut->build( EXPORTING it_item = in_item( ) IMPORTING et_item = DATA(lt) ).
    cl_abap_unit_assert=>assert_equals( act = lt[ 1 ]-status exp = 'D' ).
  ENDMETHOD.

  METHOD empty_input_ok.
    mo_cut->build( EXPORTING it_item = VALUE #( ) IMPORTING et_item = DATA(lt) ).
    cl_abap_unit_assert=>assert_initial( lt ).
  ENDMETHOD.

ENDCLASS.

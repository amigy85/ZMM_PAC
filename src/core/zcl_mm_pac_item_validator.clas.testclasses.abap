CLASS ltc_item_validator DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_today TYPE dats VALUE '20260101'.

    DATA:
      mo_log  TYPE REF TO zcl_mm_pac_log,
      mt_item TYPE zif_mm_pac_types=>tt_item,
      mv_ok   TYPE abap_bool.

    METHODS run
      IMPORTING it_rows TYPE zif_mm_pac_types=>tt_item_row
                it_cat  TYPE zif_mm_pac_types=>tt_catg    OPTIONAL
                it_sub  TYPE zif_mm_pac_types=>tt_subcatg OPTIONAL.
    METHODS has
      IMPORTING iv_no        TYPE symsgno
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS catalog_cat RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_catg.
    METHODS catalog_sub RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_subcatg.
    METHODS row_ok RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_item_row.

    METHODS year_out_of_range        FOR TESTING.
    METHODS subcat_not_in_catalog    FOR TESTING.
    METHODS parent_category_inactive FOR TESTING.
    METHODS quantity_invalid         FOR TESTING.
    METHODS value_invalid            FOR TESTING.
    METHODS description_missing      FOR TESTING.
    METHODS currency_format_invalid  FOR TESTING.
    METHODS valid_item_builds_output FOR TESTING.
ENDCLASS.


CLASS ltc_item_validator IMPLEMENTATION.

  METHOD run.
    mo_log = NEW #( ).
    DATA(lo_cut) = NEW zcl_mm_pac_item_validator( iv_today = c_today io_log = mo_log ).
    mv_ok = lo_cut->validate( EXPORTING it_rows            = it_rows
                                        it_existing_cat    = it_cat
                                        it_existing_subcat = it_sub
                              IMPORTING et_item            = mt_item ).
  ENDMETHOD.

  METHOD has.
    DATA(lt) = mo_log->get_messages( ).
    rv_ok = xsdbool( line_exists( lt[ msgno = iv_no ] ) ).
  ENDMETHOD.

  METHOD catalog_cat.
    rt = VALUE #( ( pac_year = '2026' pac_cat = 'PAC-E001' pac_cat_desc = 'Cat' status = 'A' ) ).
  ENDMETHOD.

  METHOD catalog_sub.
    rt = VALUE #( ( pac_year = '2026' pac_subcat = 'PAC-E001.1' pac_cat = 'PAC-E001' pac_subcat_desc = 'Sub' ) ).
  ENDMETHOD.

  METHOD row_ok.
    rt = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                    quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN`
                    centro = `` conta = `` ) ).
  ENDMETHOD.

  METHOD year_out_of_range.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2030` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN` ) ) ).
    cl_abap_unit_assert=>assert_true( has( '011' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD subcat_not_in_catalog.
    run( it_rows = row_ok( ) it_cat = catalog_cat( ) ).   " sem subcategorias
    cl_abap_unit_assert=>assert_true( has( '080' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD parent_category_inactive.
    run( it_rows = row_ok( )
         it_cat  = VALUE #( ( pac_year = '2026' pac_cat = 'PAC-E001' pac_cat_desc = 'Cat' status = 'I' ) )
         it_sub  = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '081' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD quantity_invalid.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `abc` unidade = `UN` valor = `100` moeda = `MZN` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '082' ) ).
  ENDMETHOD.

  METHOD value_invalid.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `-5` moeda = `MZN` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '083' ) ).
  ENDMETHOD.

  METHOD description_missing.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = ``
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '088' ) ).
  ENDMETHOD.

  METHOD currency_format_invalid.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '084' ) ).
  ENDMETHOD.

  METHOD valid_item_builds_output.
    run( it_rows = row_ok( ) it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( mv_ok ).
    cl_abap_unit_assert=>assert_equals( act = lines( mt_item ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mt_item[ 1 ]-pac_cat exp = 'PAC-E001' ).
    cl_abap_unit_assert=>assert_equals( act = mt_item[ 1 ]-status  exp = 'D' ).
  ENDMETHOD.

ENDCLASS.

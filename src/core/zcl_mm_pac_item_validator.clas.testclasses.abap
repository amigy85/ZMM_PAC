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
                it_sub  TYPE zif_mm_pac_types=>tt_subcatg OPTIONAL
                it_cur  TYPE zif_mm_pac_types=>tt_waers   OPTIONAL
                it_plt  TYPE zif_mm_pac_types=>tt_werks   OPTIONAL
                it_gl   TYPE zif_mm_pac_types=>tt_saknr   OPTIONAL
                it_uom  TYPE zif_mm_pac_types=>tt_uom     OPTIONAL.
    METHODS has
      IMPORTING iv_no        TYPE symsgno
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS catalog_cat RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_catg.
    METHODS catalog_sub RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_subcatg.
    METHODS row_ok RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_item_row.
    " conjuntos de dados-mestre por omissão (válidos)
    METHODS def_cur RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_waers.
    METHODS def_plt RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_werks.
    METHODS def_gl  RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_saknr.
    METHODS def_uom RETURNING VALUE(rt) TYPE zif_mm_pac_types=>tt_uom.

    METHODS year_out_of_range        FOR TESTING.
    METHODS subcat_not_in_catalog    FOR TESTING.
    METHODS parent_category_inactive FOR TESTING.
    METHODS quantity_invalid         FOR TESTING.
    METHODS value_invalid            FOR TESTING.
    METHODS description_missing      FOR TESTING.
    METHODS currency_format_invalid  FOR TESTING.
    METHODS valid_item_builds_output FOR TESTING.
    " D5-08
    METHODS centro_mandatory         FOR TESTING.
    METHODS conta_mandatory          FOR TESTING.
    METHODS currency_not_in_system   FOR TESTING.
    METHODS unit_not_in_system       FOR TESTING.
    METHODS plant_not_in_system      FOR TESTING.
    METHODS account_not_in_system    FOR TESTING.
ENDCLASS.


CLASS ltc_item_validator IMPLEMENTATION.

  METHOD run.
    mo_log = NEW #( ).
    DATA(lo_cut) = NEW zcl_mm_pac_item_validator( iv_today = c_today io_log = mo_log ).

    DATA(lt_cur) = COND #( WHEN it_cur IS SUPPLIED THEN it_cur ELSE def_cur( ) ).
    DATA(lt_plt) = COND #( WHEN it_plt IS SUPPLIED THEN it_plt ELSE def_plt( ) ).
    DATA(lt_gl)  = COND #( WHEN it_gl  IS SUPPLIED THEN it_gl  ELSE def_gl( ) ).
    DATA(lt_uom) = COND #( WHEN it_uom IS SUPPLIED THEN it_uom ELSE def_uom( ) ).

    mv_ok = lo_cut->validate( EXPORTING it_rows            = it_rows
                                        it_existing_cat    = it_cat
                                        it_existing_subcat = it_sub
                                        it_currencies      = lt_cur
                                        it_plants          = lt_plt
                                        it_gl_accounts     = lt_gl
                                        it_uom             = lt_uom
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

  METHOD def_cur.
    rt = VALUE #( ( 'MZN' ) ( 'USD' ) ( 'ZAR' ) ).
  ENDMETHOD.

  METHOD def_plt.
    rt = VALUE #( ( 'MPM' ) ( 'CHIM' ) ( 'SONG' ) ).
  ENDMETHOD.

  METHOD def_gl.
    rt = VALUE #( ( '0000620000' ) ).   " forma ALPHA (como na SKB1)
  ENDMETHOD.

  METHOD def_uom.
    rt = VALUE #( ( external = `UN` internal = 'UN' )
                  ( external = `KG` internal = 'KG' )
                  ( external = `CX` internal = 'CX' ) ).
  ENDMETHOD.

  METHOD row_ok.
    rt = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                    quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN`
                    centro = `MPM` conta = `620000` ) ).
  ENDMETHOD.

  METHOD year_out_of_range.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2030` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN`
                              centro = `MPM` conta = `620000` ) ) ).
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
                              quantidade = `abc` unidade = `UN` valor = `100` moeda = `MZN`
                              centro = `MPM` conta = `620000` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '082' ) ).
  ENDMETHOD.

  METHOD value_invalid.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `-5` moeda = `MZN`
                              centro = `MPM` conta = `620000` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '083' ) ).
  ENDMETHOD.

  METHOD description_missing.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = ``
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN`
                              centro = `MPM` conta = `620000` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '088' ) ).
  ENDMETHOD.

  METHOD currency_format_invalid.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `100` moeda = ``
                              centro = `MPM` conta = `620000` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '084' ) ).
  ENDMETHOD.

  METHOD valid_item_builds_output.
    run( it_rows = row_ok( ) it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( mv_ok ).
    cl_abap_unit_assert=>assert_equals( act = lines( mt_item ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mt_item[ 1 ]-pac_cat exp = 'PAC-E001' ).
    cl_abap_unit_assert=>assert_equals( act = mt_item[ 1 ]-status  exp = 'D' ).
    cl_abap_unit_assert=>assert_equals( act = mt_item[ 1 ]-meins   exp = 'UN' ).
  ENDMETHOD.

  METHOD centro_mandatory.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN`
                              centro = `` conta = `620000` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '092' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD conta_mandatory.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN`
                              centro = `MPM` conta = `` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '094' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD currency_not_in_system.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `EUR`
                              centro = `MPM` conta = `620000` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '090' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD unit_not_in_system.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `XX` valor = `100` moeda = `MZN`
                              centro = `MPM` conta = `620000` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '091' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD plant_not_in_system.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN`
                              centro = `ZZZZ` conta = `620000` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '093' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD account_not_in_system.
    run( it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_subcat = `PAC-E001.1` description = `Item`
                              quantidade = `10` unidade = `UN` valor = `100` moeda = `MZN`
                              centro = `MPM` conta = `999999` ) )
         it_cat = catalog_cat( ) it_sub = catalog_sub( ) ).
    cl_abap_unit_assert=>assert_true( has( '095' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

ENDCLASS.
*"* use this source file for your ABAP unit test classes

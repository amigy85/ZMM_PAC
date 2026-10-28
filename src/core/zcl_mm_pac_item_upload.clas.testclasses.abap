"! Duplo do repositório de itens: conta chamadas, numera e captura o inserido.
CLASS ltd_item_repo DEFINITION.
  PUBLIC SECTION.
    INTERFACES zif_mm_pac_item_repository.
    DATA:
      mv_next            TYPE i,
      mv_insert          TYPE i,
      mv_commit          TYPE i,
      mv_rollback        TYPE i,
      mv_lock            TYPE i,
      mv_unlock          TYPE i,
      mv_raise_on_insert TYPE abap_bool,
      mt_cat             TYPE zif_mm_pac_types=>tt_catg,
      mt_sub             TYPE zif_mm_pac_types=>tt_subcatg,
      mt_cur             TYPE zif_mm_pac_types=>tt_waers,
      mt_plt             TYPE zif_mm_pac_types=>tt_werks,
      mt_gl              TYPE zif_mm_pac_types=>tt_saknr,
      mt_inserted        TYPE zif_mm_pac_types=>tt_item.
ENDCLASS.

CLASS ltd_item_repo IMPLEMENTATION.
  METHOD zif_mm_pac_item_repository~read_categories.
    rt_cat = mt_cat.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~read_subcategories.
    rt_subcat = mt_sub.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~read_currencies.
    rt_waers = mt_cur.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~read_plants.
    rt_werks = mt_plt.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~read_gl_accounts.
    rt_saknr = mt_gl.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~normalize_uom.
    rv_internal = iv_external.   " o duplo aceita a unidade tal como vem
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~lock_year.
    mv_lock = mv_lock + 1.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~unlock_year.
    mv_unlock = mv_unlock + 1.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~next_item_number.
    mv_next = mv_next + 1.
    rv_item = mv_next.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~insert_new.
    mv_insert = mv_insert + 1.
    mt_inserted = it_item.
    IF mv_raise_on_insert = abap_true.
      RAISE EXCEPTION TYPE zcx_mm_pac
        EXPORTING textid = zcx_mm_pac=>db_insert_failed.
    ENDIF.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~commit.
    mv_commit = mv_commit + 1.
  ENDMETHOD.
  METHOD zif_mm_pac_item_repository~rollback.
    mv_rollback = mv_rollback + 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth_ok DEFINITION INHERITING FROM zcl_mm_pac_auth.
  PROTECTED SECTION.
    METHODS authority_check REDEFINITION.
ENDCLASS.

CLASS ltd_auth_ok IMPLEMENTATION.
  METHOD authority_check.
    rv_subrc = 0.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_item_upload DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_today TYPE dats VALUE '20260101'.

    DATA:
      mo_repo TYPE REF TO ltd_item_repo,
      mo_log  TYPE REF TO zcl_mm_pac_log,
      mo_cut  TYPE REF TO zcl_mm_pac_item_upload.

    METHODS make_cut.
    METHODS with_catalog.
    METHODS raw_valid RETURNING VALUE(rt) TYPE string_table.
    METHODS has
      IMPORTING iv_no        TYPE symsgno
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS sim_mode_never_commits      FOR TESTING.
    METHODS write_inserts_and_commits   FOR TESTING.
    METHODS numbers_assigned_on_write   FOR TESTING.
    METHODS errors_block_write          FOR TESTING.
    METHODS db_error_rolls_back         FOR TESTING.
    METHODS write_locks_release_unlocks FOR TESTING.
ENDCLASS.


CLASS ltc_item_upload IMPLEMENTATION.

  METHOD make_cut.
    mo_repo = NEW #( ).
    mo_log  = NEW #( ).
    mo_cut  = NEW #( io_repository = mo_repo
                     io_auth       = NEW ltd_auth_ok( )
                     io_parser     = NEW zcl_mm_pac_item_parser( )
                     io_log        = mo_log
                     iv_today      = c_today ).
  ENDMETHOD.

  METHOD with_catalog.
    mo_repo->mt_cat = VALUE #( ( pac_year = '2026' pac_cat = 'PAC-E001' pac_cat_desc = 'Cat' status = 'A' ) ).
    mo_repo->mt_sub = VALUE #( ( pac_year = '2026' pac_subcat = 'PAC-E001.1' pac_cat = 'PAC-E001' pac_subcat_desc = 'Sub' ) ).
    INSERT 'MZN'        INTO TABLE mo_repo->mt_cur.
    INSERT 'MPM'        INTO TABLE mo_repo->mt_plt.
    INSERT '0000620000' INTO TABLE mo_repo->mt_gl.   " forma ALPHA (como na SKB1)
  ENDMETHOD.

  METHOD raw_valid.
    rt = VALUE #(
      ( `ANO;COD_SUBCATEGORIA;DESCRICAO;QUANTIDADE;UNIDADE;VALOR;MOEDA;CENTRO;CONTA_RAZAO` )
      ( `2026;PAC-E001.1;Item;10;UN;100;MZN;MPM;620000` ) ).
  ENDMETHOD.

  METHOD has.
    DATA(lt) = mo_log->get_messages( ).
    rv_ok = xsdbool( line_exists( lt[ msgno = iv_no ] ) ).
  ENDMETHOD.

  METHOD sim_mode_never_commits.
    make_cut( ).
    with_catalog( ).
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_false ).
        mo_cut->write( ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_insert exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_commit exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_next   exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_lock   exp = 0 ).
  ENDMETHOD.

  METHOD write_inserts_and_commits.
    make_cut( ).
    with_catalog( ).
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_true ).
        mo_cut->write( ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_insert   exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_commit   exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_next     exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_rollback exp = 0 ).
    cl_abap_unit_assert=>assert_true( has( '086' ) ).
  ENDMETHOD.

  METHOD numbers_assigned_on_write.
    make_cut( ).
    with_catalog( ).
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_true ).
        mo_cut->write( ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_not_initial( act = mo_repo->mt_inserted[ 1 ]-pac_item ).
  ENDMETHOD.

  METHOD errors_block_write.
    make_cut( ).
    with_catalog( ).
    DATA(lt_raw) = VALUE string_table(
      ( `ANO;COD_SUBCATEGORIA;DESCRICAO;QUANTIDADE;UNIDADE;VALOR;MOEDA;CENTRO;CONTA_RAZAO` )
      ( `2026;PAC-E001.1;Item;abc;UN;100;MZN;;` ) ).   " quantidade inválida (082)
    TRY.
        mo_cut->prepare( it_raw = lt_raw iv_write = abap_true ).
        mo_cut->write( ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_insert exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_commit exp = 0 ).
    cl_abap_unit_assert=>assert_true( has( '061' ) ).
  ENDMETHOD.

  METHOD db_error_rolls_back.
    make_cut( ).
    with_catalog( ).
    mo_repo->mv_raise_on_insert = abap_true.
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_true ).
        mo_cut->write( ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_rollback exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_commit   exp = 0 ).
    cl_abap_unit_assert=>assert_true( has( '063' ) ).
  ENDMETHOD.

  METHOD write_locks_release_unlocks.
    make_cut( ).
    with_catalog( ).
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_true ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_lock exp = 1 ).
    mo_cut->release( ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_unlock exp = 1 ).

    make_cut( ).
    with_catalog( ).
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_false ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_lock exp = 0 ).
  ENDMETHOD.

ENDCLASS.
*"* use this source file for your ABAP unit test classes

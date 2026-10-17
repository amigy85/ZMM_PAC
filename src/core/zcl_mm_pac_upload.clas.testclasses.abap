"! Duplo do repositório: conta chamadas e devolve "existentes" configuráveis.
CLASS ltd_repo DEFINITION.
  PUBLIC SECTION.
    INTERFACES zif_mm_pac_repository.
    DATA:
      mv_insert          TYPE i,
      mv_commit          TYPE i,
      mv_rollback        TYPE i,
      mv_lock            TYPE i,
      mv_unlock          TYPE i,
      mv_raise_on_insert TYPE abap_bool,
      mt_cat             TYPE zif_mm_pac_types=>tt_catg,
      mt_sub             TYPE zif_mm_pac_types=>tt_subcatg.
ENDCLASS.

CLASS ltd_repo IMPLEMENTATION.
  METHOD zif_mm_pac_repository~read_categories.
    rt_cat = mt_cat.
  ENDMETHOD.
  METHOD zif_mm_pac_repository~read_subcategories.
    rt_subcat = mt_sub.
  ENDMETHOD.
  METHOD zif_mm_pac_repository~lock_year.
    mv_lock = mv_lock + 1.
  ENDMETHOD.
  METHOD zif_mm_pac_repository~unlock_year.
    mv_unlock = mv_unlock + 1.
  ENDMETHOD.
  METHOD zif_mm_pac_repository~insert_new.
    mv_insert = mv_insert + 1.
    IF mv_raise_on_insert = abap_true.
      RAISE EXCEPTION TYPE zcx_mm_pac
        EXPORTING textid = zcx_mm_pac=>db_insert_failed.
    ENDIF.
  ENDMETHOD.
  METHOD zif_mm_pac_repository~commit.
    mv_commit = mv_commit + 1.
  ENDMETHOD.
  METHOD zif_mm_pac_repository~rollback.
    mv_rollback = mv_rollback + 1.
  ENDMETHOD.
ENDCLASS.


"! Duplo da autorização: nunca nega.
CLASS ltd_auth_ok DEFINITION INHERITING FROM zcl_mm_pac_auth.
  PROTECTED SECTION.
    METHODS authority_check REDEFINITION.
ENDCLASS.

CLASS ltd_auth_ok IMPLEMENTATION.
  METHOD authority_check.
    rv_subrc = 0.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_upload DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_today TYPE dats VALUE '20260101'.

    DATA:
      mo_repo TYPE REF TO ltd_repo,
      mo_log  TYPE REF TO zcl_mm_pac_log,
      mo_cut  TYPE REF TO zcl_mm_pac_upload.

    METHODS make_cut.
    METHODS raw_valid RETURNING VALUE(rt) TYPE string_table.
    METHODS has
      IMPORTING iv_no        TYPE symsgno
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS sim_mode_never_commits      FOR TESTING.
    METHODS write_inserts_and_commits   FOR TESTING.
    METHODS errors_block_write          FOR TESTING.
    METHODS nothing_to_write            FOR TESTING.
    METHODS db_error_rolls_back         FOR TESTING.
    METHODS write_locks_release_unlocks FOR TESTING.
ENDCLASS.


CLASS ltc_upload IMPLEMENTATION.

  METHOD make_cut.
    mo_repo = NEW #( ).
    mo_log  = NEW #( ).
    mo_cut  = NEW #( io_repository = mo_repo
                     io_auth       = NEW ltd_auth_ok( )
                     io_parser     = NEW zcl_mm_pac_parser( )
                     io_log        = mo_log
                     iv_today      = c_today ).
  ENDMETHOD.

  METHOD raw_valid.
    rt = VALUE #(
      ( `ANO;COD_CATEGORIA;DESC_CATEGORIA;COD_SUBCATEGORIA;DESC_SUBCATEGORIA` )
      ( `2026;PAC-E001;Assessoria;PAC-E001.1;Subcategoria` ) ).
  ENDMETHOD.

  METHOD has.
    DATA(lt) = mo_log->get_messages( ).
    rv_ok = xsdbool( line_exists( lt[ msgno = iv_no ] ) ).
  ENDMETHOD.

  METHOD sim_mode_never_commits.
    make_cut( ).
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_false ).
        mo_cut->write( ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_insert exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_commit exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_lock   exp = 0 ).
  ENDMETHOD.

  METHOD write_inserts_and_commits.
    make_cut( ).
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_true ).
        mo_cut->write( ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_insert   exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_commit   exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_rollback exp = 0 ).
    cl_abap_unit_assert=>assert_true( has( '062' ) ).
  ENDMETHOD.

  METHOD errors_block_write.
    make_cut( ).
    DATA(lt_raw) = VALUE string_table(
      ( `ANO;COD_CATEGORIA;DESC_CATEGORIA;COD_SUBCATEGORIA;DESC_SUBCATEGORIA` )
      ( `2026;PAC-G155;Rede;PAC-G155-3;Sub` ) ).   " subcat formato inválido (017)
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

  METHOD nothing_to_write.
    make_cut( ).
    mo_repo->mt_cat = VALUE #( ( pac_year = '2026' pac_cat = 'PAC-E001'
                                 pac_cat_desc = 'Assessoria' status = 'A' ) ).
    mo_repo->mt_sub = VALUE #( ( pac_year = '2026' pac_subcat = 'PAC-E001.1'
                                 pac_cat = 'PAC-E001' pac_subcat_desc = 'Subcategoria' ) ).
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_true ).
        mo_cut->write( ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_insert exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_commit exp = 0 ).
    cl_abap_unit_assert=>assert_true( has( '065' ) ).
  ENDMETHOD.

  METHOD db_error_rolls_back.
    make_cut( ).
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
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_true ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_lock exp = 1 ).
    mo_cut->release( ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_unlock exp = 1 ).

    " simulação não bloqueia
    make_cut( ).
    TRY.
        mo_cut->prepare( it_raw = raw_valid( ) iv_write = abap_false ).
      CATCH zcx_mm_pac.
        cl_abap_unit_assert=>fail( 'excepcao inesperada' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_lock exp = 0 ).
  ENDMETHOD.

ENDCLASS.

CLASS ltc_validator DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_today TYPE dats VALUE '20260101'.   " ano permitido: 2026 e 2027

    DATA:
      mo_log TYPE REF TO zcl_mm_pac_log,
      mt_cat TYPE zif_mm_pac_types=>tt_catg,
      mt_sub TYPE zif_mm_pac_types=>tt_subcatg,
      mv_ok  TYPE abap_bool.

    METHODS run
      IMPORTING it_rows TYPE zif_mm_pac_types=>tt_file_row
                it_cat  TYPE zif_mm_pac_types=>tt_catg    OPTIONAL
                it_sub  TYPE zif_mm_pac_types=>tt_subcatg OPTIONAL.
    METHODS has
      IMPORTING iv_no        TYPE symsgno
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS valid_new_builds_output   FOR TESTING.
    METHODS year_out_of_range         FOR TESTING.
    METHODS two_years_in_file         FOR TESTING.
    METHODS mandatory_fields          FOR TESTING.
    METHODS bad_subcat_format         FOR TESTING.
    METHODS desc_too_long             FOR TESTING.
    METHODS subcat_prefix_mismatch    FOR TESTING.
    METHODS dup_subcat_in_file        FOR TESTING.
    METHODS cat_desc_divergent        FOR TESTING.
    METHODS subcat_exists_other_cat   FOR TESTING.
    METHODS existing_identical_ignored FOR TESTING.
    METHODS existing_divergent_reported FOR TESTING.
ENDCLASS.


CLASS ltc_validator IMPLEMENTATION.

  METHOD run.
    mo_log = NEW #( ).
    DATA(lo_cut) = NEW zcl_mm_pac_validator( iv_today = c_today io_log = mo_log ).
    mv_ok = lo_cut->validate( EXPORTING it_rows            = it_rows
                                        it_existing_cat    = it_cat
                                        it_existing_subcat = it_sub
                              IMPORTING et_cat    = mt_cat
                                        et_subcat = mt_sub ).
  ENDMETHOD.

  METHOD has.
    DATA(lt) = mo_log->get_messages( ).
    rv_ok = xsdbool( line_exists( lt[ msgno = iv_no ] ) ).
  ENDMETHOD.

  METHOD valid_new_builds_output.
    run( VALUE #( ( row = 2 pac_year = `2026` pac_cat = `PAC-E001`
                    cat_desc = `Assessoria` pac_subcat = `PAC-E001.1` subcat_desc = `Sub` ) ) ).
    cl_abap_unit_assert=>assert_true( mv_ok ).
    cl_abap_unit_assert=>assert_equals( act = lines( mt_cat ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( mt_sub ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mt_cat[ 1 ]-status exp = 'A' ).
  ENDMETHOD.

  METHOD year_out_of_range.
    run( VALUE #( ( row = 2 pac_year = `2030` pac_cat = `PAC-E001`
                    cat_desc = `Assessoria` pac_subcat = `PAC-E001.1` subcat_desc = `Sub` ) ) ).
    cl_abap_unit_assert=>assert_true( has( '011' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD two_years_in_file.
    run( VALUE #(
      ( row = 2 pac_year = `2026` pac_cat = `PAC-E001` cat_desc = `A` pac_subcat = `PAC-E001.1` subcat_desc = `S` )
      ( row = 3 pac_year = `2027` pac_cat = `PAC-E002` cat_desc = `B` pac_subcat = `PAC-E002.1` subcat_desc = `S` ) ) ).
    cl_abap_unit_assert=>assert_true( has( '008' ) ).
  ENDMETHOD.

  METHOD mandatory_fields.
    run( VALUE #( ( row = 2 pac_year = `2026` pac_cat = ``
                    cat_desc = `Assessoria` pac_subcat = `PAC-E001.1` subcat_desc = `Sub` ) ) ).
    cl_abap_unit_assert=>assert_true( has( '012' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD bad_subcat_format.
    run( VALUE #( ( row = 2 pac_year = `2026` pac_cat = `PAC-G155`
                    cat_desc = `Rede` pac_subcat = `PAC-G155-3` subcat_desc = `Sub` ) ) ).
    cl_abap_unit_assert=>assert_true( has( '017' ) ).
  ENDMETHOD.

  METHOD desc_too_long.
    run( VALUE #( ( row = 2 pac_year = `2026` pac_cat = `PAC-E001`
                    cat_desc = repeat( val = `A` occ = 73 )
                    pac_subcat = `PAC-E001.1` subcat_desc = `Sub` ) ) ).
    cl_abap_unit_assert=>assert_true( has( '022' ) ).
  ENDMETHOD.

  METHOD subcat_prefix_mismatch.
    run( VALUE #( ( row = 2 pac_year = `2026` pac_cat = `PAC-G155`
                    cat_desc = `Rede` pac_subcat = `PAC-E065.1` subcat_desc = `Sub` ) ) ).
    cl_abap_unit_assert=>assert_true( has( '018' ) ).
  ENDMETHOD.

  METHOD dup_subcat_in_file.
    run( VALUE #(
      ( row = 2 pac_year = `2026` pac_cat = `PAC-E001` cat_desc = `A` pac_subcat = `PAC-E001.1` subcat_desc = `S` )
      ( row = 3 pac_year = `2026` pac_cat = `PAC-E001` cat_desc = `A` pac_subcat = `PAC-E001.1` subcat_desc = `S` ) ) ).
    cl_abap_unit_assert=>assert_true( has( '019' ) ).
  ENDMETHOD.

  METHOD cat_desc_divergent.
    run( VALUE #(
      ( row = 2 pac_year = `2026` pac_cat = `PAC-E001` cat_desc = `DescA` pac_subcat = `PAC-E001.1` subcat_desc = `S` )
      ( row = 3 pac_year = `2026` pac_cat = `PAC-E001` cat_desc = `DescB` pac_subcat = `PAC-E001.2` subcat_desc = `S` ) ) ).
    cl_abap_unit_assert=>assert_true( has( '021' ) ).
  ENDMETHOD.

  METHOD subcat_exists_other_cat.
    run( EXPORTING
      it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_cat = `PAC-E001`
                           cat_desc = `A` pac_subcat = `PAC-E001.1` subcat_desc = `S` ) )
      it_sub  = VALUE #( ( pac_year = '2026' pac_subcat = 'PAC-E001.1'
                           pac_cat = 'PAC-G155' pac_subcat_desc = 'Outra' ) ) ).
    cl_abap_unit_assert=>assert_true( has( '023' ) ).
    cl_abap_unit_assert=>assert_false( mv_ok ).
  ENDMETHOD.

  METHOD existing_identical_ignored.
    run( EXPORTING
      it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_cat = `PAC-E001`
                           cat_desc = `Assessoria` pac_subcat = `PAC-E001.1` subcat_desc = `Sub` ) )
      it_cat  = VALUE #( ( pac_year = '2026' pac_cat = 'PAC-E001' pac_cat_desc = 'Assessoria' status = 'A' ) )
      it_sub  = VALUE #( ( pac_year = '2026' pac_subcat = 'PAC-E001.1' pac_cat = 'PAC-E001' pac_subcat_desc = 'Sub' ) ) ).
    cl_abap_unit_assert=>assert_true( has( '033' ) ).
    cl_abap_unit_assert=>assert_true( mv_ok ).
    cl_abap_unit_assert=>assert_initial( mt_cat ).
    cl_abap_unit_assert=>assert_initial( mt_sub ).
  ENDMETHOD.

  METHOD existing_divergent_reported.
    run( EXPORTING
      it_rows = VALUE #( ( row = 2 pac_year = `2026` pac_cat = `PAC-E001`
                           cat_desc = `Nova` pac_subcat = `PAC-E001.1` subcat_desc = `Sub` ) )
      it_cat  = VALUE #( ( pac_year = '2026' pac_cat = 'PAC-E001' pac_cat_desc = 'Antiga' status = 'A' ) ) ).
    cl_abap_unit_assert=>assert_true( has( '032' ) ).
    cl_abap_unit_assert=>assert_true( mv_ok ).
  ENDMETHOD.

ENDCLASS.

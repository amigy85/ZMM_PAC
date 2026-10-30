"! Duplo do leitor: devolve um item/categoria configurados, sem BD.
CLASS ltd_reader DEFINITION.
  PUBLIC SECTION.
    INTERFACES zif_mm_pac_req_reader.
    DATA:
      ms_item       TYPE zmm_pac_item,
      mv_item_found TYPE abap_bool,
      mv_cat_status TYPE zmm_pac_status,
      mv_cat_found  TYPE abap_bool.
ENDCLASS.

CLASS ltd_reader IMPLEMENTATION.
  METHOD zif_mm_pac_req_reader~read_item.
    es_item  = ms_item.
    ev_found = mv_item_found.
  ENDMETHOD.
  METHOD zif_mm_pac_req_reader~read_category.
    ev_status = mv_cat_status.
    ev_found  = mv_cat_found.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_req_validator DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_reader TYPE REF TO ltd_reader.

    METHODS make_cut RETURNING VALUE(ro) TYPE REF TO zcl_mm_pac_req_validator.
    METHODS with_item
      IMPORTING iv_cat    TYPE zmm_pac_cat
                iv_status TYPE zmm_pacitem_status
                iv_catst  TYPE zmm_pac_status DEFAULT 'A'.

    METHODS mandatory_missing_blocks FOR TESTING.
    METHODS optional_missing_ok      FOR TESTING.
    METHODS item_not_found           FOR TESTING.
    METHODS category_mismatch        FOR TESTING.
    METHODS parent_category_inactive FOR TESTING.
    METHODS item_not_active          FOR TESTING.
    METHODS valid_assignment_ok      FOR TESTING.
ENDCLASS.


CLASS ltc_req_validator IMPLEMENTATION.

  METHOD make_cut.
    mo_reader = NEW #( ).
    ro = NEW #( mo_reader ).
  ENDMETHOD.

  METHOD with_item.
    mo_reader->mv_item_found = abap_true.
    mo_reader->ms_item = VALUE #( pac_year = '2026' pac_cat = iv_cat
                                  pac_subcat = 'PAC-E001.1' pac_item = '00001'
                                  status = iv_status ).
    mo_reader->mv_cat_found  = abap_true.
    mo_reader->mv_cat_status = iv_catst.
  ENDMETHOD.

  METHOD mandatory_missing_blocks.
    DATA(lo) = make_cut( ).
    DATA(rs) = lo->validate_item( iv_year = '2026' iv_cat = '' iv_subcat = ''
                                  iv_item = '00000' iv_mandatory = abap_true ).
    cl_abap_unit_assert=>assert_false( rs-ok ).
    cl_abap_unit_assert=>assert_equals( act = rs-msgno exp = '104' ).
  ENDMETHOD.

  METHOD optional_missing_ok.
    DATA(lo) = make_cut( ).
    DATA(rs) = lo->validate_item( iv_year = '2026' iv_cat = '' iv_subcat = ''
                                  iv_item = '00000' iv_mandatory = abap_false ).
    cl_abap_unit_assert=>assert_true( rs-ok ).
  ENDMETHOD.

  METHOD item_not_found.
    DATA(lo) = make_cut( ).
    mo_reader->mv_item_found = abap_false.
    DATA(rs) = lo->validate_item( iv_year = '2026' iv_cat = 'PAC-E001' iv_subcat = 'PAC-E001.1'
                                  iv_item = '00009' iv_mandatory = abap_true ).
    cl_abap_unit_assert=>assert_false( rs-ok ).
    cl_abap_unit_assert=>assert_equals( act = rs-msgno exp = '100' ).
  ENDMETHOD.

  METHOD category_mismatch.
    DATA(lo) = make_cut( ).
    with_item( iv_cat = 'PAC-E001' iv_status = 'A' ).
    DATA(rs) = lo->validate_item( iv_year = '2026' iv_cat = 'PAC-E999' iv_subcat = 'PAC-E001.1'
                                  iv_item = '00001' iv_mandatory = abap_true ).
    cl_abap_unit_assert=>assert_false( rs-ok ).
    cl_abap_unit_assert=>assert_equals( act = rs-msgno exp = '101' ).
  ENDMETHOD.

  METHOD parent_category_inactive.
    DATA(lo) = make_cut( ).
    with_item( iv_cat = 'PAC-E001' iv_status = 'A' iv_catst = 'I' ).
    DATA(rs) = lo->validate_item( iv_year = '2026' iv_cat = 'PAC-E001' iv_subcat = 'PAC-E001.1'
                                  iv_item = '00001' iv_mandatory = abap_true ).
    cl_abap_unit_assert=>assert_false( rs-ok ).
    cl_abap_unit_assert=>assert_equals( act = rs-msgno exp = '102' ).
  ENDMETHOD.

  METHOD item_not_active.
    DATA(lo) = make_cut( ).
    with_item( iv_cat = 'PAC-E001' iv_status = 'D' ).
    DATA(rs) = lo->validate_item( iv_year = '2026' iv_cat = 'PAC-E001' iv_subcat = 'PAC-E001.1'
                                  iv_item = '00001' iv_mandatory = abap_true ).
    cl_abap_unit_assert=>assert_false( rs-ok ).
    cl_abap_unit_assert=>assert_equals( act = rs-msgno exp = '103' ).
  ENDMETHOD.

  METHOD valid_assignment_ok.
    DATA(lo) = make_cut( ).
    with_item( iv_cat = 'PAC-E001' iv_status = 'A' ).
    DATA(rs) = lo->validate_item( iv_year = '2026' iv_cat = 'PAC-E001' iv_subcat = 'PAC-E001.1'
                                  iv_item = '00001' iv_mandatory = abap_true ).
    cl_abap_unit_assert=>assert_true( rs-ok ).
    cl_abap_unit_assert=>assert_equals( act = rs-msgno exp = '000' ).
  ENDMETHOD.

ENDCLASS.
*"* use this source file for your ABAP unit test classes

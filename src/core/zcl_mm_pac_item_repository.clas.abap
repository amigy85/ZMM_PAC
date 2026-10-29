CLASS zcl_mm_pac_item_repository DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_mm_pac_item_repository .

  PRIVATE SECTION.
    CONSTANTS:
      c_tab    TYPE tabname    VALUE 'ZMM_PAC_ITEM',
      c_nr_obj TYPE inri-object VALUE 'ZMM_PAC',
      c_nr_int TYPE inri-nrrangenr VALUE '01'.
ENDCLASS.



CLASS zcl_mm_pac_item_repository IMPLEMENTATION.

  METHOD zif_mm_pac_item_repository~read_categories.
    SELECT mandt, pac_year, pac_cat, pac_cat_desc, status,
           valid_from, valid_to, ernam, erdat, erzet, aenam, aedat
      FROM zmm_pac_catg
      WHERE pac_year = @iv_year
      INTO CORRESPONDING FIELDS OF TABLE @rt_cat.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~read_subcategories.
    SELECT mandt, pac_year, pac_subcat, pac_cat, pac_subcat_desc,
           valid_from, valid_to, ernam, erdat, aenam, aedat, erzet
      FROM zmm_pac_subcatg
      WHERE pac_year = @iv_year
      INTO CORRESPONDING FIELDS OF TABLE @rt_subcat.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~lock_year.
    DATA lv_varkey TYPE rstable-varkey.
    lv_varkey = iv_year.
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable   = 'E'
        tabname        = c_tab
        varkey         = lv_varkey
        _scope         = '1'
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_mm_pac
        EXPORTING textid = zcx_mm_pac=>year_locked.
    ENDIF.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~unlock_year.
    DATA lv_varkey TYPE rstable-varkey.
    lv_varkey = iv_year.
    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        mode_rstable = 'E'
        tabname      = c_tab
        varkey       = lv_varkey
        _scope       = '1'.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~next_item_number.
    DATA lv_number TYPE nrlevel.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr             = c_nr_int
        object                  = c_nr_obj
      IMPORTING
        number                  = lv_number
      EXCEPTIONS
        interval_not_found      = 1
        number_range_not_intern = 2
        object_not_found        = 3
        quantity_is_0           = 4
        quantity_is_not_1       = 5
        interval_overflow       = 6
        buffer_overflow         = 7
        OTHERS                  = 8.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_mm_pac
        EXPORTING textid = zcx_mm_pac=>db_insert_failed.
    ENDIF.
    rv_item = lv_number.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~insert_new.
    TRY.
        INSERT zmm_pac_item FROM TABLE @it_item.
      CATCH cx_sy_open_sql_db.
        RAISE EXCEPTION TYPE zcx_mm_pac
          EXPORTING textid = zcx_mm_pac=>db_insert_failed.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~read_currencies.
    SELECT waers FROM tcurc INTO TABLE @rt_waers.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~read_plants.
    SELECT werks FROM t001w INTO TABLE @rt_werks.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~read_gl_accounts.
    " SKB1 tem buffering de registo individual; com chave parcial (só BUKRS) o
    " buffer não ajuda — ATC exige BYPASSING BUFFER (acesso directo à BD).
    SELECT saknr FROM skb1
      WHERE bukrs = @iv_bukrs
      INTO TABLE @rt_saknr
      BYPASSING BUFFER.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~normalize_uom.
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
      EXPORTING
        input          = iv_external
        language       = sy-langu
      IMPORTING
        output         = rv_internal
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc <> 0.
      CLEAR rv_internal.
    ENDIF.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~commit.
    COMMIT WORK.
  ENDMETHOD.


  METHOD zif_mm_pac_item_repository~rollback.
    ROLLBACK WORK.
  ENDMETHOD.

ENDCLASS.

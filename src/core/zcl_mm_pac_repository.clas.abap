CLASS zcl_mm_pac_repository DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_mm_pac_repository .

  PRIVATE SECTION.
    CONSTANTS c_tab TYPE tabname VALUE 'ZMM_PAC_CATG'.

    "! Argumento do bloqueio genérico: o ano (chave após MANDT).
    METHODS varkey
      IMPORTING iv_year      TYPE zmm_pac_year
      RETURNING VALUE(rv_key) TYPE string.
ENDCLASS.



CLASS zcl_mm_pac_repository IMPLEMENTATION.

  METHOD zif_mm_pac_repository~read_categories.
    SELECT mandt, pac_year, pac_cat, pac_cat_desc, status,
           valid_from, valid_to, ernam, erdat, erzet, aenam, aedat
      FROM zmm_pac_catg
      WHERE pac_year = @iv_year
      INTO CORRESPONDING FIELDS OF TABLE @rt_cat.
  ENDMETHOD.


  METHOD zif_mm_pac_repository~read_subcategories.
    SELECT mandt, pac_year, pac_subcat, pac_cat, pac_subcat_desc,
           valid_from, valid_to, ernam, erdat, aenam, aedat, erzet
      FROM zmm_pac_subcatg
      WHERE pac_year = @iv_year
      INTO CORRESPONDING FIELDS OF TABLE @rt_subcat.
  ENDMETHOD.


  METHOD zif_mm_pac_repository~lock_year.
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable   = 'E'
        tabname        = c_tab
        varkey         = varkey( iv_year )
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


  METHOD zif_mm_pac_repository~unlock_year.
    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        mode_rstable = 'E'
        tabname      = c_tab
        varkey       = varkey( iv_year )
        _scope       = '1'.
  ENDMETHOD.


  METHOD zif_mm_pac_repository~insert_new.
    " categorias antes das subcategorias (coerência FK); sem ACCEPTING DUPLICATE KEYS
    TRY.
        INSERT zmm_pac_catg    FROM TABLE @it_cat.
        INSERT zmm_pac_subcatg FROM TABLE @it_subcat.
      CATCH cx_sy_open_sql_db.
        RAISE EXCEPTION TYPE zcx_mm_pac
          EXPORTING textid = zcx_mm_pac=>db_insert_failed.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_mm_pac_repository~commit.
    COMMIT WORK.
  ENDMETHOD.


  METHOD zif_mm_pac_repository~rollback.
    ROLLBACK WORK.
  ENDMETHOD.


  METHOD varkey.
    rv_key = |{ iv_year }|.
  ENDMETHOD.

ENDCLASS.

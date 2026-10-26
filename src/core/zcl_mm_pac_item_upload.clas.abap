class ZCL_MM_PAC_ITEM_UPLOAD definition
  public
  create public .

public section.

  methods CONSTRUCTOR
    importing
      !IO_REPOSITORY type ref to ZIF_MM_PAC_ITEM_REPOSITORY
      !IO_AUTH type ref to ZCL_MM_PAC_AUTH
      !IO_PARSER type ref to ZCL_MM_PAC_ITEM_PARSER
      !IO_LOG type ref to ZCL_MM_PAC_LOG
      !IV_TODAY type DATS .
    "! Autoriza, lê/parsa e (modo Gravação) bloqueia + lê catálogo + valida + prepara
    "! os itens. NÃO grava nem consome números. Levanta ZCX_MM_PAC (050/051).
  methods PREPARE
    importing
      !IT_RAW type STRING_TABLE
      !IV_WRITE type ABAP_BOOL
    raising
      ZCX_MM_PAC .
    "! Zona sem diálogos: atribui PAC_ITEM (nº-range), INSERT + COMMIT.
  methods WRITE .
    "! Liberta o bloqueio (chamar sempre, também em excepção).
  methods RELEASE .
  methods GET_LOG
    returning
      value(RO_LOG) type ref to ZCL_MM_PAC_LOG .
  methods HAS_NEW
    returning
      value(RV_OK) type ABAP_BOOL .
  methods GET_SUMMARY
    exporting
      !EV_COUNT type I
      !EV_YEAR type ZMM_PAC_YEAR .
protected section.
  PRIVATE SECTION.
    DATA:
      mo_repository TYPE REF TO zif_mm_pac_item_repository,
      mo_auth       TYPE REF TO zcl_mm_pac_auth,
      mo_parser     TYPE REF TO zcl_mm_pac_item_parser,
      mo_log        TYPE REF TO zcl_mm_pac_log,
      mv_today      TYPE dats,
      mv_write      TYPE abap_bool,
      mv_year       TYPE zmm_pac_year,
      mv_locked     TYPE abap_bool,
      mt_item       TYPE zif_mm_pac_types=>tt_item.
ENDCLASS.



CLASS ZCL_MM_PAC_ITEM_UPLOAD IMPLEMENTATION.


  METHOD constructor.
    mo_repository = io_repository.
    mo_auth       = io_auth.
    mo_parser     = io_parser.
    mo_log        = io_log.
    mv_today      = iv_today.
  ENDMETHOD.


  METHOD get_log.
    ro_log = mo_log.
  ENDMETHOD.


  METHOD get_summary.
    ev_count = lines( mt_item ).
    ev_year  = mv_year.
  ENDMETHOD.


  METHOD has_new.
    rv_ok = xsdbool( mt_item IS NOT INITIAL ).
  ENDMETHOD.


  METHOD prepare.
    mv_write = iv_write.
    CLEAR: mt_item, mv_year, mv_locked.

    mo_auth->check( zcl_mm_pac_auth=>c_actvt_display ).

    mo_parser->parse( EXPORTING it_raw  = it_raw
                      IMPORTING et_rows = DATA(lt_rows)
                                et_msg  = DATA(lt_pmsg) ).
    mo_log->add_many( lt_pmsg ).
    IF mo_log->has_errors( ) = abap_true.
      mo_log->add( iv_type = 'E' iv_no = '061' iv_v1 = |{ mo_log->num_errors( ) }| ).
      RETURN.
    ENDIF.
    IF lt_rows IS INITIAL.
      RETURN.
    ENDIF.

    IF matches( val = lt_rows[ 1 ]-pac_year regex = `^[0-9]{4}$` ).
      mv_year = lt_rows[ 1 ]-pac_year.
    ENDIF.

    IF mv_write = abap_true.
      mo_auth->check( zcl_mm_pac_auth=>c_actvt_create ).
      IF mv_year IS NOT INITIAL.
        mo_repository->lock_year( mv_year ).
        mv_locked = abap_true.
      ENDIF.
    ENDIF.

    DATA(lo_validator) = NEW zcl_mm_pac_item_validator( iv_today = mv_today io_log = mo_log ).
    lo_validator->validate(
      EXPORTING it_rows            = lt_rows
                it_existing_cat    = mo_repository->read_categories( mv_year )
                it_existing_subcat = mo_repository->read_subcategories( mv_year )
      IMPORTING et_item            = DATA(lt_item) ).

    IF mo_log->has_errors( ) = abap_false.
      DATA(lo_changeset) = NEW zcl_mm_pac_item_changeset( iv_erdat = mv_today iv_erzet = sy-uzeit ).
      lo_changeset->build( EXPORTING it_item = lt_item IMPORTING et_item = mt_item ).
      IF mv_write = abap_false.
        mo_log->add( iv_type = 'S' iv_no = '060' ).
      ENDIF.
    ELSE.
      mo_log->add( iv_type = 'E' iv_no = '061' iv_v1 = |{ mo_log->num_errors( ) }| ).
    ENDIF.
  ENDMETHOD.


  METHOD release.
    IF mv_locked = abap_true.
      mo_repository->unlock_year( mv_year ).
      mv_locked = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD write.
    IF mv_write = abap_false.
      RETURN.                                   " simulação nunca grava (REQ-20)
    ENDIF.
    IF mo_log->has_errors( ) = abap_true.
      RETURN.                                   " nunca grava com erros
    ENDIF.
    IF mt_item IS INITIAL.
      mo_log->add( iv_type = 'S' iv_no = '087' ).   " nada a gravar
      RETURN.
    ENDIF.

    TRY.
        " atribui o nº de item (intervalo de números) só na gravação
        LOOP AT mt_item ASSIGNING FIELD-SYMBOL(<i>).
          <i>-pac_item = mo_repository->next_item_number( ).
        ENDLOOP.
        mo_repository->insert_new( mt_item ).
        mo_repository->commit( ).
        mo_log->add( iv_type = 'S' iv_no = '086'
                     iv_v1 = |{ mv_year }| iv_v2 = |{ lines( mt_item ) }| ).
      CATCH zcx_mm_pac.
        mo_repository->rollback( ).
        mo_log->add( iv_type = 'E' iv_no = '063' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

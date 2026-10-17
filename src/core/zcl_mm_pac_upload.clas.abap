CLASS zcl_mm_pac_upload DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_repository TYPE REF TO zif_mm_pac_repository
                io_auth       TYPE REF TO zcl_mm_pac_auth
                io_parser     TYPE REF TO zcl_mm_pac_parser
                io_log        TYPE REF TO zcl_mm_pac_log
                iv_today      TYPE dats.

    "! Autoriza, lê/parsa e (modo Gravação) bloqueia + lê BD + valida + prepara o
    "! changeset. NÃO grava. Levanta ZCX_MM_PAC em falta de autorização (050) ou
    "! ano bloqueado (051).
    METHODS prepare
      IMPORTING it_raw   TYPE string_table
                iv_write TYPE abap_bool
      RAISING   zcx_mm_pac.

    "! Zona sem diálogos: INSERT + COMMIT. Só grava em modo Gravação, sem erros e
    "! com registos novos. Falha de BD -> ROLLBACK + mensagem 063.
    METHODS write.

    "! Liberta o bloqueio (chamar sempre, também em excepção).
    METHODS release.

    METHODS get_log
      RETURNING VALUE(ro_log) TYPE REF TO zcl_mm_pac_log.
    METHODS has_new
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    "! Contagens dos registos novos a gravar (para o popup de confirmação 066).
    METHODS get_summary
      EXPORTING ev_cat    TYPE i
                ev_subcat TYPE i
                ev_year   TYPE zmm_pac_year.

  PRIVATE SECTION.
    DATA:
      mo_repository TYPE REF TO zif_mm_pac_repository,
      mo_auth       TYPE REF TO zcl_mm_pac_auth,
      mo_parser     TYPE REF TO zcl_mm_pac_parser,
      mo_log        TYPE REF TO zcl_mm_pac_log,
      mv_today      TYPE dats,
      mv_write      TYPE abap_bool,
      mv_year       TYPE zmm_pac_year,
      mv_locked     TYPE abap_bool,
      mt_cat        TYPE zif_mm_pac_types=>tt_catg,
      mt_subcat     TYPE zif_mm_pac_types=>tt_subcatg.
ENDCLASS.



CLASS zcl_mm_pac_upload IMPLEMENTATION.

  METHOD constructor.
    mo_repository = io_repository.
    mo_auth       = io_auth.
    mo_parser     = io_parser.
    mo_log        = io_log.
    mv_today      = iv_today.
  ENDMETHOD.


  METHOD prepare.
    mv_write = iv_write.
    CLEAR: mt_cat, mt_subcat, mv_year, mv_locked.

    " autorização para simular/consultar (REQ-15)
    mo_auth->check( zcl_mm_pac_auth=>c_actvt_display ).

    " estrutura do ficheiro (REQ-02)
    mo_parser->parse( EXPORTING it_raw  = it_raw
                      IMPORTING et_rows = DATA(lt_rows)
                                et_msg  = DATA(lt_pmsg) ).
    mo_log->add_many( lt_pmsg ).
    IF mo_log->has_errors( ) = abap_true OR lt_rows IS INITIAL.
      RETURN.
    ENDIF.

    " ano do ficheiro (só se 4 dígitos -> evita dump na conversão para NUMC)
    IF matches( val = lt_rows[ 1 ]-pac_year regex = `^[0-9]{4}$` ).
      mv_year = lt_rows[ 1 ]-pac_year.
    ENDIF.

    " modo Gravação: autorização de gravação + bloqueio antes de ler a BD (REQ-13/15)
    IF mv_write = abap_true.
      mo_auth->check( zcl_mm_pac_auth=>c_actvt_create ).
      IF mv_year IS NOT INITIAL.
        mo_repository->lock_year( mv_year ).
        mv_locked = abap_true.
      ENDIF.
    ENDIF.

    " estado da BD + validação (REQ-03..09)
    DATA(lo_validator) = NEW zcl_mm_pac_validator( iv_today = mv_today io_log = mo_log ).
    lo_validator->validate(
      EXPORTING it_rows            = lt_rows
                it_existing_cat    = mo_repository->read_categories( mv_year )
                it_existing_subcat = mo_repository->read_subcategories( mv_year )
      IMPORTING et_cat             = DATA(lt_cat)
                et_subcat          = DATA(lt_sub) ).

    " changeset (carimbo único) — só sem erros
    IF mo_log->has_errors( ) = abap_false.
      DATA(lo_changeset) = NEW zcl_mm_pac_changeset( iv_erdat = mv_today iv_erzet = sy-uzeit ).
      lo_changeset->build( EXPORTING it_cat    = lt_cat
                                     it_subcat = lt_sub
                           IMPORTING et_cat    = mt_cat
                                     et_subcat = mt_subcat ).
      IF mv_write = abap_false.
        mo_log->add( iv_type = 'S' iv_no = '060' ).
      ENDIF.
    ELSE.
      mo_log->add( iv_type = 'E' iv_no = '061' iv_v1 = |{ mo_log->num_errors( ) }| ).
    ENDIF.
  ENDMETHOD.


  METHOD write.
    IF mv_write = abap_false.
      RETURN.                                   " simulação nunca grava (REQ-10)
    ENDIF.
    IF mo_log->has_errors( ) = abap_true.
      RETURN.                                   " nunca grava com erros (INV-6)
    ENDIF.
    IF mt_cat IS INITIAL AND mt_subcat IS INITIAL.
      mo_log->add( iv_type = 'S' iv_no = '065' ).   " nada a gravar (REQ-12)
      RETURN.
    ENDIF.

    TRY.
        mo_repository->insert_new( it_cat    = mt_cat
                                   it_subcat = mt_subcat ).
        mo_repository->commit( ).
        mo_log->add( iv_type = 'S' iv_no = '062'
                     iv_v1 = |{ mv_year }|
                     iv_v2 = |{ lines( mt_cat ) }|
                     iv_v3 = |{ lines( mt_subcat ) }| ).
      CATCH zcx_mm_pac.
        mo_repository->rollback( ).
        mo_log->add( iv_type = 'E' iv_no = '063' ).
    ENDTRY.
  ENDMETHOD.


  METHOD release.
    IF mv_locked = abap_true.
      mo_repository->unlock_year( mv_year ).
      mv_locked = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD get_log.
    ro_log = mo_log.
  ENDMETHOD.


  METHOD has_new.
    rv_ok = xsdbool( mt_cat IS NOT INITIAL OR mt_subcat IS NOT INITIAL ).
  ENDMETHOD.

  METHOD get_summary.
    ev_cat    = lines( mt_cat ).
    ev_subcat = lines( mt_subcat ).
    ev_year   = mv_year.
  ENDMETHOD.

ENDCLASS.

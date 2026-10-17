*&---------------------------------------------------------------------*
*& Report ZMM_PAC_UPLOAD
*& Upload do catálogo do Plano Anual de Compras (categorias/subcategorias).
*& Só este programa conhece ecrãs; a lógica vive em ZCL_MM_PAC_UPLOAD.
*&---------------------------------------------------------------------*
REPORT zmm_pac_upload.

SELECTION-SCREEN BEGIN OF BLOCK b_file WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_file TYPE rlgrap-filename LOWER CASE.
SELECTION-SCREEN END OF BLOCK b_file.

SELECTION-SCREEN BEGIN OF BLOCK b_mode WITH FRAME TITLE TEXT-b02.
  PARAMETERS: p_sim RADIOBUTTON GROUP mode DEFAULT 'X',
              p_upd RADIOBUTTON GROUP mode.
SELECTION-SCREEN END OF BLOCK b_mode.

SELECTION-SCREEN BEGIN OF BLOCK b_out WITH FRAME TITLE TEXT-b03.
  PARAMETERS p_ewonly AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b_out.


CLASS lcl_app DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS f4.
    CLASS-METHODS run.
  PRIVATE SECTION.
    CLASS-METHODS confirm
      IMPORTING io_upload    TYPE REF TO zcl_mm_pac_upload
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    CLASS-METHODS display
      IMPORTING io_log TYPE REF TO zcl_mm_pac_log.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD f4.
    p_file = NEW zcl_mm_pac_file( )->f4_filename( ).
  ENDMETHOD.

  METHOD run.
    " REQ-17: o upload não corre em fundo
    IF sy-batch = abap_true.
      MESSAGE e052(zmm_pac).
      RETURN.
    ENDIF.

    " leitura do posto de trabalho (cp1252)
    DATA lv_failed TYPE abap_bool.
    DATA(lo_file) = NEW zcl_mm_pac_file( ).
    DATA(lt_raw)  = lo_file->read( EXPORTING iv_name   = CONV string( p_file )
                                   IMPORTING ev_failed = lv_failed ).
    IF lv_failed = abap_true.
      MESSAGE e002(zmm_pac) WITH p_file.
      RETURN.
    ENDIF.

    DATA(lo_log)    = NEW zcl_mm_pac_log( ).
    DATA(lo_upload) = NEW zcl_mm_pac_upload(
      io_repository = NEW zcl_mm_pac_repository( )
      io_auth       = NEW zcl_mm_pac_auth( )
      io_parser     = NEW zcl_mm_pac_parser( )
      io_log        = lo_log
      iv_today      = sy-datum ).

    TRY.
        lo_upload->prepare( it_raw = lt_raw iv_write = p_upd ).

        IF p_upd = abap_true
           AND lo_upload->has_new( ) = abap_true
           AND lo_log->has_errors( ) = abap_false.
          IF confirm( lo_upload ) = abap_true.
            lo_upload->write( ).
          ELSE.
            lo_log->add( iv_type = 'S' iv_no = '064' ).   " gravação cancelada
          ENDIF.
        ENDIF.

      CATCH zcx_mm_pac INTO DATA(lx).
        " autorização (050) / ano bloqueado (051)
        lo_log->add( iv_type = 'E' iv_no = lx->if_t100_message~t100key-msgno ).
    ENDTRY.

    lo_upload->release( ).
    display( lo_log ).
  ENDMETHOD.

  METHOD confirm.
    DATA lv_answer TYPE c LENGTH 1.
    DATA lv_text   TYPE string.

    io_upload->get_summary( IMPORTING ev_cat    = DATA(lv_cat)
                                      ev_subcat = DATA(lv_sub)
                                      ev_year   = DATA(lv_year) ).
    MESSAGE i066(zmm_pac) WITH lv_cat lv_sub lv_year INTO lv_text.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = CONV string( TEXT-t01 )
        text_question         = lv_text
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        OTHERS                = 1.

    rv_ok = xsdbool( sy-subrc = 0 AND lv_answer = '1' ).
  ENDMETHOD.

  METHOD display.
    DATA(lt_msg) = io_log->get_messages( ).
    IF p_ewonly = abap_true.
      DELETE lt_msg WHERE msgty <> 'E' AND msgty <> 'W'.
    ENDIF.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_salv)
                                CHANGING  t_table      = lt_msg ).
        lo_salv->get_functions( )->set_all( abap_true ).
        lo_salv->get_columns( )->set_optimize( abap_true ).
        lo_salv->display( ).
      CATCH cx_salv_msg.
        " sem ALV: nada a fazer (as mensagens já estão no log)
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  lcl_app=>f4( ).

AT SELECTION-SCREEN.
  IF p_file IS INITIAL.
    MESSAGE e001(zmm_pac).
  ENDIF.

START-OF-SELECTION.
  lcl_app=>run( ).

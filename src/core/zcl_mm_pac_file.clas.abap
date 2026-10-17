CLASS zcl_mm_pac_file DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    "! Diálogo F4 para escolher o ficheiro CSV no posto de trabalho.
    METHODS f4_filename
      RETURNING VALUE(rv_name) TYPE string.

    "! Lê o ficheiro do posto de trabalho em Windows-1252 (cp1252, D-06/A1),
    "! uma linha física por registo. ev_failed = 'X' se a leitura falhar (002).
    METHODS read
      IMPORTING iv_name       TYPE string
      EXPORTING ev_failed     TYPE abap_bool
      RETURNING VALUE(rt_raw) TYPE string_table.
ENDCLASS.



CLASS zcl_mm_pac_file IMPLEMENTATION.

  METHOD f4_filename.
    DATA: lt_files  TYPE filetable,
          lv_rc     TYPE i,
          lv_action TYPE i.

    cl_gui_frontend_services=>file_open_dialog(
      EXPORTING
        default_extension = 'csv'
        file_filter       = 'CSV (*.csv)|*.csv|Todos (*.*)|*.*'
        multiselection    = abap_false
      CHANGING
        file_table        = lt_files
        rc                = lv_rc
        user_action       = lv_action
      EXCEPTIONS
        OTHERS            = 1 ).

    IF sy-subrc = 0
       AND lv_action = cl_gui_frontend_services=>action_ok
       AND line_exists( lt_files[ 1 ] ).
      rv_name = lt_files[ 1 ]-filename.
    ENDIF.
  ENDMETHOD.


  METHOD read.
    CLEAR ev_failed.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename = iv_name
        filetype = 'ASC'
        codepage = '1160'            " Windows-1252 (ANSI)
      CHANGING
        data_tab = rt_raw
      EXCEPTIONS
        OTHERS   = 1 ).

    IF sy-subrc <> 0.
      ev_failed = abap_true.
      CLEAR rt_raw.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

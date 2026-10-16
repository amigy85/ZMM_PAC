CLASS zcl_mm_pac_log DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    "! Constrói o texto a partir da classe de mensagens ZMM_PAC e regista a mensagem.
    METHODS add
      IMPORTING iv_type TYPE symsgty
                iv_no   TYPE symsgno
                iv_row  TYPE i     DEFAULT 0
                iv_v1   TYPE clike OPTIONAL
                iv_v2   TYPE clike OPTIONAL
                iv_v3   TYPE clike OPTIONAL
                iv_v4   TYPE clike OPTIONAL.

    "! Junta um conjunto de mensagens já formadas (ex.: saída do parser).
    METHODS add_many
      IMPORTING it_msg TYPE zif_mm_pac_types=>tt_msg.

    METHODS get_messages
      RETURNING VALUE(rt_msg) TYPE zif_mm_pac_types=>tt_msg.

    "! Nº de mensagens de erro (tipos E e A).
    METHODS num_errors
      RETURNING VALUE(rv) TYPE i.

    "! Nº de avisos (tipo W).
    METHODS num_warnings
      RETURNING VALUE(rv) TYPE i.

    METHODS has_errors
      RETURNING VALUE(rv) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mt_msg TYPE zif_mm_pac_types=>tt_msg.
ENDCLASS.



CLASS zcl_mm_pac_log IMPLEMENTATION.

  METHOD add.
    DATA lv_text TYPE string.
    MESSAGE ID 'ZMM_PAC' TYPE iv_type NUMBER iv_no
            WITH iv_v1 iv_v2 iv_v3 iv_v4 INTO lv_text.
    APPEND VALUE #( msgty = iv_type
                    msgno = iv_no
                    row   = iv_row
                    text  = lv_text ) TO mt_msg.
  ENDMETHOD.

  METHOD add_many.
    APPEND LINES OF it_msg TO mt_msg.
  ENDMETHOD.

  METHOD get_messages.
    rt_msg = mt_msg.
  ENDMETHOD.

  METHOD num_errors.
    LOOP AT mt_msg TRANSPORTING NO FIELDS WHERE msgty = 'E' OR msgty = 'A'.
      rv = rv + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD num_warnings.
    LOOP AT mt_msg TRANSPORTING NO FIELDS WHERE msgty = 'W'.
      rv = rv + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD has_errors.
    rv = xsdbool( num_errors( ) > 0 ).
  ENDMETHOD.

ENDCLASS.

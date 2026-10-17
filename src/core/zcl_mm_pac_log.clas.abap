class ZCL_MM_PAC_LOG definition
  public
  create public .

public section.

    "! Constrói o texto a partir da classe de mensagens ZMM_PAC e regista a mensagem.
  methods ADD
    importing
      !IV_TYPE type SYMSGTY
      !IV_NO type SYMSGNO
      !IV_ROW type I default 0
      !IV_V1 type CLIKE optional
      !IV_V2 type CLIKE optional
      !IV_V3 type CLIKE optional
      !IV_V4 type CLIKE optional .
    "! Junta um conjunto de mensagens já formadas (ex.: saída do parser).
  methods ADD_MANY
    importing
      !IT_MSG type ZIF_MM_PAC_TYPES=>TT_MSG .
  methods GET_MESSAGES
    returning
      value(RT_MSG) type ZIF_MM_PAC_TYPES=>TT_MSG .
    "! Nº de mensagens de erro (tipos E e A).
  methods NUM_ERRORS
    returning
      value(RV) type I .
    "! Nº de avisos (tipo W).
  methods NUM_WARNINGS
    returning
      value(RV) type I .
  methods HAS_ERRORS
    returning
      value(RV) type ABAP_BOOL .
protected section.
  PRIVATE SECTION.
    DATA mt_msg TYPE zif_mm_pac_types=>tt_msg.
ENDCLASS.



CLASS ZCL_MM_PAC_LOG IMPLEMENTATION.


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


  METHOD has_errors.
    rv = xsdbool( num_errors( ) > 0 ).
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
ENDCLASS.

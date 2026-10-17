CLASS zcl_mm_pac_auth DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS:
      c_actvt_display TYPE activ_auth VALUE '03',   " simular / consultar (REQ-15)
      c_actvt_create  TYPE activ_auth VALUE '01'.   " gravar

    "! Verifica a autorização para a actividade; se faltar -> ZCX_MM_PAC (050).
    METHODS check
      IMPORTING iv_actvt TYPE activ_auth
      RAISING   zcx_mm_pac.

  PROTECTED SECTION.
    "! Executa o AUTHORITY-CHECK e devolve o sy-subrc. Redefinível nos testes
    "! (duplo por herança) para simular autorizado/negado sem autorizações reais.
    METHODS authority_check
      IMPORTING iv_actvt        TYPE activ_auth
      RETURNING VALUE(rv_subrc) TYPE i.
ENDCLASS.



CLASS zcl_mm_pac_auth IMPLEMENTATION.

  METHOD check.
    IF authority_check( iv_actvt ) <> 0.
      RAISE EXCEPTION TYPE zcx_mm_pac
        EXPORTING textid = zcx_mm_pac=>no_authorization.
    ENDIF.
  ENDMETHOD.

  METHOD authority_check.
    AUTHORITY-CHECK OBJECT 'ZMM_PAC' ID 'ACTVT' FIELD iv_actvt.
    rv_subrc = sy-subrc.
  ENDMETHOD.

ENDCLASS.

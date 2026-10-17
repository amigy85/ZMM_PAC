class ZCL_MM_PAC_AUTH definition
  public
  create public .

public section.

  constants C_ACTVT_DISPLAY type ACTIV_AUTH value '03' ##NO_TEXT. " simular / consultar (REQ-15)
  constants C_ACTVT_CREATE type ACTIV_AUTH value '01' ##NO_TEXT. " gravar

    "! Verifica a autorização para a actividade; se faltar -> ZCX_MM_PAC (050).
  methods CHECK
    importing
      !IV_ACTVT type ACTIV_AUTH
    raising
      ZCX_MM_PAC .
  PROTECTED SECTION.
    "! Executa o AUTHORITY-CHECK e devolve o sy-subrc. Redefinível nos testes
    "! (duplo por herança) para simular autorizado/negado sem autorizações reais.
    METHODS authority_check
      IMPORTING iv_actvt        TYPE activ_auth
      RETURNING VALUE(rv_subrc) TYPE i.
private section.
ENDCLASS.



CLASS ZCL_MM_PAC_AUTH IMPLEMENTATION.


  METHOD authority_check.
    AUTHORITY-CHECK OBJECT 'ZMM_PAC' ID 'ACTVT' FIELD iv_actvt.
    rv_subrc = sy-subrc.
  ENDMETHOD.


  METHOD check.
    IF authority_check( iv_actvt ) <> 0.
      RAISE EXCEPTION TYPE zcx_mm_pac
        EXPORTING textid = zcx_mm_pac=>no_authorization.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

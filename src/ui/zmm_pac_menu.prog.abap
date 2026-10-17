*&---------------------------------------------------------------------*
*& Report ZMM_PAC_MENU
*& Lançador do Plano Anual de Compras (ADR-05).
*& Mudança 1: só o carregamento (upload). Consulta/manutenção entram nas
*& mudanças 2/3, acrescentando aqui novos botões.
*&---------------------------------------------------------------------*
REPORT zmm_pac_menu.

*DATA pb_up TYPE smp_dyntxt.

SELECTION-SCREEN BEGIN OF BLOCK b_menu WITH FRAME TITLE TEXT-b01.
  SELECTION-SCREEN PUSHBUTTON /1(40) pb_up USER-COMMAND upld.
SELECTION-SCREEN END OF BLOCK b_menu.



INITIALIZATION.
   pb_up = TEXT-p01.

AT SELECTION-SCREEN.
  IF sy-ucomm = 'UPLD'.
    CALL TRANSACTION 'ZMM_PAC_UPLOAD'.
  ENDIF.

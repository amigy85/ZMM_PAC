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
  SELECTION-SCREEN SKIP.
  SELECTION-SCREEN PUSHBUTTON /1(40) pb_it USER-COMMAND itup.
SELECTION-SCREEN END OF BLOCK b_menu.



INITIALIZATION.
  pb_up = TEXT-p01.
  pb_it = TEXT-p02.

AT SELECTION-SCREEN.
  CASE sy-ucomm.
    WHEN 'UPLD'.
      CALL TRANSACTION 'ZMM_PAC_UPLOAD'.
    WHEN 'ITUP'.
      CALL TRANSACTION 'ZMM_PAC_ITEM_UPLOAD'.
  ENDCASE.

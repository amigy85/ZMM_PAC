*&---------------------------------------------------------------------*
*& IF_EX_ME_PROCESS_REQ_CUST~CHECK (ZCL_IM_ME_PROCESS_REQ_CUST, pacote ZMM)
*& Versao com a validacao PAC (mudanca 4) + limpeza (opcao C):
*&   PAC  : validacao bloqueante da atribuicao PAC (REQ-30..REQ-33)
*&   F1   : SELECT em ZREQ lido uma vez por item (era 2x)
*&   F2   : mensagens 041 usam i_act_items2-banfn (era gs_eban-banfn, vazio)
*&   F3   : removido bloco comentado "orcamento de funcionamento" + DATA nao usada
*& Lógica legada preservada (knttp/werks/pstyp/afnam, centro de custo, ME22N vs PO, matkl).
*& Entrega por TRANSPORTE. Partes alteradas validadas via syntaxCheckCode (ADT).
*&---------------------------------------------------------------------*
METHOD if_ex_me_process_req_cust~check.

  INCLUDE mm_messages_mac.

  DATA: gs_zrqccusto TYPE zrqccusto.

  DATA: t_item       TYPE mmpur_requisition_items,
        w_item       TYPE mmpur_requisition_item,
        lt_acct_ref  TYPE mmpur_accounting_list,
        ls_acct_ref  TYPE mmpur_accounting_type,
        i_act_items  TYPE mereq_item,
        wa_exkn      TYPE exkn,
        ref          TYPE REF TO if_purchase_requisition_item,
        ref2         TYPE REF TO if_accounting_model_mm,
        t_itemdata   TYPE STANDARD TABLE OF mereq_item,
        w_itemdata   TYPE mereq_item,
        i_act_items2 TYPE mereq_header.

  DATA: lv_knttp TYPE knttp,
        lv_pstyp TYPE pstyp,
        lv_werks TYPE werks,
        lv_afnam TYPE afnam,
        ls_afnam TYPE afnam,
        lv_tabix TYPE sy-tabix,
        lv_cont  TYPE sy-tabix,
        lv_len   TYPE i.

  DATA: r_knttp  TYPE RANGE OF mereq_item-knttp,
        rs_knttp LIKE LINE OF r_knttp.

  " verificar RC com PO ou solicitacao (ME22N)
  TYPES: BEGIN OF ty_s_di.
           INCLUDE TYPE mereq_item.
  TYPES:   chind TYPE bu_chind.
  TYPES: END OF ty_s_di.
  DATA: gt_pbo   TYPE STANDARD TABLE OF ty_s_di,
        gt_pai   TYPE STANDARD TABLE OF ty_s_di,
        ls_struc TYPE ty_s_di.
  FIELD-SYMBOLS: <ld_chind> TYPE bu_chind,
                 <ls_di>    TYPE any.

  " validacao PAC (mudanca 4)
  DATA: lo_pac_val  TYPE REF TO zcl_mm_pac_req_validator,
        lv_pac_mand TYPE abap_bool.

  rs_knttp-sign = 'I'. rs_knttp-option = 'EQ'. rs_knttp-low = 'K'.
  APPEND rs_knttp TO r_knttp.
  CLEAR rs_knttp.
  rs_knttp-sign = 'I'. rs_knttp-option = 'EQ'. rs_knttp-low = 'F'.
  APPEND rs_knttp TO r_knttp.

  lv_cont = 1.

  CALL METHOD im_header->get_data  RECEIVING re_data  = i_act_items2.
  CALL METHOD im_header->get_items RECEIVING re_items = t_item.

  " PAC obrigatorio p/ metodos formais (ZMANB in CP/CL/AD/DF); opcional em NS/vazio
  lv_pac_mand = xsdbool( i_act_items2-zmanb IS NOT INITIAL AND i_act_items2-zmanb <> 'NS' ).
  lo_pac_val  = NEW zcl_mm_pac_req_validator( NEW zcl_mm_pac_req_reader( ) ).

* 1.ª passagem: validacao de material/classificacao + recolha p/ comparacao ME22N
  LOOP AT t_item INTO w_item.
    ref = w_item-item.
    CALL METHOD ref->get_data RECEIVING re_data = i_act_items.

    IF i_act_items-matnr = ' '
      AND i_act_items-pstyp NE 9
      AND i_act_items-knttp NE ' '
      AND i_act_items-loekz EQ ' '.
      mmpur_message 'E' 'ZMM' '027' space space space space.
    ENDIF.

    APPEND i_act_items TO gt_pai.
    APPEND i_act_items TO t_itemdata.
  ENDLOOP.

* 2.ª passagem: coerencia knttp/werks/pstyp/requisitante, centro de custo e PAC
  LOOP AT t_item INTO w_item.
    lv_tabix = sy-tabix.
    ref = w_item-item.
    CALL METHOD ref->get_data RECEIVING re_data = i_act_items.

    lt_acct_ref = w_item-item->if_acct_container_mm~get_items( ).
    LOOP AT lt_acct_ref INTO ls_acct_ref.
      ref2 = ls_acct_ref-model.
      CALL METHOD ref2->get_exkn RECEIVING re_exkn = wa_exkn.
    ENDLOOP.

    " F1: requisitante (zzunorg) lido uma vez por item
    CLEAR ls_afnam.
    SELECT SINGLE zzunorg INTO ls_afnam FROM zreq WHERE afnam = i_act_items-afnam.
    DATA(lv_req_found) = xsdbool( sy-subrc = 0 ).

    IF i_act_items-loekz EQ ' '.
      IF lv_tabix = lv_cont.
        IF lv_req_found = abap_true.
          lv_afnam = ls_afnam.
        ENDIF.
        lv_knttp = i_act_items-knttp.
        lv_pstyp = i_act_items-pstyp.
        lv_werks = i_act_items-werks.
      ENDIF.
    ELSE.
      ADD 1 TO lv_cont.
    ENDIF.

    IF i_act_items-knttp NE lv_knttp.
      IF ( i_act_items-knttp NOT IN r_knttp OR lv_knttp NOT IN r_knttp )
         AND i_act_items-pstyp NE 7
         AND i_act_items-loekz EQ ' '.
        mmpur_message 'E' 'ZMM' '016' space space space space.
      ENDIF.
    ENDIF.

    IF i_act_items-werks NE lv_werks AND i_act_items-loekz EQ ' '.
      mmpur_message 'E' 'ZMM' '014' space space space space.
    ENDIF.

    IF i_act_items-pstyp NE lv_pstyp
       AND i_act_items-knttp NE 'A'
       AND i_act_items-loekz EQ ' '.
      mmpur_message 'E' 'ZMM' '015' space space space space.
    ENDIF.

    IF ls_afnam NE lv_afnam
       AND i_act_items-pstyp NE 7
       AND i_act_items-loekz EQ ' '.
      mmpur_message 'E' 'ZMM' '013' space space space space.
    ENDIF.

    " centro de custo (knttp K, pstyp 9 ou 0)
    IF ( i_act_items-knttp = 'K' AND i_act_items-pstyp = '9' AND i_act_items-loekz EQ ' ' )
    OR ( i_act_items-knttp = 'K' AND i_act_items-pstyp = '0' AND i_act_items-loekz EQ ' ' ).
      CLEAR wa_exkn.
      lt_acct_ref = w_item-item->if_acct_container_mm~get_items( ).
      LOOP AT lt_acct_ref INTO ls_acct_ref.
        ref2 = ls_acct_ref-model.
        CALL METHOD ref2->get_exkn RECEIVING re_exkn = wa_exkn.
        SELECT SINGLE bname INTO gs_zrqccusto-bname FROM zrqccusto
          WHERE kostl = wa_exkn-kostl.
        IF wa_exkn-kostl <> ''.
          IF sy-subrc <> 0.
            MESSAGE e047(zmm) WITH wa_exkn-kostl.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " PAC (mudanca 4): so itens nao eliminados; reutiliza i_act_items
    IF i_act_items-loekz IS INITIAL.
      DATA(ls_pac_v) = lo_pac_val->validate_item(
          iv_year      = i_act_items-pac_year
          iv_cat       = i_act_items-pac_cat
          iv_subcat    = i_act_items-pac_subcat
          iv_item      = i_act_items-pac_item
          iv_mandatory = lv_pac_mand ).
      IF ls_pac_v-ok = abap_false.
        mmpur_message 'E' 'ZMM_PAC' ls_pac_v-msgno
                      ls_pac_v-msgv1 ls_pac_v-msgv2 ls_pac_v-msgv3 space.
      ENDIF.
    ENDIF.
  ENDLOOP.

* Verificar se tem Sol. Cotacao ou PO (DSI-AA 27.04.2020)
  IF sy-tcode = 'ME22N' OR sy-tcode = 'ME22'.

    SELECT * FROM eban INTO CORRESPONDING FIELDS OF TABLE gt_pbo
      WHERE banfn = i_act_items2-banfn.

    LOOP AT t_itemdata INTO w_itemdata.
      IF w_itemdata-statu EQ 'A' OR w_itemdata-statu EQ 'B'.

        CALL FUNCTION 'CHANGEDOCUMENT_PREPARE_TABLES'
          EXPORTING
            check_indicator        = abap_false
            tablename              = 'EBAN'
          TABLES
            table_new              = gt_pai
            table_old              = gt_pbo
          EXCEPTIONS
            nametab_error          = 1
            wrong_structure_length = 2
            OTHERS                 = 3.

        IF gt_pai IS NOT INITIAL AND gt_pbo IS NOT INITIAL.

          LOOP AT gt_pai ASSIGNING <ls_di>.          " INSERT & UPDATE
            MOVE-CORRESPONDING <ls_di> TO ls_struc.
            ASSIGN COMPONENT 'CHIND' OF STRUCTURE <ls_di> TO <ld_chind>.
            CASE <ld_chind>.
              WHEN 'I'.
              WHEN 'U'.
                SELECT menge FROM ekpo INTO @DATA(w_menge)
                   WHERE banfn = @i_act_items2-banfn
                     AND bnfpo = @ls_struc-bnfpo
                     AND loekz = ' '.
                  IF ls_struc-menge > w_menge.
                    mmpur_message 'E' 'ZMM' '041' i_act_items2-banfn space space space.
                  ENDIF.
                ENDSELECT.
              WHEN OTHERS.
                CONTINUE.
            ENDCASE.
          ENDLOOP.

          LOOP AT gt_pbo INTO <ls_di>.               " DELETE
            MOVE-CORRESPONDING <ls_di> TO ls_struc.
            ASSIGN COMPONENT 'CHIND' OF STRUCTURE <ls_di> TO <ld_chind>.
            CASE <ld_chind>.
              WHEN 'D'.
                SELECT * FROM ekpo INTO TABLE @DATA(wa_ekpo)
                   WHERE banfn = @i_act_items2-banfn
                     AND bnfpo = @ls_struc-bnfpo
                     AND loekz = ' '.
                IF sy-subrc = 0.
                  mmpur_message 'E' 'ZMM' '041' i_act_items2-banfn space space space.
                ENDIF.
              WHEN OTHERS.
                CONTINUE.
            ENDCASE.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDIF.

  lv_len = strlen( i_act_items-matkl ).
  IF lv_len = 2 AND i_act_items-loekz EQ ' '.
    MESSAGE e020(zmm) WITH i_act_items-matkl.
  ENDIF.

ENDMETHOD.

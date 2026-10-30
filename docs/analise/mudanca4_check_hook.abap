*&---------------------------------------------------------------------*
*& Gancho PAC — colar no FIM do método IF_EX_ME_PROCESS_REQ_CUST~CHECK
*& da classe ZCL_IM_ME_PROCESS_REQ_CUST (pacote ZMM), antes de ENDMETHOD.
*& Entrega por TRANSPORTE (objecto fora do repo abapGit). Tarefa 3.1.
*& Requer: INCLUDE mm_messages_mac já presente no CHECK (está) e as classes
*& ZCL_MM_PAC_REQ_VALIDATOR / ZCL_MM_PAC_REQ_READER activas (abapGit).
*&---------------------------------------------------------------------*

*--- Validacao da atribuicao PAC na RC (mudanca 4) -----------------------*
  DATA: lo_pac_val  TYPE REF TO zcl_mm_pac_req_validator,
        ls_pac_hdr  TYPE mereq_header,
        ls_pac_itm  TYPE mereq_item,
        lv_pac_mand TYPE abap_bool.

  ls_pac_hdr = im_header->get_data( ).
  " Obrigatorio para metodos formais (ZMANB in CP/CL/AD/DF); opcional em NS/vazio
  lv_pac_mand = xsdbool( ls_pac_hdr-zmanb IS NOT INITIAL AND ls_pac_hdr-zmanb <> 'NS' ).

  lo_pac_val = NEW zcl_mm_pac_req_validator( NEW zcl_mm_pac_req_reader( ) ).

  LOOP AT im_header->get_items( ) INTO DATA(ls_pac_wrap).
    ls_pac_itm = ls_pac_wrap-item->get_data( ).
    CHECK ls_pac_itm-loekz IS INITIAL.          " ignora itens eliminados

    DATA(ls_pac_v) = lo_pac_val->validate_item(
        iv_year      = ls_pac_itm-pac_year
        iv_cat       = ls_pac_itm-pac_cat
        iv_subcat    = ls_pac_itm-pac_subcat
        iv_item      = ls_pac_itm-pac_item
        iv_mandatory = lv_pac_mand ).

    IF ls_pac_v-ok = abap_false.
      mmpur_message 'E' 'ZMM_PAC' ls_pac_v-msgno
                    ls_pac_v-msgv1 ls_pac_v-msgv2 ls_pac_v-msgv3 space.
    ENDIF.
  ENDLOOP.
*-------------------------------------------------------------------------*

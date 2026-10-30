*&---------------------------------------------------------------------*
*& Integração PAC no IF_EX_ME_PROCESS_REQ_CUST~CHECK (ZCL_IM_ME_PROCESS_REQ_CUST,
*& pacote ZMM). Entrega por TRANSPORTE. Tarefa 3.1.
*& Abordagem conservadora: 3 inserções cirúrgicas; a lógica legada mantém-se.
*& Requer: INCLUDE mm_messages_mac (já existe no CHECK) e as classes
*& ZCL_MM_PAC_REQ_VALIDATOR / ZCL_MM_PAC_REQ_READER activas (abapGit).
*&---------------------------------------------------------------------*

* ---- INSERÇÃO 1: junto das restantes DATA do método ----
  DATA: lo_pac_val  TYPE REF TO zcl_mm_pac_req_validator,
        lv_pac_mand TYPE abap_bool.

* ---- INSERÇÃO 2: ANTES do 2.º "LOOP AT t_item INTO w_item" ----
*     (i_act_items2 = cabeçalho, já lido no topo do método)
  " PAC obrigatorio p/ metodos formais (ZMANB in CP/CL/AD/DF); opcional em NS/vazio
  lv_pac_mand = xsdbool( i_act_items2-zmanb IS NOT INITIAL AND i_act_items2-zmanb <> 'NS' ).
  lo_pac_val  = NEW zcl_mm_pac_req_validator( NEW zcl_mm_pac_req_reader( ) ).

* ---- INSERÇÃO 3: no FIM do corpo do 2.º LOOP, antes do ENDLOOP ----
*     (reutiliza i_act_items já obtido no loop -> sem get_data extra)
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

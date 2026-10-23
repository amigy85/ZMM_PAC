INTERFACE zif_mm_pac_types
  PUBLIC .

  TYPES:
    "! Categorias lidas da BD / a inserir (chave MANDT implícito + ano + categoria)
    tt_catg    TYPE SORTED TABLE OF zmm_pac_catg    WITH UNIQUE KEY pac_year pac_cat,
    "! Subcategorias (chave sem PAC_CAT, ADR-02)
    tt_subcatg TYPE SORTED TABLE OF zmm_pac_subcatg WITH UNIQUE KEY pac_year pac_subcat,

    "! Uma linha de dados do ficheiro, "crua" (tudo string) — o parser só normaliza
    "! (trim/maiúsculas) e NÃO trunca; o validador mede comprimento (REQ-11), valida
    "! o ano (REQ-03) e constrói depois as linhas tipadas ZMM_PAC_CATG/SUBCATG.
    BEGIN OF ty_file_row,
      row         TYPE i,                     " nº da linha física (mensagens)
      pac_year    TYPE string,
      pac_cat     TYPE string,
      cat_desc    TYPE string,
      pac_subcat  TYPE string,
      subcat_desc TYPE string,
    END OF ty_file_row,
    tt_file_row TYPE STANDARD TABLE OF ty_file_row WITH DEFAULT KEY,

    "! Linha de log para o ALV de resultado
    BEGIN OF ty_msg,
      msgty TYPE symsgty,
      msgno TYPE symsgno,
      row   TYPE i,
      text  TYPE string,
    END OF ty_msg,
    tt_msg TYPE STANDARD TABLE OF ty_msg WITH DEFAULT KEY,

    "! Estatísticas do resultado
    BEGIN OF ty_stats,
      cat_new    TYPE i,
      subcat_new TYPE i,
      errors     TYPE i,
      warnings   TYPE i,
      identical  TYPE i,
      divergent  TYPE i,
    END OF ty_stats.

  TYPES:
    "! Linha "crua" do ficheiro de itens de planeamento (mudança 5); tudo string.
    "! PAC_CAT é derivado da subcategoria; PAC_ITEM vem do intervalo de números.
    BEGIN OF ty_item_row,
      row         TYPE i,
      pac_year    TYPE string,
      pac_subcat  TYPE string,
      description TYPE string,
      quantidade  TYPE string,
      unidade     TYPE string,
      valor       TYPE string,
      moeda       TYPE string,
      centro      TYPE string,
      conta       TYPE string,
    END OF ty_item_row,
    tt_item_row TYPE STANDARD TABLE OF ty_item_row WITH DEFAULT KEY,
    "! Itens de planeamento a inserir (estrutura real da tabela)
    tt_item     TYPE STANDARD TABLE OF zmm_pac_item WITH DEFAULT KEY.

  CONSTANTS:
    c_status_active   TYPE zmm_pac_status VALUE 'A',
    c_status_inactive TYPE zmm_pac_status VALUE 'I'.

ENDINTERFACE.

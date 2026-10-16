INTERFACE zif_mm_pac_types
  PUBLIC .

  TYPES:
    "! Categorias lidas da BD / a inserir (chave MANDT implícito + ano + categoria)
    tt_catg    TYPE SORTED TABLE OF zmm_pac_catg    WITH UNIQUE KEY pac_year pac_cat,
    "! Subcategorias (chave sem PAC_CAT, ADR-02)
    tt_subcatg TYPE SORTED TABLE OF zmm_pac_subcatg WITH UNIQUE KEY pac_year pac_subcat,

    "! Uma linha de dados do ficheiro, já lida pelo parser
    BEGIN OF ty_file_row,
      row         TYPE i,                     " nº da linha física (mensagens)
      pac_year    TYPE zmm_pac_year,
      pac_cat     TYPE zmm_pac_cat,
      cat_desc    TYPE zmm_pac_cat_desc,
      pac_subcat  TYPE zmm_pac_subcat,
      subcat_desc TYPE zmm_pac_subcat_desc,
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

  CONSTANTS:
    c_status_active   TYPE zmm_pac_status VALUE 'A',
    c_status_inactive TYPE zmm_pac_status VALUE 'I'.

ENDINTERFACE.

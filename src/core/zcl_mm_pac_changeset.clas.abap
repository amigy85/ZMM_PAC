CLASS zcl_mm_pac_changeset DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_erdat TYPE dats
                iv_erzet TYPE tims
                iv_ernam TYPE syuname DEFAULT sy-uname.

    "! Preenche ERNAM/ERDAT/ERZET (AE* vazios) e VALID_FROM=01.01 / VALID_TO=31.12
    "! em cada registo, devolvendo as tabelas prontas a inserir. Carimbo único.
    METHODS build
      IMPORTING it_cat    TYPE zif_mm_pac_types=>tt_catg
                it_subcat TYPE zif_mm_pac_types=>tt_subcatg
      EXPORTING et_cat    TYPE zif_mm_pac_types=>tt_catg
                et_subcat TYPE zif_mm_pac_types=>tt_subcatg.

  PRIVATE SECTION.
    DATA:
      mv_erdat TYPE dats,
      mv_erzet TYPE tims,
      mv_ernam TYPE syuname.
ENDCLASS.



CLASS zcl_mm_pac_changeset IMPLEMENTATION.

  METHOD constructor.
    mv_erdat = iv_erdat.
    mv_erzet = iv_erzet.
    mv_ernam = iv_ernam.
  ENDMETHOD.


  METHOD build.
    CLEAR: et_cat, et_subcat.

    et_cat = it_cat.
    LOOP AT et_cat ASSIGNING FIELD-SYMBOL(<c>).
      <c>-ernam      = mv_ernam.
      <c>-erdat      = mv_erdat.
      <c>-erzet      = mv_erzet.
      CLEAR: <c>-aenam, <c>-aedat.
      <c>-valid_from = |{ <c>-pac_year }0101|.
      <c>-valid_to   = |{ <c>-pac_year }1231|.
    ENDLOOP.

    et_subcat = it_subcat.
    LOOP AT et_subcat ASSIGNING FIELD-SYMBOL(<s>).
      <s>-ernam      = mv_ernam.
      <s>-erdat      = mv_erdat.
      <s>-erzet      = mv_erzet.
      CLEAR: <s>-aenam, <s>-aedat.
      <s>-valid_from = |{ <s>-pac_year }0101|.
      <s>-valid_to   = |{ <s>-pac_year }1231|.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

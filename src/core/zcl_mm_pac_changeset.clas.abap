class ZCL_MM_PAC_CHANGESET definition
  public
  final
  create public .

public section.

  methods CONSTRUCTOR
    importing
      !IV_ERDAT type DATS
      !IV_ERZET type TIMS
      !IV_ERNAM type SYUNAME default SY-UNAME .
    "! Preenche ERNAM/ERDAT/ERZET (AE* vazios) e VALID_FROM=01.01 / VALID_TO=31.12
    "! em cada registo, devolvendo as tabelas prontas a inserir. Carimbo único.
  methods BUILD
    importing
      !IT_CAT type ZIF_MM_PAC_TYPES=>TT_CATG
      !IT_SUBCAT type ZIF_MM_PAC_TYPES=>TT_SUBCATG
    exporting
      !ET_CAT type ZIF_MM_PAC_TYPES=>TT_CATG
      !ET_SUBCAT type ZIF_MM_PAC_TYPES=>TT_SUBCATG .
protected section.
  PRIVATE SECTION.
    DATA:
      mv_erdat TYPE dats,
      mv_erzet TYPE tims,
      mv_ernam TYPE syuname.
ENDCLASS.



CLASS ZCL_MM_PAC_CHANGESET IMPLEMENTATION.


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


  METHOD constructor.
    mv_erdat = iv_erdat.
    mv_erzet = iv_erzet.
    mv_ernam = iv_ernam.
  ENDMETHOD.
ENDCLASS.

class ZCL_MM_PAC_ITEM_CHANGESET definition
  public
  final
  create public .

public section.

  methods CONSTRUCTOR
    importing
      !IV_ERDAT type DATS
      !IV_ERZET type TIMS
      !IV_ERNAM type SYUNAME default SY-UNAME .
    "! Carimba ERNAM/ERDAT/ERZET (AE* vazios) em cada item. O STATUS já vem 'D' do
    "! validador e o PAC_ITEM é atribuído pelo repositório na gravação. Carimbo único.
  methods BUILD
    importing
      !IT_ITEM type ZIF_MM_PAC_TYPES=>TT_ITEM
    exporting
      !ET_ITEM type ZIF_MM_PAC_TYPES=>TT_ITEM .
protected section.
  PRIVATE SECTION.
    DATA:
      mv_erdat TYPE dats,
      mv_erzet TYPE tims,
      mv_ernam TYPE syuname.
ENDCLASS.



CLASS ZCL_MM_PAC_ITEM_CHANGESET IMPLEMENTATION.


  METHOD build.
    CLEAR et_item.
    et_item = it_item.
    LOOP AT et_item ASSIGNING FIELD-SYMBOL(<i>).
      <i>-ernam = mv_ernam.
      <i>-erdat = mv_erdat.
      <i>-erzet = mv_erzet.
      CLEAR: <i>-aenam, <i>-aedat.
    ENDLOOP.
  ENDMETHOD.


  METHOD constructor.
    mv_erdat = iv_erdat.
    mv_erzet = iv_erzet.
    mv_ernam = iv_ernam.
  ENDMETHOD.
ENDCLASS.

CLASS zcl_mm_pac_item_changeset DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_erdat TYPE dats
                iv_erzet TYPE tims
                iv_ernam TYPE syuname DEFAULT sy-uname.

    "! Carimba ERNAM/ERDAT/ERZET (AE* vazios) em cada item. O STATUS já vem 'D' do
    "! validador e o PAC_ITEM é atribuído pelo repositório na gravação. Carimbo único.
    METHODS build
      IMPORTING it_item TYPE zif_mm_pac_types=>tt_item
      EXPORTING et_item TYPE zif_mm_pac_types=>tt_item.

  PRIVATE SECTION.
    DATA:
      mv_erdat TYPE dats,
      mv_erzet TYPE tims,
      mv_ernam TYPE syuname.
ENDCLASS.



CLASS zcl_mm_pac_item_changeset IMPLEMENTATION.

  METHOD constructor.
    mv_erdat = iv_erdat.
    mv_erzet = iv_erzet.
    mv_ernam = iv_ernam.
  ENDMETHOD.

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

ENDCLASS.

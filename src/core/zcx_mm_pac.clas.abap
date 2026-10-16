class ZCX_MM_PAC definition
  public
  inheriting from CX_STATIC_CHECK
  create private .

public section.

  interfaces IF_T100_MESSAGE .

  constants:
    begin of NO_AUTHORIZATION,
      msgid type symsgid value 'ZMM_PAC',
      msgno type symsgno value '050',
      attr1 type scx_attrname value '',
      attr2 type scx_attrname value '',
      attr3 type scx_attrname value '',
      attr4 type scx_attrname value '',
    end of NO_AUTHORIZATION .
  constants:
    begin of YEAR_LOCKED,
      msgid type symsgid value 'ZMM_PAC',
      msgno type symsgno value '051',
      attr1 type scx_attrname value '',
      attr2 type scx_attrname value '',
      attr3 type scx_attrname value '',
      attr4 type scx_attrname value '',
    end of YEAR_LOCKED .
  constants:
    begin of DB_INSERT_FAILED,
      msgid type symsgid value 'ZMM_PAC',
      msgno type symsgno value '063',
      attr1 type scx_attrname value '',
      attr2 type scx_attrname value '',
      attr3 type scx_attrname value '',
      attr4 type scx_attrname value '',
    end of DB_INSERT_FAILED .

  methods CONSTRUCTOR
    importing
      !TEXTID like IF_T100_MESSAGE=>T100KEY optional
      !PREVIOUS like PREVIOUS optional .
protected section.
private section.
ENDCLASS.



CLASS ZCX_MM_PAC IMPLEMENTATION.


  method CONSTRUCTOR.
CALL METHOD SUPER->CONSTRUCTOR
EXPORTING
PREVIOUS = PREVIOUS
.
clear me->textid.
if textid is initial.
  IF_T100_MESSAGE~T100KEY = IF_T100_MESSAGE=>DEFAULT_TEXTID.
else.
  IF_T100_MESSAGE~T100KEY = TEXTID.
endif.
  endmethod.
ENDCLASS.

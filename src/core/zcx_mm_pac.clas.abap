class ZCX_MM_PAC definition
  public
  inheriting from CX_STATIC_CHECK
  create public .

public section.

  interfaces IF_T100_MESSAGE .
  interfaces IF_T100_DYN_MSG .

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
    super->constructor( previous = previous ).
    if textid is initial.
      if_t100_message~t100key = if_t100_message=>default_textid.
    else.
      if_t100_message~t100key = textid.
    endif.
  endmethod.
ENDCLASS.

#!/usr/bin/env python3
"""
abapgit_meta.py - Gera e valida metafiles do abapGit.

Garante deterministicamente a codificacao que o abapGit espera:
UTF-8, LF, quebra de linha final, indentacao de 2 espacos. BOM nos XML; .abap SEM BOM.

Sem dependencias externas. Python 3.8+.

Comandos:
  dot    - .abapgit.xml (configuracao do repositorio, na raiz)
  devc   - package.devc.xml
  clas   - <nome>.clas.xml (+ esqueleto .abap opcional)
  intf   - <nome>.intf.xml (+ esqueleto .abap opcional)
  prog   - <nome>.prog.xml (+ esqueleto .abap opcional)
  doma   - <nome>.doma.xml
  dtel   - <nome>.dtel.xml
  check  - valida um repositorio inteiro
"""

import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET

BOM = "\ufeff"
XML_VERSION = "v1.0.0"
ASX_NS = "http://www.sap.com/abapxml"

VALID_SUBC = {"1", "I", "M", "F", "K", "J", "S"}
VALID_FOLDER_LOGIC = {"PREFIX", "FULL", "MIXED"}


# --------------------------------------------------------------------------
# Escrita
# --------------------------------------------------------------------------

def write_file(path, text):
    """Grava em UTF-8, LF, quebra de linha final. BOM nos XML; .abap SEM BOM
    (o abapGit nao remove o BOM do fonte .abap na importacao -> erro de sintaxe)."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    if not text.endswith("\n"):
        text += "\n"
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    use_bom = not path.endswith(".abap")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write((BOM if use_bom else "") + text)
    print("escrito: {}".format(path))


def esc(value):
    """Escapa texto para conteudo XML."""
    return (
        str(value)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def object_metafile(serializer, body_lines):
    """Monta um metafile de objecto (com wrapper <abapGit>)."""
    lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<abapGit version="{v}" serializer="{s}" serializer_version="{v}">'.format(
            v=XML_VERSION, s=serializer
        ),
        ' <asx:abap xmlns:asx="{}" version="1.0">'.format(ASX_NS),
        "  <asx:values>",
    ]
    lines.extend("   " + line for line in body_lines)
    lines.extend(["  </asx:values>", " </asx:abap>", "</abapGit>"])
    return "\n".join(lines)


# --------------------------------------------------------------------------
# Geradores
# --------------------------------------------------------------------------

def cmd_dot(args):
    """.abapgit.xml - NAO leva o wrapper <abapGit>. Caso especial."""
    if args.folder_logic not in VALID_FOLDER_LOGIC:
        sys.exit("ERRO: folder-logic tem de ser um de {}".format(
            ", ".join(sorted(VALID_FOLDER_LOGIC))))

    folder = args.starting_folder
    if not folder.startswith("/") or not folder.endswith("/"):
        sys.exit("ERRO: starting-folder deve comecar e terminar com '/' (ex.: /src/)")

    lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<asx:abap xmlns:asx="{}" version="1.0">'.format(ASX_NS),
        " <asx:values>",
        "  <DATA>",
        "   <MASTER_LANGUAGE>{}</MASTER_LANGUAGE>".format(esc(args.lang)),
        "   <STARTING_FOLDER>{}</STARTING_FOLDER>".format(esc(folder)),
        "   <FOLDER_LOGIC>{}</FOLDER_LOGIC>".format(args.folder_logic),
    ]
    if args.ignore:
        lines.append("   <IGNORE>")
        for pattern in args.ignore:
            lines.append("    <item>{}</item>".format(esc(pattern)))
        lines.append("   </IGNORE>")
    lines.extend(["  </DATA>", " </asx:values>", "</asx:abap>"])

    write_file(os.path.join(args.out, ".abapgit.xml"), "\n".join(lines))
    print("\nLembrete: .abapgit.xml fica na RAIZ do repositorio, nunca dentro de {}".format(folder))


def cmd_devc(args):
    body = [
        "<DEVC>",
        " <CTEXT>{}</CTEXT>".format(esc(args.description)),
        "</DEVC>",
    ]
    write_file(os.path.join(args.out, "package.devc.xml"),
               object_metafile("LCL_OBJECT_DEVC", body))


def cmd_clas(args):
    name = args.name.lower()
    upper = args.name.upper()
    body = [
        "<VSEOCLASS>",
        " <CLSNAME>{}</CLSNAME>".format(upper),
        " <LANGU>{}</LANGU>".format(esc(args.lang)),
        " <DESCRIPT>{}</DESCRIPT>".format(esc(args.description)),
        " <STATE>1</STATE>",
        " <CLSCCINCL>X</CLSCCINCL>",
        " <FIXPT>X</FIXPT>",
        " <UNICODE>X</UNICODE>",
        "</VSEOCLASS>",
    ]
    write_file(os.path.join(args.out, name + ".clas.xml"),
               object_metafile("LCL_OBJECT_CLAS", body))

    if args.skeleton:
        code = "\n".join([
            "CLASS {} DEFINITION".format(upper.lower()),
            "  PUBLIC",
            "  FINAL",
            "  CREATE PUBLIC.",
            "",
            "  PUBLIC SECTION.",
            "  PROTECTED SECTION.",
            "  PRIVATE SECTION.",
            "ENDCLASS.",
            "",
            "",
            "CLASS {} IMPLEMENTATION.".format(upper.lower()),
            "ENDCLASS.",
        ])
        write_file(os.path.join(args.out, name + ".clas.abap"), code)

    if upper.startswith("ZCX_") or upper.startswith("YCX_"):
        print("\nAVISO: parece uma classe de excepcao. VSEOCLASS precisa de CATEGORY/EXPOSURE")
        print("       especificos da variante escolhida. Serialize um exemplo do SAP e compare")
        print("       antes de fazer pull, senao a classe pode nao activar.")


def cmd_intf(args):
    name = args.name.lower()
    upper = args.name.upper()
    body = [
        "<VSEOINTERF>",
        " <CLSNAME>{}</CLSNAME>".format(upper),
        " <LANGU>{}</LANGU>".format(esc(args.lang)),
        " <DESCRIPT>{}</DESCRIPT>".format(esc(args.description)),
        " <EXPOSURE>2</EXPOSURE>",
        " <STATE>1</STATE>",
        " <UNICODE>X</UNICODE>",
        "</VSEOINTERF>",
    ]
    write_file(os.path.join(args.out, name + ".intf.xml"),
               object_metafile("LCL_OBJECT_INTF", body))

    if args.skeleton:
        code = "\n".join([
            "INTERFACE {} PUBLIC.".format(upper.lower()),
            "ENDINTERFACE.",
        ])
        write_file(os.path.join(args.out, name + ".intf.abap"), code)


def cmd_prog(args):
    if args.subc not in VALID_SUBC:
        sys.exit("ERRO: subc tem de ser um de {}".format(", ".join(sorted(VALID_SUBC))))

    name = args.name.lower()
    upper = args.name.upper()
    body = ["<PROGDIR>", " <NAME>{}</NAME>".format(upper),
            " <SUBC>{}</SUBC>".format(args.subc), " <FIXPT>X</FIXPT>"]
    if args.subc != "I":                     # includes nao levam VARCL/RSTAT
        body.extend([" <VARCL>X</VARCL>", " <RSTAT>T</RSTAT>"])
    body.extend([" <UCCHECK>X</UCCHECK>", "</PROGDIR>"])

    if args.description:
        body.extend([
            "<TPOOL>",
            " <item>",
            "  <ID>R</ID>",
            "  <ENTRY>{}</ENTRY>".format(esc(args.description)),
            "  <LENGTH>{}</LENGTH>".format(len(args.description)),
            " </item>",
            "</TPOOL>",
        ])

    write_file(os.path.join(args.out, name + ".prog.xml"),
               object_metafile("LCL_OBJECT_PROG", body))

    if args.skeleton:
        code = "REPORT {}.\n".format(upper.lower()) if args.subc == "1" else ""
        write_file(os.path.join(args.out, name + ".prog.abap"), code)


def cmd_doma(args):
    upper = args.name.upper()
    leng = "{:06d}".format(args.length)
    body = [
        "<DD01V>",
        " <DOMNAME>{}</DOMNAME>".format(upper),
        " <DDLANGUAGE>{}</DDLANGUAGE>".format(esc(args.lang)),
        " <DATATYPE>{}</DATATYPE>".format(args.datatype.upper()),
        " <LENG>{}</LENG>".format(leng),
        " <OUTPUTLEN>{}</OUTPUTLEN>".format(leng),
    ]
    if args.decimals:
        body.append(" <DECIMALS>{:06d}</DECIMALS>".format(args.decimals))
    body.extend([
        " <DDTEXT>{}</DDTEXT>".format(esc(args.description)),
        "</DD01V>",
    ])
    write_file(os.path.join(args.out, args.name.lower() + ".doma.xml"),
               object_metafile("LCL_OBJECT_DOMA", body))
    print("\nNota: para valores fixos, acrescentar <VALEXI>X</VALEXI> em DD01V e um bloco")
    print("      DD07V_TAB. Ver references/object-templates.md.")


def cmd_dtel(args):
    upper = args.name.upper()
    desc = args.description
    body = [
        "<DD04V>",
        " <ROLLNAME>{}</ROLLNAME>".format(upper),
        " <DDLANGUAGE>{}</DDLANGUAGE>".format(esc(args.lang)),
        " <DOMNAME>{}</DOMNAME>".format(args.domain.upper()),
        " <HEADLEN>10</HEADLEN>",
        " <SCRLEN1>10</SCRLEN1>",
        " <SCRLEN2>20</SCRLEN2>",
        " <SCRLEN3>40</SCRLEN3>",
        " <DDTEXT>{}</DDTEXT>".format(esc(desc)),
        " <REPTEXT>{}</REPTEXT>".format(esc(desc[:10])),
        " <SCRTEXT_S>{}</SCRTEXT_S>".format(esc(desc[:10])),
        " <SCRTEXT_M>{}</SCRTEXT_M>".format(esc(desc[:20])),
        " <SCRTEXT_L>{}</SCRTEXT_L>".format(esc(desc[:40])),
        "</DD04V>",
    ]
    write_file(os.path.join(args.out, args.name.lower() + ".dtel.xml"),
               object_metafile("LCL_OBJECT_DTEL", body))


# --------------------------------------------------------------------------
# Validacao
# --------------------------------------------------------------------------

FILENAME_RE = re.compile(r"^[a-z0-9_#\-]+\.[a-z0-9]+(\.[a-z0-9_.]+)?\.[a-z0-9]+$")

# tipos cujo metafile e o unico ficheiro (sem .abap associado)
METADATA_ONLY = {"devc", "tabl", "dtel", "doma", "ttyp", "msag", "enqu",
                 "view", "shlp", "sicf", "auth", "susc", "suso", "iarp",
                 "nrob", "para", "ssfo", "ssst", "tobj", "type"}


def read_text(path):
    with open(path, "rb") as fh:
        raw = fh.read()
    has_bom = raw.startswith(b"\xef\xbb\xbf")
    body = raw[3:] if has_bom else raw
    has_crlf = b"\r\n" in body
    ends_nl = body.endswith(b"\n")
    try:
        text = body.decode("utf-8")
    except UnicodeDecodeError:
        text = None
    return text, has_bom, has_crlf, ends_nl


def cmd_check(args):
    root = os.path.abspath(args.root)
    errors, warnings, fixed = [], [], []

    # --- .abapgit.xml -----------------------------------------------------
    dot_path = os.path.join(root, ".abapgit.xml")
    if not os.path.isfile(dot_path):
        errors.append(".abapgit.xml em falta na raiz do repositorio")
        starting_folder = "/src/"
    else:
        text, has_bom, has_crlf, ends_nl = read_text(dot_path)
        if text is None:
            errors.append(".abapgit.xml nao esta em UTF-8 valido")
            starting_folder = "/src/"
        else:
            if "<abapGit" in text:
                errors.append(
                    ".abapgit.xml tem o wrapper <abapGit> - esse elemento pertence apenas "
                    "aos metafiles de objecto. Deve comecar directamente em <asx:abap>")
            m = re.search(r"<STARTING_FOLDER>(.*?)</STARTING_FOLDER>", text)
            starting_folder = m.group(1) if m else "/src/"
            m = re.search(r"<FOLDER_LOGIC>(.*?)</FOLDER_LOGIC>", text)
            if m and m.group(1) not in VALID_FOLDER_LOGIC:
                errors.append("FOLDER_LOGIC invalido: {}".format(m.group(1)))
            elif not m:
                warnings.append("FOLDER_LOGIC nao definido (o abapGit assume um valor)")
            if not re.search(r"<MASTER_LANGUAGE>", text):
                warnings.append("MASTER_LANGUAGE nao definido no .abapgit.xml")

    src_root = os.path.join(root, starting_folder.strip("/"))
    if not os.path.isdir(src_root):
        errors.append("STARTING_FOLDER '{}' nao existe no repositorio".format(starting_folder))
        report(errors, warnings, fixed)
        return

    master_lang = None
    if os.path.isfile(dot_path):
        t, *_ = read_text(dot_path)
        if t:
            m = re.search(r"<MASTER_LANGUAGE>(.*?)</MASTER_LANGUAGE>", t)
            master_lang = m.group(1) if m else None

    # --- percorrer o starting folder --------------------------------------
    for dirpath, _dirnames, filenames in os.walk(src_root):
        rel_dir = os.path.relpath(dirpath, root)

        if "package.devc.xml" not in filenames:
            errors.append("{}: falta package.devc.xml".format(rel_dir))

        stems = {}   # (nome, tipo) -> {"xml": bool, "code": bool}

        for fname in sorted(filenames):
            fpath = os.path.join(dirpath, fname)
            rel = os.path.relpath(fpath, root)

            if fname != fname.lower():
                errors.append("{}: nome de ficheiro tem maiusculas".format(rel))

            if fname != "package.devc.xml" and not FILENAME_RE.match(fname):
                warnings.append("{}: nome fora do padrao <nome>.<tipo>.<ext>".format(rel))

            # codificacao
            text, has_bom, has_crlf, ends_nl = read_text(fpath)
            problems = []
            if fname.endswith(".abap"):
                if has_bom:
                    problems.append("tem BOM (abap nao leva BOM)")
            else:
                if not has_bom:
                    problems.append("sem BOM")
            if has_crlf:
                problems.append("CRLF")
            if not ends_nl:
                problems.append("sem newline final")
            if text is None:
                errors.append("{}: nao esta em UTF-8 valido".format(rel))
                continue
            if problems:
                if args.fix:
                    write_file(fpath, text)
                    fixed.append("{}: corrigido ({})".format(rel, ", ".join(problems)))
                else:
                    errors.append("{}: {}".format(rel, ", ".join(problems)))

            # XML bem formado + wrapper
            if fname.endswith(".xml"):
                try:
                    ET.fromstring(text)
                except ET.ParseError as exc:
                    errors.append("{}: XML malformado ({})".format(rel, exc))
                    continue
                if "<abapGit" not in text:
                    errors.append("{}: falta o elemento raiz <abapGit>".format(rel))
                elif 'version="{}"'.format(XML_VERSION) not in text:
                    errors.append("{}: atributo version deve ser {}".format(rel, XML_VERSION))
                if master_lang:
                    for tag in ("LANGU", "DDLANGUAGE", "MASTERLANG"):
                        for found in re.findall(r"<{0}>(.*?)</{0}>".format(tag), text):
                            if found and found != master_lang:
                                warnings.append(
                                    "{}: {} = '{}' difere de MASTER_LANGUAGE '{}'".format(
                                        rel, tag, found, master_lang))

            # emparelhar metafile <-> codigo
            if fname == "package.devc.xml":
                continue
            parts = fname.split(".")
            if len(parts) >= 3:
                key = (parts[0], parts[1])
                entry = stems.setdefault(key, {"xml": False, "code": False})
                if len(parts) == 3 and parts[2] == "xml":
                    entry["xml"] = True
                elif parts[-1] in ("abap", "html", "js", "css", "json", "xml", "po", "properties"):
                    entry["code"] = True

        for (name, otype), entry in sorted(stems.items()):
            if not entry["xml"]:
                errors.append("{}/{}.{}: codigo sem metafile .xml".format(rel_dir, name, otype))
            elif not entry["code"] and otype not in METADATA_ONLY:
                warnings.append("{}/{}.{}.xml: metafile sem ficheiro de codigo".format(
                    rel_dir, name, otype))

    report(errors, warnings, fixed)


def report(errors, warnings, fixed):
    if fixed:
        print("\nCORRIGIDO ({}):".format(len(fixed)))
        for item in fixed:
            print("  * " + item)
    if errors:
        print("\nERROS ({}):".format(len(errors)))
        for item in errors:
            print("  x " + item)
    if warnings:
        print("\nAVISOS ({}):".format(len(warnings)))
        for item in warnings:
            print("  ! " + item)
    if not errors and not warnings:
        print("\nOK - nenhum problema encontrado.")
    elif not errors:
        print("\nSem erros bloqueantes.")
    sys.exit(1 if errors else 0)


# --------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def add_common(p, lang=True, out=True):
        if lang:
            p.add_argument("--lang", default="E", help="lingua principal (default: E)")
        if out:
            p.add_argument("--out", default=".", help="pasta de destino (default: .)")

    p = sub.add_parser("dot", help=".abapgit.xml")
    add_common(p)
    p.add_argument("--starting-folder", default="/src/")
    p.add_argument("--folder-logic", default="PREFIX",
                   choices=sorted(VALID_FOLDER_LOGIC))
    p.add_argument("--ignore", nargs="*", default=[], help="padroes CP a ignorar")
    p.set_defaults(func=cmd_dot)

    p = sub.add_parser("devc", help="package.devc.xml")
    add_common(p, lang=False)
    p.add_argument("--description", required=True)
    p.set_defaults(func=cmd_devc)

    p = sub.add_parser("clas", help="metafile de classe")
    add_common(p)
    p.add_argument("--name", required=True)
    p.add_argument("--description", required=True)
    p.add_argument("--skeleton", action="store_true", help="gerar tambem o .abap vazio")
    p.set_defaults(func=cmd_clas)

    p = sub.add_parser("intf", help="metafile de interface")
    add_common(p)
    p.add_argument("--name", required=True)
    p.add_argument("--description", required=True)
    p.add_argument("--skeleton", action="store_true")
    p.set_defaults(func=cmd_intf)

    p = sub.add_parser("prog", help="metafile de programa")
    add_common(p)
    p.add_argument("--name", required=True)
    p.add_argument("--description", default="")
    p.add_argument("--subc", default="1", choices=sorted(VALID_SUBC))
    p.add_argument("--skeleton", action="store_true")
    p.set_defaults(func=cmd_prog)

    p = sub.add_parser("doma", help="metafile de dominio")
    add_common(p)
    p.add_argument("--name", required=True)
    p.add_argument("--description", required=True)
    p.add_argument("--datatype", default="CHAR")
    p.add_argument("--length", type=int, default=10)
    p.add_argument("--decimals", type=int, default=0)
    p.set_defaults(func=cmd_doma)

    p = sub.add_parser("dtel", help="metafile de data element")
    add_common(p)
    p.add_argument("--name", required=True)
    p.add_argument("--description", required=True)
    p.add_argument("--domain", required=True)
    p.set_defaults(func=cmd_dtel)

    p = sub.add_parser("check", help="validar repositorio")
    p.add_argument("--root", default=".")
    p.add_argument("--fix", action="store_true",
                   help="corrigir automaticamente BOM/EOL/newline final")
    p.set_defaults(func=cmd_check)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

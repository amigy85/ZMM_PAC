# Tasks

Cada tarefa é marcada `- [x]` **depois** de o objecto activar no SAP e o teste
passar (o utilizador confirma a activação). Referência de commit:
`[refs: add-pac-catalog-upload <n.º>]`.

## 0. Preparação

- [x] 0.1 Decisões D-01, D-02, D-03, D-06, D-07 registadas como decididas em `proposal.md` (bloqueiam o apply) — D-06 fechada 2026-10-13 (só PAC; regex validada; cp1252; sem aspas)
- [x] 0.2 Nível de SP do SAP_BASIS confirmado via MCP (CVERS: SAP_BASIS 740 SP0022) e registado no `CLAUDE.md` — 2026-10-14; `FILTER`/`REDUCE`/`FOR` permitidos (SP22 ≥ SP08)
- [x] 0.3 Data elements standard da §5.2 confirmados via MCP (DD04L) — 2026-10-14: `MANDT`, `DATAB`, `DATBI`, `ERNAM`, `ERDAT`, `ERZET`, `AENAM`, `AEDAT`, `AEZET` existem todos; `AEZET` presente (TIMS 6), sem fallback para `UZEIT`
- [ ] 0.4 `rec/client` em QAS/PRD confirmado com Basis (registo de alterações) [REQ-14 / segurança]
- [x] 0.5 Packages `ZMM_PAC`, `_DATA`, `_CORE`, `_UI` criados no DEV; repositório abapGit ligado (online, branch `change/add-pac-catalog-upload`, PREFIX); pull sem diffs fantasma; ordem `CBDK918074` registada em `proposal.md` — 2026-10-14
- [x] 0.6 `.abapgit.xml`, `.gitattributes` e os `package.devc.xml` gerados; `abapgit_meta.py check` sem erros — 2026-10-14 (`check` exit 0; `.abapgit.xml` com `MASTER_LANGUAGE=P`, `/src/`, `PREFIX`); git inicializado no ramo `change/add-pac-catalog-upload`

## 1. Dicionário de dados

- [ ] 1.1 Domínios e data elements `ZMM_PAC_*` — objectos existentes corrigidos no local (SE11) e movidos para `ZMM_PAC_DATA`; **falta serializar** para `/src/data/` [modelo de dados]
- [ ] 1.2 Tabelas `ZMM_PAC_CATG` e `ZMM_PAC_SUBCATG` corrigidas no local (chave MANDT+PAC_YEAR+PAC_SUBCAT, validade BEGDA/ENDDA, auditoria com ERZET, descrições CHAR 72); **falta serializar** [ADR-02]
- [ ] 1.3 Foreign key `ZMM_PAC_SUBCATG-PAC_CAT` → `ZMM_PAC_CATG` criada e verificada via MCP (2026-10-15); **falta** o `.tabl.xml` serializado [REQ-06]
- [ ] 1.4 Classe de mensagens `ZMM_PAC` completa com todas as mensagens da §8.1 [todos os REQ]

## 2. Núcleo

- [ ] 2.1 `ZCX_MM_PAC` criada no SE24 (CX_STATIC_CHECK + IF_T100_MESSAGE; textos 050/051/063) e serializada
- [ ] 2.2 `ZIF_MM_PAC_TYPES` e `ZIF_MM_PAC_REPOSITORY`
- [ ] 2.3 `ZCL_MM_PAC_PARSER` + testes [REQ-02, REQ-05 normalização]
- [ ] 2.4 `ZCL_MM_PAC_LOG` + testes [REQ-16]
- [ ] 2.5 `ZCL_MM_PAC_VALIDATOR` + testes [REQ-03..REQ-09]
- [ ] 2.6 `ZCL_MM_PAC_CHANGESET` + testes [REQ-14]
- [ ] 2.7 `ZCL_MM_PAC_REPOSITORY`; bloqueio `ENQUEUE_E_TABLE` verificado em SM12 (criar `EZ_MM_PAC` se falhar) [REQ-13, REQ-11]
- [ ] 2.8 `ZCL_MM_PAC_AUTH` e objecto de autorização `ZMM_PAC` (SU21) serializado [REQ-15]
- [ ] 2.9 `ZCL_MM_PAC_UPLOAD` + testes com duplos [REQ-10, REQ-11, REQ-12, REQ-13, REQ-15]

## 3. Interface

- [ ] 3.1 `ZMM_PAC_UPLOAD` com ecrã de selecção, ALV e popup de confirmação; textos de selecção serializados [REQ-01, REQ-16, REQ-17]
- [ ] 3.2 `ZMM_PAC_MENU`; transacções `ZMM_PAC` e `ZMM_PAC_UPLOAD` criadas em SE93 e serializadas [ADR-05]

## 4. Verificação

- [ ] 4.1 Todos os testes ABAP Unit verdes (mapeamento cenário → teste da §14.1) [REQ-01..REQ-17]
- [ ] 4.2 ATC/Code Inspector sem findings de prioridade 1 e 2
- [ ] 4.3 Testes manuais em QAS da §14.3 executados e evidenciados (SE16N, SCU3, SM12, SU53, SM37)
- [ ] 4.4 REQ-18 medido em QAS com ficheiro de 10 000 linhas (< 60 s)
- [ ] 4.5 `abapgit_meta.py check` sem erros; pull limpo (sem diffs fantasma) no DEV

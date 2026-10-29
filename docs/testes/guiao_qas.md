# Guião único de testes manuais em QAS — ZMM_PAC

Cobre as **mudanças 1 (catálogo)** e **5 (itens de planeamento)** num único transporte.
Executar em QAS **depois de importado o transporte** e com os utilizadores/perfis de teste
prontos. Registar o resultado de cada passo na coluna *Resultado* (OK / NOK + nota).

> Dados: o caso feliz do catálogo usa `valido_303.csv` (anonimizado, 215 cat / 303 subcat).
> O caso feliz dos itens usa um ficheiro de itens cujas subcategorias existam no catálogo do
> ano e com `CENTRO`/`CONTA_RAZAO` reais (ex. `item_valido.real.csv`, local/gitignored).
> Ficheiros de erro versionados em `docs/testes/`.

## 0. Pré-requisitos

| # | Verificação | Resultado |
|---|---|---|
| 0.1 | Transporte importado sem erros de retorno (STMS, RC ≤ 4) | |
| 0.2 | DDIC activo em QAS: `ZMM_PAC_CATG`, `ZMM_PAC_SUBCATG`, `ZMM_PAC_ITEM` (SE11) | |
| 0.3 | Objecto de intervalo de números `ZMM_PAC` com intervalo `01` definido (SNRO) | |
| 0.4 | Objecto de autorização `ZMM_PAC` (classe `ZPAC`) e perfis: **Consulta** (`ACTVT 03`), **Gestor** (`ACTVT 01/02/03`) | |
| 0.5 | 2 utilizadores de teste: `U_CONS` (só `03`) e `U_GEST` (`01/02/03`) | |
| 0.6 | Transacções `ZMM_PAC`, `ZMM_PAC_UPLOAD`, `ZMM_PAC_ITEM_UPLOAD` arrancam (SE93) | |
| 0.7 | Mensagens da classe `ZMM_PAC` presentes: 001–011, 016, 050–064, 080–095 (SE91) | |

## 1. Mudança 1 — catálogo (`ZMM_PAC_UPLOAD`)

Com `U_GEST`, transacção `ZMM_PAC_UPLOAD`.

| # | Cenário | Passos | Esperado | Resultado |
|---|---|---|---|---|
| 1.1 | Simulação caso feliz | `valido_303.csv`, modo Simulação | ALV 215 cat + 303 subcat, msg `060`; SE16N: tabelas **vazias** | |
| 1.2 | Gravação caso feliz | mesmo ficheiro, modo Gravação, confirmar | msg de gravação; SE16N: **215**/`ZMM_PAC_CATG`, **303**/`ZMM_PAC_SUBCATG`, `STATUS='A'`, validade `01.01–31.12` do ano, `ERNAM/ERDAT/ERZET` carimbados, `AE*` vazios | |
| 1.3 | Reupload (existentes) | repetir 1.2 | existentes **comparados e reportados** (idênticos/divergentes), **sem** `UPDATE`; nenhum registo alterado | |
| 1.4 | Cabeçalho inválido | `cabecalho_errado.csv` | erro `004`, nada gravado | |
| 1.5 | Nº de colunas | `colunas_erradas.csv` | erro `005` | |
| 1.6 | Só cabeçalho | `so_cabecalho.csv` | erro `006` | |
| 1.7 | Dois anos | `dois_anos.csv` | erro `008` | |
| 1.8 | Relação inválida | `relacao_invalida.csv` | erro `018` | |
| 1.9 | Duplicados | `duplicados.csv` | erros `019`/`021` | |
| 1.10 | Formato/descrição | `formato_invalido.csv` | erros `016`/`017`/`022`; descrição > 72 **não truncada** | |
| 1.11 | Limite de volume | `10001_linhas.csv` | erro `007` | |
| 1.12 | Acentos cp1252 | `ansi_1252.csv` | acentos preservados, sem erro | |

## 2. Mudança 5 — itens (`ZMM_PAC_ITEM_UPLOAD`, `P_BUKRS = HCB`)

Com `U_GEST`. Requer o catálogo da secção 1 carregado.

| # | Cenário | Passos | Esperado | Resultado |
|---|---|---|---|---|
| 2.1 | Simulação caso feliz | `item_valido.real.csv`, Simulação | ALV com N itens, msg `060`; `ZMM_PAC_ITEM` **vazia**, **0 números** consumidos | |
| 2.2 | Gravação caso feliz | mesmo ficheiro, Gravação, confirmar (`089`) | msg `086`; SE16N: itens com `PAC_ITEM` **sequencial**, `STATUS='D'`, `PAC_CAT` derivado, `SAKNR` com **zeros à esquerda**, `MEINS` **interna**, `VALOR` **CURR**, `ERNAM/ERDAT/ERZET` carimbados, `AE*` vazios | |
| 2.3 | Numeração contínua | repetir 2.2 | `PAC_ITEM` **continua** a sequência (não reinicia), sem buracos/duplicados | |
| 2.4 | Ficheiro de erros | `item_erros.csv`, Gravação | ALV com `082/083/088/085/084/092/094/080/090/091/093/095` + `061`; **0 gravados** | |
| 2.5 | Moeda inexistente | linha com `MOEDA` fora de TCURC | erro `090`, bloqueia | |
| 2.6 | Unidade inexistente | linha com `UNIDADE` fora de T006 | erro `091`, bloqueia | |
| 2.7 | Centro inexistente / vazio | `CENTRO` inválido / em branco | erro `093` / `092`, bloqueia | |
| 2.8 | Conta inexistente / vazia | `CONTA_RAZAO` fora de `SKB1(HCB)` / em branco | erro `095` / `094`, bloqueia | |
| 2.9 | Subcategoria inexistente | subcat fora do catálogo do ano | erro `080`, bloqueia | |
| 2.10 | Categoria-mãe inactiva | pôr uma categoria a `STATUS='I'` (SE16N) e carregar item dessa família | erro `081`, bloqueia | |
| 2.11 | Empresa alternativa | correr com `P_BUKRS` diferente de `HCB` | contas validadas contra essa empresa (erro `095` se não existirem lá) | |

## 3. Volume (performance)

| # | Cenário | Esperado | Resultado |
|---|---|---|---|
| 3.1 | 10 000 itens (`item_10000.real.csv`, Gravação) | < 60 s; `086` com 10 000; numeração contínua; leituras de dados-mestre/catálogo **uma vez** (não por linha) | |

## 4. Segurança e execução (transversal, ambas as mudanças)

| # | Cenário | Passos | Esperado | Resultado |
|---|---|---|---|---|
| 4.1 | Autorização — só consulta | com `U_CONS`, tentar **Gravação** (catálogo e itens) | nega com `050` (ACTVT 01); **Simulação** permitida (`03`); SU53 mostra a verificação | |
| 4.2 | Autorização antes de ler | `U_CONS` em Gravação | negado **antes** de ler o ficheiro | |
| 4.3 | Execução em fundo | agendar em SM37 (ambos os programas) | mensagem `052` e fim, **sem** gravação | |
| 4.4 | Bloqueio por ano | 2 sessões `U_GEST` em Gravação do mesmo ano em simultâneo | a 2.ª recebe `051`; SM12 mostra o bloqueio da 1.ª; libertado no fim (também em erro) | |
| 4.5 | Atomicidade | forçar erro a meio (ex. ficheiro grande com 1 linha inválida) | **0 gravados** (nunca parcial), `061` | |
| 4.6 | Documentos de alteração | após gravações, SCU3 sobre as 3 tabelas | alterações registadas (se o log de dados estiver activo) | |

## 5. Smoke test a jusante — subtela PAC na Requisição de Compra (XM02/0111)

Confirma que os dados carregados são consumíveis pela RC (não é âmbito da mudança 1/5, mas
valida a cadeia). Com `U_GEST`, criar RC (ME51N) e abrir a subtela PAC:

| # | Cenário | Esperado | Resultado |
|---|---|---|---|
| 5.1 | F4 de categoria | lista só categorias `STATUS='A'` do ano corrente | |
| 5.2 | F4 de subcategoria | lista subcategorias da categoria escolhida | |
| 5.3 | Botão "atribuir item PAC" | popup com os `ZMM_PAC_ITEM` do ano+subcategoria; selecção preenche o item na RC | |
| 5.4 | Categoria/subcategoria inválida | mensagens `s001`/`s002` | |

## 6. Registo final

| Item | Valor |
|---|---|
| Transporte(s) | |
| Data / responsável | |
| Total passos OK / NOK | |
| Incidências abertas | |
| Decisão (apto a PRD?) | |

> Critério de aceitação: todos os passos das secções 0–4 **OK**; secção 5 informativa (liga à
> mudança 4). Qualquer NOK em 1.x/2.x/4.x é bloqueador de PRD.

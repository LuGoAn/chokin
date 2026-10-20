# Chokin

Chokin e um aplicativo de gestao financeira pessoal offline-first desenvolvido em Flutter para Android. O foco do sistema e proporcionar controle patrimonial confiavel, continuo e preciso, eliminando dependencias de servidores remotos ou compartilhamento de dados com terceiros.

---

## Indice

- [Visao Geral](#visao-geral)
- [Principais Funcionalidades](#principais-funcionalidades)
  - [1. Gestao Continua e Projecao de Recorrencias](#1-gestao-continua-e-projecao-de-recorrencias)
  - [2. Cartoes de Credito e Faturas](#2-cartoes-de-credito-e-faturas)
  - [3. Cobrancas e Reembolsos de Terceiros](#3-cobrancas-e-reembolsos-de-terceiros)
  - [4. Captura Automatica de Notificacoes Bancarias](#4-captura-automatica-de-notificacoes-bancarias)
  - [5. Backup Local e Exportacao de Dados](#5-backup-local-e-exportacao-de-dados)
  - [6. Atualizacoes Integradas via GitHub](#6-atualizacoes-integradas-via-github)
- [Arquitetura e Seguranca](#arquitetura-e-seguranca)
- [Download e Instalacao](#download-e-instalacao)
- [Compilacao a partir do Codigo-Fonte](#compilacao-a-partir-do-codigo-fonte)
- [Tecnologias Utilizadas](#tecnologias-utilizadas)
- [Licenca](#licenca)

---

## Visao Geral

Diferente de aplicativos financeiros tradicionais que exigem conexao permanente ou vinculacao de contas bancarias a servicos em nuvem, o Chokin adota uma abordagem estritamente local (offline-first). Todos os registros financeiros, extratos e calculos permanecem armazenados unicamente no banco de dados SQLite interno do dispositivo.

O aplicativo resolve problemas comuns de planejamento orcamentario, tais como o calculo correto do limite de cartao em compras parceladas, o isolamento de gastos pessoais em relacao a compras feitas para parentes ou amigos, e a projecao futura de receitas recorrentes sem inflacionar artificialmente o saldo em conta atual.

---

## Principais Funcionalidades

### 1. Gestao Continua e Projecao de Recorrencias

- Projecao automatica de receitas e despesas recorrentes (mensal, semanal, quinzenal e anual) para os proximos 12 meses.
- Seguranca contabil: transacoes com datas futuras sao exibidas no planejamento futuro, mas nao alteram o saldo disponivel presente e nao criam movimentacoes antecipadas no livro-razao (ledger).
- Maturacao automatica: quando o dia de uma cobranca ou receita agendada chega, ela e automaticamente integrada ao saldo em conta.
- Cancelamento seguro de recorrencias: opcao de encerrar uma serie recorrente "daqui para frente" sem alterar nem apagar os lancamentos dos meses passados.

### 2. Cartoes de Credito e Faturas

- Calculo preciso de limite utilizado: considera compras a vista do ciclo atual e parcelas de compras parceladas reais, excluindo assinaturas futuras projetadas para nao comprometer o limite bancario antecipadamente.
- Visualizacao clara no Dashboard com indicacao explicita do mes de cada fatura: Fatura Atual, Fatura Futura, Fatura Fechada ou Fatura Paga com selo de confirmacao.
- Registro de estornos e devolucoes: suporte a estorno total ou parcial, com amortizacao automatica das ultimas parcelas ou devolucao direta via Pix/dinheiro.
- Pagamento integral ou parcial de faturas com compensacao automatica pela reserva financeira em caso de saldo insuficiente.

### 3. Cobrancas e Reembolsos de Terceiros

- Separacao estrita entre gastos pessoais e compras efetuadas para amigos ou familiares.
- Gestao de devedores por mes: compras parceladas para terceiros sao distribuidas mes a mes de acordo com cada parcela devida.
- Amortizacao e quitacao cronologica de dividas.
- Possibilidade de desfazer recebimentos ou editar cobrancas a qualquer momento.

### 4. Captura Automatica de Notificacoes Bancarias

- Servico nativo em segundo plano (Android NotificationListenerService) para captura de compras aprovadas e transferencias Pix.
- Filtro inteligente anti-promocoes e anti-spam: rejeita automaticamente propagandas de emprestimo, aumentos de limite e cupons.
- Caixa de Entrada (Inbox) para revisao do usuario antes da integracao definitiva ao historico financeiro.
- Deteccao de duplicidades entre notificacoes concorrentes (ex: cartao e carteiras digitais como Samsung Pay ou Google Pay).

### 5. Backup Local e Exportacao de Dados

- Backup manual e automatico (frequencias configuraveis: diaria, 3 dias, semanal ou mensal) com gravacao em arquivos JSON versionados na pasta local de documentos do aparelho.
- Restauracao rapida de backups sem perda de integridade relacional.
- Exportacao de relatorios em planilha CSV compativel com Excel e Google Sheets, com filtros por mes, ano completo, periodo customizado ou historico total.
- Importacao direta de faturas CSV do Nubank com envio dos itens para a Caixa de Entrada.

### 6. Atualizacoes Integradas via GitHub

- Verificacao automatica de novas versoes ao iniciar o aplicativo ou sob demanda na tela de configuracoes.
- Consulta direta a API de Releases do GitHub, identificando novas funcionalidades e fornecendo link direto para download do executavel atualizado (chokin.apk).

---

## Arquitetura e Seguranca

- Paradigma: Offline-First.
- Banco de Dados: SQLite local protegido em sandbox privada do Android.
- Privacade: Zero telemetria, zero rastreadores e zero envio de informacoes para a internet.
- Integridade Contabil: Todas as alteracoes de saldo passam pelo motor de livro-razao (FinancialMovementEngine), garantindo consistencia matematica e auditabilidade completa do historico.
- Dinheiro em centavos: todos os valores sao inteiros em centavos, sem erro de arredondamento; o saldo disponivel e a Caixinha sao sempre a soma das movimentacoes.
- Atualizacoes: o repositorio e privado, entao a verificacao de versoes usa um token do GitHub informado em Ajustes, guardado apenas no celular (nunca no codigo nem nos backups).
- Interface: visual Sumi, inspirado no kakeibo (caderno japones de financas), com fundo de nanquim, texto cor de papel e uma unica cor de destaque. Imagens de referencia das telas em `test/goldens`.

---

## Download e Instalacao

Para instalar o aplicativo no seu dispositivo Android:

1. Acesse a secao de Releases do repositorio no GitHub.
2. Na versao mais recente, faca o download do arquivo `chokin.apk`.
3. No seu aparelho Android, abra o arquivo baixado.
4. Caso solicitado, permita a instalacao de aplicativos a partir de fontes confiaveis.
5. Conclua a instalacao e abra o aplicativo.

---

## Compilacao a partir do Codigo-Fonte

Caso prefira compilar o executavel a partir do codigo-fonte:

### Requisitos

- Flutter SDK (versao 3.0.0 ou superior)
- Android SDK com Java JDK 17
- Git configurado

### Instrucoes

1. Clone o repositorio:
```bash
git clone https://github.com/LuGoAn/chokin.git
cd chokin
```

2. Obtenha as dependencias do projeto:
```bash
flutter pub get
```

3. Execute a suite de testes automatizados para verificar a integridade:
```bash
flutter test
```

4. Compile o pacote de producao (Release):
```bash
flutter build apk --release --no-tree-shake-icons
```

O arquivo compilado estara disponivel em:
`build/app/outputs/flutter-apk/app-release.apk`

---

## Tecnologias Utilizadas

- Flutter & Dart
- SQLite (via sqflite)
- Kotlin (servicos nativos de notificacao em segundo plano no Android)
- Material Design 3

---

## Licenca

Projeto de uso pessoal e privado. Todos os direitos reservados.

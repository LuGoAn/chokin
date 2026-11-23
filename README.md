# Chokin

App de finanças pessoais pra Android que eu fiz porque nenhum dos que testei separava o que eu gasto do que eu pago pelos outros. Compro parcelado no cartão pra família e amigos, e no fim do mês eu não sabia mais quanto era meu e quanto eu tinha pra receber. No Chokin cada compra pode ser marcada como de outra pessoa, e a dívida dela vai caindo parcela por parcela.

Tudo fica salvo no celular (SQLite). Não tem conta, nem servidor, nem telemetria.

## O que ele faz

Um exemplo do dia a dia: chega a notificação do banco de uma compra de R$ 120,00 no cartão. O app captura, joga na Caixa de Entrada e eu só confirmo ou descarto. Se foi uma compra pro meu primo, marco o devedor, e ela entra na fatura do cartão mas não no meu gasto do mês.

- Cartões e faturas, com limite calculado em cima das parcelas reais e estorno total ou parcial.
- Recorrências projetadas pros próximos 12 meses, sem mexer no saldo de hoje até a data chegar.
- Cobranças de terceiros por mês, com quitação em ordem cronológica.
- Leitura das notificações do banco (um `NotificationListenerService` em Kotlin), com filtro pra propaganda de empréstimo e cupom.
- Importação de fatura CSV do Nubank, exportação em CSV e backup em JSON, manual ou automático.
- Aviso de versão nova, consultando a última release do GitHub.

Os valores são guardados em centavos, e o saldo é sempre a soma das movimentações.

## Instalar

Baixe o `chokin-<versão>.apk` na [última release](https://github.com/LuGoAn/chokin/releases/latest) e abra no celular. O Android vai pedir pra liberar a instalação de fontes desconhecidas.

## Rodar o código

Flutter 3 e JDK 17.

```bash
git clone https://github.com/LuGoAn/chokin.git
cd chokin
flutter pub get
flutter test
flutter run
```

Os testes de tela usam imagens de referência em `test/goldens`.

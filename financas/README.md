# Minhas Finanças

App Android (Flutter/Dart) para controle de finanças pessoais. Todos os dados
ficam **somente no aparelho**, em um banco SQLite local.

## Funcionalidades

- **Lançamentos** de receitas e despesas com categorias (personalizáveis).
- **Parcelamento** de 2x a 48x: no cartão, cada parcela cai na fatura do mês
  certo; fora do cartão (boleto, carnê), uma parcela por mês.
- **Cartões de crédito**: dia de fechamento e vencimento, fatura por mês
  (aberta, fechada ou paga), limite usado/disponível (parcelas futuras ocupam
  o limite) e pagamento de fatura.
- **Saldo e resumo mensal**: saldo em conta hoje, receitas, despesas e
  resultado do mês.
- **Gráficos**: despesas/receitas por categoria (rosca) e receitas x despesas
  dos últimos 6 meses (barras).
- **Orçamento mensal por categoria**, com alerta perto do limite e ao estourar.
- **Metas de economia**, com valor sugerido por mês para cumprir o prazo.
- **Segurança**: PIN de 4 ou 6 dígitos (guardado como hash no Keystore do
  Android), desbloqueio por biometria, bloqueio automático após 30 s em
  segundo plano, espera de 30 s após 5 tentativas erradas. O backup na
  nuvem do Android fica desativado para os dados do app.

## Como as contas são feitas

| Conceito | Regra |
|---|---|
| Compra no cartão | Entra na fatura do mês de **vencimento**. Compras a partir do dia de fechamento vão para a fatura seguinte. |
| Resumo do mês | Receitas e despesas fora do cartão pela data; compras no cartão pelo mês da fatura. |
| Saldo em conta | Receitas − despesas fora do cartão (até hoje) − faturas pagas. |
| Pagar fatura | Sai do saldo e libera o limite, mas não conta como despesa (as compras já contaram). |

## Gerar o APK

### Pelo GitHub (sem instalar nada)

A cada push na pasta `financas/`, o workflow **Gerar APK** roda os testes e gera
o APK. Baixe em **Actions → Gerar APK (Minhas Finanças) → execução mais
recente → Artifacts → `minhas-financas-apk`**. Também dá para rodar
manualmente com **Run workflow**.

### No seu computador

Pré-requisitos: [Flutter](https://docs.flutter.dev/get-started/install) e o
Android Studio (que instala o Android SDK).

```bash
cd financas
flutter pub get
flutter test                 # roda os testes
flutter run                  # roda no celular conectado (modo depuração)
flutter build apk --release  # gera build/app/outputs/flutter-apk/app-release.apk
```

Para instalar, copie o `app-release.apk` para o celular e abra (é preciso
permitir "instalar apps de fontes desconhecidas").

> O APK de release está assinado com a chave de depuração, o que basta para
> uso pessoal. Para publicar na Play Store, crie uma chave própria:
> <https://docs.flutter.dev/deployment/android#sign-the-app>.

## Estrutura do código

```
lib/
  main.dart, app.dart        inicialização, tema e camada de bloqueio
  core/                      dinheiro (centavos), datas/faturas, ícones e cores
  data/database.dart         tabelas e consultas (drift + SQLite)
  security/                  PIN e biometria
  ui/                        telas: início, lançamentos, cartões, relatórios,
                             orçamentos, metas, categorias, segurança
test/                        testes de regras, banco e telas
```

Valores são sempre guardados em **centavos** (inteiros) para evitar erros de
arredondamento.

Depois de alterar as tabelas em `lib/data/database.dart`, gere o código do
banco de novo:

```bash
dart run build_runner build
```

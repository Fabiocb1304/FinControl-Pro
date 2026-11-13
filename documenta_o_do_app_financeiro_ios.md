# Master Specification (SPEC.md) — App Financeiro iOS (FinControl Pro)

> **Instrução para o Agente de IA (Antigravity):**
> Você atuará como um Engenheiro iOS Sênior especialista em Swift 6, SwiftUI, SwiftData e Swift Charts. Seu objetivo é desenvolver este aplicativo seguindo rigorosamente a arquitetura, a modelagem de dados, as regras matemáticas de negócio e os padrões de alta performance ($120\text{ FPS}$) e animações fluidas descritos neste documento. Não utilize APIs depreciadas (como `ObservableObject` antigo ou `CoreData` legado); utilize exclusivamente a macro `@Observable`, `SwiftData` e concorrência estruturada (`async/await` e `@ModelActor`).

---

## 1. Visão Geral do Produto

Aplicativo nativo para iOS (iOS 17.0+) focado em controle financeiro pessoal de alta precisão. O grande diferencial do sistema é a separação contábil exata entre **gastos pessoais do usuário** e **empréstimos de limite de cartão de crédito para terceiros**, permitindo registrar recebimentos e abatimentos na fatura sem distorcer o orçamento pessoal ou os gráficos de custo de vida, além de consolidar o saldo em contas bancárias e a carteira de investimentos.

---

## 2. Stack Tecnológica e Padrões de Arquitetura

* **Linguagem & SDK:** Swift 6, iOS 17.0+.
* **UI Framework:** SwiftUI (100% declarativo).
* **Gerenciamento de Estado:** Macro `@Observable` (Observation Framework) para atualizações granulares de tela sem re-renderizações desnecessárias.
* **Persistência Local & Nuvem:** `SwiftData` com suporte a sincronização via `CloudKit`.
* **Gráficos e Relatórios:** `Swift Charts` nativo com suporte a inspeção interativa por toque.
* **Segurança:** `LocalAuthentication` (FaceID / TouchID).
* **Arquitetura:** MVVM + Camada de Serviços (`@ModelActor` para operações pesadas em background).

### Estrutura de Diretórios Obrigatória

```text
/FinControlApp
  ├── /App
  │     └── FinControlApp.swift          # Configuração do ModelContainer e LockScreen (FaceID)
  ├── /Models                            # Entidades @Model do SwiftData
  │     ├── Account.swift
  │     ├── Category.swift
  │     ├── CreditCard.swift
  │     ├── Borrower.swift
  │     ├── Transaction.swift
  │     ├── Invoice.swift
  │     ├── ThirdPartySettlement.swift
  │     └── Investment.swift
  ├── /Services                          # Regras de negócio, cálculos e persistência assíncrona
  │     ├── FinanceEngineActor.swift     # Cálculo de faturas, limites e abatimentos em background
  │     ├── InvoiceGeneratorService.swift# Geração de parcelas e fechamento mensal
  │     └── NotificationService.swift    # Alertas locais (80% e 100% da meta, vencimentos)
  ├── /ViewModels                        # Estados da UI com @Observable
  │     ├── DashboardViewModel.swift
  │     ├── CreditCardViewModel.swift
  │     ├── AccountExtractViewModel.swift
  │     └── InvestmentViewModel.swift
  ├── /Views
  │     ├── /Main
  │     │     └── MainTabView.swift      # Navegação principal com botão central (+)
  │     ├── /Dashboard
  │     │     ├── DashboardView.swift
  │     │     └── InteractiveChartsView.swift
  │     ├── /CreditCards
  │     │     ├── CardsListView.swift
  │     │     ├── InvoiceDetailView.swift
  │     │     └── ThirdPartyLoansView.swift
  │     ├── /Accounts
  │     │     └── AccountsExtractView.swift
  │     ├── /Investments
  │     │     └── InvestmentsPortfolioView.swift
  │     └── /TransactionForm
  │           └── AddTransactionSheet.swift
  └── /Components                        # Componentes visuais reutilizáveis e animados
        ├── AnimatedCurrencyText.swift
        ├── GlassCardView.swift
        └── SwipeableTransactionRow.swift
```

---

## 3. Requisitos de Performance ($120\text{ FPS}$), Interatividade e Animações

O aplicativo deve rodar com fluidez absoluta (ProMotion $120\text{ FPS}$) e resposta tátil imediata.

### 3.1. Diretrizes de Desempenho
1. **Zero Bloqueio da Main Thread:** Todos os cálculos de somatório de faturas, geração de parcelas futuras, abatimento de empréstimos e consolidação de investimentos devem rodar fora da thread principal ou através de queries otimizadas (`FetchDescriptor` com `#Predicate` e `fetchLimit`).
2. **Renderização Preguiçosa (Lazy Loading):** Listas de extrato e faturas devem usar `LazyVStack` dentro de `ScrollView`, evitando carregar meses passados ou futuros na memória até que sejam solicitados.
3. **Cache de Resumo Mensal:** Os totalizadores do mês ativo devem ficar cacheados na `Invoice` e na `Account` para abertura instantânea do Dashboard.

### 3.2. Sistema de Animações e Micro-interações
1. **Física de Mola (Spring Physics):** Todas as expansões de cards, trocas de abas e filtros devem utilizar `.animation(.spring(duration: 0.35, bounce: 0.15), value:)` para permitir interrupção fluida pelo toque do usuário.
2. **Transição Numérica de Valores:** Todo valor monetário exibido na tela (saldos, faturas, investimentos) deve aplicar `.contentTransition(.numericText(value:))` para que os números rolem suavemente ao atualizar.
3. **Geometria Conectada:** Utilizar `.matchedGeometryEffect` na transição entre o cartão de crédito no carrossel e a tela de detalhes da fatura, bem como na expansão dos detalhes de um devedor (`Borrower`).
4. **Gráficos Interativos:** Nos gráficos do `Swift Charts`, implementar `.chartXSelection(value:)` e `.chartAngleSelection(value:)` para permitir que o usuário deslize o dedo sobre as barras/fatias e veja o valor exato atualizado dinamicamente no cabeçalho do card.
5. **Feedback Háptico (Taptic Engine):**
   * `.sensoryFeedback(.selection, trigger:)` ao trocar de mês, filtrar categorias ou deslizar o dedo sobre os gráficos.
   * `.sensoryFeedback(.success, trigger:)` ao registrar um novo lançamento, concluir um aporte ou dar baixa/abater uma dívida de terceiro na fatura.
6. **Gestos Rápidos (`Swipe Actions`):** Nas linhas de despesas de terceiros dentro da fatura, permitir deslizar para a direita para **"Marcar como Recebido/Abater"** e para a esquerda para **"Cobrar via WhatsApp"** (`ShareLink`).

---

## 4. Regras de Negócio e Fórmulas Matemáticas

### RN01 - Gestão de Contas (Débito, Pix e Dinheiro)
* Suporte a múltiplas contas bancárias.
* Movimentações de entrada (`Income`), saída (`Expense`), transferência entre contas (`Transfer`) e reembolso de terceiros (`ThirdPartyReimbursement`).
* **Regra de Ouro:** Reembolsos pagos por terceiros aumentam o saldo da conta bancária, mas **nunca** devem ser somados como "Receita Pessoal" nos gráficos de ganhos mensais.

### RN02 - Cálculo de Limite do Cartão de Crédito
O limite disponível do cartão é reduzido por todas as parcelas em aberto (tanto de gastos próprios quanto de gastos emprestados para terceiros), sendo restituído conforme faturas são pagas ou valores são abatidos antecipadamente:

$$
\text{Limite Disponível} = \text{Limite Total} - \sum \text{Parcelas Abertas (Próprias)} - \sum \text{Parcelas Abertas (Terceiros)} + \sum \text{Abatimentos Antecipados}
$$

### RN03 - Separação Contábil da Fatura do Cartão
Cada fatura mensal (`Invoice`) deve apresentar 3 indicadores distintos e simultâneos na interface:

1. **Fatura Bruta (Valor total cobrado pelo banco):**
   $$
   \text{Fatura Bruta} = \sum \text{Parcelas Próprias do Mês} + \sum \text{Parcelas de Terceiros do Mês}
   $$

2. **Meu Custo Real (Impacto no orçamento pessoal do usuário):**
   $$
   \text{Meu Custo Real} = \sum \text{Parcelas Próprias do Mês}
   $$
   *(Apenas as transações que compõem o "Meu Custo Real" entram nos gráficos de despesas por categoria e no consumo de metas de orçamento).*

3. **Saldo Líquido a Pagar da Fatura (Considerando abatimentos já feitos):**
   $$
   \text{Saldo a Pagar} = \text{Fatura Bruta} - \text{Abatimentos Antecipados Realizados}
   $$

### RN04 - Fluxo de Empréstimo de Cartão e Abatimento na Fatura
Ao lançar uma compra no cartão e marcar `isThirdParty = true` vinculando um devedor (`Borrower`):
* Se a compra for parcelada em $N$ vezes, o sistema gera automaticamente $N$ registros vinculados às respectivas faturas futuras, determinando a fatura correta a partir da comparação entre a data da compra e o `closingDay` (dia de fechamento) do cartão.
* Quando o terceiro paga o usuário, o sistema oferece duas opções de baixa para a parcela ou para o total devido pelo terceiro naquele mês:
  * **Opção 1 — Recebido na Conta (`ReceivedInAccount`):** O dinheiro entra no saldo da conta bancária selecionada como reembolso, aguardando o fechamento da fatura.
  * **Opção 2 — Abatido Direto na Fatura (`AppliedToInvoice`):** O usuário já adiantou esse valor no pagamento da fatura junto ao banco. O sistema incrementa o campo `prepaidAmount` da fatura, reduz o `Saldo a Pagar` e libera imediatamente o `Limite Disponível` do cartão.

### RN05 - Orçamentos e Alertas de Saúde Financeira
* Cada categoria de gasto possui um teto mensal (`monthlyBudget`).
* O sistema calcula o percentual consumido apenas com gastos próprios (Débito/Pix + Cartão Próprio):
  $$
  \text{Consumo da Categoria (\%)} = \left( \frac{\text{Gastos Próprios na Categoria}}{\text{Meta Mensal da Categoria}} \right) \times 100
  $$
* Disparar alerta visual e notificação local ao atingir $80\%$ (Atenção - Amarelo) e $100\%$ (Crítico - Vermelho).

---

## 5. Modelagem de Dados (`SwiftData` `@Model`)

Implemente as seguintes entidades utilizando `@Model` do SwiftData:

### 1. `Account` (Conta Bancária)
* `id: UUID`
* `name: String` (ex: "Nubank", "Itaú")
* `initialBalance: Double`
* `currentBalance: Double`
* `colorHex: String`
* `iconName: String`
* `@Relationship(deleteRule: .cascade) var transactions: [Transaction]`

### 2. `Category` (Categoria de Orçamento)
* `id: UUID`
* `name: String`
* `iconName: String`
* `colorHex: String`
* `isIncome: Bool`
* `monthlyBudget: Double?`

### 3. `CreditCard` (Cartão de Crédito)
* `id: UUID`
* `name: String`
* `totalLimit: Double`
* `closingDay: Int` ($1$ a $31$)
* `dueDay: Int` ($1$ a $31$)
* `colorHex: String`
* `@Relationship(deleteRule: .cascade) var invoices: [Invoice]`

### 4. `Borrower` (Terceiro / Devedor de Cartão)
* `id: UUID`
* `name: String`
* `phone: String?`
* `avatarColorHex: String`
* `@Relationship(deleteRule: .cascade) var transactions: [Transaction]`
* `@Relationship(deleteRule: .cascade) var settlements: [ThirdPartySettlement]`

### 5. `Invoice` (Fatura Mensal do Cartão)
* `id: UUID`
* `month: Int` ($1$ a $12$)
* `year: Int`
* `statusRaw: String` (`Open`, `Closed`, `Paid`)
* `prepaidAmount: Double` (Total já abatido antecipadamente na fatura)
* `card: CreditCard?`
* `@Relationship(deleteRule: .cascade) var transactions: [Transaction]`
* `@Relationship(deleteRule: .cascade) var settlements: [ThirdPartySettlement]`

### 6. `Transaction` (Transação / Parcela Individual)
* `id: UUID`
* `parentTransactionId: UUID?` (Agrupa parcelas de uma mesma compra)
* `title: String`
* `amount: Double`
* `date: Date`
* `paymentMethodRaw: String` (`DebitPix`, `CreditCard`, `Transfer`, `Reimbursement`)
* `isThirdParty: Bool` (Define se foi cartão emprestado)
* `installmentIndex: Int` (ex: $1$)
* `totalInstallments: Int` (ex: $10$)
* `isPaidOrSettled: Bool`
* `account: Account?`
* `category: Category?`
* `invoice: Invoice?`
* `borrower: Borrower?`

### 7. `ThirdPartySettlement` (Registro de Abatimento/Pagamento de Terceiro)
* `id: UUID`
* `amount: Double`
* `date: Date`
* `settlementTypeRaw: String` (`ReceivedInAccount`, `AppliedToInvoice`)
* `borrower: Borrower?`
* `invoice: Invoice?`
* `destinationAccount: Account?`

### 8. `Investment` (Ativo de Investimento)
* `id: UUID`
* `name: String` (ex: "Tesouro Selic", "PETR4", "Bitcoin")
* `assetClassRaw: String` (`FixedIncome`, `Stocks`, `RealEstateFunds`, `Crypto`)
* `institution: String`
* `investedAmount: Double` (Custo de aquisição)
* `currentBalance: Double` (Valor atualizado com rendimentos)
* `lastUpdated: Date`

---

## 6. Especificação de Telas (UI/UX Design System)

Utilizar visual moderno estilo Apple Wallet / Apple Health, suporte nativo a *Dark Mode*, cartões com fundo translúcido (`.ultraThinMaterial`), cantos arredondados (`cornerRadius: 20`) e tipografia `SF Pro Rounded` para valores financeiros.

### Aba 1: Dashboard (`DashboardView`)
* **Header:** Seletor de Mês/Ano com animação deslizante e botão de ocultação de valores (Modo Privacidade com efeito `.redacted(reason: .placeholder)`).
* **Bento Grid de Resumo:**
  * Card 1: Saldo Total em Contas.
  * Card 2: Patrimônio Investido + Rentabilidade ($\%$).
  * Card 3: Fatura do Mês (mostrando em destaque **Meu Gasto Real** e, abaixo em verde, o valor **A Receber de Terceiros**).
* **Gráfico Interativo Principal (`Swift Charts`):**
  * Alternância animada entre:
    1. *Gastos Reais por Categoria* (`SectorMark` - Gráfico de Rosca interativo).
    2. *Composição da Fatura* (`BarMark` empilhado: Meus Gastos vs. Gastos de Terceiros vs. Abatimentos).
* **Termômetro de Metas:** Barras de progresso animadas para as categorias com orçamento definido.

### Aba 2: Cartões e Empréstimos (`CardsListView` & `InvoiceDetailView`)
* **Carrossel 3D de Cartões:** Barra de limite com 3 cores (Azul: Meu uso | Laranja: Uso de Terceiros | Cinza: Limite Disponível).
* **Filtro Interno da Fatura (Segmented Control animado):**
  * `Visão Geral`: Lista todas as compras da fatura.
  * `Meus Gastos`: Filtra apenas despesas pessoais do usuário.
  * `Cartão Emprestado (Por Pessoa)`: Agrupa os gastos por `Borrower`. Exibe o total devido por cada pessoa no mês, o status (`Pendente`, `Recebido`, `Abatido na Fatura`), botão **"Abater Valor"** (abre modal rápido para escolher se recebeu na conta ou já abateu na fatura) e botão **"Enviar Resumo"** (gera texto formatado com todas as parcelas da pessoa naquele mês para compartilhamento via WhatsApp).

### Aba 3: Modal Central de Lançamento Rápido (`AddTransactionSheet`)
* Apresentado com `.presentationDetents([.large])`.
* Teclado numérico customizado ágil com formatação de moeda em tempo real.
* Quando o método selecionado for **Cartão de Crédito**:
  * Exibir seletor de parcelas ($1\text{x}$ a $24\text{x}$).
  * Exibir Toggle destacado com ícone: **"Emprestei o Cartão para alguém?"**
  * Se ativado (com animação `.spring`): oculta a seleção de categoria de orçamento pessoal e exibe o seletor horizontal de pessoas (`Borrower`), com botão para criar um novo contato rapidamente.

### Aba 4: Extrato de Contas (`AccountsExtractView`)
* Lista de contas bancárias no topo com saldo individual.
* Extrato unificado em `LazyVStack` agrupado por dia, diferenciando visualmente despesas pessoais, receitas e reembolsos de cartão recebidos de terceiros.

### Aba 5: Investimentos (`InvestmentsPortfolioView`)
* Card de Patrimônio Total e Lucro/Prejuízo consolidado ($R\$$ e $\%$).
* Gráfico de Rosca (`SectorMark`) mostrando a alocação da carteira por classe de ativo.
* Lista de ativos agrupados por classe com botões rápidos para **Novo Aporte** (com opção de debitar o valor automaticamente de uma `Account`) e **Atualizar Saldo Atual**.

---

## 7. Roteiro de Execução Passo a Passo (Para o Antigravity)

> **Comando para o Agente:** Execute a criação do projeto seguindo estritamente a ordem das fases abaixo, garantindo que cada fase compile sem erros antes de avançar para a próxima.

* **Passo 1 (Camada de Dados):** Crie todos os modelos `@Model` na pasta `/Models` e configure o `ModelContainer` no arquivo principal do App, incluindo dados de exemplo (*Preview/Seed Data*) para testes imediatos.
* **Passo 2 (Motor Financeiro e Regras de Cartão):** Implemente o `FinanceEngineActor` e o `InvoiceGeneratorService` na pasta `/Services`, garantindo a criação automática de faturas por data de fechamento, geração de parcelas e a matemática exata de separação entre gasto próprio, empréstimo de terceiro e abatimento de fatura.
* **Passo 3 (Componentes Visuais e Animações):** Crie os componentes reutilizáveis (`AnimatedCurrencyText`, `GlassCardView`) aplicando `.contentTransition(.numericText())`, `.spring` e `.sensoryFeedback`.
* **Passo 4 (Telas de Cartão, Abatimento e Lançamentos):** Construa a `AddTransactionSheet` com o fluxo de cartão emprestado e a `InvoiceDetailView` com a aba de gestão por devedor (`Borrower`), baixa de valores e gerador de cobrança para WhatsApp.
* **Passo 5 (Dashboard Interativo e Investimentos):** Implemente a `DashboardView` com os gráficos interativos do `Swift Charts`, o controle de metas por categoria e a tela `InvestmentsPortfolioView`.
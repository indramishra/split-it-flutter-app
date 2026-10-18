# Splitwise Flutter Clone

A complete Flutter clone of Splitwise, reverse-engineered using **REA (Reverse Engineer Anything)** to extract real-world data structures, API contracts, and the core **Min-Cash-Flow Debt Simplification Algorithm**.

---

## 🚀 Key Features

1. **Groups & Type Categories**:
   - Manage groups (Home, Trip, Couple, Other).
   - Track total group spending and individual balances.
   - Toggle **"Simplify Debts"** per group.

2. **Friends & Ledger**:
   - Individual balances across all shared expenses.
   - Real-time indicator ("owes you" vs "you owe").

3. **Expense Splitting**:
   - **Split Equally** across all participants.
   - **Exact Amounts / Shares** with automatic total reconciliation.
   - Assign payers and categorize (Food & Drink, Groceries, Travel, Rent, Utilities, etc.).

4. **Debt Simplification Engine (`lib/services/debt_simplifier.dart`)**:
   - Resolves cyclical and transit debts using greedy matching of maximum debtor with maximum creditor.
   - Reduces $O(N^2)$ cross-payments to at most $N-1$ transactions.

5. **Settle Up**:
   - Record cash / direct payments to clear debts.
   - Updates balances and logs audit activity in the Activity timeline.

---

## 🛠️ Tech Stack & Architecture

- **State Management**: `provider` (`ChangeNotifier`)
- **Models**:
  - `User` (`lib/models/user.dart`)
  - `Group` (`lib/models/group.dart`)
  - `Expense` & `ActivityItem` (`lib/models/expense.dart`)
  - `Debt` (`lib/models/user.dart`)
- **Theme**: Clean Splitwise signature teal (`#1CC29F`), charcoal typography, and positive/negative balance indicators.

---

## 🏃 Getting Started

### Prerequisites
- Flutter 3.13+ (`/Users/indramanimishra/local/restorent-app/flutter/bin/flutter`)

### Run Tests
```bash
flutter test
```

### Run Static Analysis
```bash
flutter analyze
```

### Launch App
```bash
# On macOS / Chrome / iOS simulator / Android device
flutter run
```

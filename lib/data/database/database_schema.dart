abstract final class DatabaseSchema {
  static const int version = 6;

  static const Map<String, String> tables = {
    'people': '''
      CREATE TABLE people (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        createdAt TEXT NOT NULL
      )
    ''',
    'categories': '''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        colorHex TEXT NOT NULL,
        type TEXT NOT NULL,
        isCustom INTEGER NOT NULL DEFAULT 0,
        displayOrder INTEGER NOT NULL DEFAULT 0
      )
    ''',
    'credit_cards': '''
      CREATE TABLE credit_cards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        closingDay INTEGER NOT NULL,
        dueDay INTEGER NOT NULL,
        creditLimitCents INTEGER,
        flag TEXT,
        colorHex TEXT NOT NULL
      )
    ''',
    'invoices': '''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        cardId TEXT NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        closingDate TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        effectiveDueDate TEXT NOT NULL,
        totalAmountCents INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        paidAt TEXT,
        paidAmountCents INTEGER,
        FOREIGN KEY (cardId) REFERENCES credit_cards (id) ON DELETE CASCADE
      )
    ''',
    'transactions': '''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amountCents INTEGER NOT NULL,
        purchaseDate TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        type TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        personId TEXT NOT NULL,
        cardId TEXT,
        totalInstallments INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        sourceNotificationId TEXT,
        isCancelled INTEGER NOT NULL DEFAULT 0,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurrence TEXT NOT NULL DEFAULT 'none',
        recurringGroupId TEXT,
        recurrenceEndedAt TEXT,
        recurrenceExceptions TEXT,
        createdAt TEXT,
        refundAmountCents INTEGER NOT NULL DEFAULT 0,
        refundedAt TEXT,
        refundMethod TEXT,
        refundNotes TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories (id),
        FOREIGN KEY (personId) REFERENCES people (id),
        FOREIGN KEY (cardId) REFERENCES credit_cards (id)
      )
    ''',
    'installments': '''
      CREATE TABLE installments (
        id TEXT PRIMARY KEY,
        transactionId TEXT NOT NULL,
        invoiceId TEXT NOT NULL,
        installmentNumber INTEGER NOT NULL,
        totalInstallments INTEGER NOT NULL,
        amountCents INTEGER NOT NULL,
        personId TEXT,
        FOREIGN KEY (transactionId) REFERENCES transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''',
    'reimbursements': '''
      CREATE TABLE reimbursements (
        id TEXT PRIMARY KEY,
        personId TEXT NOT NULL,
        transactionId TEXT NOT NULL,
        totalAmountCents INTEGER NOT NULL,
        remainingAmountCents INTEGER NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (personId) REFERENCES people (id),
        FOREIGN KEY (transactionId) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''',
    'reimbursement_payments': '''
      CREATE TABLE reimbursement_payments (
        id TEXT PRIMARY KEY,
        reimbursementId TEXT NOT NULL,
        amountCents INTEGER NOT NULL,
        paymentDate TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (reimbursementId) REFERENCES reimbursements (id) ON DELETE CASCADE
      )
    ''',
    'financial_movements': '''
      CREATE TABLE financial_movements (
        id TEXT PRIMARY KEY,
        transactionId TEXT,
        invoiceId TEXT,
        reimbursementId TEXT,
        type TEXT NOT NULL,
        amountCents INTEGER NOT NULL,
        movementDate TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''',
    'inbox_notifications': '''
      CREATE TABLE inbox_notifications (
        id TEXT PRIMARY KEY,
        rawId TEXT NOT NULL,
        packageName TEXT NOT NULL,
        appName TEXT NOT NULL,
        rawTitle TEXT NOT NULL,
        rawText TEXT NOT NULL,
        parsedAmount REAL,
        parsedMerchant TEXT,
        suggestedPaymentMethod TEXT,
        eventTimestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        duplicateGroupId TEXT,
        duplicateScore REAL NOT NULL DEFAULT 0.0,
        detectedSources TEXT
      )
    ''',
    'app_settings': '''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''',
  };
}

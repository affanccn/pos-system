const fs = require('fs');
let file = 'c:/Users/Asus/backend/prisma/schema.prisma';
let code = fs.readFileSync(file, 'utf8');

// Fix enums
code = code.replace(/enum OrderItemStatus \{[\s\S]*?\}/, 
  'enum OrderItemStatus {\n' +
  '  PENDING\n' +
  '  PREPARING\n' +
  '  READY\n' +
  '  SERVED\n' +
  '  CANCELLED\n' +
  '  VOID\n' +
  '  COMPLIMENTARY\n' +
  '  RETURNED\n' +
  '}');

code = code.replace(/enum PaymentMethod \{[\s\S]*?\}/,
  'enum PaymentMethod {\n' +
  '  CASH\n' +
  '  CARD\n' +
  '  MIXED\n' +
  '  ACCOUNT\n' +
  '}');

// Fix Order
code = code.replace(/totalAmountCents Int\s*@default\(0\) @map\("total_amount_cents"\)\s*notes\s*String\?\s*@db\.VarChar\(255\)/,
  'totalAmountCents Int         @default(0) @map("total_amount_cents")\n' +
  '  paidAmountCents  Int         @default(0) @map("paid_amount_cents")\n' +
  '  discountAmountCents Int      @default(0) @map("discount_amount_cents")\n' +
  '  notes            String?     @db.VarChar(255)');

// Fix OrderItem
code = code.replace(/quantity\s*Int\s*@default\(1\)\s*totalPriceCents\s*Int\s*@map\("total_price_cents"\)\s*status\s*OrderItemStatus @default\(PENDING\)/,
  'quantity            Int             @default(1)\n' +
  '  paidQuantity        Int             @default(0) @map("paid_quantity")\n' +
  '  totalPriceCents     Int             @map("total_price_cents")\n' +
  '  discountAmountCents Int             @default(0) @map("discount_amount_cents")\n' +
  '  status              OrderItemStatus @default(PENDING)');

fs.writeFileSync(file, code, 'utf8');

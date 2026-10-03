const fs = require('fs');
let file = 'c:/Users/Asus/pos_mobile/lib/features/order/order_screen.dart';
let code = fs.readFileSync(file, 'utf8');

if (!code.includes('catalog_model.dart')) {
    code = code.replace(/import 'package:flutter\/material\.dart';/, "import 'package:flutter/material.dart';\nimport '../../data/models/catalog_model.dart';");
}

code = code.replace(/onTap:\s*\(\)\s*\{\s*ref\.read\(cartProvider\)\.addProduct\(product\);\s*\},/g, 
"onTap: () { if (product.modifierGroups.isNotEmpty) { _showModifierModal(context, product, ref); } else { ref.read(cartProvider).addProduct(product); } },");

code = code.replace(/cart\.removeProduct\(item\.product\)/g, 'cart.removeProductAt(index)');
code = code.replace(/cart\.addProduct\(item\.product\)/g, 'cart.addProductAt(index)');

fs.writeFileSync(file, code, 'utf8');

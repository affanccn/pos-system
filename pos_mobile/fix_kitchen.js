const fs = require('fs');
let file = 'c:/Users/Asus/pos_mobile/lib/features/kitchen/kitchen_screen.dart';
let code = fs.readFileSync(file, 'utf8');

// Update _buildStationChip UI
const chipPattern = /_buildStationChip\('[^']*',\s*'ALL',\s*Icons\.all_inclusive\),[\s\S]*?_buildStationChip\('[^']*',\s*'BAR',\s*Icons\.local_bar\),/;
code = code.replace(chipPattern, 
"_buildStationChip('Tüm Siparişler', 'ALL', Icons.all_inclusive),\n" +
"                  const SizedBox(width: 8),\n" +
"                  _buildStationChip('Mutfak', 'KITCHEN', Icons.restaurant),\n" +
"                  const SizedBox(width: 8),\n" +
"                  _buildStationChip('Bar / İçecek', 'BAR', Icons.local_bar),\n" +
"                  const SizedBox(width: 8),\n" +
"                  _buildStationChip('Tatlı', 'DESSERT', Icons.cake),\n" +
"                  const SizedBox(width: 8),\n" +
"                  _buildStationChip('Kahve', 'COFFEE', Icons.coffee),");

// Update _matchesStation logic
const matchesPattern = /bool _matchesStation\(dynamic item\) \{[\s\S]*?return false;\s*\}/;
const newMatches = "bool _matchesStation(dynamic item) {\n" +
"    if (_selectedStation == 'ALL') return true;\n" +
"    final stationType = item['product']?['category']?['stationType'] as String? ?? 'KITCHEN';\n" +
"    return stationType == _selectedStation;\n" +
"  }";
code = code.replace(matchesPattern, newMatches);

fs.writeFileSync(file, code, 'utf8');

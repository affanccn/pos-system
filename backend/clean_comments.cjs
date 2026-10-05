const fs = require('fs');
const path = require('path');

function walk(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(function(file) {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (stat && stat.isDirectory()) {
      results = results.concat(walk(file));
    } else {
      if (file.endsWith('.ts') || file.endsWith('.js') || file.endsWith('.dart')) {
        results.push(file);
      }
    }
  });
  return results;
}

function cleanFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split('\n');
  let newLines = [];
  
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    // Check if line is a comment
    if (trimmed.startsWith('//') && !trimmed.startsWith('///')) {
      // Keep structural or linting comments
      if (trimmed.toLowerCase().includes('eslint') || 
          trimmed.toLowerCase().includes('ignore') || 
          trimmed.toLowerCase().includes('todo') ||
          trimmed.includes('prettier')) {
        newLines.push(lines[i]);
      } else {
        // Skip this line (remove comment)
        continue;
      }
    } else if (lines[i].includes(' // ') || lines[i].includes('\t// ')) {
      // Inline comments like `const x = 1; // do this`
      // We will remove the comment part
      const parts = lines[i].split(' // ');
      if (parts.length > 1) {
        newLines.push(parts[0].trimEnd());
      } else {
        const parts2 = lines[i].split('\t// ');
        if (parts2.length > 1) {
          newLines.push(parts2[0].trimEnd());
        } else {
          newLines.push(lines[i]);
        }
      }
    } else {
      newLines.push(lines[i]);
    }
  }
  
  const newContent = newLines.join('\n');
  if (content !== newContent) {
    fs.writeFileSync(filePath, newContent, 'utf8');
    console.log(`Temizlendi: ${filePath}`);
  }
}

const backendSrc = path.join(__dirname, 'src');
const flutterLib = path.join(__dirname, '..', 'pos_mobile', 'lib');

const filesToClean = [...walk(backendSrc), ...walk(flutterLib)];

filesToClean.forEach(cleanFile);
console.log('Tüm AI benzeri yorum satırları temizlendi!');

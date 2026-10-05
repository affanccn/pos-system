const fs = require('fs');
const path = require('path');

function cleanFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split('\n');
  let newLines = [];
  
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed.startsWith('//') && !trimmed.startsWith('///')) {
      if (trimmed.toLowerCase().includes('eslint') || 
          trimmed.toLowerCase().includes('ignore') || 
          trimmed.toLowerCase().includes('todo') ||
          trimmed.includes('prettier')) {
        newLines.push(lines[i]);
      } else {
        continue;
      }
    } else if (lines[i].includes(' // ') || lines[i].includes('\t// ')) {
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

cleanFile(path.join(__dirname, 'prisma', 'seed.ts'));

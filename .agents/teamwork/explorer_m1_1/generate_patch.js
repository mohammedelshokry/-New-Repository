const fs = require('fs');
const path = require('path');

const originalFile = path.resolve(__dirname, '../../../backend/src/index.ts');
const proposedFile = path.resolve(__dirname, 'proposed_index.ts');

const origContent = fs.readFileSync(originalFile, 'utf8').replace(/\r\n/g, '\n');
const propContent = fs.readFileSync(proposedFile, 'utf8').replace(/\r\n/g, '\n');

// Simple unified diff generator
function createUnifiedDiff(oldName, newName, oldStr, newStr) {
  const oldLines = oldStr.split('\n');
  const newLines = newStr.split('\n');
  
  const diffLines = [
    `--- a/${oldName}`,
    `+++ b/${newName}`
  ];

  let i = 0, j = 0;
  while (i < oldLines.length || j < newLines.length) {
    if (i < oldLines.length && j < newLines.length && oldLines[i] === newLines[j]) {
      i++;
      j++;
    } else {
      let startI = i;
      let startJ = j;
      while (i < oldLines.length && j < newLines.length && oldLines[i] !== newLines[j]) {
        i++;
        j++;
      }
      if (i > startI || j > startJ) {
        diffLines.push(`@@ -${startI + 1},${i - startI} +${startJ + 1},${j - startJ} @@`);
        for (let k = startI; k < i; k++) {
          diffLines.push(`-${oldLines[k]}`);
        }
        for (let k = startJ; k < j; k++) {
          diffLines.push(`+${newLines[k]}`);
        }
      }
    }
  }
  return diffLines.join('\n');
}

const diff = createUnifiedDiff('src/index.ts', 'src/index.ts', origContent, propContent);
fs.writeFileSync(path.join(__dirname, 'index.patch'), diff, 'utf8');
console.log('Saved index.patch');

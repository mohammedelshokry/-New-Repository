const path = require('path');
const backendDir = path.resolve(__dirname, '../../../backend');
const ts = require(path.join(backendDir, 'node_modules/typescript'));
const fs = require('fs');

const filePath = path.join(backendDir, 'api/[...path].ts');
let code = fs.readFileSync(filePath, 'utf8');
code = code.replace('// @ts-nocheck', '// removed ts-nocheck');

const options = {
  target: ts.ScriptTarget.ES2022,
  module: ts.ModuleKind.CommonJS,
  esModuleInterop: true,
  strict: false,
  skipLibCheck: true,
  noEmit: true
};

const host = ts.createCompilerHost(options);
const originalGetSourceFile = host.getSourceFile;
host.getSourceFile = (fileName, languageVersion) => {
  if (path.resolve(fileName) === filePath) {
    return ts.createSourceFile(fileName, code, languageVersion);
  }
  return originalGetSourceFile(fileName, languageVersion);
};

const program = ts.createProgram([filePath], options, host);
const allDiagnostics = ts.getPreEmitDiagnostics(program);

console.log('Total diagnostics for api/[...path].ts:', allDiagnostics.length);
allDiagnostics.forEach((d) => {
  if (d.file) {
    const { line, character } = d.file.getLineAndCharacterOfPosition(d.start);
    const message = ts.flattenDiagnosticMessageText(d.messageText, '\n');
    console.log(`[Line ${line + 1}:${character + 1}] ${message}`);
  }
});

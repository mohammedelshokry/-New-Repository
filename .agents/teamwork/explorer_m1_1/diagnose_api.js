const path = require('path');
const backendDir = path.resolve(__dirname, '../../../backend');
const ts = require(path.join(backendDir, 'node_modules/typescript'));
const fs = require('fs');

const apiFile = path.join(backendDir, 'api/[...path].ts');
let code = fs.readFileSync(apiFile, 'utf8');
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
  if (path.resolve(fileName) === apiFile) {
    return ts.createSourceFile(fileName, code, languageVersion);
  }
  return originalGetSourceFile(fileName, languageVersion);
};

const program = ts.createProgram([apiFile], options, host);
const diagnostics = ts.getPreEmitDiagnostics(program);

console.log('Total diagnostics in api/[...path].ts:', diagnostics.length);
const errors = diagnostics.map(d => {
  if (!d.file) return d.messageText;
  const { line, character } = d.file.getLineAndCharacterOfPosition(d.start);
  const message = ts.flattenDiagnosticMessageText(d.messageText, '\n');
  return `[Line ${line + 1}:${character + 1}] ${message}`;
});
console.log(errors);
fs.writeFileSync(path.join(__dirname, 'api_errors.json'), JSON.stringify(errors, null, 2));

const path = require('path');
const backendDir = path.resolve(__dirname, '../../../backend');
const ts = require(path.join(backendDir, 'node_modules/typescript'));
const fs = require('fs');

const indexFile = path.join(backendDir, 'src/index.ts');
let code = fs.readFileSync(indexFile, 'utf8');

function compile(sourceCode) {
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
    if (path.resolve(fileName) === indexFile) {
      return ts.createSourceFile(fileName, sourceCode, languageVersion);
    }
    return originalGetSourceFile(fileName, languageVersion);
  };

  const program = ts.createProgram([indexFile], options, host);
  const diagnostics = ts.getPreEmitDiagnostics(program);
  return diagnostics.map(d => {
    if (!d.file) return d.messageText;
    const { line, character } = d.file.getLineAndCharacterOfPosition(d.start);
    const message = ts.flattenDiagnosticMessageText(d.messageText, '\n');
    return `[Line ${line + 1}:${character + 1}] ${message}`;
  });
}

// 1. Raw code without ts-nocheck
const rawCode = code.replace('// @ts-nocheck', '// removed ts-nocheck');
const rawErrors = compile(rawCode);
console.log('Raw errors count:', rawErrors.length);

// Let's write them to test_results.json
fs.writeFileSync(path.join(__dirname, 'raw_errors.json'), JSON.stringify(rawErrors, null, 2));

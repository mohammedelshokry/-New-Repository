const path = require('path');
const backendDir = path.resolve(__dirname, '../../../backend');
const ts = require(path.join(backendDir, 'node_modules/typescript'));
const fs = require('fs');

const indexFile = path.join(backendDir, 'src/index.ts');
let code = fs.readFileSync(indexFile, 'utf8');

// Apply the tested fixes to in-memory code
code = code.replace(/\r\n/g, '\n');
code = code.replace('// @ts-nocheck', '// Type safety enabled');
code = code.replace('const PORT = process.env.PORT || 3001;', 'const PORT = Number(process.env.PORT) || 3001;');
code = code.replace("apiVersion: '2025-01-27.acacia'", "apiVersion: '2026-08-26.dahlia'");
code = code.replace(
  "import * as admin from 'firebase-admin';",
  "import { initializeApp, cert, getApps } from 'firebase-admin/app';\nimport { getMessaging } from 'firebase-admin/messaging';"
);
code = code.replace(
`try {
  const serviceAccount = require('../../firebase-admin.json');
  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  }
} catch (e) {}`,
`try {
  const serviceAccountPath = path.join(__dirname, '..', 'firebase-admin.json');
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    if (getApps().length === 0) {
      initializeApp({ credential: cert(serviceAccount) });
    }
  }
} catch (e) {}`
);
code = code.replaceAll('admin.messaging()', 'getMessaging()');
code = code.replace(
  `} catch (e) {\n    console.error(error); res.status(500).json({ error: 'Server error' });\n  }`,
  `} catch (e) {\n    console.error(e); res.status(500).json({ error: 'Server error' });\n  }`
);
code = code.replace(
  `app.get('/api/venues/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const venue = await prisma.venue.findUnique({
      where: { id: req.params.id },`,
  `app.get('/api/venues/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const venueId = req.params.id as string;
    const venue = await prisma.venue.findUnique({
      where: { id: venueId },`
);
code = code.replace(
  `const { rating, comment } = req.body;
    const venueId = req.params.id;`,
  `const { rating, comment } = req.body;
    const venueId = req.params.id as string;`
);
code = code.replace(
  `totalReviews: aggr._count.id`,
  `totalReviews: aggr._count?.id || 0`
);
code = code.replace(
  `const venueId = req.params.id;
    // verify owner`,
  `const venueId = req.params.id as string;
    // verify owner`
);
code = code.replace(
  `app.patch('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id;`,
  `app.patch('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id as string;`
);
code = code.replace(
  `app.delete('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id;`,
  `app.delete('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id as string;`
);
code = code.replace(
  `app.get('/api/courts/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const court = await prisma.court.findUnique({
      where: { id: req.params.id },`,
  `app.get('/api/courts/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id as string;
    const court = await prisma.court.findUnique({
      where: { id: courtId },`
);
code = code.replace(
  `app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id;`,
  `app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id as string;`
);
code = code.replace(
  `app.post('/api/bookings/:id/confirm-attendance', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id;`,
  `app.post('/api/bookings/:id/confirm-attendance', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id as string;`
);

// Now test tsconfig options:
const proposedTsConfig = {
  compilerOptions: {
    target: "es2022",
    module: "commonjs",
    rootDir: "./",
    outDir: "./dist",
    esModuleInterop: true,
    forceConsistentCasingInFileNames: true,
    strict: false,
    skipLibCheck: true,
    types: ["node", "express"]
  },
  include: ["src/**/*", "prisma/**/*"],
  exclude: ["node_modules", "dist", "api"]
};

// Parse config with TS
const parsed = ts.parseJsonConfigFileContent(
  proposedTsConfig,
  ts.sys,
  backendDir
);

console.log('Parsed fileNames in project:', parsed.fileNames);

const host = ts.createCompilerHost(parsed.options);
const origGetSourceFile = host.getSourceFile;
host.getSourceFile = (fileName, languageVersion) => {
  if (path.resolve(fileName) === indexFile) {
    return ts.createSourceFile(fileName, code, languageVersion);
  }
  return origGetSourceFile(fileName, languageVersion);
};

const program = ts.createProgram(parsed.fileNames, parsed.options, host);
const diagnostics = ts.getPreEmitDiagnostics(program);

console.log('Project-wide diagnostics count:', diagnostics.length);
diagnostics.forEach(d => {
  if (d.file) {
    const { line, character } = d.file.getLineAndCharacterOfPosition(d.start);
    console.log(`${d.file.fileName} [${line + 1}:${character + 1}]: ${ts.flattenDiagnosticMessageText(d.messageText, '\n')}`);
  } else {
    console.log(d.messageText);
  }
});

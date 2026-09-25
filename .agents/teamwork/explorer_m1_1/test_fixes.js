const path = require('path');
const backendDir = path.resolve(__dirname, '../../../backend');
const ts = require(path.join(backendDir, 'node_modules/typescript'));
const fs = require('fs');

const indexFile = path.join(backendDir, 'src/index.ts');
let code = fs.readFileSync(indexFile, 'utf8');

// Normalize line endings to LF for reliable string matching
const isCRLF = code.includes('\r\n');
code = code.replace(/\r\n/g, '\n');

// 1. Remove // @ts-nocheck
code = code.replace('// @ts-nocheck', '// Type safety enabled');

// 2. Fix PORT
code = code.replace('const PORT = process.env.PORT || 3001;', 'const PORT = Number(process.env.PORT) || 3001;');

// 3. Fix Stripe
code = code.replace("apiVersion: '2025-01-27.acacia'", "apiVersion: '2026-08-26.dahlia'");

// 4. Fix Firebase imports & init
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

// Fix admin.messaging() calls
code = code.replaceAll('admin.messaging()', 'getMessaging()');

// 5. Fix ReferenceError at line 164: catch (e) { console.error(error); ... }
code = code.replace(
  `} catch (e) {\n    console.error(error); res.status(500).json({ error: 'Server error' });\n  }`,
  `} catch (e) {\n    console.error(e); res.status(500).json({ error: 'Server error' });\n  }`
);

// 6. Fix req.params in routes:
// GET /api/venues/:id
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

// POST /api/venues/:id/reviews
code = code.replace(
  `const { rating, comment } = req.body;
    const venueId = req.params.id;`,
  `const { rating, comment } = req.body;
    const venueId = req.params.id as string;`
);

// Prisma aggregate: aggr._count.id
code = code.replace(
  `totalReviews: aggr._count.id`,
  `totalReviews: aggr._count?.id || 0`
);

// POST /api/venues/:id/courts
code = code.replace(
  `const venueId = req.params.id;
    // verify owner`,
  `const venueId = req.params.id as string;
    // verify owner`
);

// PATCH /api/courts/:id
code = code.replace(
  `app.patch('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id;`,
  `app.patch('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id as string;`
);

// DELETE /api/courts/:id
code = code.replace(
  `app.delete('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id;`,
  `app.delete('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id as string;`
);

// GET /api/courts/:id
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

// PATCH /api/bookings/:id/status
code = code.replace(
  `app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id;`,
  `app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id as string;`
);

// POST /api/bookings/:id/confirm-attendance
code = code.replace(
  `app.post('/api/bookings/:id/confirm-attendance', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id;`,
  `app.post('/api/bookings/:id/confirm-attendance', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id as string;`
);

// Convert back to CRLF if needed
if (isCRLF) {
  code = code.replace(/\n/g, '\r\n');
}

// Function to compile and get diagnostics
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

const errors = compile(code);
console.log('Errors count after fixes:', errors.length);
if (errors.length > 0) {
  console.log('Remaining errors:');
  console.log(errors);
} else {
  console.log('SUCCESS! Zero compiler errors!');
}

fs.writeFileSync(path.join(__dirname, 'remaining_errors.json'), JSON.stringify(errors, null, 2));

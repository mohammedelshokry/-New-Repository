import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { PrismaClient } from './generated/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

let appInstance: any = null;
let initError: any = null;

try {
  const app = express();
  const prisma = new PrismaClient();
  const PORT = process.env.PORT || 3001;
  const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev-only';

  app.use(cors({ origin: '*' }));
  app.use(express.json());

  app.get('/api/debug', (req, res) => {
    res.json({ ok: true, msg: 'Express is running inside handler' });
  });

  // Basic health check
  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok' });
  });

  appInstance = app;
} catch(e: any) {
  initError = e;
}

export default function handler(req: Request, res: Response) {
  if (initError) {
    return res.status(500).json({
      error: 'Initialization Failed',
      message: initError.message,
      stack: initError.stack
    });
  }
  if (!appInstance) {
    return res.status(500).json({ error: 'App not initialized' });
  }
  return appInstance(req, res);
}

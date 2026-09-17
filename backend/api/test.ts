import express from 'express';
const app = express();
app.get('/api/test', (req, res) => {
  res.json({ message: 'Vercel is working perfectly!' });
});
export default app;

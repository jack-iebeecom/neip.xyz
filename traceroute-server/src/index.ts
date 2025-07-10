import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { tracerouteRouter } from './routes/traceroute';
import { logger } from './utils/logger';

// Load environment variables
dotenv.config();

const app = express();
const port = process.env.PORT || 3002;

// Middleware
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  methods: ['GET'],
  credentials: true
}));

// Routes
app.use('/api', tracerouteRouter);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Start server
app.listen(port, () => {
  logger.info(`Server is running on port ${port}`);
}); 
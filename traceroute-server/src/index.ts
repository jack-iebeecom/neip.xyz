import express from 'express';
import cors from 'cors';
import { config } from 'dotenv';
import { setupTracerouteRoutes } from './routes/traceroute';
import { setupLogger } from './utils/logger';

// Load environment variables
config();

const app = express();
const PORT = process.env.PORT || 3002;
const logger = setupLogger();

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    server: process.env.SERVER_NAME || 'tokyo',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Setup routes
setupTracerouteRoutes(app);

// Start server
app.listen(PORT, () => {
  logger.info(`Traceroute server started on port ${PORT}`, {
    server: process.env.SERVER_NAME || 'tokyo',
    port: PORT,
    node: process.version,
    os: process.platform
  });
}); 
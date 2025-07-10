import { Router, Request, Response } from 'express';
import { spawn } from 'child_process';
import { logger } from '../utils/logger';

const router = Router();

// Middleware to check API key
const checkApiKey = (req: Request, res: Response, next: Function) => {
  const apiKey = req.headers['x-api-key'];
  if (!apiKey || apiKey !== process.env.API_KEY) {
    logger.warn('Invalid API key attempt', { ip: req.ip });
    return res.status(401).json({ error: 'Invalid API key' });
  }
  next();
};

router.get('/traceroute', checkApiKey, (req: Request, res: Response) => {
  const target = req.query.target as string;
  const maxHops = parseInt(process.env.MAX_HOPS || '30');
  const timeoutMs = parseInt(process.env.TIMEOUT_MS || '5000');

  if (!target) {
    return res.status(400).json({ error: 'Target host is required' });
  }

  // Validate target format (domain or IP)
  const domainRegex = /^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$/;
  const ipRegex = /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/;
  if (!domainRegex.test(target) && !ipRegex.test(target)) {
    return res.status(400).json({ error: 'Invalid target format' });
  }

  // Set response headers for SSE
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  // Start traceroute process
  const traceroute = spawn('traceroute', ['-n', '-w', '2', '-m', maxHops.toString(), target]);
  let timeout: NodeJS.Timeout;

  // Reset timeout on each data
  const resetTimeout = () => {
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(() => {
      logger.warn('Traceroute timeout', { target });
      traceroute.kill();
      res.write('data: {"error": "Timeout"}\n\n');
      res.end();
    }, timeoutMs);
  };

  traceroute.stdout.on('data', (data) => {
    resetTimeout();
    res.write(`data: ${JSON.stringify({ data: data.toString() })}\n\n`);
  });

  traceroute.stderr.on('data', (data) => {
    logger.error('Traceroute error', { error: data.toString(), target });
    res.write(`data: ${JSON.stringify({ error: data.toString() })}\n\n`);
  });

  traceroute.on('close', (code) => {
    if (timeout) clearTimeout(timeout);
    if (code !== null) {
      res.write(`data: ${JSON.stringify({ done: true, code })}\n\n`);
    }
    res.end();
  });

  // Handle client disconnect
  req.on('close', () => {
    if (timeout) clearTimeout(timeout);
    traceroute.kill();
  });
});

export const tracerouteRouter = router; 
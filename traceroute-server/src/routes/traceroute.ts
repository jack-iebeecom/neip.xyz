import { Application, Request, Response } from 'express';
import { spawn } from 'child_process';
import { setupLogger } from '../utils/logger';

const logger = setupLogger();

interface TracerouteOptions {
  maxHops?: number;
  timeout?: number;
}

export function setupTracerouteRoutes(app: Application) {
  app.post('/api/tracert', async (req: Request, res: Response) => {
    const { host, maxHops = 30, timeout = 5000 } = req.body;
    
    // Input validation
    if (!host || typeof host !== 'string') {
      return res.status(400).json({ error: 'Invalid host parameter' });
    }

    // Sanitize host input (basic example - should be more comprehensive)
    const sanitizedHost = host.replace(/[^a-zA-Z0-9.-]/g, '');

    // Set headers for SSE
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    try {
      // Build command based on OS
      const isWindows = process.platform === 'win32';
      const command = isWindows ? 'tracert' : 'traceroute';
      const args = isWindows 
        ? ['-h', maxHops.toString(), '-w', timeout.toString(), sanitizedHost]
        : ['-m', maxHops.toString(), '-w', '1', sanitizedHost];

      logger.info('Starting traceroute', {
        host: sanitizedHost,
        command,
        args,
        server: process.env.SERVER_NAME || 'tokyo'
      });

      // Start traceroute process
      const tracerouteProcess = spawn(command, args);
      let hopCount = 0;

      tracerouteProcess.stdout.on('data', (data) => {
        const output = data.toString().trim();
        if (output) {
          // Extract hop number if present
          const hopMatch = output.match(/^\s*(\d+)\s/);
          if (hopMatch) {
            hopCount = Math.max(hopCount, parseInt(hopMatch[1]));
          }

          const message = JSON.stringify({
            type: 'output',
            message: output,
            timestamp: new Date().toISOString(),
            hopCount
          });
          res.write(`data: ${message}\n\n`);
        }
      });

      tracerouteProcess.stderr.on('data', (data) => {
        const error = data.toString().trim();
        logger.error('Traceroute error', {
          error,
          host: sanitizedHost,
          server: process.env.SERVER_NAME
        });
        const message = JSON.stringify({
          type: 'error',
          message: error,
          timestamp: new Date().toISOString()
        });
        res.write(`data: ${message}\n\n`);
      });

      tracerouteProcess.on('close', (code) => {
        const message = JSON.stringify({
          type: 'complete',
          message: `Traceroute completed with exit code ${code}`,
          timestamp: new Date().toISOString(),
          success: code === 0,
          hopCount
        });
        res.write(`data: ${message}\n\n`);
        res.end();
      });

      // Handle client disconnect
      req.on('close', () => {
        tracerouteProcess.kill();
        logger.info('Client disconnected, terminating traceroute', {
          host: sanitizedHost,
          server: process.env.SERVER_NAME
        });
      });

    } catch (error) {
      logger.error('Failed to start traceroute', {
        error,
        host: sanitizedHost,
        server: process.env.SERVER_NAME
      });
      const message = JSON.stringify({
        type: 'error',
        message: 'Failed to start traceroute process',
        timestamp: new Date().toISOString()
      });
      res.write(`data: ${message}\n\n`);
      res.end();
    }
  });
} 
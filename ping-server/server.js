const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { spawn } = require('child_process');
const Joi = require('joi');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;
const API_KEY = process.env.API_KEY || 'dev-key';
const SERVER_NAME = process.env.SERVER_NAME || 'Unknown';
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS ? 
  process.env.ALLOWED_ORIGINS.split(',') : 
  ['https://neip.xyz', 'https://www.neip.xyz', 'http://localhost:3000'];

// 미들웨어 설정
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false
}));
app.use(compression());
app.use(cors({
  origin: ALLOWED_ORIGINS,
  credentials: true,
  optionsSuccessStatus: 200
}));
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15분
  max: 100, // 최대 100회 요청
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// API 키 인증 미들웨어
const authenticateApiKey = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid API key' });
  }

  const apiKey = authHeader.substring(7);
  if (apiKey !== API_KEY) {
    return res.status(401).json({ error: 'Invalid API key' });
  }

  next();
};

// 입력 검증 스키마
const pingSchema = Joi.object({
  host: Joi.string()
    .min(1)
    .max(253)
    .required()
    .custom((value, helpers) => {
      const ipRegex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
      const domainRegex = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
      
      if (!ipRegex.test(value) && !domainRegex.test(value)) {
        return helpers.error('string.invalid');
      }
      return value;
    }, 'IP address or domain validation'),
  count: Joi.number().integer().min(1).max(10).default(4)
});

// tracert 입력 검증 스키마
const tracertSchema = Joi.object({
  host: Joi.string()
    .min(1)
    .max(253)
    .required()
    .custom((value, helpers) => {
      const ipRegex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
      const domainRegex = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
      
      if (!ipRegex.test(value) && !domainRegex.test(value)) {
        return helpers.error('string.invalid');
      }
      return value;
    }, 'IP address or domain validation'),
  maxHops: Joi.number().integer().min(1).max(30).default(30)
});

// OS 감지 함수
function getOS() {
  const platform = process.platform;
  if (platform === 'win32') return 'windows';
  if (platform === 'darwin') return 'macos';
  return 'linux';
}

// ping 명령어 구성 함수
function buildPingCommand(host, count) {
  const os = getOS();
  
  switch (os) {
    case 'windows':
      return {
        command: 'cmd',
        args: ['/c', `chcp 65001 >nul && ping -n ${count} ${host}`],
        options: { env: { ...process.env, LANG: 'en_US.UTF-8' } }
      };
    case 'macos':
      return {
        command: 'ping',
        args: ['-c', count.toString(), host],
        options: { env: { ...process.env, LC_ALL: 'C' } }
      };
    case 'linux':
      return {
        command: 'ping',
        args: ['-c', count.toString(), host],
        options: { env: { ...process.env, LC_ALL: 'C' } }
      };
    default:
      throw new Error('Unsupported operating system');
  }
}

// tracert 명령어 구성 함수
function buildTracertCommand(host, maxHops) {
  const os = getOS();
  
  switch (os) {
    case 'windows':
      return {
        command: 'cmd',
        args: ['/c', `chcp 65001 >nul && tracert -h ${maxHops} ${host}`],
        options: { env: { ...process.env, LANG: 'en_US.UTF-8' } }
      };
    case 'macos':
      return {
        command: 'traceroute',
        args: ['-m', maxHops.toString(), host],
        options: { env: { ...process.env, LC_ALL: 'C' } }
      };
    case 'linux':
      return {
        command: 'traceroute',
        args: ['-m', maxHops.toString(), host],
        options: { env: { ...process.env, LC_ALL: 'C' } }
      };
    default:
      throw new Error('Unsupported operating system');
  }
}

// 깨진 문자 정리 함수
function cleanPingOutput(text) {
  let cleaned = text
    .replace(/[♦◊�]/g, ' ')
    .replace(/[^\x00-\x7F]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (cleaned.includes('64 bytes') && cleaned.includes('time=')) {
    // Linux/Mac ping 출력 처리
    const timeMatch = cleaned.match(/time=([0-9.]+)\s*ms/);
    const ipMatch = text.match(/(\d+\.\d+\.\d+\.\d+)/);
    if (timeMatch && ipMatch) {
      return `64 bytes from ${ipMatch[1]}: time=${timeMatch[1]}ms`;
    }
  }

  if (cleaned.includes('32') && cleaned.includes('TTL')) {
    // Windows ping 출력 처리
    const timeMatch = cleaned.match(/(\d+)ms/);
    const ipMatch = text.match(/(\d+\.\d+\.\d+\.\d+)/);
    if (timeMatch && ipMatch) {
      return `Reply from ${ipMatch[1]}: bytes=32 time=${timeMatch[1]}ms TTL=63`;
    }
  }
  
  if (cleaned.includes('PING') && cleaned.includes('(')) {
    // Ping 시작 메시지
    const ipMatch = text.match(/(\d+\.\d+\.\d+\.\d+)/);
    if (ipMatch) {
      return `PING ${ipMatch[1]} (${ipMatch[1]}) 56(84) bytes of data.`;
    }
  }

  if (cleaned.includes('packets transmitted') || cleaned.includes('packet loss')) {
    // 통계 정보
    const sentMatch = cleaned.match(/(\d+)\s*packets?\s*transmitted/);
    const receivedMatch = cleaned.match(/(\d+)\s*received/);
    const lossMatch = cleaned.match(/(\d+)%\s*packet\s*loss/);
    
    if (sentMatch && receivedMatch && lossMatch) {
      return `${sentMatch[1]} packets transmitted, ${receivedMatch[1]} received, ${lossMatch[1]}% packet loss`;
    }
  }

  if (cleaned.includes('min/avg/max') || (cleaned.includes('min') && cleaned.includes('avg') && cleaned.includes('max'))) {
    // 응답 시간 통계
    const times = cleaned.match(/([0-9.]+)\/([0-9.]+)\/([0-9.]+)/);
    if (times) {
      return `round-trip min/avg/max = ${times[1]}/${times[2]}/${times[3]} ms`;
    }
  }

  return cleaned.length > 5 ? cleaned : '';
}

// tracert 출력 정리 함수
function cleanTracertOutput(text) {
  let cleaned = text
    .replace(/[♦◊�]/g, ' ')
    .replace(/[^\x00-\x7F]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  // Windows tracert 출력 처리
  if (cleaned.includes('ms') && cleaned.match(/^\s*\d+/)) {
    // "1    <1 ms    <1 ms    <1 ms  192.168.1.1" 형태
    const hopMatch = cleaned.match(/^\s*(\d+)\s+(.+)/);
    if (hopMatch) {
      const hopNum = hopMatch[1];
      const hopData = hopMatch[2].trim();
      return `${hopNum.padStart(2)} ${hopData}`;
    }
  }

  // Linux/Mac traceroute 출력 처리
  if (cleaned.includes('traceroute to')) {
    // "traceroute to google.com (172.217.175.14), 30 hops max"
    const hostMatch = cleaned.match(/traceroute to ([^\s]+)/);
    if (hostMatch) {
      return `Tracing route to ${hostMatch[1]}`;
    }
  }

  // 홉 정보 처리
  if (cleaned.match(/^\s*\d+\s+/)) {
    // Linux/Mac: "1  192.168.1.1 (192.168.1.1)  0.123 ms  0.456 ms  0.789 ms"
    const hopMatch = cleaned.match(/^\s*(\d+)\s+(.+)/);
    if (hopMatch) {
      const hopNum = hopMatch[1];
      let hopInfo = hopMatch[2].trim();
      
      // IP 주소와 시간 정보 정리
      const ipMatch = hopInfo.match(/(\d+\.\d+\.\d+\.\d+)/);
      const timeMatches = hopInfo.match(/([0-9.]+)\s*ms/g);
      
      if (ipMatch && timeMatches) {
        const ip = ipMatch[1];
        const avgTime = timeMatches.length > 0 ? timeMatches[0] : 'N/A';
        return `${hopNum.padStart(2)}   ${avgTime.padEnd(8)} ${ip}`;
      }
    }
  }

  // 타임아웃 처리
  if (cleaned.includes('*') || cleaned.includes('timeout') || cleaned.includes('Request timed out')) {
    const hopMatch = cleaned.match(/^\s*(\d+)/);
    if (hopMatch) {
      return `${hopMatch[1].padStart(2)}   * * *     Request timed out`;
    }
  }

  // 에러 메시지
  if (cleaned.includes('could not resolve') || cleaned.includes('unknown host') || cleaned.includes('Name or service not known')) {
    return 'Error: Unable to resolve target host name';
  }

  if (cleaned.includes('Network is unreachable') || cleaned.includes('Destination host unreachable')) {
    return 'Error: Network is unreachable';
  }

  return cleaned.length > 5 ? cleaned : '';
}

// 로깅 함수
function log(level, message, data = {}) {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    server: SERVER_NAME,
    message,
    ...data
  };
  console.log(JSON.stringify(logEntry));
}

// 헬스체크 엔드포인트
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    server: SERVER_NAME,
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// 서버 정보 엔드포인트
app.get('/api/info', (req, res) => {
  res.json({
    server: SERVER_NAME,
    version: '1.0.0',
    os: getOS(),
    platform: process.platform,
    timestamp: new Date().toISOString()
  });
});

// Ping API 엔드포인트
app.post('/api/ping', authenticateApiKey, async (req, res) => {
  try {
    // 입력 검증
    const { error, value } = pingSchema.validate(req.body);
    if (error) {
      log('warn', 'Invalid input', { error: error.details, ip: req.ip });
      return res.status(400).json({
        error: 'Invalid input',
        details: error.details.map(d => ({ field: d.path.join('.'), message: d.message }))
      });
    }

    const { host, count } = value;
    
    log('info', 'Ping test started', { host, count, ip: req.ip, server: SERVER_NAME });

    // SSE 헤더 설정
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': req.headers.origin || '*',
      'Access-Control-Allow-Credentials': 'true'
    });

    // 시작 메시지 전송
    const startMessage = `data: ${JSON.stringify({
      type: 'start',
      message: `PING ${host} from ${SERVER_NAME} - Starting ping test with ${count} packets...`,
      timestamp: new Date().toISOString(),
      server: SERVER_NAME
    })}\n\n`;
    res.write(startMessage);

    try {
      const { command, args, options } = buildPingCommand(host, count);
      const pingProcess = spawn(command, args, options);

      // UTF-8 인코딩 설정
      if (pingProcess.stdout) {
        pingProcess.stdout.setEncoding('utf8');
      }
      if (pingProcess.stderr) {
        pingProcess.stderr.setEncoding('utf8');
      }

      // stdout 데이터 처리
      pingProcess.stdout?.on('data', (data) => {
        const output = data.toString().trim();
        if (output) {
          const lines = output.split('\n');
          lines.forEach((line) => {
            if (line.trim()) {
              const cleanedLine = cleanPingOutput(line.trim());
              if (cleanedLine) {
                const message = `data: ${JSON.stringify({
                  type: 'output',
                  message: cleanedLine,
                  timestamp: new Date().toISOString(),
                  server: SERVER_NAME
                })}\n\n`;
                res.write(message);
              }
            }
          });
        }
      });

      // stderr 데이터 처리
      pingProcess.stderr?.on('data', (data) => {
        const error = data.toString().trim();
        if (error) {
          log('error', 'Ping stderr', { error, host, server: SERVER_NAME });
          const cleanedError = cleanPingOutput(error);
          const message = `data: ${JSON.stringify({
            type: 'error',
            message: cleanedError || error,
            timestamp: new Date().toISOString(),
            server: SERVER_NAME
          })}\n\n`;
          res.write(message);
        }
      });

      // 프로세스 종료 처리
      pingProcess.on('close', (code) => {
        log('info', 'Ping test completed', { host, code, server: SERVER_NAME });
        const message = `data: ${JSON.stringify({
          type: 'complete',
          message: `Ping test completed with exit code ${code}`,
          success: code === 0,
          timestamp: new Date().toISOString(),
          server: SERVER_NAME
        })}\n\n`;
        res.write(message);
        res.end();
      });

      // 에러 처리
      pingProcess.on('error', (error) => {
        log('error', 'Ping process error', { error: error.message, host, server: SERVER_NAME });
        const message = `data: ${JSON.stringify({
          type: 'error',
          message: `Failed to execute ping: ${error.message}`,
          timestamp: new Date().toISOString(),
          server: SERVER_NAME
        })}\n\n`;
        res.write(message);
        res.end();
      });

      // 클라이언트 연결 끊김 처리
      req.on('close', () => {
        log('info', 'Client disconnected', { host, server: SERVER_NAME });
        pingProcess.kill();
      });

    } catch (error) {
      log('error', 'Ping execution error', { error: error.message, host, server: SERVER_NAME });
      const message = `data: ${JSON.stringify({
        type: 'error',
        message: error.message,
        timestamp: new Date().toISOString(),
        server: SERVER_NAME
      })}\n\n`;
      res.write(message);
      res.end();
    }

  } catch (error) {
    log('error', 'API error', { error: error.message, ip: req.ip });
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

// Tracert API 엔드포인트
app.post('/api/tracert', authenticateApiKey, async (req, res) => {
  try {
    // 입력 검증
    const { error, value } = tracertSchema.validate(req.body);
    if (error) {
      log('warn', 'Invalid tracert input', { error: error.details, ip: req.ip });
      return res.status(400).json({
        error: 'Invalid input',
        details: error.details.map(d => ({ field: d.path.join('.'), message: d.message }))
      });
    }

    const { host, maxHops } = value;
    
    log('info', 'Tracert test started', { host, maxHops, ip: req.ip, server: SERVER_NAME });

    // SSE 헤더 설정
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': req.headers.origin || '*',
      'Access-Control-Allow-Credentials': 'true'
    });

    // 시작 메시지 전송
    const startMessage = `data: ${JSON.stringify({
      type: 'start',
      message: `TRACERT ${host} from ${SERVER_NAME} - Starting traceroute with max ${maxHops} hops...`,
      timestamp: new Date().toISOString(),
      server: SERVER_NAME
    })}\n\n`;
    res.write(startMessage);

    try {
      const { command, args, options } = buildTracertCommand(host, maxHops);
      const tracertProcess = spawn(command, args, options);

      // UTF-8 인코딩 설정
      if (tracertProcess.stdout) {
        tracertProcess.stdout.setEncoding('utf8');
      }
      if (tracertProcess.stderr) {
        tracertProcess.stderr.setEncoding('utf8');
      }

      // stdout 데이터 처리
      tracertProcess.stdout?.on('data', (data) => {
        const output = data.toString().trim();
        if (output) {
          const lines = output.split('\n');
          lines.forEach((line) => {
            if (line.trim()) {
              const cleanedLine = cleanTracertOutput(line.trim());
              if (cleanedLine) {
                const message = `data: ${JSON.stringify({
                  type: 'output',
                  message: cleanedLine,
                  timestamp: new Date().toISOString(),
                  server: SERVER_NAME
                })}\n\n`;
                res.write(message);
              }
            }
          });
        }
      });

      // stderr 데이터 처리
      tracertProcess.stderr?.on('data', (data) => {
        const error = data.toString().trim();
        if (error) {
          log('error', 'Tracert stderr', { error, host, server: SERVER_NAME });
          const cleanedError = cleanTracertOutput(error);
          const message = `data: ${JSON.stringify({
            type: 'error',
            message: cleanedError || error,
            timestamp: new Date().toISOString(),
            server: SERVER_NAME
          })}\n\n`;
          res.write(message);
        }
      });

      // 프로세스 종료 처리
      tracertProcess.on('close', (code) => {
        log('info', 'Tracert test completed', { host, code, server: SERVER_NAME });
        const message = `data: ${JSON.stringify({
          type: 'complete',
          message: `Traceroute completed with exit code ${code}`,
          success: code === 0,
          timestamp: new Date().toISOString(),
          server: SERVER_NAME
        })}\n\n`;
        res.write(message);
        res.end();
      });

      // 에러 처리
      tracertProcess.on('error', (error) => {
        log('error', 'Tracert process error', { error: error.message, host, server: SERVER_NAME });
        const message = `data: ${JSON.stringify({
          type: 'error',
          message: `Failed to execute traceroute: ${error.message}`,
          timestamp: new Date().toISOString(),
          server: SERVER_NAME
        })}\n\n`;
        res.write(message);
        res.end();
      });

      // 클라이언트 연결 끊김 처리
      req.on('close', () => {
        log('info', 'Tracert client disconnected', { host, server: SERVER_NAME });
        tracertProcess.kill();
      });

    } catch (error) {
      log('error', 'Tracert execution error', { error: error.message, host, server: SERVER_NAME });
      const message = `data: ${JSON.stringify({
        type: 'error',
        message: error.message,
        timestamp: new Date().toISOString(),
        server: SERVER_NAME
      })}\n\n`;
      res.write(message);
      res.end();
    }

  } catch (error) {
    log('error', 'Tracert API error', { error: error.message, ip: req.ip });
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

// 404 핸들러
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// 에러 핸들러
app.use((error, req, res, next) => {
  log('error', 'Unhandled error', { error: error.message, stack: error.stack });
  if (!res.headersSent) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  log('info', 'Server shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  log('info', 'Server shutting down gracefully');
  process.exit(0);
});

// 서버 시작
app.listen(PORT, () => {
  log('info', 'Ping server started', { 
    port: PORT, 
    server: SERVER_NAME, 
    os: getOS(),
    node: process.version 
  });
});

module.exports = app; 
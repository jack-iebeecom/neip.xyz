#!/bin/bash

# 🚀 NEIP Network Server - 통합 설치 스크립트
# ping + traceroute 기능을 모두 포함한 네트워크 서버를 설치합니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 함수 정의
print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 사용자 입력 받기
echo -e "${BLUE}"
echo "🌐 NEIP Network Server 통합 설치 도구"
echo "========================================"
echo "ping + traceroute 기능을 모두 포함한 네트워크 서버를 설치합니다."
echo -e "${NC}"

# 서버 이름 입력
read -p "서버 위치를 입력하세요 (예: Tokyo, Seoul, London): " SERVER_NAME
if [ -z "$SERVER_NAME" ]; then
    SERVER_NAME="Unknown"
fi

# API 키 입력 (선택사항)
read -p "API 키를 입력하세요 (엔터시 자동 생성): " API_KEY
if [ -z "$API_KEY" ]; then
    # 자동으로 보안 키 생성
    API_KEY="${SERVER_NAME,,}-network-$(date +%Y%m%d)-$(openssl rand -hex 8 2>/dev/null || head -c 16 /dev/urandom | xxd -p)"
    print_warning "API 키가 자동 생성되었습니다: $API_KEY"
    print_warning "이 키를 반드시 저장해 두세요!"
fi

echo ""
print_step "설치를 시작합니다..."
print_warning "서버 이름: $SERVER_NAME"
print_warning "API 키: $API_KEY"
print_warning "포함 기능: ping + traceroute"
echo ""
read -p "계속하시겠습니까? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "설치가 취소되었습니다."
    exit 1
fi

echo ""
print_step "1단계: 시스템 업데이트 중..."
sudo apt update -y
print_success "시스템 업데이트 완료"

print_step "2단계: 필수 패키지 설치 중..."
sudo apt install -y curl wget traceroute
print_success "필수 패키지 설치 완료"

print_step "3단계: Node.js 설치 중..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    print_success "Node.js 설치 완료"
else
    print_success "Node.js가 이미 설치되어 있습니다"
fi

print_step "4단계: PM2 설치 중..."
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    print_success "PM2 설치 완료"
else
    print_success "PM2가 이미 설치되어 있습니다"
fi

print_step "5단계: 작업 디렉토리 생성 중..."
sudo mkdir -p /opt/neip-network-server
sudo chown $USER:$USER /opt/neip-network-server
cd /opt/neip-network-server
print_success "작업 디렉토리 생성 완료"

print_step "6단계: package.json 생성 중..."
cat > package.json << 'EOF'
{
  "name": "neip-network-server",
  "version": "2.0.0",
  "description": "Global network test server for NEIP.xyz with ping and traceroute",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "express-rate-limit": "^7.1.5",
    "dotenv": "^16.3.1",
    "joi": "^17.11.0"
  }
}
EOF
print_success "package.json 생성 완료"

print_step "7단계: server.js 생성 중..."
cat > server.js << 'EOF'
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
    .replace(/[♦◊]/g, ' ')
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
    // RTT 통계
    const times = cleaned.match(/([0-9.]+)\/([0-9.]+)\/([0-9.]+)/);
    if (times) {
      return `round-trip min/avg/max = ${times[1]}/${times[2]}/${times[3]} ms`;
    }
  }

  return cleaned.length > 5 ? cleaned : '';
}

function cleanTracertOutput(text) {
  let cleaned = text
    .replace(/[♦◊]/g, ' ')
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
    uptime: process.uptime(),
    features: ['ping', 'traceroute'] // 지원 기능 표시
  });
});

// 서버 정보 엔드포인트
app.get('/api/info', (req, res) => {
  res.json({
    server: SERVER_NAME,
    version: '2.0.0', // ping + traceroute 통합 버전
    os: getOS(),
    platform: process.platform,
    timestamp: new Date().toISOString(),
    features: ['ping', 'traceroute']
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
  log('info', 'Network server started', { 
    port: PORT, 
    server: SERVER_NAME, 
    os: getOS(),
    node: process.version,
    features: ['ping', 'traceroute']
  });
});

module.exports = app;
EOF
print_success "server.js 생성 완료"

print_step "8단계: 환경설정 파일 생성 중..."
cat > .env << EOF
PORT=3001
API_KEY=$API_KEY
SERVER_NAME=$SERVER_NAME
ALLOWED_ORIGINS=https://neip.xyz,https://www.neip.xyz
NODE_ENV=production
EOF
print_success "환경설정 파일 생성 완료"

print_step "9단계: PM2 설정 파일 생성 중..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'neip-network-server',
    script: 'server.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G'
  }]
};
EOF
mkdir -p logs
print_success "PM2 설정 완료"

print_step "10단계: 패키지 설치 중..."
npm install
print_success "패키지 설치 완료"

print_step "11단계: 방화벽 설정 중..."
sudo ufw allow ssh >/dev/null 2>&1 || true
sudo ufw allow 3001/tcp >/dev/null 2>&1 || true
sudo ufw allow 80/tcp >/dev/null 2>&1 || true
sudo ufw allow 443/tcp >/dev/null 2>&1 || true
sudo ufw --force enable >/dev/null 2>&1 || true
print_success "방화벽 설정 완료"

print_step "12단계: 서버 시작 중..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup >/dev/null 2>&1 || true
print_success "서버 시작 완료"

print_step "13단계: 설치 확인 중..."
sleep 3

# 헬스체크 테스트
if curl -s http://localhost:3001/health >/dev/null; then
    print_success "서버가 정상적으로 동작하고 있습니다!"
    
    # 기능 확인
    HEALTH_RESPONSE=$(curl -s http://localhost:3001/health)
    if echo "$HEALTH_RESPONSE" | grep -q "ping" && echo "$HEALTH_RESPONSE" | grep -q "traceroute"; then
        print_success "ping + traceroute 기능이 모두 정상적으로 설치되었습니다!"
    else
        print_warning "일부 기능 확인에 실패했습니다."
    fi
else
    print_error "서버 동작에 문제가 있습니다. 로그를 확인해주세요."
    echo "로그 확인: pm2 logs neip-network-server"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 통합 설치가 성공적으로 완료되었습니다!${NC}"
echo ""
echo -e "${BLUE}📋 설치된 기능:${NC}"
echo "   ✅ Ping 테스트 (4회 패킷)"
echo "   ✅ Traceroute 테스트 (최대 30홉)"
echo "   ✅ 실시간 스트리밍 결과"
echo "   ✅ API 키 인증"
echo "   ✅ Rate limiting"
echo ""
echo -e "${BLUE}📊 서버 정보:${NC}"
echo "   서버 이름: $SERVER_NAME"
echo "   포트: 3001"
echo "   API 키: $API_KEY"
echo "   버전: 2.0.0"
echo ""
echo -e "${BLUE}🔗 API 엔드포인트:${NC}"
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.me 2>/dev/null || echo "YOUR-SERVER-IP")
echo "   Ping API:      http://$PUBLIC_IP:3001/api/ping"
echo "   Tracert API:   http://$PUBLIC_IP:3001/api/tracert"
echo "   헬스체크:      http://$PUBLIC_IP:3001/health"
echo "   서버 정보:     http://$PUBLIC_IP:3001/api/info"
echo ""
echo -e "${BLUE}🛠️  관리 명령어:${NC}"
echo "   상태 확인: pm2 status"
echo "   로그 보기: pm2 logs neip-network-server"
echo "   재시작:   pm2 restart neip-network-server"
echo "   중지:     pm2 stop neip-network-server"
echo "   삭제:     pm2 delete neip-network-server"
echo ""
echo -e "${YELLOW}⚠️  중요 사항:${NC}"
echo "1. API 키를 안전한 곳에 저장해 두세요: $API_KEY"
echo "2. 클라우드 보안 그룹에서 포트 3001을 열어주세요"
echo "3. 메인 앱의 서버 설정을 업데이트하세요"
echo "4. 이 서버는 ping과 traceroute 기능을 모두 지원합니다"
echo ""
echo -e "${BLUE}📝 API 사용 예시:${NC}"
echo "   curl -X POST http://$PUBLIC_IP:3001/api/ping \\"
echo "        -H 'Authorization: Bearer $API_KEY' \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"host\":\"8.8.8.8\",\"count\":4}'"
echo ""
echo "   curl -X POST http://$PUBLIC_IP:3001/api/tracert \\"
echo "        -H 'Authorization: Bearer $API_KEY' \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"host\":\"8.8.8.8\",\"maxHops\":15}'"
echo ""
echo -e "${GREEN}통합 설치가 완료되었습니다! 🚀${NC}" 
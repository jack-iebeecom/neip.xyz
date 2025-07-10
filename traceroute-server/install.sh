#!/bin/bash

# 🚀 NEIP Traceroute Server - 설치 스크립트
# 이 스크립트를 실행하면 traceroute 서버가 자동으로 설치됩니다.

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
echo "🌟 NEIP Traceroute Server 설치 도구"
echo "======================================"
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
    API_KEY="${SERVER_NAME,,}-traceroute-$(date +%Y%m%d)-$(openssl rand -hex 8 2>/dev/null || head -c 16 /dev/urandom | xxd -p)"
    print_warning "API 키가 자동 생성되었습니다: $API_KEY"
    print_warning "이 키를 반드시 저장해 두세요!"
fi

echo ""
print_step "설치를 시작합니다..."
print_warning "서버 이름: $SERVER_NAME"
print_warning "API 키: $API_KEY"
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

print_step "2단계: Node.js 설치 중..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    print_success "Node.js 설치 완료"
else
    print_success "Node.js가 이미 설치되어 있습니다"
fi

print_step "3단계: traceroute 설치 중..."
if ! command -v traceroute &> /dev/null; then
    sudo apt install -y traceroute
    print_success "traceroute 설치 완료"
else
    print_success "traceroute가 이미 설치되어 있습니다"
fi

print_step "4단계: PM2 설치 중..."
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    print_success "PM2 설치 완료"
else
    print_success "PM2가 이미 설치되어 있습니다"
fi

print_step "5단계: 작업 디렉토리 생성 중..."
sudo mkdir -p /opt/neip-traceroute-server
sudo chown $USER:$USER /opt/neip-traceroute-server
cd /opt/neip-traceroute-server
print_success "작업 디렉토리 생성 완료"

print_step "6단계: package.json 생성 중..."
cat > package.json << 'EOF'
{
  "name": "neip-traceroute-server",
  "version": "1.0.0",
  "description": "Global traceroute server for NEIP.xyz",
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
const PORT = process.env.PORT || 3002;
const API_KEY = process.env.API_KEY || 'dev-key';
const SERVER_NAME = process.env.SERVER_NAME || 'Unknown';
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS ? 
  process.env.ALLOWED_ORIGINS.split(',') : 
  ['https://neip.xyz', 'https://www.neip.xyz', 'http://localhost:3000'];

app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
app.use(compression());
app.use(cors({ origin: ALLOWED_ORIGINS, credentials: true, optionsSuccessStatus: 200 }));
app.use(express.json({ limit: '10mb' }));

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, max: 100,
  message: { error: 'Too many requests from this IP, please try again later.', retryAfter: '15 minutes' },
  standardHeaders: true, legacyHeaders: false,
});
app.use('/api/', limiter);

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

const tracerouteSchema = Joi.object({
  host: Joi.string().min(1).max(253).required().custom((value, helpers) => {
    const ipRegex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    const domainRegex = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
    if (!ipRegex.test(value) && !domainRegex.test(value)) {
      return helpers.error('string.invalid');
    }
    return value;
  }, 'IP address or domain validation'),
  maxHops: Joi.number().integer().min(1).max(30).default(30)
});

function buildTracerouteCommand(host, maxHops) {
  return { command: 'traceroute', args: ['-n', '-w', '2', '-m', maxHops.toString(), host], options: { env: { ...process.env, LC_ALL: 'C' } } };
}

function cleanTracerouteOutput(text) {
  return text.replace(/[♦◊]/g, ' ').replace(/[^\x00-\x7F]/g, ' ').replace(/\s+/g, ' ').trim();
}

function log(level, message, data = {}) {
  const timestamp = new Date().toISOString();
  const logEntry = { timestamp, level, server: SERVER_NAME, message, ...data };
  console.log(JSON.stringify(logEntry));
}

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', server: SERVER_NAME, timestamp: new Date().toISOString(), uptime: process.uptime() });
});

app.get('/api/info', (req, res) => {
  res.json({ server: SERVER_NAME, version: '1.0.0', os: 'linux', platform: process.platform, timestamp: new Date().toISOString() });
});

app.post('/api/traceroute', authenticateApiKey, async (req, res) => {
  try {
    const { error, value } = tracerouteSchema.validate(req.body);
    if (error) {
      log('warn', 'Invalid input', { error: error.details, ip: req.ip });
      return res.status(400).json({ error: 'Invalid input', details: error.details.map(d => ({ field: d.path.join('.'), message: d.message })) });
    }
    const { host, maxHops } = value;
    log('info', 'Traceroute test started', { host, maxHops, ip: req.ip, server: SERVER_NAME });
    res.writeHead(200, {
      'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': req.headers.origin || '*', 'Access-Control-Allow-Credentials': 'true'
    });
    const startMessage = `data: ${JSON.stringify({ type: 'start', message: `TRACEROUTE ${host} from ${SERVER_NAME} - Starting traceroute test...`, timestamp: new Date().toISOString(), server: SERVER_NAME })}\n\n`;
    res.write(startMessage);
    try {
      const { command, args, options } = buildTracerouteCommand(host, maxHops);
      const tracerouteProcess = spawn(command, args, options);
      if (tracerouteProcess.stdout) { tracerouteProcess.stdout.setEncoding('utf8'); }
      if (tracerouteProcess.stderr) { tracerouteProcess.stderr.setEncoding('utf8'); }
      tracerouteProcess.stdout?.on('data', (data) => {
        const output = data.toString().trim();
        if (output) {
          const lines = output.split('\n');
          lines.forEach((line) => {
            if (line.trim()) {
              const cleanedLine = cleanTracerouteOutput(line.trim());
              if (cleanedLine) {
                const message = `data: ${JSON.stringify({ type: 'output', message: cleanedLine, timestamp: new Date().toISOString(), server: SERVER_NAME })}\n\n`;
                res.write(message);
              }
            }
          });
        }
      });
      tracerouteProcess.stderr?.on('data', (data) => {
        const error = data.toString().trim();
        if (error) {
          log('error', 'Traceroute stderr', { error, host, server: SERVER_NAME });
          const cleanedError = cleanTracerouteOutput(error);
          const message = `data: ${JSON.stringify({ type: 'error', message: cleanedError || error, timestamp: new Date().toISOString(), server: SERVER_NAME })}\n\n`;
          res.write(message);
        }
      });
      tracerouteProcess.on('close', (code) => {
        log('info', 'Traceroute test completed', { host, code, server: SERVER_NAME });
        const message = `data: ${JSON.stringify({ type: 'complete', message: `Traceroute test completed with exit code ${code}`, success: code === 0, timestamp: new Date().toISOString(), server: SERVER_NAME })}\n\n`;
        res.write(message);
        res.end();
      });
      tracerouteProcess.on('error', (error) => {
        log('error', 'Traceroute process error', { error: error.message, host, server: SERVER_NAME });
        const message = `data: ${JSON.stringify({ type: 'error', message: `Failed to execute traceroute: ${error.message}`, timestamp: new Date().toISOString(), server: SERVER_NAME })}\n\n`;
        res.write(message);
        res.end();
      });
      req.on('close', () => { log('info', 'Client disconnected', { host, server: SERVER_NAME }); tracerouteProcess.kill(); });
    } catch (error) {
      log('error', 'Traceroute execution error', { error: error.message, host, server: SERVER_NAME });
      const message = `data: ${JSON.stringify({ type: 'error', message: error.message, timestamp: new Date().toISOString(), server: SERVER_NAME })}\n\n`;
      res.write(message); res.end();
    }
  } catch (error) {
    log('error', 'API error', { error: error.message, ip: req.ip });
    if (!res.headersSent) { res.status(500).json({ error: 'Internal server error' }); }
  }
});

app.use('*', (req, res) => { res.status(404).json({ error: 'Not found' }); });
app.use((error, req, res, next) => { log('error', 'Unhandled error', { error: error.message, stack: error.stack }); if (!res.headersSent) { res.status(500).json({ error: 'Internal server error' }); } });
process.on('SIGTERM', () => { log('info', 'Server shutting down gracefully'); process.exit(0); });
process.on('SIGINT', () => { log('info', 'Server shutting down gracefully'); process.exit(0); });
app.listen(PORT, () => { log('info', 'Traceroute server started', { port: PORT, server: SERVER_NAME, os: 'linux', node: process.version }); });
module.exports = app;
EOF
print_success "server.js 생성 완료"

print_step "8단계: 환경설정 파일 생성 중..."
cat > .env << EOF
PORT=3002
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
    name: 'neip-traceroute-server',
    script: 'server.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3002
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
sudo ufw allow 3002/tcp >/dev/null 2>&1 || true
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
if curl -s http://localhost:3002/health >/dev/null; then
    print_success "서버가 정상적으로 동작하고 있습니다!"
else
    print_error "서버 동작에 문제가 있습니다. 로그를 확인해주세요."
    echo "로그 확인: pm2 logs neip-traceroute-server"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 설치가 성공적으로 완료되었습니다!${NC}"
echo ""
echo -e "${BLUE}📋 서버 정보:${NC}"
echo "   서버 이름: $SERVER_NAME"
echo "   포트: 3002"
echo "   API 키: $API_KEY"
echo ""
echo -e "${BLUE}🔗 테스트 링크:${NC}"
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.me 2>/dev/null || echo "YOUR-SERVER-IP")
echo "   헬스체크: http://$PUBLIC_IP:3002/health"
echo "   서버 정보: http://$PUBLIC_IP:3002/api/info"
echo ""
echo -e "${BLUE}🛠️  관리 명령어:${NC}"
echo "   상태 확인: pm2 status"
echo "   로그 보기: pm2 logs neip-traceroute-server"
echo "   재시작:   pm2 restart neip-traceroute-server"
echo "   중지:     pm2 stop neip-traceroute-server"
echo ""
echo -e "${YELLOW}⚠️  중요 사항:${NC}"
echo "1. API 키를 안전한 곳에 저장해 두세요: $API_KEY"
echo "2. 클라우드 보안 그룹에서 포트 3002를 열어주세요"
echo "3. 메인 앱의 GLOBAL_SERVERS 설정을 업데이트하세요"
echo ""
echo -e "${GREEN}설치가 완료되었습니다! 🚀${NC}" 
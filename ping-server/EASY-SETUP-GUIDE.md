# 🌟 초보자를 위한 Ping 서버 설치 가이드

이 가이드는 **컴퓨터 초보자도 쉽게 따라할 수 있도록** 작성되었습니다.  
도쿄 서버를 예시로 설명하지만, 다른 지역도 동일한 방법으로 설치할 수 있습니다.

## 📋 사전 준비사항

### 1. 우분투 서버 준비
다음 중 하나의 방법으로 우분투 서버를 준비하세요:

**클라우드 서비스 추천:**
- **AWS EC2** (아마존)
- **Google Cloud Platform** 
- **Microsoft Azure**
- **Vultr** (저렴함)
- **DigitalOcean** (초보자 친화적)

**서버 사양:**
- **OS**: Ubuntu 20.04 LTS 또는 22.04 LTS
- **메모리**: 최소 1GB (2GB 권장)
- **CPU**: 1코어 이상
- **저장공간**: 최소 10GB

### 2. 필요한 정보 준비
- 서버 IP 주소 (예: `123.456.789.012`)
- SSH 접속용 사용자명 (보통 `ubuntu` 또는 `root`)
- SSH 키 파일 또는 비밀번호

## 🚀 1단계: 서버 접속하기

### Windows 사용자 (PowerShell 또는 Command Prompt)
```bash
# SSH로 서버 접속
ssh ubuntu@123.456.789.012

# 또는 키 파일이 있다면
ssh -i your-key.pem ubuntu@123.456.789.012
```

### Mac/Linux 사용자 (터미널)
```bash
# SSH로 서버 접속
ssh ubuntu@123.456.789.012

# 또는 키 파일이 있다면
ssh -i your-key.pem ubuntu@123.456.789.012
```

**⚠️ 주의사항:**
- `123.456.789.012`를 실제 서버 IP로 바꾸세요
- `ubuntu`를 실제 사용자명으로 바꾸세요
- 처음 접속시 "계속 연결하시겠습니까?" 메시지가 나오면 `yes` 입력

## 📦 2단계: 서버 기본 설정

서버에 접속했다면, 다음 명령어들을 **순서대로** 실행하세요:

```bash
# 1. 시스템 업데이트 (2-3분 소요)
sudo apt update && sudo apt upgrade -y

# 2. Node.js 18 설치 (1-2분 소요)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 3. PM2 설치 (프로세스 관리자)
sudo npm install -g pm2

# 4. 설치 확인
node --version
npm --version
pm2 --version
```

**예상 결과:**
```
node --version
v18.19.0

npm --version  
10.2.3

pm2 --version
5.3.0
```

## 📁 3단계: 파일 업로드하기

이제 ping-server 파일들을 서버에 업로드해야 합니다.

### 방법 1: 직접 다운로드 (가장 쉬운 방법)

서버에서 다음 명령어를 실행:

```bash
# 1. 작업 디렉토리 만들기
sudo mkdir -p /opt/neip-ping-server
sudo chown $USER:$USER /opt/neip-ping-server
cd /opt/neip-ping-server

# 2. 필요한 파일들 직접 생성
# package.json 생성
cat > package.json << 'EOF'
{
  "name": "neip-ping-server",
  "version": "1.0.0",
  "description": "Global ping test server for NEIP.xyz",
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
```

이제 서버 파일을 생성합니다:

```bash
# server.js 생성 (긴 파일이므로 여러 부분으로 나누어 생성)
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
  windowMs: 15 * 60 * 1000,
  max: 100,
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

// ping 명령어 구성 함수
function buildPingCommand(host, count) {
  return {
    command: 'ping',
    args: ['-c', count.toString(), host],
    options: { env: { ...process.env, LC_ALL: 'C' } }
  };
}

// 깨진 문자 정리 함수
function cleanPingOutput(text) {
  let cleaned = text
    .replace(/[♦◊�]/g, ' ')
    .replace(/[^\x00-\x7F]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (cleaned.includes('64 bytes') && cleaned.includes('time=')) {
    const timeMatch = cleaned.match(/time=([0-9.]+)\s*ms/);
    const ipMatch = text.match(/(\d+\.\d+\.\d+\.\d+)/);
    if (timeMatch && ipMatch) {
      return `64 bytes from ${ipMatch[1]}: time=${timeMatch[1]}ms`;
    }
  }

  if (cleaned.includes('PING') && cleaned.includes('(')) {
    const ipMatch = text.match(/(\d+\.\d+\.\d+\.\d+)/);
    if (ipMatch) {
      return `PING ${ipMatch[1]} (${ipMatch[1]}) 56(84) bytes of data.`;
    }
  }

  if (cleaned.includes('packets transmitted') || cleaned.includes('packet loss')) {
    const sentMatch = cleaned.match(/(\d+)\s*packets?\s*transmitted/);
    const receivedMatch = cleaned.match(/(\d+)\s*received/);
    const lossMatch = cleaned.match(/(\d+)%\s*packet\s*loss/);
    
    if (sentMatch && receivedMatch && lossMatch) {
      return `${sentMatch[1]} packets transmitted, ${receivedMatch[1]} received, ${lossMatch[1]}% packet loss`;
    }
  }

  if (cleaned.includes('min/avg/max') || (cleaned.includes('min') && cleaned.includes('avg') && cleaned.includes('max'))) {
    const times = cleaned.match(/([0-9.]+)\/([0-9.]+)\/([0-9.]+)/);
    if (times) {
      return `round-trip min/avg/max = ${times[1]}/${times[2]}/${times[3]} ms`;
    }
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
    os: 'linux',
    platform: process.platform,
    timestamp: new Date().toISOString()
  });
});

// Ping API 엔드포인트
app.post('/api/ping', authenticateApiKey, async (req, res) => {
  try {
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

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': req.headers.origin || '*',
      'Access-Control-Allow-Credentials': 'true'
    });

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

      if (pingProcess.stdout) {
        pingProcess.stdout.setEncoding('utf8');
      }
      if (pingProcess.stderr) {
        pingProcess.stderr.setEncoding('utf8');
      }

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

app.use('*', (req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use((error, req, res, next) => {
  log('error', 'Unhandled error', { error: error.message, stack: error.stack });
  if (!res.headersSent) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

process.on('SIGTERM', () => {
  log('info', 'Server shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  log('info', 'Server shutting down gracefully');
  process.exit(0);
});

app.listen(PORT, () => {
  log('info', 'Ping server started', { 
    port: PORT, 
    server: SERVER_NAME, 
    os: 'linux',
    node: process.version 
  });
});

module.exports = app;
EOF
```

## ⚙️ 4단계: 환경설정 파일 만들기

**중요:** 아래 명령어에서 `Tokyo`와 `your-secure-api-key-here`를 원하는 값으로 바꾸세요!

```bash
# .env 파일 생성 (설정 변경 필요!)
cat > .env << 'EOF'
PORT=3001
API_KEY=your-secure-api-key-here
SERVER_NAME=Tokyo
ALLOWED_ORIGINS=https://neip.xyz,https://www.neip.xyz
NODE_ENV=production
EOF
```

**💡 설정값 변경 방법:**
```bash
# 파일 편집하기
nano .env

# 또는
vim .env
```

**nano 편집기 사용법:**
- 화살표키로 이동
- 내용 수정
- `Ctrl + O` → `Enter` (저장)
- `Ctrl + X` (종료)

**⚠️ 꼭 바꿔야 할 것들:**
- `API_KEY`: 보안을 위해 복잡한 문자열로 변경 (예: `tokyo-ping-secret-2024-abc123`)
- `SERVER_NAME`: 서버 위치 (예: `Tokyo`, `Seoul`, `London` 등)

## 📦 5단계: 프로그램 설치하기

```bash
# 1. 필요한 패키지 설치 (1-2분 소요)
npm install

# 2. PM2 설정 파일 생성
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'neip-ping-server',
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

# 3. 로그 디렉토리 생성
mkdir -p logs
```

## 🔥 6단계: 방화벽 설정

```bash
# 1. UFW 방화벽 설치 및 설정
sudo ufw allow ssh
sudo ufw allow 3001/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# 2. 방화벽 상태 확인
sudo ufw status
```

**예상 결과:**
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
3001/tcp                   ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

## 🚀 7단계: 서버 실행하기

```bash
# 1. PM2로 서버 시작
pm2 start ecosystem.config.js

# 2. 시스템 부팅시 자동 시작 설정
pm2 save
pm2 startup

# 위 명령어 실행 후 나오는 명령어를 복사해서 실행
# 예: sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu
```

## ✅ 8단계: 테스트하기

### 1. 로컬 테스트 (서버에서)
```bash
# 헬스체크 테스트
curl http://localhost:3001/health

# 예상 결과:
# {"status":"healthy","server":"Tokyo","timestamp":"2024-01-01T00:00:00.000Z","uptime":123}
```

### 2. 외부에서 테스트
**다른 컴퓨터에서** 브라우저나 터미널로 테스트:

```bash
# 헬스체크 (브라우저 주소창에 입력)
http://YOUR-SERVER-IP:3001/health

# 또는 터미널에서
curl http://YOUR-SERVER-IP:3001/health
```

**⚠️ 주의:** `YOUR-SERVER-IP`를 실제 서버 IP로 바꾸세요!

### 3. Ping API 테스트
```bash
# API 테스트 (YOUR-API-KEY를 실제 키로 바꾸세요)
curl -X POST http://YOUR-SERVER-IP:3001/api/ping \
  -H "Authorization: Bearer YOUR-API-KEY" \
  -H "Content-Type: application/json" \
  -d '{"host":"google.com","count":4}'
```

## 🛠️ 9단계: 서버 관리 명령어

### 서버 상태 확인
```bash
# PM2 상태 확인
pm2 status

# 로그 보기
pm2 logs neip-ping-server

# 실시간 로그
pm2 logs neip-ping-server --follow
```

### 서버 제어
```bash
# 서버 재시작
pm2 restart neip-ping-server

# 서버 중지
pm2 stop neip-ping-server

# 서버 다시 시작
pm2 start neip-ping-server
```

### 설정 변경 후
```bash
# .env 파일 수정 후 재시작
nano .env
pm2 restart neip-ping-server
```

## 🐛 문제 해결

### ❌ 문제 1: `npm install` 실패
```bash
# Node.js 재설치
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
```

### ❌ 문제 2: 권한 오류
```bash
# 디렉토리 권한 수정
sudo chown -R $USER:$USER /opt/neip-ping-server
```

### ❌ 문제 3: 방화벽 문제
```bash
# 방화벽 상태 확인
sudo ufw status verbose

# 포트 3001 다시 열기
sudo ufw allow 3001/tcp
```

### ❌ 문제 4: PM2 실행 실패
```bash
# PM2 재설치
sudo npm uninstall -g pm2
sudo npm install -g pm2
```

### ❌ 문제 5: 외부에서 접속 안됨
1. **클라우드 보안 그룹** 확인 (AWS, GCP 등)
2. **포트 3001** 인바운드 규칙 추가
3. **서버 IP** 다시 확인

## 🎯 10단계: 메인 앱에 연결하기

서버가 정상 동작한다면, 메인 애플리케이션의 설정을 업데이트하세요:

### 실제 서버 IP로 변경
`src/app/api/ping/global/route.ts` 파일에서:

```javascript
tokyo: {
  name: 'Tokyo', 
  endpoint: 'http://YOUR-SERVER-IP:3001/api/ping',  // 실제 IP로 변경!
  fallback: 'local'
},
```

### API 키 설정
환경변수 파일 (`.env.local`)에 추가:
```
PING_SERVER_API_KEY=your-secure-api-key-here
```

## 🏆 완료!

축하합니다! 🎉 도쿄 ping 서버가 성공적으로 설치되었습니다!

### 다음 할 일:
1. **도메인 연결** (선택사항): `ping-tokyo.neip.xyz` 같은 도메인 설정
2. **SSL 인증서** (선택사항): HTTPS 지원
3. **다른 도시 서버**: 같은 방법으로 추가 설치
4. **모니터링**: 서버 상태 정기 확인

### 도움이 필요하면:
- 로그 확인: `pm2 logs neip-ping-server`
- 서버 상태: `pm2 status`
- 시스템 리소스: `htop` 또는 `top`

**잘했습니다!** 🌟 이제 전세계 어디서나 ping 테스트를 할 수 있는 서버가 준비되었습니다! 
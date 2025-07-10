# Traceroute Server

Global traceroute server for neip.xyz. This server provides a REST API endpoint for executing traceroute commands and streaming the results back to the client.

## 빠른 설치 가이드 (우분투/데비안)

1. 저장소 클론:
   ```bash
   git clone https://github.com/your-username/traceroute-server.git
   cd traceroute-server
   ```

2. 설치 스크립트 실행:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

설치 스크립트는 다음 작업을 자동으로 수행합니다:
- Node.js 18.x 설치 (없는 경우)
- traceroute 패키지 설치 (없는 경우)
- 프로젝트 의존성 설치
- 환경 설정 파일(.env) 생성 및 랜덤 API 키 생성
- TypeScript 코드 빌드
- PM2를 통한 서비스 등록 및 자동 시작 설정

## 수동 설치 방법

자동 설치가 실패하거나 다른 리눅스 배포판을 사용하는 경우:

1. 필수 패키지 설치:
   ```bash
   # Node.js 18.x 설치 (배포판에 따라 다를 수 있음)
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs

   # traceroute 설치
   sudo apt-get install -y traceroute
   ```

2. 프로젝트 설정:
   ```bash
   # 의존성 설치
   npm install

   # 환경 설정
   cp .env.example .env
   # .env 파일을 열어서 설정 수정

   # 빌드
   npm run build
   ```

3. PM2로 서비스 등록:
   ```bash
   # PM2 전역 설치
   sudo npm install -g pm2

   # 서비스 시작
   pm2 start dist/index.js --name "traceroute-server"
   pm2 save
   pm2 startup
   ```

## 서버 관리

- 서버 상태 확인: `pm2 status`
- 로그 확인: `pm2 logs traceroute-server`
- 서버 재시작: `pm2 restart traceroute-server`
- 서버 중지: `pm2 stop traceroute-server`
- 서버 제거: `pm2 delete traceroute-server`

## 문제 해결

1. 포트 충돌
   - .env 파일에서 `PORT` 값을 변경
   - 서버 재시작: `pm2 restart traceroute-server`

2. 권한 문제
   - `sudo` 권한 확인
   - traceroute 명령어 실행 권한 확인

3. 로그 확인
   - 실시간 로그: `pm2 logs traceroute-server`
   - 에러 로그: `cat error.log`
   - 전체 로그: `cat combined.log`

## Features

- Real-time traceroute execution with SSE (Server-Sent Events)
- Cross-platform support (Windows/Linux)
- Input sanitization and validation
- Configurable max hops and timeout
- Detailed logging
- Health check endpoint

## Prerequisites

- Node.js 18+
- traceroute (Linux) or tracert (Windows) command available in system PATH
- Proper network permissions to execute traceroute commands

## Configuration

Environment variables:
- `PORT`: Server port (default: 3002)
- `SERVER_NAME`: Server identifier (e.g., 'tokyo')
- `LOG_LEVEL`: Winston log level (default: 'info')
- `API_KEY`: API key for authentication

## Usage

Start the server:
```bash
npm start
```

For development:
```bash
npm run dev
```

## API Endpoints

### Health Check
```
GET /health
```

### Execute Traceroute
```
POST /api/tracert
Content-Type: application/json

{
  "host": "example.com",
  "maxHops": 30,
  "timeout": 5000
}
```

Response is streamed using Server-Sent Events (SSE) format.

## Security Considerations

- Host input is sanitized to prevent command injection
- API key authentication required
- Rate limiting recommended in production
- Proper firewall rules required for traceroute 
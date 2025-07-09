# NEIP Ping Server

글로벌 멀티 서버 ping 테스트를 위한 독립적인 API 서버입니다.

## 🌍 서버 위치

- 🇰🇷 Seoul, South Korea
- 🇯🇵 Tokyo, Japan  
- 🇭🇰 Hong Kong
- 🇸🇬 Singapore
- 🇻🇳 Ho Chi Minh, Vietnam
- 🇬🇧 London, United Kingdom
- 🇺🇸 Los Angeles, United States

## 🚀 빠른 시작

### 1. 로컬 개발

```bash
# 의존성 설치
npm install

# 환경변수 설정
cp .env.example .env
# .env 파일을 편집하여 설정값 조정

# 개발 서버 실행
npm run dev

# 또는 프로덕션 모드
npm start
```

### 2. Docker 실행

```bash
# Docker 이미지 빌드
docker build -t neip-ping-server .

# 컨테이너 실행
docker run -d \
  --name ping-server-tokyo \
  -p 3001:3001 \
  -e SERVER_NAME="Tokyo" \
  -e API_KEY="your-secure-api-key" \
  neip-ping-server
```

## 🏗️ 우분투 서버 배포

### 사전 요구사항

- Ubuntu 20.04 LTS 이상
- Root 또는 sudo 권한
- 공인 IP 주소

### 자동 배포

```bash
# 1. 서버 파일 업로드
rsync -avz ping-server/ user@your-server:/opt/neip-ping-server/

# 2. 서버에 접속
ssh user@your-server

# 3. 배포 스크립트 실행
sudo chmod +x /opt/neip-ping-server/deploy.sh
sudo /opt/neip-ping-server/deploy.sh "Tokyo" "your-api-key" 3001
```

### 수동 배포

```bash
# 1. 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 2. Node.js 설치
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 3. PM2 설치
sudo npm install -g pm2

# 4. 애플리케이션 설정
sudo mkdir -p /opt/neip-ping-server
sudo chown $USER:$USER /opt/neip-ping-server
cd /opt/neip-ping-server

# 5. 파일 복사 및 설치
npm install --production

# 6. 환경변수 설정
cat > .env << EOF
PORT=3001
API_KEY=your-secure-api-key-here
SERVER_NAME=Tokyo
ALLOWED_ORIGINS=https://neip.xyz,https://www.neip.xyz
NODE_ENV=production
EOF

# 7. PM2로 실행
pm2 start server.js --name neip-ping-server
pm2 save
pm2 startup
```

## 🔧 API 엔드포인트

### 헬스체크

```bash
GET /health
```

응답:
```json
{
  "status": "healthy",
  "server": "Tokyo",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": 12345
}
```

### 서버 정보

```bash
GET /api/info
```

응답:
```json
{
  "server": "Tokyo",
  "version": "1.0.0",
  "os": "linux",
  "platform": "linux",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### Ping 테스트

```bash
POST /api/ping
Authorization: Bearer your-api-key
Content-Type: application/json

{
  "host": "google.com",
  "count": 4
}
```

응답 (Server-Sent Events):
```
data: {"type":"start","message":"PING google.com from Tokyo - Starting ping test...","timestamp":"2024-01-01T00:00:00.000Z","server":"Tokyo"}

data: {"type":"output","message":"64 bytes from 172.217.175.78: time=15.2ms","timestamp":"2024-01-01T00:00:00.000Z","server":"Tokyo"}

data: {"type":"complete","message":"Ping test completed with exit code 0","success":true,"timestamp":"2024-01-01T00:00:00.000Z","server":"Tokyo"}
```

## 🔐 보안 설정

### API 키 생성

```bash
# 안전한 API 키 생성
openssl rand -hex 32
```

### 방화벽 설정

```bash
# UFW 방화벽 설정
sudo ufw allow ssh
sudo ufw allow 3001/tcp
sudo ufw enable
```

### Nginx 리버스 프록시

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # SSE 지원
        proxy_buffering off;
        proxy_cache off;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
    }
    
    location /health {
        proxy_pass http://localhost:3001/health;
    }
}
```

## 🔄 관리 명령어

### PM2 관리

```bash
# 상태 확인
pm2 status

# 로그 확인
pm2 logs neip-ping-server

# 재시작
pm2 restart neip-ping-server

# 중지
pm2 stop neip-ping-server

# 삭제
pm2 delete neip-ping-server
```

### 로그 확인

```bash
# 실시간 로그
tail -f /var/log/neip-ping-server/combined.log

# 에러 로그
tail -f /var/log/neip-ping-server/error.log
```

## 🧪 테스트

### 로컬 테스트

```bash
# 헬스체크
curl http://localhost:3001/health

# Ping 테스트
curl -X POST http://localhost:3001/api/ping \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"host":"google.com","count":4}'
```

### 서버 테스트

```bash
# 서버에서 테스트
curl http://your-server-ip/health

# 외부에서 테스트  
curl -X POST http://your-server-ip/api/ping \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"host":"google.com","count":4}'
```

## 🐛 문제 해결

### 일반적인 문제

1. **ping 명령어를 찾을 수 없음**
   ```bash
   # Ubuntu에서 ping 설치
   sudo apt install iputils-ping
   ```

2. **권한 오류**
   ```bash
   # 파일 권한 확인
   ls -la /opt/neip-ping-server/
   sudo chown -R $USER:$USER /opt/neip-ping-server/
   ```

3. **포트가 이미 사용 중**
   ```bash
   # 포트 사용 프로세스 확인
   sudo lsof -i :3001
   sudo netstat -tlnp | grep :3001
   ```

4. **방화벽 문제**
   ```bash
   # 방화벽 상태 확인
   sudo ufw status verbose
   ```

### 로그 분석

- **정상 시작**: `"Ping server started"`
- **인증 실패**: `"Missing or invalid API key"`
- **입력 오류**: `"Invalid input"`
- **ping 실패**: `"Failed to execute ping"`

## 🚀 배포 체크리스트

- [ ] 서버 OS 업데이트
- [ ] Node.js 18+ 설치
- [ ] 애플리케이션 파일 업로드
- [ ] 환경변수 설정 (.env)
- [ ] 의존성 설치 (`npm install --production`)
- [ ] PM2 설정 및 실행
- [ ] 방화벽 설정
- [ ] Nginx 리버스 프록시 설정
- [ ] SSL 인증서 설정 (선택사항)
- [ ] 헬스체크 테스트
- [ ] API 기능 테스트
- [ ] 메인 애플리케이션에 서버 정보 추가

## 📞 지원

문제가 발생하면 다음을 확인하세요:

1. 서버 로그: `pm2 logs neip-ping-server`
2. 시스템 로그: `journalctl -u nginx -f`
3. 네트워크 연결: `ping google.com`
4. 포트 상태: `sudo netstat -tlnp | grep :3001`

---

**NEIP.xyz** - Global Network Tools Platform 
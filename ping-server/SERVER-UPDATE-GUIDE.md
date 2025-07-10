# 🚀 NEIP Ping Server - Traceroute 업데이트 가이드

## 📋 개요
이 가이드는 기존 ping 서버에 traceroute 기능을 추가하는 업데이트 절차를 설명합니다.

## ⚡ 빠른 업데이트 (자동 스크립트)

### 1단계: 업데이트 스크립트 다운로드
```bash
# 각 서버에 SSH 접속 후
cd /tmp
wget https://raw.githubusercontent.com/jack-iebeecom/neip.xyz/main/ping-server/update-server.sh
chmod +x update-server.sh
```

### 2단계: 자동 업데이트 실행
```bash
sudo ./update-server.sh
```

## 🔧 수동 업데이트 (상세 절차)

### 1단계: 기존 서버 백업
```bash
# 현재 서버 중지
pm2 stop neip-ping-server

# 백업 생성
sudo cp -r /opt/neip-ping-server /opt/neip-ping-server.backup.$(date +%Y%m%d_%H%M%S)
```

### 2단계: 최신 코드 다운로드
```bash
# 임시 디렉토리 생성
cd /tmp
git clone https://github.com/jack-iebeecom/neip.xyz.git neip-update

# ping-server 디렉토리로 이동
cd neip-update/ping-server
```

### 3단계: 환경 설정 백업
```bash
# 기존 .env 파일 백업
cp /opt/neip-ping-server/.env /tmp/env.backup
```

### 4단계: 새 코드 배포
```bash
# 새 코드 복사
sudo cp -r /tmp/neip-update/ping-server/* /opt/neip-ping-server/

# 환경 설정 복원
sudo cp /tmp/env.backup /opt/neip-ping-server/.env
```

### 5단계: 의존성 설치 및 서비스 재시작
```bash
# 의존성 설치
cd /opt/neip-ping-server
sudo npm install --production

# 서비스 재시작
pm2 restart neip-ping-server

# 상태 확인
pm2 status
```

### 6단계: 업데이트 확인
```bash
# Health check
curl http://localhost:3001/health

# Ping API 테스트
curl -X POST http://localhost:3001/api/ping \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"host": "8.8.8.8", "count": 4}'

# 🆕 Traceroute API 테스트
curl -X POST http://localhost:3001/api/tracert \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"host": "8.8.8.8", "maxHops": 10}'
```

## 🔍 업데이트된 기능들

### 새로운 API 엔드포인트
- `POST /api/tracert` - Traceroute 실행

### 새로운 기능
- ✅ Windows/Linux/macOS 크로스 플랫폼 지원
- ✅ Server-Sent Events 스트리밍
- ✅ 최대 홉 수 설정 (1-30)
- ✅ 향상된 에러 처리 및 로깅
- ✅ UTF-8 인코딩 지원

### API 요청 형식
```json
{
  "host": "google.com",
  "maxHops": 30
}
```

### API 응답 형식 (Stream)
```
data: {"type":"start","message":"TRACERT google.com from Tokyo - Starting...","timestamp":"2024-01-15T10:30:00.000Z","server":"Tokyo"}

data: {"type":"output","message":"1  192.168.1.1  1.5ms","timestamp":"2024-01-15T10:30:01.000Z","server":"Tokyo"}

data: {"type":"complete","message":"Traceroute completed","timestamp":"2024-01-15T10:30:15.000Z","server":"Tokyo"}
```

## 🛠️ 문제 해결

### 서비스가 시작되지 않는 경우
```bash
# 로그 확인
pm2 logs neip-ping-server

# 수동 실행으로 에러 확인
cd /opt/neip-ping-server
node server.js
```

### 백업에서 복원
```bash
# 서비스 중지
pm2 stop neip-ping-server

# 백업 복원
sudo rm -rf /opt/neip-ping-server
sudo cp -r /opt/neip-ping-server.backup.YYYYMMDD_HHMMSS /opt/neip-ping-server

# 서비스 재시작
pm2 restart neip-ping-server
```

### 의존성 문제
```bash
# Node.js 버전 확인 (16+ 필요)
node --version

# npm 캐시 정리
npm cache clean --force

# 의존성 재설치
rm -rf node_modules package-lock.json
npm install --production
```

## 📊 서버별 업데이트 체크리스트

### Tokyo Server (74.222.29.149:3001)
- [ ] 백업 생성
- [ ] 코드 업데이트
- [ ] 서비스 재시작
- [ ] API 테스트 (ping + traceroute)
- [ ] 로그 확인

### Los Angeles Server (38.34.178.82:3001)  
- [ ] 백업 생성
- [ ] 코드 업데이트
- [ ] 서비스 재시작
- [ ] API 테스트 (ping + traceroute)
- [ ] 로그 확인

## 🎯 업데이트 후 확인사항

1. **서비스 상태**: `pm2 status`로 정상 실행 확인
2. **Health Check**: `curl http://localhost:3001/health`
3. **Ping API**: 기존 기능 정상 작동 확인
4. **Traceroute API**: 새 기능 정상 작동 확인
5. **로그 모니터링**: `pm2 logs neip-ping-server`로 에러 없는지 확인

## 📞 지원

업데이트 중 문제가 발생하면:
1. 백업에서 즉시 복원
2. 로그 파일 수집
3. 문제 상황 문서화

---
**⚠️ 중요**: 프로덕션 서버 업데이트 전에 반드시 백업을 생성하세요! 
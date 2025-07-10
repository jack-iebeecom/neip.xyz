# 🌐 NEIP Traceroute 배포 가이드

## 📋 개요
기존 글로벌 ping 서버에 traceroute 기능을 추가하는 배포 가이드입니다.

## 🚀 배포 순서

### 1단계: 로컬 테스트 (권장)

#### A. 로컬에서 ping-server 실행
```bash
cd ping-server
npm install
node server.js
```

#### B. 기존 ping 기능 테스트
```bash
curl -X POST http://localhost:3001/api/ping \
  -H "Authorization: Bearer dev-key" \
  -H "Content-Type: application/json" \
  -d '{"host": "google.com", "count": 3}'
```

#### C. 새로운 traceroute 기능 테스트
```bash
curl -X POST http://localhost:3001/api/tracert \
  -H "Authorization: Bearer dev-key" \
  -H "Content-Type: application/json" \
  -d '{"host": "google.com", "maxHops": 10}'
```

### 2단계: 글로벌 서버 배포

#### A. 업데이트 스크립트 업로드
```bash
# 각 서버에 스크립트 업로드
scp ping-server/update-server.sh user@server:/tmp/
```

#### B. 서버별 업데이트 실행
```bash
# SSH로 각 서버 접속 후 실행
ssh user@server
chmod +x /tmp/update-server.sh
/tmp/update-server.sh
```

## 🌍 글로벌 서버 목록

### 현재 활성 서버들
1. **도쿄 서버** (일본)
   - IP: 74.222.29.149
   - 포트: 3001

2. **LA 서버** (미국)
   - IP: 38.34.178.82
   - 포트: 3001

3. **서울 서버** (한국)
   - IP: 141.164.49.156
   - 포트: 3001

4. **홍콩 서버**
   - IP: 38.54.23.29
   - 포트: 3001

5. **싱가포르 서버**
   - IP: 139.180.159.248
   - 포트: 3001

6. **호치민 서버** (베트남)
   - IP: 154.205.143.125
   - 포트: 3001

7. **마드리드 서버** (스페인)
   - IP: 208.85.19.20
   - 포트: 3001

8. **상파울루 서버** (브라질)
   - IP: 216.238.100.179
   - 포트: 3001

9. **런던 서버** (영국)
   - IP: 154.205.130.123
   - 포트: 3001

## 🔧 배포 스크립트 실행 명령어

### 일괄 배포 스크립트 (추천)
```bash
#!/bin/bash
# deploy-traceroute.sh

SERVERS=(
    "74.222.29.149"      # Tokyo
    "38.34.178.82"       # LA
    "141.164.49.156"     # Seoul
    "38.54.23.29"        # Hong Kong
    "139.180.159.248"    # Singapore
    "154.205.143.125"    # Ho Chi Minh
    "208.85.19.20"       # Madrid
    "216.238.100.179"    # São Paulo
    "154.205.130.123"    # London
)

USER="root"  # 또는 실제 사용자명

for server in "${SERVERS[@]}"; do
    echo "🚀 Deploying to $server..."
    
    # 스크립트 업로드
    scp ping-server/update-server.sh $USER@$server:/tmp/
    
    # 원격 실행
    ssh $USER@$server "chmod +x /tmp/update-server.sh && /tmp/update-server.sh"
    
    echo "✅ $server 완료"
    echo ""
done

echo "🎉 모든 서버 배포 완료!"
```

### 개별 서버 배포
```bash
# 예: 도쿄 서버
scp ping-server/update-server.sh root@74.222.29.149:/tmp/
ssh root@74.222.29.149 "chmod +x /tmp/update-server.sh && /tmp/update-server.sh"
```

## ✅ 배포 후 검증

### 1. 헬스체크 확인
```bash
curl http://SERVER_IP:3001/health
```

**예상 응답:**
```json
{
  "status": "healthy",
  "server": "Tokyo",
  "timestamp": "2025-01-10T10:00:00.000Z",
  "uptime": 123.45,
  "features": ["ping", "traceroute"]
}
```

### 2. 서버 정보 확인
```bash
curl http://SERVER_IP:3001/api/info
```

**예상 응답:**
```json
{
  "server": "Tokyo",
  "version": "2.0.0",
  "os": "linux",
  "platform": "linux",
  "timestamp": "2025-01-10T10:00:00.000Z",
  "features": ["ping", "traceroute"]
}
```

### 3. 기능 테스트
```bash
# Ping 테스트
curl -X POST http://SERVER_IP:3001/api/ping \
  -H "Authorization: Bearer API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"host": "google.com", "count": 3}'

# Traceroute 테스트
curl -X POST http://SERVER_IP:3001/api/tracert \
  -H "Authorization: Bearer API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"host": "google.com", "maxHops": 10}'
```

## 🔄 롤백 가이드

### 문제 발생시 롤백
```bash
# 각 서버에서 실행
cd /opt/neip-ping-server
cp backup-YYYYMMDD-HHMMSS/server.js ./server.js
pm2 restart neip-ping-server
```

## 📊 모니터링

### PM2 상태 확인
```bash
pm2 list
pm2 logs neip-ping-server
pm2 monit
```

### 서버 성능 확인
```bash
# CPU/메모리 사용량
top -p $(pgrep -f neip-ping-server)

# 네트워크 연결 확인
netstat -tlnp | grep 3001
```

## 🎯 성공 기준

- ✅ 모든 서버에서 헬스체크 통과
- ✅ 기존 ping 기능 정상 작동
- ✅ 새로운 traceroute 기능 정상 작동
- ✅ PM2에서 서버 상태 "online"
- ✅ 서버 버전 2.0.0으로 업데이트
- ✅ features 배열에 ["ping", "traceroute"] 포함

## 🚨 주의사항

1. **점진적 배포**: 도쿄 서버에서 먼저 테스트 후 다른 서버 진행
2. **백업 보관**: 각 서버의 백업 파일 보관 (자동 생성됨)
3. **API 키 확인**: 각 서버의 실제 API 키 사용
4. **방화벽**: 포트 3001이 열려있는지 확인
5. **의존성**: traceroute 패키지 자동 설치됨

## 🎉 완료 후

배포 완료 후 프론트엔드에서 `/tools/traceroute` 페이지를 테스트하여 모든 서버의 traceroute 기능이 정상 작동하는지 확인하세요. 
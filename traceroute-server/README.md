# Traceroute Server

neip.xyz의 글로벌 traceroute 서버입니다. 각 글로벌 서버에서 traceroute 명령을 실행하고 실시간으로 결과를 스트리밍하는 API를 제공합니다.

## 우분투 서버 설치 방법

### 방법 1: 자동 설치 (권장)
```bash
# 1. 필요한 기본 패키지 설치
sudo apt-get update
sudo apt-get install -y curl git

# 2. 한 줄 설치 명령어 실행
curl -fsSL https://raw.githubusercontent.com/jack-iebeecom/neip.xyz/main/traceroute-server/install.sh | sudo bash
```

### 방법 2: 수동 설치
```bash
# 1. 저장소 클론
git clone https://github.com/jack-iebeecom/neip.xyz.git
cd neip.xyz/traceroute-server

# 2. 설치 스크립트 실행
sudo chmod +x install.sh
sudo ./install.sh
```

## 설치 확인

1. 서비스 상태 확인:
```bash
sudo pm2 status
```

예상 출력:
```
┌────┬────────────────────┬──────────┬──────┬───────────┬──────────┬──────────┐
│ id │ name              │ mode     │ ↺    │ status    │ cpu      │ memory   │
├────┼────────────────────┼──────────┼──────┼───────────┼──────────┼──────────┤
│ 0  │ traceroute-server │ fork     │ 0    │ online    │ 0%       │ 50.0mb   │
└────┴────────────────────┴──────────┴──────┴───────────┴──────────┴──────────┘
```

2. 서버 작동 테스트:
```bash
# 헬스 체크
curl http://localhost:3002/health

# API 테스트 (API 키는 /root/traceroute-server/.env 파일에서 확인)
curl -X POST http://localhost:3002/api/tracert \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"host": "google.com"}'
```

## API 키 확인 및 변경

```bash
# API 키 확인
sudo cat /root/traceroute-server/.env | grep API_KEY

# API 키 변경
sudo nano /root/traceroute-server/.env
# API_KEY 값을 수정 후 저장 (Ctrl + X, Y, Enter)
sudo pm2 restart traceroute-server
```

## 서버 관리 명령어

```bash
# 서버 상태 확인
sudo pm2 status

# 실시간 로그 보기
sudo pm2 logs traceroute-server

# 서버 재시작
sudo pm2 restart traceroute-server

# 서버 중지
sudo pm2 stop traceroute-server

# 서버 시작
sudo pm2 start traceroute-server
```

## 방화벽 설정 (UFW 사용 시)

```bash
# 3002 포트 개방
sudo ufw allow 3002/tcp
sudo ufw status
```

## 환경 설정

설정 파일 위치: `/root/traceroute-server/.env`

```bash
# 설정 파일 수정
sudo nano /root/traceroute-server/.env

# 기본 설정 항목
PORT=3002              # 서버 포트
SERVER_NAME=tokyo      # 서버 식별자 (설치 위치에 맞게 변경)
LOG_LEVEL=info        # 로그 레벨
API_KEY=your_api_key  # API 인증 키
```

## 문제 해결

1. 포트 충돌 시:
```bash
# 포트 변경
sudo nano /root/traceroute-server/.env
# PORT=3002를 다른 번호로 변경
sudo pm2 restart traceroute-server

# 또는 포트 사용 중인 프로세스 확인
sudo lsof -i :3002
```

2. 권한 문제 발생 시:
```bash
# traceroute 권한 확인
sudo traceroute google.com

# 필요한 경우 traceroute 재설치
sudo apt-get update
sudo apt-get install --reinstall traceroute
```

3. 로그 확인:
```bash
# 실시간 로그
sudo pm2 logs traceroute-server

# 에러 로그
sudo cat /root/traceroute-server/error.log

# 전체 로그
sudo cat /root/traceroute-server/combined.log
```

## 서버 제거

완전 제거 방법:
```bash
# PM2 서비스 제거
sudo pm2 delete traceroute-server
sudo pm2 save

# 설치 파일 제거
cd /root
sudo rm -rf traceroute-server

# Node.js 제거 (선택 사항)
sudo apt-get remove -y nodejs
sudo apt-get autoremove -y

# PM2 제거 (선택 사항)
sudo npm uninstall -g pm2
``` 
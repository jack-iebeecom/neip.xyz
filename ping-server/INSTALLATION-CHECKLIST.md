# ✅ Ping 서버 설치 체크리스트

이 체크리스트를 따라하면 **누구나 쉽게** ping 서버를 설치할 수 있습니다!

## 🎯 방법 선택하기

### 🚀 방법 1: 빠른 설치 (추천! 5분 완료)

가장 쉬운 방법입니다. 스크립트가 모든 것을 자동으로 해줍니다.

```bash
# 1. 서버에 접속
ssh ubuntu@YOUR-SERVER-IP

# 2. 설치 스크립트 다운로드
wget https://raw.githubusercontent.com/your-repo/ping-server/main/quick-install.sh
# 또는 파일을 직접 복사

# 3. 실행 권한 부여
chmod +x quick-install.sh

# 4. 스크립트 실행
./quick-install.sh
```

**✅ 완료!** 5분 후 서버가 실행됩니다!

---

### 📋 방법 2: 수동 설치 (단계별)

더 자세히 알고 싶다면 이 방법을 사용하세요.

## 📦 사전 준비

### ☑️ 1. 서버 준비
- [ ] 우분투 서버 (20.04 LTS 이상) 준비
- [ ] 서버 IP 주소 확인: `_______________`
- [ ] SSH 접속 정보 확인
- [ ] 서버에 SSH로 접속 성공

### ☑️ 2. 클라우드 설정 (해당시)
- [ ] AWS/GCP/Azure 보안 그룹에서 포트 3001 인바운드 허용
- [ ] SSH 포트 22 인바운드 허용

## 🔧 설치 단계

### ☑️ 3. 기본 소프트웨어 설치
```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# Node.js 18 설치
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# PM2 설치
sudo npm install -g pm2

# 설치 확인
node --version    # v18.x.x 표시되어야 함
npm --version     # 9.x.x 또는 10.x.x 표시되어야 함
pm2 --version     # 5.x.x 표시되어야 함
```
- [ ] 모든 설치 완료
- [ ] 버전 확인 완료

### ☑️ 4. 파일 생성
```bash
# 작업 디렉토리 생성
sudo mkdir -p /opt/neip-ping-server
sudo chown $USER:$USER /opt/neip-ping-server
cd /opt/neip-ping-server
```
- [ ] 디렉토리 생성 완료
- [ ] 디렉토리로 이동 완료

### ☑️ 5. 필요한 파일들 생성

**중요:** `EASY-SETUP-GUIDE.md` 파일의 3단계를 따라 다음 파일들을 생성하세요:
- [ ] `package.json` 생성
- [ ] `server.js` 생성 (가장 긴 파일)
- [ ] `.env` 생성 (**API_KEY와 SERVER_NAME 수정 필수!**)
- [ ] `ecosystem.config.js` 생성
- [ ] `logs` 디렉토리 생성

### ☑️ 6. 환경설정 값 수정
```bash
# .env 파일 편집
nano .env

# 반드시 수정해야 할 값들:
# API_KEY=your-secure-api-key-here  ← 복잡한 문자열로 변경
# SERVER_NAME=Tokyo                 ← 실제 서버 위치로 변경
```
- [ ] API_KEY 수정 완료: `___________________________`
- [ ] SERVER_NAME 수정 완료: `__________`

### ☑️ 7. 패키지 설치 및 서버 시작
```bash
# 패키지 설치
npm install

# 방화벽 설정
sudo ufw allow ssh
sudo ufw allow 3001/tcp
sudo ufw --force enable

# 서버 시작
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```
- [ ] npm install 성공
- [ ] 방화벽 설정 완료
- [ ] PM2로 서버 시작 완료

## 🧪 테스트

### ☑️ 8. 로컬 테스트 (서버에서)
```bash
# 헬스체크
curl http://localhost:3001/health

# 예상 결과:
# {"status":"healthy","server":"Tokyo","timestamp":"...","uptime":123}
```
- [ ] 헬스체크 성공
- [ ] 올바른 JSON 응답 확인

### ☑️ 9. 외부 테스트
**다른 컴퓨터에서** 브라우저로 접속:
```
http://YOUR-SERVER-IP:3001/health
```
- [ ] 외부에서 접속 성공
- [ ] 브라우저에서 JSON 응답 확인

### ☑️ 10. API 테스트
```bash
# API 테스트 (YOUR-API-KEY를 실제 키로 변경)
curl -X POST http://YOUR-SERVER-IP:3001/api/ping \
  -H "Authorization: Bearer YOUR-API-KEY" \
  -H "Content-Type: application/json" \
  -d '{"host":"google.com","count":4}'
```
- [ ] API 호출 성공
- [ ] ping 결과 스트리밍 확인

## 🔧 관리

### ☑️ 11. 서버 관리 명령어 익히기
```bash
# 상태 확인
pm2 status

# 로그 보기
pm2 logs neip-ping-server

# 재시작
pm2 restart neip-ping-server
```
- [ ] 관리 명령어 숙지

### ☑️ 12. 메인 앱 연결
메인 프로젝트의 `src/app/api/ping/global/route.ts` 파일에서:
```javascript
tokyo: {
  name: 'Tokyo', 
  endpoint: 'http://YOUR-SERVER-IP:3001/api/ping',  // 실제 IP로 변경!
  fallback: 'local'
},
```
- [ ] 메인 앱 설정 업데이트
- [ ] 환경변수에 API_KEY 추가

## 🎉 완료 확인

모든 체크박스가 체크되었다면 설치 완료! 🚀

### 최종 확인사항:
- [ ] 서버가 정상 실행 중 (`pm2 status`로 확인)
- [ ] 외부에서 헬스체크 접속 가능
- [ ] API 키가 안전한 곳에 저장됨
- [ ] 메인 앱에서 글로벌 ping 테스트 동작

## 🆘 문제 해결

### ❌ 자주 발생하는 문제들:

**문제 1: `npm install` 실패**
```bash
# 해결: Node.js 재설치
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
```

**문제 2: 외부에서 접속 안됨**
- [ ] 클라우드 보안 그룹에서 포트 3001 허용했는지 확인
- [ ] `sudo ufw status` 명령어로 방화벽 확인

**문제 3: API 인증 실패**
- [ ] `.env` 파일의 API_KEY 확인
- [ ] 메인 앱의 API_KEY와 일치하는지 확인

**문제 4: PM2 서버 실행 실패**
```bash
# 로그 확인
pm2 logs neip-ping-server

# 재시작
pm2 restart neip-ping-server
```

## 📞 도움 요청

문제가 해결되지 않으면:
1. `pm2 logs neip-ping-server` 로그 확인
2. `sudo ufw status` 방화벽 상태 확인  
3. `curl http://localhost:3001/health` 로컬 테스트
4. 클라우드 보안 그룹 설정 재확인

---

**축하합니다!** 🌟 이제 전 세계 어디서나 ping 테스트를 할 수 있는 서버가 완성되었습니다! 
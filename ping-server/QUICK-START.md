# ⚡ 5분 완성! Ping 서버 빠른 설치

## 📱 단 3단계로 완료

### 1단계: 서버 접속
```bash
ssh ubuntu@YOUR-SERVER-IP
```

### 2단계: 빠른 설치 스크립트 실행
```bash
# 스크립트 다운로드 (또는 파일 직접 복사)
wget https://raw.githubusercontent.com/your-repo/ping-server/main/quick-install.sh

# 실행 권한 부여
chmod +x quick-install.sh

# 설치 실행
./quick-install.sh
```

**설치 중 입력할 내용:**
- 서버 위치: `Tokyo` (원하는 도시명)
- API 키: 엔터 (자동 생성) 또는 직접 입력

### 3단계: 완료! 🎉

**테스트:**
```bash
curl http://YOUR-SERVER-IP:3001/health
```

## 📋 중요한 3가지

1. **API 키 저장**: 설치 완료 후 나오는 API 키를 꼭 저장하세요!
2. **방화벽 허용**: 클라우드 보안 그룹에서 포트 3001 허용
3. **메인 앱 연결**: 
   ```javascript
   // src/app/api/ping/global/route.ts
   tokyo: {
     name: 'Tokyo', 
     endpoint: 'http://YOUR-SERVER-IP:3001/api/ping',
     fallback: 'local'
   }
   ```

## 🛠️ 관리 명령어

```bash
pm2 status                    # 상태 확인
pm2 logs neip-ping-server    # 로그 보기
pm2 restart neip-ping-server # 재시작
```

## 🆘 문제 해결

**외부 접속 안됨:**
- AWS/GCP 보안 그룹에서 포트 3001 인바운드 허용
- `sudo ufw status` 방화벽 확인

**서버 실행 실패:**
- `pm2 logs neip-ping-server` 로그 확인
- `pm2 restart neip-ping-server` 재시작

---

## 📚 더 자세한 가이드

- **초보자용**: `EASY-SETUP-GUIDE.md` (단계별 상세 설명)
- **체크리스트**: `INSTALLATION-CHECKLIST.md` (확인 항목)
- **기술 문서**: `README.md` (개발자용)

**완료! 이제 전 세계 ping 테스트가 가능합니다!** 🌍 
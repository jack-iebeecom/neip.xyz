# 🧪 일본 도쿄 서버 로컬 테스트 가이드

이 가이드는 실제 도쿄 서버 배포 전에 로컬에서 시스템을 테스트하는 방법을 설명합니다.

## 🚀 1단계: 로컬 Ping 서버 실행

터미널을 새로 열고 ping 서버를 실행합니다:

```bash
# ping-server 디렉토리로 이동
cd ping-server

# 의존성 설치
npm install

# 서버 실행 (포트 3001에서)
npm start
```

서버가 성공적으로 시작되면 다음과 같은 로그가 표시됩니다:
```json
{"timestamp":"2024-01-01T00:00:00.000Z","level":"info","server":"Tokyo","message":"Ping server started","port":3001,"os":"windows","node":"v18.x.x"}
```

## 🧪 2단계: 헬스체크 테스트

새 터미널에서 서버가 정상적으로 동작하는지 확인:

```bash
# 헬스체크
curl http://localhost:3001/health

# 예상 응답:
# {"status":"healthy","server":"Tokyo","timestamp":"2024-01-01T00:00:00.000Z","uptime":123}
```

## 🌐 3단계: Next.js 메인 앱 실행

메인 프로젝트 루트에서 Next.js 앱을 실행:

```bash
# 메인 프로젝트 루트로 이동
cd ..

# Next.js 개발 서버 실행
npm run dev
```

## 🔄 4단계: 글로벌 Ping 테스트

1. 브라우저에서 `http://localhost:3000/tools/ping` 접속
2. 입력란에 테스트할 호스트 입력 (예: `google.com`)
3. "🚀 Start Global Ping Test" 버튼 클릭
4. 테이블에서 Tokyo 행의 상태가 "Testing..." → "Completed"로 변경되는지 확인

## 📊 예상 결과

**성공적인 테스트**에서는 다음을 확인할 수 있어야 합니다:

### 도쿄 서버 (실제 원격 API)
- Status: 🟢 Completed  
- Avg Time: 실제 핑 응답시간 (예: 15ms)
- Packet Loss: 0%
- Details: "View Details" 클릭 시 실제 ping 출력 표시

### 다른 서버들 (로컬 fallback)
- Status: 🟢 Completed
- Avg Time: 로컬 핑 결과
- Packet Loss: 0%
- Details: 로컬에서 실행된 ping 결과

## 🔍 5단계: 상세 결과 확인

Tokyo 서버의 "View Details"를 클릭하면 다음과 같은 출력을 볼 수 있습니다:

```
PING google.com from Tokyo - Starting ping test with 4 packets...
64 bytes from 172.217.175.78: time=15.2ms
64 bytes from 172.217.175.78: time=14.8ms
64 bytes from 172.217.175.78: time=16.1ms
64 bytes from 172.217.175.78: time=15.5ms
4 packets transmitted, 4 received, 0% packet loss
round-trip min/avg/max = 14.8/15.4/16.1 ms
Ping test completed with exit code 0
```

## 🐛 문제 해결

### 문제 1: ping 서버 연결 실패
```
Error: Remote server Tokyo unavailable, using local fallback
```

**해결방법:**
1. ping 서버(포트 3001)가 실행 중인지 확인
2. 방화벽에서 포트 3001이 열려있는지 확인
3. `curl http://localhost:3001/health`로 직접 테스트

### 문제 2: API 인증 실패
```
Error: Missing or invalid API key
```

**해결방법:**
1. ping-server/.env 파일의 API_KEY 확인
2. global/route.ts의 인증 키가 일치하는지 확인

### 문제 3: CORS 에러
```
Access to fetch at 'http://localhost:3001/api/ping' from origin 'http://localhost:3000' has been blocked by CORS policy
```

**해결방법:**
1. ping-server/.env의 ALLOWED_ORIGINS에 `http://localhost:3000` 포함 확인
2. ping 서버 재시작

## ✅ 테스트 성공 기준

다음이 모두 동작하면 테스트 성공입니다:

- [ ] ping 서버가 포트 3001에서 정상 실행
- [ ] 헬스체크 API 응답 정상
- [ ] 메인 앱에서 글로벌 ping 테스트 시작 가능
- [ ] Tokyo 서버가 원격 API 호출 (fallback 아님)
- [ ] 실시간 결과 스트리밍 정상 동작
- [ ] 테이블에 평균 응답시간, 패킷 손실률 표시
- [ ] 상세 결과 보기 기능 동작

## 🚀 다음 단계

로컬 테스트가 성공했다면:

1. **실제 도쿄 서버 배포**: 일본의 우분투 서버에 ping 서버 배포
2. **도메인 설정**: `ping-tokyo.neip.xyz` 등의 도메인 연결
3. **SSL 인증서**: HTTPS 지원을 위한 SSL 설정
4. **글로벌 서버 설정 업데이트**: 실제 서버 주소로 변경
5. **다른 도시 서버들 순차 배포**

## 📞 지원

문제가 발생하면:

1. ping 서버 로그 확인: 터미널의 출력 메시지
2. 브라우저 개발자 도구 → Network 탭에서 API 요청 상태 확인
3. 브라우저 콘솔에서 JavaScript 에러 확인

---

**다음**: 실제 서버 배포를 위한 `deploy.sh` 스크립트 사용법 
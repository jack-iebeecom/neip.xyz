#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[neip.xyz] Traceroute 서버 설치를 시작합니다...${NC}"

# 작업 디렉토리 생성 및 권한 설정
INSTALL_DIR="/opt/traceroute-server"
echo -e "${GREEN}작업 디렉토리를 생성합니다: ${INSTALL_DIR}${NC}"
sudo mkdir -p $INSTALL_DIR
sudo chown -R $USER:$USER $INSTALL_DIR
cd $INSTALL_DIR

# Node.js 설치 확인 및 설치
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js를 설치합니다...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# traceroute 설치 확인
if ! command -v traceroute &> /dev/null; then
    echo -e "${YELLOW}traceroute를 설치합니다...${NC}"
    sudo apt-get update
    sudo apt-get install -y traceroute
fi

# 프로젝트 파일 복사
echo -e "${GREEN}프로젝트 파일을 복사합니다...${NC}"
sudo cp -r . $INSTALL_DIR/
sudo chown -R $USER:$USER $INSTALL_DIR

# 의존성 설치
echo -e "${GREEN}의존성 패키지를 설치합니다...${NC}"
cd $INSTALL_DIR
npm install

# TypeScript 전역 설치
echo -e "${GREEN}TypeScript를 설치합니다...${NC}"
sudo npm install -g typescript

# 환경 설정 파일 생성
if [ ! -f .env ]; then
    echo -e "${YELLOW}.env 파일을 생성합니다...${NC}"
    cp .env.example .env
    
    # 랜덤 API 키 생성
    API_KEY=$(openssl rand -hex 32)
    sed -i "s/your_api_key_here/$API_KEY/g" .env
    
    echo -e "${GREEN}생성된 API 키: $API_KEY${NC}"
    echo -e "${YELLOW}필요한 경우 .env 파일에서 설정을 수정해주세요.${NC}"
fi

# TypeScript 빌드
echo -e "${GREEN}TypeScript 코드를 빌드합니다...${NC}"
npm run build

# dist 디렉토리 확인
if [ ! -d "dist" ]; then
    echo -e "${RED}빌드 실패: dist 디렉토리가 없습니다.${NC}"
    exit 1
fi

# PM2 설치 및 서비스 등록
if ! command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}PM2를 설치합니다...${NC}"
    sudo npm install -g pm2
fi

# 서비스 시작
echo -e "${GREEN}서비스를 시작합니다...${NC}"
pm2 delete traceroute-server > /dev/null 2>&1 || true
pm2 start dist/index.js --name "traceroute-server"
pm2 save
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp /home/$USER

# 방화벽 설정
echo -e "${GREEN}방화벽 설정을 업데이트합니다...${NC}"
sudo ufw allow 3002/tcp

echo -e "${GREEN}설치가 완료되었습니다!${NC}"
echo -e "${YELLOW}서버 상태 확인: pm2 status${NC}"
echo -e "${YELLOW}로그 확인: pm2 logs traceroute-server${NC}"

# 설치 정보 출력
echo -e "\n${GREEN}=== 설치 정보 ===${NC}"
echo -e "설치 디렉토리: ${INSTALL_DIR}"
echo -e "API 키: $API_KEY"
echo -e "포트: 3002"
echo -e "서비스 이름: traceroute-server"
echo -e "\n${YELLOW}문제가 발생하면 다음 명령어로 로그를 확인하세요:${NC}"
echo -e "pm2 logs traceroute-server" 
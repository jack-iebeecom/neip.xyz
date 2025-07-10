#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[neip.xyz] Traceroute 서버 설치를 시작합니다...${NC}"

# Node.js 설치 확인
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js가 설치되어 있지 않습니다. 설치를 진행합니다...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# traceroute 설치 확인
if ! command -v traceroute &> /dev/null; then
    echo -e "${YELLOW}traceroute가 설치되어 있지 않습니다. 설치를 진행합니다...${NC}"
    sudo apt-get update
    sudo apt-get install -y traceroute
fi

# 의존성 설치
echo -e "${GREEN}의존성 패키지를 설치합니다...${NC}"
npm install

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

# PM2 설치 및 서비스 등록
if ! command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}PM2를 설치합니다...${NC}"
    sudo npm install -g pm2
fi

# 서비스 시작
echo -e "${GREEN}서비스를 시작합니다...${NC}"
pm2 start dist/index.js --name "traceroute-server"
pm2 save
pm2 startup

echo -e "${GREEN}설치가 완료되었습니다!${NC}"
echo -e "${YELLOW}서버 상태 확인: pm2 status${NC}"
echo -e "${YELLOW}로그 확인: pm2 logs traceroute-server${NC}" 
# SonarQube Integration Guide

## 🎉 SonarQube가 Docker Compose에 추가되었습니다!

**SonarQube 10.3 Community Edition**이 로컬 개발 환경에 통합되어 코드 품질 및 보안 분석을 제공합니다.

---

## 📊 Overview

### What is SonarQube?

SonarQube는 코드 품질 및 보안을 지속적으로 검사하는 오픈소스 플랫폼입니다.

**주요 기능**:
- 🐛 **버그 탐지**: 잠재적 버그와 코드 스멜 감지
- 🔒 **보안 취약점**: OWASP Top 10, CWE 기반 보안 이슈 발견
- 📏 **코드 커버리지**: 테스트 커버리지 추적
- 📈 **기술 부채**: 코드 개선에 필요한 시간 추정
- 🎯 **Quality Gates**: 코드 품질 기준 설정 및 자동 검증

### Architecture

```
┌─────────────────┐
│   Developers    │
└────────┬────────┘
         │ (1) Push code
         ↓
┌─────────────────┐
│   GitHub/Git    │
└────────┬────────┘
         │ (2) Trigger analysis
         ↓
┌─────────────────┐      ┌──────────────┐
│  SonarScanner   │ ───→ │  SonarQube   │
│  (CI/CD or CLI) │      │  Server      │
└─────────────────┘      └──────┬───────┘
                                │ (3) Store results
                                ↓
                         ┌──────────────┐
                         │  PostgreSQL  │
                         │  Database    │
                         └──────────────┘
```

---

## 🚀 Quick Start

### 1. Start Services

```bash
# Create .env file from example
cp docker/env/.env.dev.example docker/env/.env.dev

# Start all services (including SonarQube)
make dev-up
```

**SonarQube 시작 시간**: 약 60-90초 (첫 시작 시 더 오래 걸릴 수 있음)

### 2. Access SonarQube

```bash
# Browser
open http://localhost:9000
```

**기본 로그인 정보**:
- Username: `admin`
- Password: `admin`

**⚠️ 첫 로그인 시 비밀번호 변경 필수**

### 3. Health Check

```bash
# Check if SonarQube is ready
curl http://localhost:9000/api/system/status

# Expected response: {"status":"UP"}
```

---

## 🔧 Configuration

### Environment Variables

```bash
# docker/env/.env.dev
SONARQUBE_PORT=9000
SONARQUBE_DB_NAME=wealist_sonarqube_db
SONARQUBE_DB_USER=sonarqube_service
SONARQUBE_DB_PASSWORD=sonarqube_service_password
```

### Database

SonarQube uses PostgreSQL for data storage:
- **Database**: `wealist_sonarqube_db`
- **User**: `sonarqube_service`
- **Auto-created**: By `docker/init/postgres/init-db.sh`

### Volumes

```yaml
volumes:
  sonarqube-data:       # Analysis results, settings
  sonarqube-extensions: # Plugins
  sonarqube-logs:       # Application logs
```

**Data Persistence**: All data persists across container restarts.

---

## 📦 Project Setup

### Create Projects

#### Option 1: Manual Setup (UI)

1. **Navigate**: http://localhost:9000 → Projects → Create Project
2. **Project key**: e.g., `wealist-user-service`
3. **Display name**: `weAlist User Service`
4. **Main branch**: `main`
5. **Generate token**:
   - Token name: `user-service-token`
   - Type: Project Analysis Token
   - Copy and save the token

#### Option 2: API (Automated)

```bash
# Create project via API
curl -X POST -u admin:your-new-password \
  "http://localhost:9000/api/projects/create" \
  -d "name=weAlist User Service&project=wealist-user-service"

# Generate token
curl -X POST -u admin:your-new-password \
  "http://localhost:9000/api/user_tokens/generate" \
  -d "name=user-service-token&projectKey=wealist-user-service"
```

### Recommended Projects

Create one project per service:
- `wealist-auth-service` (Java/Spring Boot)
- `wealist-user-service` (Go)
- `wealist-board-service` (Go)
- `wealist-chat-service` (Go)
- `wealist-noti-service` (Go)
- `wealist-storage-service` (Go)
- `wealist-video-service` (Go)
- `wealist-frontend` (React/TypeScript)

---

## 🔍 Code Analysis

### Method 1: SonarScanner CLI (Recommended for local)

#### Install SonarScanner

```bash
# macOS
brew install sonar-scanner

# Linux (manual)
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
unzip sonar-scanner-cli-5.0.1.3006-linux.zip
export PATH=$PATH:/path/to/sonar-scanner/bin
```

#### Analyze Go Services

```bash
cd services/user-service

# Create sonar-project.properties
cat > sonar-project.properties <<EOF
sonar.projectKey=wealist-user-service
sonar.projectName=weAlist User Service
sonar.projectVersion=1.0
sonar.sources=.
sonar.exclusions=**/*_test.go,**/vendor/**,**/migrations/**
sonar.go.coverage.reportPaths=coverage.out
sonar.host.url=http://localhost:9000
sonar.token=YOUR_TOKEN_HERE
EOF

# Run tests with coverage
go test -coverprofile=coverage.out ./...

# Run SonarScanner
sonar-scanner
```

#### Analyze Java Service (auth-service)

```bash
cd services/auth-service

# Maven
mvn clean verify sonar:sonar \
  -Dsonar.projectKey=wealist-auth-service \
  -Dsonar.projectName="weAlist Auth Service" \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=YOUR_TOKEN_HERE

# Or Gradle
./gradlew sonar \
  -Dsonar.projectKey=wealist-auth-service \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=YOUR_TOKEN_HERE
```

#### Analyze Frontend (React/TypeScript)

```bash
cd services/frontend

# Create sonar-project.properties
cat > sonar-project.properties <<EOF
sonar.projectKey=wealist-frontend
sonar.projectName=weAlist Frontend
sonar.projectVersion=1.0
sonar.sources=src
sonar.exclusions=**/*.test.ts,**/*.test.tsx,**/node_modules/**,**/dist/**
sonar.typescript.lcov.reportPaths=coverage/lcov.info
sonar.host.url=http://localhost:9000
sonar.token=YOUR_TOKEN_HERE
EOF

# Run tests with coverage
npm test -- --coverage

# Run SonarScanner
sonar-scanner
```

### Method 2: GitHub Actions (CI/CD)

Create `.github/workflows/sonarqube.yml`:

```yaml
name: SonarQube Analysis

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  sonarqube:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for better analysis

      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.24'

      - name: Run tests with coverage
        run: |
          cd services/user-service
          go test -coverprofile=coverage.out ./...

      - name: SonarQube Scan
        uses: sonarsource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: http://your-sonarqube-server:9000
        with:
          projectBaseDir: services/user-service
```

---

## 📈 Quality Gates

### Default Quality Gate

SonarQube comes with a default quality gate:
- **Bugs**: 0 new bugs
- **Vulnerabilities**: 0 new vulnerabilities
- **Security Hotspots**: 100% reviewed
- **Code Smells**: ≤ 3% new technical debt ratio
- **Coverage**: ≥ 80% on new code
- **Duplications**: ≤ 3% on new code

### Custom Quality Gate (Recommended)

1. **Navigate**: Quality Gates → Create
2. **Name**: `weAlist Standard`
3. **Conditions**:
   - Coverage on New Code ≥ 70%
   - Duplicated Lines on New Code ≤ 3%
   - Maintainability Rating on New Code ≥ A
   - Reliability Rating on New Code ≥ A
   - Security Rating on New Code ≥ A
4. **Set as Default**: Actions → Set as Default

---

## 🔌 IDE Integration

### VS Code

Install **SonarLint** extension:
```bash
code --install-extension SonarSource.sonarlint-vscode
```

Configure `.vscode/settings.json`:
```json
{
  "sonarlint.connectedMode.servers": [
    {
      "serverId": "wealist-local",
      "serverUrl": "http://localhost:9000",
      "token": "YOUR_TOKEN_HERE"
    }
  ],
  "sonarlint.connectedMode.project": {
    "serverId": "wealist-local",
    "projectKey": "wealist-user-service"
  }
}
```

### IntelliJ IDEA / GoLand

1. **Install Plugin**: Settings → Plugins → SonarLint
2. **Configure**:
   - Settings → Tools → SonarLint → Connect to SonarQube
   - Server URL: `http://localhost:9000`
   - Token: YOUR_TOKEN_HERE
   - Project: `wealist-user-service`

---

## 📊 Monitoring (Prometheus Integration)

SonarQube metrics are automatically scraped by Prometheus:

```yaml
# docker/monitoring/prometheus/prometheus.yml
- job_name: 'sonarqube'
  static_configs:
    - targets: ['sonarqube:9000']
  metrics_path: '/api/monitoring/metrics'
```

**Available Metrics**:
- `sonarqube_project_lines_of_code`
- `sonarqube_project_bugs`
- `sonarqube_project_vulnerabilities`
- `sonarqube_project_code_smells`
- `sonarqube_project_coverage`

**Grafana Dashboard**: Import dashboard ID `9139` for SonarQube monitoring.

---

## 🛠️ Maintenance

### Backup Data

```bash
# Backup volumes
docker run --rm \
  -v wealist-sonarqube-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/sonarqube-data-$(date +%Y%m%d).tar.gz /data
```

### Clear Analysis Data

```bash
# Navigate to Administration → Projects → Management
# Select project → Delete
```

### Reset Admin Password

```bash
# Stop SonarQube
docker stop wealist-sonarqube

# Reset password via database
docker exec -it wealist-postgres psql -U postgres -d wealist_sonarqube_db -c \
  "UPDATE users SET crypted_password='$2a$12$uCkkXmhW5ThVK8mpBvnXOOJRLd64LJeHTeCkSuB3lfaR2N0AYBaSi', \
   salt=null WHERE login='admin';"
# This resets password to: admin

# Restart SonarQube
docker start wealist-sonarqube
```

### Update SonarQube

```bash
# Pull new image
docker pull sonarqube:10.4-community

# Update docker-compose.yml
image: sonarqube:10.4-community

# Restart
docker-compose down
docker-compose up -d sonarqube
```

---

## 🚨 Troubleshooting

### SonarQube Won't Start

**Check logs**:
```bash
docker logs wealist-sonarqube
```

**Common issues**:

1. **Elasticsearch bootstrap checks failed**
   ```bash
   # Already disabled in docker-compose.yml
   SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true
   ```

2. **Database connection error**
   ```bash
   # Check PostgreSQL is running
   docker ps | grep postgres

   # Check database exists
   docker exec -it wealist-postgres psql -U postgres -c "\l" | grep sonarqube
   ```

3. **Port already in use**
   ```bash
   # Change port in .env
   SONARQUBE_PORT=9001
   ```

### Analysis Fails

1. **Invalid token**
   - Regenerate token in SonarQube UI
   - Update sonar-project.properties

2. **Network issues**
   ```bash
   # Check SonarQube is accessible
   curl http://localhost:9000/api/system/status
   ```

3. **Coverage file not found**
   ```bash
   # Verify coverage file exists
   ls -la coverage.out

   # Check path in sonar-project.properties
   sonar.go.coverage.reportPaths=coverage.out
   ```

---

## 📚 Best Practices

### 1. Run Analysis Regularly

- **Locally**: Before committing
- **CI/CD**: On every PR
- **Scheduled**: Nightly on main branch

### 2. Fix Issues by Priority

1. **Blocker**: Bugs that crash the application
2. **Critical**: Security vulnerabilities
3. **Major**: Serious code smells
4. **Minor**: Maintainability issues

### 3. Code Coverage Goals

- **New code**: ≥ 70%
- **Overall**: ≥ 60%
- **Critical paths**: ≥ 90%

### 4. Use Quality Profiles

- **Go**: SonarQube Way (default)
- **Java**: SonarQube Way for Java
- **TypeScript**: SonarQube Way for TypeScript

### 5. Address Security Hotspots

- Review all security hotspots
- Mark as "Safe" with justification or fix
- Don't ignore without review

---

## 🔗 Additional Resources

- **SonarQube Docs**: https://docs.sonarqube.org/latest/
- **SonarScanner for Go**: https://docs.sonarqube.org/latest/analyzing-source-code/scanners/sonarscanner/
- **Quality Gates**: https://docs.sonarqube.org/latest/user-guide/quality-gates/
- **SonarLint**: https://www.sonarsource.com/products/sonarlint/

---

## 📊 Example: Complete Workflow

### 1. Initial Setup

```bash
# Start services
make dev-up

# Wait for SonarQube to be ready
curl http://localhost:9000/api/system/status

# Login and change password
open http://localhost:9000
```

### 2. Create Project & Token

```bash
# Via UI or API
curl -X POST -u admin:new-password \
  "http://localhost:9000/api/projects/create" \
  -d "name=User Service&project=wealist-user-service"

# Generate token
curl -X POST -u admin:new-password \
  "http://localhost:9000/api/user_tokens/generate" \
  -d "name=user-service-token&projectKey=wealist-user-service"
```

### 3. Analyze Code

```bash
cd services/user-service

# Create config
cat > sonar-project.properties <<EOF
sonar.projectKey=wealist-user-service
sonar.projectName=weAlist User Service
sonar.sources=.
sonar.exclusions=**/*_test.go,**/vendor/**
sonar.go.coverage.reportPaths=coverage.out
sonar.host.url=http://localhost:9000
sonar.token=YOUR_TOKEN
EOF

# Run tests & analysis
go test -coverprofile=coverage.out ./...
sonar-scanner
```

### 4. Review Results

```bash
# Open project
open http://localhost:9000/dashboard?id=wealist-user-service
```

---

**Status**: ✅ SonarQube Integration Complete!
**Environment**: Docker Compose only (local development)
**Access**: http://localhost:9000

# wealist-argo-helm

이 프로젝트는 Helm Chart와 ArgoCD를 사용하여 Wealist 서비스를 배포하는 저장소입니다.

## 📁 프로젝트 구조

- **charts/** - 각 서비스별 개별 Helm Chart
- **environments/** - 환경별 설정 파일 (localhost, dev, prod)
  - Chart 템플릿은 변경하지 않고, 모든 환경에서 공통으로 사용합니다
  - 환경별로 다른 값들만 이 디렉토리에서 관리합니다

> ⚠️ **중요**: 배포 전에 각 환경의 `secret` 파일에 환경변수 값을 반드시 설정해야 합니다.

---

## 🚀 빠른 시작 가이드

Kind 클러스터에서 Wealist 서비스를 배포하는 두 가지 방법이 있습니다.

| 환경 | 이미지 레지스트리 | 데이터베이스 | 사용 목적 |
|------|------------------|--------------|-----------|
| **localhost** | 로컬 레지스트리 (`localhost:5001`) | 클러스터 내부 Pod | 로컬에서 직접 빌드한 이미지로 테스트 |
| **dev** | GitHub Container Registry (ghcr.io) | 호스트 PC (외부 DB) | GitHub에 푸시된 이미지로 개발 환경 구성 |

---

## 🏠 방법 1: Localhost 환경 배포

로컬에서 빌드한 Docker 이미지를 사용하여 배포합니다. 모든 컴포넌트(DB 포함)가 클러스터 내부에서 실행됩니다.

### Step 1. Kind 클러스터 및 로컬 레지스트리 생성

```bash
make kind-localhost-setup
```

**이 명령어가 수행하는 작업:**

| 단계 | 작업 내용 |
|------|----------|
| 0 | **필수 도구 확인** - kubectl, kind, helm, istioctl 설치 여부 확인 (미설치 시 자동 설치) |
| 1 | **Secrets 파일 확인** - `secrets.yaml` 없으면 `secrets.example.yaml`에서 자동 생성 |
| 2 | **Kind 클러스터 생성** - 클러스터 + Istio Ambient 모드 + 로컬 레지스트리(`localhost:5001`) 설정 |
| 3 | **모든 이미지 로드** - PostgreSQL, Redis, MinIO 등 인프라 이미지 + Backend/Frontend 서비스 이미지 빌드 및 로드 |

### Step 2. Docker 이미지 빌드 및 푸시 (선택사항)

서비스 코드 수정 후 직접 빌드가 필요한 경우:

```bash
# 예시: 서비스 이미지 빌드 및 푸시
docker build -t localhost:5001/service-name:latest .
docker push localhost:5001/service-name:latest
```

이미지 업로드 확인:
```bash
curl -s http://localhost:5001/v2/_catalog | jq
```

### Step 3. Helm 차트 배포

```bash
make helm-install-all ENV=localhost
```

**이 명령어가 수행하는 작업:**

| 단계 | 작업 내용 |
|------|----------|
| 1 | **Secrets 체크** - `secrets.yaml` 파일 존재 여부 확인 |
| 2 | **DB 체크 스킵** - localhost는 내부 Pod 사용이므로 외부 DB 체크 생략 |
| 3 | **Helm 의존성 빌드** - 모든 차트의 의존성 업데이트 |
| 4 | **cert-manager 설치** - 환경에서 활성화된 경우에만 설치 |
| 5 | **인프라 설치** - PostgreSQL, Redis Pod + MinIO, LiveKit 등 |
| 6 | **서비스 설치** - auth, user, board, chat, noti, storage, video 서비스 (DB auto-migrate 활성화) |
| 7 | **Frontend 설치** - localhost.yaml에서 `frontend.enabled=true`인 경우 |
| 8 | **Istio 설정** - HTTPRoute, DestinationRules, PeerAuthentication |
| 9 | **Istio Addons** - Kiali, Jaeger (서비스 메시 관측성) |
| 10 | **모니터링 스택** - Prometheus, Grafana, Loki |

✅ **Localhost 환경 배포 완료!**

---

## 🌐 방법 2: Dev 환경 배포

GitHub Container Registry(ghcr.io)에 있는 이미지를 사용하고, 호스트 PC의 PostgreSQL/Redis를 사용합니다.

### Step 1. Kind 클러스터 생성

```bash
make kind-dev-setup
```

**이 명령어가 수행하는 작업:**

| 단계 | 작업 내용 |
|------|----------|
| 1 | **필수 도구 확인** - kubectl, kind, helm, istioctl, AWS CLI 설치 여부 확인 |
| 2 | **Secrets 파일 확인** - `secrets.yaml` 없으면 자동 생성 |
| 3 | **AWS 로그인 확인** - ECR 접근을 위한 AWS 자격증명 확인/설정 |
| 4 | **Kind 클러스터 생성** - 클러스터 + Istio Ambient + ECR Secret 생성 |
| 5 | **외부 DB 연결 테스트** - 호스트 PC의 PostgreSQL(172.18.0.1:5432), Redis(172.18.0.1:6379) 연결 확인 |
| 6 | **인프라 이미지 로드** - MinIO, LiveKit 등 (DB 이미지 제외) |
| 7 | **ECR 이미지 확인** - 각 서비스의 `dev-latest` 태그 이미지 존재 여부 확인 |
| 8 | **ArgoCD 설치** - GitOps 자동 배포 설정 |

### Step 2. Helm 차트 배포

```bash
make helm-install-all ENV=dev
```

**이 명령어가 수행하는 작업:**

| 단계 | 작업 내용 |
|------|----------|
| 1 | **Secrets 체크** - `secrets.yaml` 파일 존재 여부 확인 |
| 2 | **DB 연결 체크** - 호스트 PC의 PostgreSQL/Redis 실행 상태 확인 |
| 3 | **Helm 의존성 빌드** - 모든 차트의 의존성 업데이트 |
| 4 | **cert-manager 설치** - TLS 인증서 자동 발급 (활성화된 경우) |
| 5 | **인프라 설치** - 외부 DB 연결 설정 (postgres.enabled=false, external.enabled=true) |
| 6 | **서비스 설치** - ECR에서 이미지 pull, AWS Account ID 자동 설정 |
| 7 | **Istio 설정** - HTTPRoute, DestinationRules, PeerAuthentication |
| 8 | **Istio Addons** - Kiali, Jaeger |
| 9 | **모니터링 스택** - Prometheus, Grafana, Loki (외부 DB exporter 설정) |

✅ **Dev 환경 배포 완료!**

---

## 📋 환경별 비교

| 항목 | Localhost | Dev |
|------|-----------|-----|
| **클러스터 생성** | `make kind-localhost-setup` | `make kind-dev-setup` |
| **Helm 배포** | `make helm-install-all ENV=localhost` | `make helm-install-all ENV=dev` |
| **이미지 소스** | 로컬 레지스트리 (`localhost:5001`) | ghcr.io / AWS ECR |
| **이미지 빌드** | 직접 빌드 필요 | GitHub Actions 자동 빌드 |
| **데이터베이스** | 클러스터 내부 Pod | 호스트 PC (외부 DB) |
| **ArgoCD** | 미설치 | 자동 설치 |
| **적합한 상황** | 로컬 개발 및 테스트 | CI/CD 통합 테스트 |

---

## 📊 배포 후 접속 정보

### 서비스 접속
- **Gateway**: `http://localhost:80` (또는 `:8080`)

### 모니터링 대시보드
| 서비스 | URL |
|--------|-----|
| Grafana | `http://localhost:8080/api/monitoring/grafana` |
| Prometheus | `http://localhost:8080/api/monitoring/prometheus` |
| Kiali | `http://localhost:8080/api/monitoring/kiali` |
| Jaeger | `http://localhost:8080/api/monitoring/jaeger` |

### ArgoCD (dev 환경만)
- **URL**: `https://localhost:8079`
- **User**: `admin`
- **Password**: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

---

## 🔍 클러스터 정보 확인

### 배포 정보 확인

```bash
make kind-info
```

**출력 정보:**
- Git Repository (Repo, Branch, Commit)
- 배포자 정보 (Name, Email, Time)
- 클러스터 설정 (Namespace, Istio 모드)

### 배포 정보 업데이트

```bash
make kind-info-update
```

**수행 작업:**
- 현재 Git 정보 (repo, branch, commit)를 네임스페이스 annotation에 기록
- 배포자 정보 (git config user.name, user.email) 기록
- 배포 시간 기록

---

## 💡 주요 참고사항

- Chart 템플릿은 수정하지 말고, `environments/` 디렉토리의 값만 수정하세요
- 환경별 시크릿 설정을 잊지 마세요
- 클러스터 삭제: `kind delete cluster --name wealist`
- 상태 확인: `make status`
- Pod 로그: `kubectl logs -n <namespace> <pod-name>`

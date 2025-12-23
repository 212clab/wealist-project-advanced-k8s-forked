# ============================================
# ArgoCD Makefile
# ============================================
.PHONY: argo-help cluster-up cluster-down bootstrap deploy argo-clean argo-status helm-install-infra all
.PHONY: setup-local-argocd kind-setup-ecr load-infra-images-ecr

# 색상
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m

# 변수
CLUSTER_NAME ?= wealist-dev
SEALED_SECRETS_KEY ?= k8s/argocd/scripts/sealed-secrets-dev-20251218-152119.key
ENVIRONMENT ?= dev
ENV ?= dev

argo-help: ## [ArgoCD] 도움말 표시
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Wealist Platform - Make Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "빠른 시작:"
	@echo "  make all              - 클러스터 생성부터 배포까지 전체 프로세스"
	@echo ""
	@echo "단계별 실행:"
	@echo "  make cluster-up       - Kind 클러스터 생성"
	@echo "  make bootstrap        - ArgoCD & Sealed Secrets 설치"
	@echo "  make deploy           - Applications 배포"
	@echo ""
	@echo "관리:"
	@echo "  make status           - 전체 상태 확인"
	@echo "  make logs             - ArgoCD 로그 확인"
	@echo "  make ui               - ArgoCD UI 열기"
	@echo "  make clean            - 모든 리소스 삭제"
	@echo "  make cluster-down     - 클러스터 삭제"
	@echo ""
	@echo "시크릿 관리:"
	@echo "  make seal-secrets     - Secrets 재암호화"
	@echo "  make backup-keys      - Sealed Secrets 키 백업"
	@echo ""
	@echo "변수:"
	@echo "  ENVIRONMENT=$(ENVIRONMENT)"
	@echo "  SEALED_SECRETS_KEY=$(SEALED_SECRETS_KEY)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

all-simple: cluster-up bootstrap ## 전체 프로세스 (클러스터 → Helm Infra → Bootstrap → 배포)
	@echo ""
	@echo -e "$(GREEN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo -e "$(GREEN)✅ 전체 배포 완료!$(NC)"
	@echo -e "$(GREEN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo ""
	@echo "ArgoCD UI: https://localhost:8079"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
	@echo ""
	@echo "다음 명령어로 포트 포워딩:"
	@echo "  make ui"

# ============================================
# 클러스터 관리
# ============================================

cluster-up: ## Kind 클러스터 + 로컬 레지스트리 + 이미지 준비
	@echo -e "$(YELLOW)📦 Kind 클러스터 + 로컬 환경 설정 중...$(NC)"
	@if kind get clusters | grep -q "$(CLUSTER_NAME)"; then \
		echo -e "$(YELLOW)⚠️  클러스터가 이미 존재합니다: $(CLUSTER_NAME)$(NC)"; \
		read -p "삭제하고 다시 만들까요? (y/N): " answer; \
		if [ "$$answer" = "y" ] || [ "$$answer" = "Y" ]; then \
			$(MAKE) cluster-down; \
		else \
			echo "기존 클러스터를 사용합니다."; \
			$(MAKE) load-images-only; \
			exit 0; \
		fi; \
	fi
	@echo -e "$(YELLOW)🏗️  Step 1: 클러스터 + 레지스트리 생성...$(NC)"
	@if [ -f "k8s/installShell/0.setup-cluster.sh" ]; then \
		chmod +x k8s/installShell/0.setup-cluster.sh; \
		cd k8s/installShell && ./0.setup-cluster.sh; \
	else \
		echo -e "$(RED)❌ 0.setup-cluster.sh not found$(NC)"; \
		exit 1; \
	fi
	@kubectl cluster-info
	@echo -e "$(GREEN)✅ 클러스터 + 로컬 환경 준비 완료$(NC)"

load-images-only: ## 이미지만 로드 (기존 클러스터용)
	@echo -e "$(YELLOW)📦 인프라 이미지 로드...$(NC)"
	@if [ -f "k8s/installShell/1.load_infra_images.sh" ]; then \
		chmod +x k8s/installShell/1.load_infra_images.sh; \
		cd k8s/installShell && ./1.load_infra_images.sh; \
	fi
	@echo -e "$(YELLOW)🔨 서비스 이미지 빌드 및 로드...$(NC)"
	@if [ -f "k8s/installShell/2.build_services_and_load.sh" ]; then \
		chmod +x k8s/installShell/2.build_services_and_load.sh; \
		cd k8s/installShell && ./2.build_services_and_load.sh; \
	fi
	@echo -e "$(GREEN)✅ 이미지 로드 완료$(NC)"
	@echo -e "$(YELLOW)� 인프클라 이미지 로드...$(NC)"
	@if [ -f "k8s/installShell/1.load_infra_images.sh" ]; then \
		chmod +x k8s/installShell/1.load_infra_images.sh; \
		cd k8s/installShell && ./1.load_infra_images.sh; \
	fi
	@echo -e "$(YELLOW)🔨 서비스 이미지 빌드 및 로드...$(NC)"
	@if [ -f "k8s/installShell/2.build_services_and_load.sh" ]; then \
		chmod +x k8s/installShell/2.build_services_and_load.sh; \
		cd k8s/installShell && ./2.build_services_and_load.sh; \
	fi
	@echo -e "$(GREEN)✅ 이미지 로드 완료$(NC)"

cluster-down: ## Kind 클러스터 삭제
	@echo -e "$(YELLOW)🗑️  클러스터 삭제 중...$(NC)"
	@kind delete cluster --name $(CLUSTER_NAME) || true
	@echo -e "$(GREEN)✅ 클러스터 삭제 완료$(NC)"

# ============================================
# Bootstrap
# ============================================

bootstrap: check-key ## ArgoCD & Sealed Secrets 설치 (키 복원 포함)
	@echo -e "$(YELLOW)🚀 Bootstrap 시작...$(NC)"
	@chmod +x k8s/argocd/scripts/deploy-argocd.sh
	@./k8s/argocd/scripts/deploy-argocd.sh $(SEALED_SECRETS_KEY)

check-key: ## Sealed Secrets 키 파일 확인
	@if [ ! -f "$(SEALED_SECRETS_KEY)" ]; then \
		echo -e "$(RED)❌ 키 파일을 찾을 수 없습니다: $(SEALED_SECRETS_KEY)$(NC)"; \
		echo ""; \
		echo "옵션:"; \
		echo "  1. 키 파일을 현재 디렉토리에 배치"; \
		echo "  2. SEALED_SECRETS_KEY 변수로 경로 지정:"; \
		echo "     make bootstrap SEALED_SECRETS_KEY=path/to/key.yaml"; \
		echo "  3. 키 없이 진행 (새 키 생성):"; \
		echo "     make bootstrap-without-key"; \
		echo ""; \
		exit 1; \
	fi
	@echo -e "$(GREEN)✅ 키 파일 확인: $(SEALED_SECRETS_KEY)$(NC)"

bootstrap-without-key: ## 키 없이 Bootstrap (새 키 생성)
	@echo -e "$(YELLOW)⚠️  키 없이 진행 - 새 키가 생성됩니다$(NC)"
	@chmod +x k8s/argocd/scripts/deploy-argocd.sh
	@./k8s/argocd/scripts/deploy-argocd.sh

argo-install-simple: ## ArgoCD만 간단 설치 (Sealed Secrets 없이)
	@echo "ArgoCD 설치 중..."
	@kubectl create namespace argocd 2>/dev/null || true
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "ArgoCD 설치 완료, Pod 준비 대기 중..."
	@kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || echo "WARNING: ArgoCD server not ready yet"
	@echo ""
	@echo "=============================================="
	@echo "  ✅ ArgoCD 설치 완료!"
	@echo "=============================================="
	@echo ""
	@echo "  포트 포워딩:"
	@echo "    kubectl port-forward svc/argocd-server -n argocd 8079:443"
	@echo ""
	@echo "  로그인 정보:"
	@echo "    URL: https://localhost:8079"
	@echo "    User: admin"
	@echo "    Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo '(아직 생성 안됨)')"
	@echo ""
	@echo "  Git 레포 연결:"
	@echo "    make argo-add-repo"
	@echo "=============================================="

argo-add-repo: ## Git 레포지토리 ArgoCD에 등록
	@echo "Git 레포지토리를 ArgoCD에 등록합니다."
	@echo ""
	@echo "GitHub Personal Access Token이 필요합니다."
	@echo "Token 생성: https://github.com/settings/tokens (repo 권한 필요)"
	@echo ""
	@read -p "GitHub Username: " gh_user; \
	read -p "GitHub Token: " gh_token; \
	read -p "Repository URL (예: https://github.com/org/repo.git): " repo_url; \
	kubectl -n argocd create secret generic repo-creds \
		--from-literal=url=$$repo_url \
		--from-literal=username=$$gh_user \
		--from-literal=password=$$gh_token \
		--dry-run=client -o yaml | kubectl apply -f -; \
	echo ""; \
	echo "✅ Git 레포 등록 완료: $$repo_url"

argo-ui: ## ArgoCD UI 포트 포워딩
	@echo "ArgoCD UI 포트 포워딩: https://localhost:8079"
	@echo "종료하려면 Ctrl+C"
	@kubectl port-forward svc/argocd-server -n argocd 8079:443

# ============================================
# 배포
# ============================================

# deploy: ## Applications 배포 (Root App 생성)
# 	@echo -e "$(YELLOW)🎯 Applications 배포 중...$(NC)"
# 	@kubectl apply -f k8s/argocd/apps/project.yaml || true
# 	@kubectl apply -f k8s/argocd/apps/root-app.yaml || true
# 	@echo -e "$(GREEN)✅ 배포 완료$(NC)"
# 	@echo ""
# 	@echo "Applications 확인:"
# 	@kubectl get applications -n argocd

# ============================================
# 상태 확인
# ============================================

argo-status: ## [ArgoCD] 전체 상태 확인
	@echo -e "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo -e "$(YELLOW)📊 시스템 상태$(NC)"
	@echo -e "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo ""
	@echo "🏗️  클러스터:"
	@kubectl cluster-info | head -1 || echo "클러스터 없음"
	@echo ""
	@echo "📦 ArgoCD Pods:"
	@kubectl get pods -n argocd --no-headers 2>/dev/null | grep -E "Running|Ready" | wc -l | xargs -I {} echo "  Running: {} pods"
	@echo ""
	@echo "🔐 Sealed Secrets:"
	@kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets --no-headers 2>/dev/null | wc -l | xargs -I {} echo "  Controller: {} pod(s)"
	@echo ""
	@echo "🎯 Applications:"
	@kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l | xargs -I {} echo "  Total: {}"
	@kubectl get applications -n argocd --no-headers 2>/dev/null | grep Synced | wc -l | xargs -I {} echo "  Synced: {}"
	@echo ""
	@echo "🔒 SealedSecrets:"
	@kubectl get sealedsecrets -n wealist-$(ENVIRONMENT) --no-headers 2>/dev/null | wc -l | xargs -I {} echo "  Total: {}"
	@echo ""
	@echo "🗝️  Secrets:"
	@kubectl get secrets -n wealist-$(ENVIRONMENT) --no-headers 2>/dev/null | wc -l | xargs -I {} echo "  Total: {}"
	@echo ""
	@echo -e "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"

status-detail: ## 상세 상태 확인
	@echo "📦 ArgoCD Pods:"
	@kubectl get pods -n argocd
	@echo ""
	@echo "🔐 Sealed Secrets:"
	@kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
	@echo ""
	@echo "🎯 Applications:"
	@kubectl get applications -n argocd
	@echo ""
	@echo "🔒 SealedSecrets:"
	@kubectl get sealedsecrets -A
	@echo ""
	@echo "🗝️  Secrets:"
	@kubectl get secrets -n wealist-$(ENVIRONMENT)

# ============================================
# UI 및 로그
# ============================================

ui: ## ArgoCD UI 접속 (포트 포워딩)
	@echo -e "$(GREEN)🌐 ArgoCD UI 접속...$(NC)"
	@echo ""
	@echo "URL: https://localhost:8079"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
	@echo ""
	@echo "브라우저에서 https://localhost:8079 를 열어주세요"
	@echo "(Ctrl+C로 중지)"
	@echo ""
	@kubectl port-forward svc/argocd-server -n argocd 8079:443

logs: ## ArgoCD 로그 확인
	@echo "ArgoCD Application Controller 로그:"
	@kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50

logs-sealed: ## Sealed Secrets Controller 로그
	@echo "Sealed Secrets Controller 로그:"
	@kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets --tail=50

# ============================================
# Secrets 관리
# ============================================

seal-secrets: ## Secrets 재암호화
	@echo -e "$(YELLOW)🔐 Secrets 재암호화...$(NC)"
	@chmod +x k8s/argocd/scripts/re-seal-secrets-complete.sh
	@./k8s/argocd/scripts/re-seal-secrets-complete.sh $(ENVIRONMENT)

backup-keys: ## Sealed Secrets 키 백업
	@echo -e "$(YELLOW)💾 키 백업 중...$(NC)"
	@BACKUP_FILE="sealed-secrets-$(ENVIRONMENT)-$$(date +%Y%m%d-%H%M%S).key"; \
	kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > $$BACKUP_FILE; \
	echo -e "$(GREEN)✅ 키 백업 완료: $$BACKUP_FILE$(NC)"; \
	echo ""; \
	echo -e "$(RED)⚠️  이 파일을 안전한 곳에 보관하세요!$(NC)"

# ============================================
# 정리
# ============================================

argo-clean: ## [ArgoCD] 모든 리소스 삭제 (클러스터는 유지)
	@echo -e "$(YELLOW)🗑️  리소스 삭제 중...$(NC)"
	@kubectl delete namespace wealist-$(ENVIRONMENT) --ignore-not-found=true
	@kubectl delete namespace argocd --ignore-not-found=true
	@echo -e "$(GREEN)✅ 리소스 삭제 완료$(NC)"

argo-clean-all: cluster-down ## [ArgoCD] 클러스터 포함 모든 것 삭제
	@echo -e "$(GREEN)✅ 전체 정리 완료$(NC)"

# ============================================
# 개발 편의 기능
# ============================================

restart-argocd: ## ArgoCD 재시작
	@echo -e "$(YELLOW)🔄 ArgoCD 재시작...$(NC)"
	@kubectl rollout restart deployment -n argocd
	@kubectl rollout status deployment -n argocd

restart-sealed: ## Sealed Secrets Controller 재시작
	@echo -e "$(YELLOW)🔄 Sealed Secrets Controller 재시작...$(NC)"
	@kubectl delete pod -n kube-system -l app.kubernetes.io/name=sealed-secrets
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets -n kube-system --timeout=300s
	@echo -e "$(GREEN)✅ 재시작 완료$(NC)"

sync-all: ## 모든 Applications Sync
	@echo -e "$(YELLOW)🔄 전체 Sync...$(NC)"
	@kubectl get applications -n argocd -o name | xargs -I {} kubectl patch {} -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
	@echo -e "$(GREEN)✅ Sync 완료$(NC)"

# ============================================
# 트러블슈팅
# ============================================

debug: ## 디버깅 정보 출력
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🔍 디버깅 정보"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "클러스터 정보:"
	@kubectl cluster-info
	@echo ""
	@echo "Nodes:"
	@kubectl get nodes
	@echo ""
	@echo "Namespaces:"
	@kubectl get namespaces
	@echo ""
	@echo "ArgoCD Applications:"
	@kubectl get applications -n argocd
	@echo ""
	@echo "SealedSecrets 상태:"
	@kubectl get sealedsecrets -A
	@echo ""
	@echo "Sealed Secrets Controller 로그 (last 20):"
	@kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets --tail=20
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

verify-secrets: ## Secrets 복호화 확인
	@echo -e "$(YELLOW)🔐 Secrets 확인...$(NC)"
	@echo ""
	@echo "SealedSecrets:"
	@kubectl get sealedsecrets -n wealist-$(ENVIRONMENT)
	@echo ""
	@echo "Secrets:"
	@kubectl get secrets -n wealist-$(ENVIRONMENT)
	@echo ""
	@if kubectl get secret wealist-shared-secret -n wealist-$(ENVIRONMENT) &> /dev/null; then \
		echo -e "$(GREEN)✅ wealist-shared-secret 존재$(NC)"; \
		kubectl describe secret wealist-shared-secret -n wealist-$(ENVIRONMENT) | grep -A 10 "Data:"; \
	else \
		echo -e "$(RED)❌ wealist-shared-secret 없음$(NC)"; \
		echo ""; \
		echo "SealedSecret 상태:"; \
		kubectl describe sealedsecret wealist-shared-secret -n wealist-$(ENVIRONMENT) 2>/dev/null || echo "SealedSecret도 없음"; \
	fi
# ... (기존 내용 유지) ...

# ============================================
# 로컬 개발 (Kind + Registry) - ArgoCD용
# ============================================
# NOTE: kind-setup은 kind.mk에서 정의됨 (Istio Ambient + 로컬 레지스트리)
# 아래는 ECR 직접 연결이 필요한 ArgoCD 환경용

setup-local-argocd: ## [ArgoCD] 로컬 개발 환경 전체 설정 (ECR + Bootstrap)
	$(MAKE) kind-setup-ecr
	$(MAKE) load-infra-images-ecr
	$(MAKE) bootstrap
	$(MAKE) deploy

kind-setup-ecr: ## [ArgoCD] Kind 클러스터 + ECR 직접 연결
	@echo -e "$(YELLOW)🏗️  Kind 클러스터 + ECR 설정...$(NC)"
	@if [ -f "k8s/helm/scripts/dev/0.setup-cluster.sh" ]; then \
		chmod +x k8s/helm/scripts/dev/0.setup-cluster.sh; \
		./k8s/helm/scripts/dev/0.setup-cluster.sh; \
	else \
		echo -e "$(RED)❌ 0.setup-cluster.sh not found$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)✅ Kind 클러스터 + ECR 준비 완료$(NC)"

load-infra-images-ecr: ## [ArgoCD] 인프라 이미지 로드
	@echo -e "$(YELLOW)📦 인프라 이미지 로드 중...$(NC)"
	@if [ -f "k8s/helm/scripts/dev/1.load_infra_images.sh" ]; then \
		chmod +x k8s/helm/scripts/dev/1.load_infra_images.sh; \
		./k8s/helm/scripts/dev/1.load_infra_images.sh; \
	else \
		echo -e "$(RED)❌ 1.load_infra_images.sh not found$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)✅ 인프라 이미지 로드 완료$(NC)"

check-images: ## 로컬 레지스트리 이미지 확인
	@echo -e "$(YELLOW)🔍 로컬 레지스트리 이미지 확인...$(NC)"
	@echo ""
	@echo "Registry catalog:"
	@curl -s http://localhost:5001/v2/_catalog | jq -r '.repositories[]' || echo "No images found"
	@echo ""
	@echo "서비스 이미지 확인:"
	@for svc in auth-service user-service board-service chat-service noti-service storage-service video-service; do \
		echo -n "  $$svc: "; \
		if curl -sf "http://localhost:5001/v2/$$svc/tags/list" > /dev/null 2>&1; then \
			echo -e "$(GREEN)✅$(NC)"; \
		else \
			echo -e "$(RED)❌$(NC)"; \
		fi; \
	done

# ============================================
# 수정된 all 타겟
# ============================================

all: setup-local ## 전체 프로세스 (Registry + 이미지 + Bootstrap + 배포)
	@echo ""
	@echo -e "$(GREEN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo -e "$(GREEN)✅ 전체 배포 완료!$(NC)"
	@echo -e "$(GREEN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo ""
	@echo "ArgoCD UI: https://localhost:8079"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
	@echo ""
	@echo "로컬 Registry: http://localhost:5001"
	@echo "이미지 확인: make check-images"
	@echo ""
	@echo "다음 명령어로 포트 포워딩:"
	@echo "  make ui"

# ============================================
# 기존 cluster-up 타겟 수정 (Registry 포함)
# ============================================

cluster-up-simple: ## Kind 클러스터만 생성 (Registry 없이)
	@echo -e "$(YELLOW)📦 Kind 클러스터 생성 중...$(NC)"
	@if kind get clusters | grep -q "$(CLUSTER_NAME)"; then \
		echo -e "$(YELLOW)⚠️  클러스터가 이미 존재합니다: $(CLUSTER_NAME)$(NC)"; \
		read -p "삭제하고 다시 만들까요? (y/N): " answer; \
		if [ "$$answer" = "y" ] || [ "$$answer" = "Y" ]; then \
			$(MAKE) cluster-down; \
		else \
			echo "기존 클러스터를 사용합니다."; \
			exit 0; \
		fi; \
	fi
	@if [ -f "k8s/installShell/kind-config.yaml" ]; then \
		kind create cluster --name $(CLUSTER_NAME) --config k8s/installShell/kind-config.yaml; \
	else \
		kind create cluster --name $(CLUSTER_NAME); \
	fi
	@kubectl cluster-info
	@echo -e "$(GREEN)✅ 클러스터 생성 완료$(NC)"


#!/bin/bash
# Kind 클러스터 + 로컬 레지스트리 + Istio Ambient 설정 스크립트
# - 로컬 레지스트리: Docker Hub rate limit 우회
# - Istio Ambient: Service Mesh (sidecar-less)
# - Gateway API: Kubernetes 표준 Ingress

set -e

CLUSTER_NAME="wealist"
REG_NAME="kind-registry"
REG_PORT="5001"
ISTIO_VERSION="1.24.0"
GATEWAY_API_VERSION="v1.2.0"

echo "🚀 Kind 클러스터 + Istio Ambient + Gateway API 설정"
echo "   - Istio: ${ISTIO_VERSION}"
echo "   - Gateway API: ${GATEWAY_API_VERSION}"
echo ""

# 1. 기존 클러스터 삭제 (있으면)
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "기존 클러스터 삭제 중..."
    kind delete cluster --name "$CLUSTER_NAME"
fi

# 2. 로컬 레지스트리 시작 (없으면)
if [ "$(docker inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)" != 'true' ]; then
    echo "📦 로컬 레지스트리 시작 (localhost:${REG_PORT})"
    docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --network bridge --name "${REG_NAME}" registry:2
fi

# 3. Kind 설정 파일 생성 (로컬 레지스트리 포함)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat > "${SCRIPT_DIR}/kind-config.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REG_PORT}"]
          endpoint = ["http://${REG_NAME}:5000"]
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
      - containerPort: 30080
        hostPort: 8080
        protocol: TCP
  - role: worker
  - role: worker
EOF

# 4. Kind 클러스터 생성
echo "🚀 Kind 클러스터 생성 중..."
kind create cluster --name "$CLUSTER_NAME" --config "${SCRIPT_DIR}/kind-config.yaml"

# 5. 레지스트리를 Kind 네트워크에 연결
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REG_NAME}" 2>/dev/null)" = 'null' ]; then
    echo "레지스트리를 Kind 네트워크에 연결..."
    docker network connect "kind" "${REG_NAME}"
fi

# 6. 레지스트리 ConfigMap 생성
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# 7. Gateway API CRDs 설치 (Istio Gateway API 사용을 위해 필수)
echo "⏳ Gateway API CRDs 설치 중..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml
echo "✅ Gateway API CRDs 설치 완료"

# 8. Istio Ambient 모드 설치
echo "⏳ Istio Ambient 모드 설치 중..."

# istioctl 설치 확인 및 경로 설정
ISTIOCTL=""
if command -v istioctl &> /dev/null; then
    ISTIOCTL="istioctl"
    echo "✅ istioctl 발견: $(which istioctl)"
elif [ -f "./istio-${ISTIO_VERSION}/bin/istioctl" ]; then
    ISTIOCTL="./istio-${ISTIO_VERSION}/bin/istioctl"
    echo "✅ 로컬 istioctl 사용: ${ISTIOCTL}"
elif [ -f "../istio-${ISTIO_VERSION}/bin/istioctl" ]; then
    ISTIOCTL="../istio-${ISTIO_VERSION}/bin/istioctl"
    echo "✅ 로컬 istioctl 사용: ${ISTIOCTL}"
elif [ -f "../../istio-${ISTIO_VERSION}/bin/istioctl" ]; then
    ISTIOCTL="../../istio-${ISTIO_VERSION}/bin/istioctl"
    echo "✅ 로컬 istioctl 사용: ${ISTIOCTL}"
else
    echo "⚠️  istioctl이 설치되어 있지 않습니다."
    echo "   다음 명령어로 설치하세요:"
    echo "   curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -"
    exit 1
fi

# Istio Ambient 프로필 설치
${ISTIOCTL} install --set profile=ambient --skip-confirmation

echo "⏳ Istio 컴포넌트 준비 대기 중..."
kubectl wait --namespace istio-system \
  --for=condition=ready pod \
  --selector=app=istiod \
  --timeout=120s || echo "WARNING: istiod not ready yet"

kubectl wait --namespace istio-system \
  --for=condition=ready pod \
  --selector=app=ztunnel \
  --timeout=120s || echo "WARNING: ztunnel not ready yet"

echo "✅ Istio Ambient 설치 완료"

# 9. Istio Ingress Gateway 설치 (외부 트래픽용)
# Kind에서 localhost:80 접근을 위해 hostPort 사용
echo "⏳ Istio Ingress Gateway 설치 중..."
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: istio-ingressgateway
  namespace: istio-system
  annotations:
    # Kind: ClusterIP + hostPort 방식 사용 (NodePort 불필요)
    networking.istio.io/service-type: ClusterIP
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
  infrastructure:
    annotations:
      # control-plane 노드에 스케줄링 (hostPort 80 사용)
      traffic.sidecar.istio.io/includeInboundPorts: ""
EOF

echo "⏳ Istio Gateway Pod 준비 대기 중..."
sleep 5  # Gateway 생성 후 Pod 생성까지 대기
kubectl wait --namespace istio-system \
  --for=condition=ready pod \
  --selector=gateway.networking.k8s.io/gateway-name=istio-ingressgateway \
  --timeout=120s || echo "WARNING: Istio gateway not ready yet"

# 10. Istio Gateway를 hostPort 80으로 노출 (Kind용)
# Gateway Pod가 직접 노드의 80 포트를 사용하도록 패치
echo "⚙️ Istio Gateway hostPort 80 설정 중..."
kubectl patch deployment istio-ingressgateway -n istio-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/ports",
    "value": [
      {"containerPort": 80, "hostPort": 80, "protocol": "TCP", "name": "http"},
      {"containerPort": 443, "hostPort": 443, "protocol": "TCP", "name": "https"}
    ]
  },
  {
    "op": "add",
    "path": "/spec/template/spec/nodeSelector",
    "value": {"ingress-ready": "true"}
  }
]' 2>/dev/null || echo "Gateway deployment patch skipped (may already be configured)"

# Gateway Pod 재시작 대기
echo "⏳ Gateway Pod 재시작 대기 중..."
sleep 3
kubectl wait --namespace istio-system \
  --for=condition=ready pod \
  --selector=gateway.networking.k8s.io/gateway-name=istio-ingressgateway \
  --timeout=120s || echo "WARNING: Istio gateway not ready yet"

echo ""
echo "✅ 클러스터 준비 완료!"
echo ""
echo "📦 로컬 레지스트리: localhost:${REG_PORT}"
echo "🌐 Istio Gateway: localhost (hostPort 80)"
echo ""
echo "📝 다음 단계:"
echo "   1. 네임스페이스에 Ambient 모드 활성화:"
echo "      kubectl label ns <namespace> istio.io/dataplane-mode=ambient"
echo "   2. HTTPRoute로 서비스 라우팅 설정"
echo "   3. localhost/svc/{service}/api/... 로 접근"
echo ""

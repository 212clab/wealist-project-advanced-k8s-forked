# syntax=docker/dockerfile:1.4
# Builder stage
FROM golang:1.24-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates tzdata && rm -rf /var/lib/apt/lists/*

# Set working directory to project root
WORKDIR /workspace

# Copy go workspace file
COPY go.work go.work.sum* ./

# Copy shared package
COPY packages/wealist-advanced-go-pkg/ ./packages/wealist-advanced-go-pkg/

# Copy service go.mod files first (for layer caching)
COPY services/chat-service/go.mod services/chat-service/go.sum ./services/chat-service/

# Download dependencies with cache mount
WORKDIR /workspace/services/chat-service
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy service source code
COPY services/chat-service/ ./

# Build with cache mount (dramatically speeds up incremental builds)
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o chat-api ./cmd/api

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata wget

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Set working directory
WORKDIR /home/appuser

# Copy binary from builder
COPY --from=builder --chown=appuser:appuser /workspace/services/chat-service/chat-api .

# Copy configuration files
COPY --from=builder --chown=appuser:appuser /workspace/services/chat-service/configs ./configs

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8001/health || exit 1

# Run the application
CMD ["./chat-api"]

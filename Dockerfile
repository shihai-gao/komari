# ==========================================
# 阶段 1：构建前端
# ==========================================
FROM node:20-alpine AS web-builder

WORKDIR /web
RUN apk add --no-cache git

RUN git clone --depth 1 -b radix https://github.com/komari-monitor/komari-web.git .

RUN npm install
RUN npm run build


# ==========================================
# 阶段 2：编译 Go（带调试信息，方便看日志）
# ==========================================
FROM golang:1.24-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git

COPY . .

# 关键：前端放到正确位置
RUN mkdir -p /app/public/defaultTheme
COPY --from=web-builder /web/dist /app/public/defaultTheme/dist

# 验证前端文件存在
RUN ls -la /app/public/defaultTheme/dist/ && test -f /app/public/defaultTheme/dist/index.html

# 编译（保留调试符号，方便看 panic 堆栈）
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o komari main.go


# ==========================================
# 阶段 3：运行环境
# ==========================================
FROM alpine:3.21

WORKDIR /app

RUN apk add --no-cache ca-certificates curl tzdata

# 下载 cloudflared
RUN set -eux; \
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
    -o /usr/local/bin/cloudflared; \
    chmod +x /usr/local/bin/cloudflared

COPY --from=builder /app/komari /app/komari
RUN chmod +x /app/komari

# 预先创建所有必要目录
RUN mkdir -p /app/data && chmod 777 /app/data

# 环境变量
ENV GIN_MODE=release
ENV KOMARI_DB_TYPE=sqlite
ENV KOMARI_DB_FILE=/app/data/komari.db
ENV KOMARI_LISTEN=0.0.0.0:25774
# 禁用 cloudflared 自动启动（避免未知问题）
ENV KOMARI_CLOUDFLARED_TOKEN=""

EXPOSE 25774

VOLUME ["/app/data"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:25774/ping || exit 1

CMD ["/app/komari", "server"]

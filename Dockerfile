# ==========================================
# 阶段 1：构建前端
# ==========================================
FROM node:20-alpine AS web-builder

WORKDIR /web
RUN apk add --no-cache git

# 克隆前端仓库（dev_runsite 分支也用这个前端）
RUN git clone --depth 1 -b radix https://github.com/komari-monitor/komari-web.git .

RUN npm install
RUN npm run build
# 产物在 /web/dist


# ==========================================
# 阶段 2：编译 Go
# ==========================================
FROM golang:1.24-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git

# 复制后端源码
COPY . .

# 关键：把前端 dist 放到 public/defaultTheme/dist
# 这样 //go:embed defaultTheme 才能找到文件
COPY --from=web-builder /web/dist /app/public/defaultTheme/dist

# 编译（dev_runsite 用 CGO_ENABLED=0，sqlite 用纯 Go 实现）
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o komari main.go


# ==========================================
# 阶段 3：运行环境（保持原分支特色：带 cloudflared）
# ==========================================
FROM alpine:3.21

WORKDIR /app

RUN apk add --no-cache ca-certificates curl tzdata

# 下载 cloudflared（dev_runsite 分支原有功能）
RUN set -eux; \
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
    -o /usr/local/bin/cloudflared; \
    chmod +x /usr/local/bin/cloudflared

# 复制编译好的二进制
COPY --from=builder /app/komari /app/komari
RUN chmod +x /app/komari

ENV GIN_MODE=release
ENV KOMARI_DB_TYPE=sqlite
ENV KOMARI_DB_FILE=/app/data/komari.db
ENV KOMARI_LISTEN=0.0.0.0:25774

EXPOSE 25774

VOLUME ["/app/data"]

CMD ["/app/komari", "server"]

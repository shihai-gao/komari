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
# 阶段 2：编译 Go
# ==========================================
FROM golang:1.24-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git

# 复制后端源码
COPY . .

# 关键：把前端 dist 放到 public/defaultTheme/dist
# 同时确保 defaultTheme 目录本身有内容（go:embed 需要非空目录）
RUN mkdir -p /app/public/defaultTheme
COPY --from=web-builder /web/dist /app/public/defaultTheme/dist

# 编译
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

# 从编译阶段复制二进制
COPY --from=builder /app/komari /app/komari
RUN chmod +x /app/komari

# 关键：预先创建 data 目录并设置权限
RUN mkdir -p /app/data && chmod 755 /app/data

ENV GIN_MODE=release
ENV KOMARI_DB_TYPE=sqlite
ENV KOMARI_DB_FILE=/app/data/komari.db
ENV KOMARI_LISTEN=0.0.0.0:25774

EXPOSE 25774

# 数据持久化
VOLUME ["/app/data"]

CMD ["/app/komari", "server"]

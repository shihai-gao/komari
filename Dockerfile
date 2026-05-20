# 阶段1：编译 Go 程序（构建器）
FROM golang:1.23-alpine AS builder

WORKDIR /app

# 安装 git
RUN apk add --no-cache git

# 复制源码
COPY . .

# 编译
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o komari main.go

# 阶段2：运行镜像（最终）
FROM alpine:3.21

WORKDIR /app

# 安装依赖
RUN apk add --no-cache ca-certificates curl tzdata

# 下载 cloudflared
RUN set -eux; \
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -o /usr/local/bin/cloudflared; \
    chmod +x /usr/local/bin/cloudflared

# 从编译阶段复制二进制
COPY --from=builder /app/komari /app/komari

RUN chmod +x /app/komari

ENV GIN_MODE=release
ENV KOMARI_DB_TYPE=sqlite
ENV KOMARI_DB_FILE=/app/data/komari.db
ENV KOMARI_LISTEN=0.0.0.0:25774

EXPOSE 25774

CMD ["/app/komari", "server"]

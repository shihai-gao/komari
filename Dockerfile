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
# 阶段 2：编译 Go 后端
# ==========================================
FROM golang:1.24-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git

COPY . .

# 放入前端构建产物
RUN mkdir -p /app/public/defaultTheme
COPY --from=web-builder /web/dist /app/public/defaultTheme/dist

# 验证静态资源
RUN ls -la /app/public/defaultTheme/dist/ && test -f /app/public/defaultTheme/dist/index.html

# 编译二进制
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/komari main.go


# ==========================================
# 阶段 3：运行环境
# ==========================================
FROM alpine:3.21

WORKDIR /app

# 安装运行时依赖
RUN apk add --no-cache ca-certificates tzdata curl

# 复制后端二进制
COPY --from=builder /app/komari /app/komari

# 复制静态资源（这一步很关键）
COPY --from=builder /app/public /app/public

# 创建数据目录
RUN chmod +x /app/komari && \
    mkdir -p /app/data && \
    chmod 777 /app/data

# 运行环境变量
ENV GIN_MODE=release
ENV KOMARI_DB_TYPE=sqlite
ENV KOMARI_DB_FILE=/app/data/komari.db
ENV KOMARI_LISTEN=0.0.0.0:25774
ENV PORT=25774

EXPOSE 25774

# 注意：先不要加 HEALTHCHECK，避免干扰排查
CMD ["/bin/sh", "-c", "echo '== app files ==' && ls -la /app && echo '== public ==' && ls -la /app/public && echo '== data ==' && ls -la /app/data && echo '== starting komari ==' && exec /app/komari"]

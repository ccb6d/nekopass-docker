# syntax=docker/dockerfile:1

FROM node:22-bookworm AS web-builder
WORKDIR /src
COPY web/package.json web/package-lock.json ./web/
RUN npm ci --prefix web
COPY web ./web
RUN npm run build --prefix web

FROM golang:1.26-bookworm AS go-builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=web-builder /src/web/dist ./web/dist
RUN CGO_ENABLED=0 go build -trimpath \
    -ldflags="-X github.com/nekopass/nekopass/internal/release.Version=v0.19.0-docker" \
    -o /out/nekopass ./cmd/nekopass

FROM debian:bookworm-slim AS runtime
ARG APP_UID=10001
ARG APP_GID=10001
RUN groupadd --gid ${APP_GID} nekopass \
    && useradd --uid ${APP_UID} --gid ${APP_GID} --create-home --home-dir /nonexistent --shell /usr/sbin/nologin nekopass \
    && apt-get update \
    && apt-get install --no-install-recommends --yes ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && install -d -o nekopass -g nekopass /opt/nekopass/web /var/lib/nekopass
COPY --from=go-builder /out/nekopass /opt/nekopass/bin/nekopass
COPY --from=web-builder /src/web/dist /opt/nekopass/web
COPY deploy/docker/entrypoint-panel.sh /usr/local/bin/entrypoint-panel.sh
RUN chmod 0755 /usr/local/bin/entrypoint-panel.sh \
    && chown -R nekopass:nekopass /opt/nekopass /var/lib/nekopass
USER nekopass
WORKDIR /opt/nekopass
EXPOSE 8080 9443
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=5 \
    CMD curl --fail --silent http://127.0.0.1:8080/healthz >/dev/null || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint-panel.sh"]

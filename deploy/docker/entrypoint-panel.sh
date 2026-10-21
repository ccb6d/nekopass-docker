#!/bin/sh
set -eu

/opt/nekopass/bin/nekopass -mode migrate
exec /opt/nekopass/bin/nekopass -web /opt/nekopass/web -http :8080 -grpc :9443

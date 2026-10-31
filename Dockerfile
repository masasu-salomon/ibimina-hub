# Two stages: the first one installs dependencies, the second one is what
# actually ships. Anything npm leaves behind in stage 1 (cache, temp files)
# never makes it into the final image.

# Exact tag instead of node:20-alpine so every build uses the same Node and
# Alpine versions. A floating tag can change under us between two CI runs.
FROM node:20.20.2-alpine3.23 AS deps

# All the following commands run inside /app (created if missing).
WORKDIR /app

# Only the manifests are copied here, not the code. Docker caches this layer
# and the npm ci below, so editing something in src/ doesn't trigger a full
# reinstall - it only reruns when package.json or the lockfile change.
COPY package.json package-lock.json ./

# npm ci installs exactly what's in the lockfile.
# --omit=dev leaves out jest, supertest and eslint (not needed at runtime).
# --ignore-scripts stops packages from running install scripts during the
# build. None of our deps need one, so this is just less attack surface.
# Cleaning the cache afterwards keeps the layer smaller.
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force


# Runtime stage. Same pinned base so the node_modules from stage 1 match.
FROM node:20.20.2-alpine3.23

# OCI labels, shown by `docker inspect` and on registries.
LABEL org.opencontainers.image.title="ibimina-hub" \
      org.opencontainers.image.description="REST API for community savings groups (ibimina) in Rwanda" \
      org.opencontainers.image.source="https://github.com/masasu-salomon/ibimina-hub" \
      org.opencontainers.image.licenses="MIT"

# NODE_ENV=production makes Express skip some dev-only behaviour (e.g. stack
# traces in error pages). PORT is read by src/config and can be overridden
# with -e PORT=... or from docker-compose.
ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

# Bring over only the installed packages from the deps stage, then the app.
# package.json goes in before src because it changes less often.
#
# No --chown on purpose: these files stay owned by root, and the node user
# can read them but not change them. If someone got code execution through
# the app they still couldn't modify the source or node_modules. With
# --chown=node:node the process would own (and be able to rewrite) its code.
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# Switch to the unprivileged "node" user that ships with the official image
# (uid 1000). Everything after this, including the app, runs as node, not root.
USER node

# Documents the port the API listens on. It doesn't publish anything by
# itself, that's done with -p or the ports: section in compose.
EXPOSE 3000

# Docker calls /health every 30s and marks the container unhealthy after 3
# failures. start-period gives the server a few seconds to boot first.
# wget is already in alpine (busybox) so we don't have to install curl.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Exec form (JSON array) so node runs as PID 1 directly instead of under
# /bin/sh. That way it receives SIGTERM from `docker stop` and shuts down
# straight away rather than getting killed after the 10s timeout.
CMD ["node", "src/server.js"]

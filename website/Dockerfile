# WuselWall website: Astro, prerendered pages served by the Node standalone adapter.
FROM node:22-alpine@sha256:0a7108bf6c7bf5de370ffb1a3ed6be93d405b43ff159f681a8d18c0e2bc2e402 AS build
WORKDIR /site
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# LEGAL_STRICT=1 (the deploy script's default) fails the build while the Impressum
# still holds placeholders, so an unfilled legal page can never go live by accident.
ARG LEGAL_STRICT=0
ENV LEGAL_STRICT=$LEGAL_STRICT
RUN npm run build

FROM node:22-alpine@sha256:0a7108bf6c7bf5de370ffb1a3ed6be93d405b43ff159f681a8d18c0e2bc2e402
WORKDIR /site
ENV NODE_ENV=production HOST=0.0.0.0 PORT=4321
COPY --from=build /site/dist ./dist
COPY --from=build /site/package.json ./
COPY --from=build /site/node_modules ./node_modules
USER node
EXPOSE 4321
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://127.0.0.1:4321/healthz/ >/dev/null || exit 1
CMD ["node", "dist/server/entry.mjs"]

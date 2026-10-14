# WuselWall website: Astro, prerendered pages served by the Node standalone adapter.
FROM node:25-alpine@sha256:bdf2cca6fe3dabd014ea60163eca3f0f7015fbd5c7ee1b0e9ccb4ced6eb02ef4 AS build
WORKDIR /site
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# LEGAL_STRICT=1 (the deploy script's default) fails the build while the Impressum
# still holds placeholders, so an unfilled legal page can never go live by accident.
ARG LEGAL_STRICT=0
ENV LEGAL_STRICT=$LEGAL_STRICT
RUN npm run build

FROM node:25-alpine@sha256:bdf2cca6fe3dabd014ea60163eca3f0f7015fbd5c7ee1b0e9ccb4ced6eb02ef4
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

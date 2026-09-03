# JARVIS server for hosting (Railway, Render, Fly.io, any Docker host)
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY server.mjs ./
COPY public ./public
COPY notes ./notes
ENV PORT=3131 HOST=0.0.0.0 NODE_ENV=production
EXPOSE 3131
CMD ["node", "server.mjs"]

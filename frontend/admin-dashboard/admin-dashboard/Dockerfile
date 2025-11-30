FROM node:20-alpine

# Set working directory
WORKDIR /app

# Install pnpm
RUN npm install -g pnpm


# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install

# Copy source
COPY . .

# Copy production environment file
COPY .env.production .env.production

# Build app with production environment
RUN pnpm run build

RUN npm install -g serve

# Create non-root user and assign ownership
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 && \
    chown -R nextjs:nodejs /app
USER nextjs

# Expose app port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://0.0.0.0:3000/ || exit 1

# Start server with SPA mode (serves files directly, falls back to index.html)
CMD ["serve", "-s", "dist", "-l", "tcp://0.0.0.0:3000"]

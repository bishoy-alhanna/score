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

# Build app
RUN pnpm run build

# Create /admin directory structure for serving
# Move dist contents to dist/admin so serve can serve from root
RUN mkdir -p /app/dist_temp && \
    mv /app/dist /app/dist_temp/admin && \
    mv /app/dist_temp /app/dist

# Copy serve configuration
COPY serve.json /app/

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
    CMD wget --no-verbose --tries=1 --spider http://0.0.0.0:3000/admin/ || exit 1

# Start server with configuration file
CMD ["serve", "-c", "serve.json", "-l", "tcp://0.0.0.0:3000"]

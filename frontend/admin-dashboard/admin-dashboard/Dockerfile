FROM node:20-alpine

# Manually configure PNPM_HOME and PATH
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"

# Set working directory
WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Create PNPM_HOME directory to avoid issues
RUN mkdir -p "${PNPM_HOME}"

# Install serve globally (no need for pnpm setup)
RUN pnpm add -g serve

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source
COPY . .

# Build app
RUN pnpm run build

# Create non-root user and assign ownership
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 && \
    chown -R nextjs:nodejs /app
USER nextjs

# Expose app port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000 || exit 1

# Start server
CMD ["serve", "-s", "dist", "-l", "3000"]

# TweetStream Frontend Dockerfile
# Uses Python HTTP server for serving static files in Kubernetes

FROM python:3.11-alpine

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -s /bin/sh -D appuser

# Copy frontend files
COPY index.html .

# Create health check endpoint
RUN echo "healthy" > health

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port 8080 (non-privileged)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# Start Python HTTP server
CMD ["python3", "-m", "http.server", "8080"] 
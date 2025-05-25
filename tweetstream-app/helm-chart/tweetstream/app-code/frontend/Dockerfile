# Frontend Dockerfile using NGINX
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy static files
COPY index.html /usr/share/nginx/html/

# Create a simple health check page
RUN echo '{"status":"healthy","service":"tweetstream-frontend"}' > /usr/share/nginx/html/health.json

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/health.json || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"] 
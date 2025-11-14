FROM nginx:alpine

# Copy production config with SSL
COPY nginx.conf /etc/nginx/nginx.conf

# Copy cache clearing page
COPY clear-cache.html /usr/share/nginx/html/clear-cache.html

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
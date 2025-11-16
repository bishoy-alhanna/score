FROM nginx:alpine

# Copy production config with SSL
COPY nginx.conf /etc/nginx/nginx.conf

# Copy HTML utilities
COPY clear-cache.html /usr/share/nginx/html/clear-cache.html
COPY debug.html /usr/share/nginx/html/debug.html
COPY cache-buster.html /usr/share/nginx/html/cache-buster.html
COPY js-test.html /usr/share/nginx/html/js-test.html

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
FROM nginx:alpine

# Copy pre-built Flutter web app
COPY build/web /usr/share/nginx/html

# Cloud Run uses PORT env variable
ENV PORT=8080
RUN sed -i 's/listen\s*80;/listen 8080;/g' /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]

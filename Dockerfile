FROM php:8.5-fpm-alpine3.23

# Set shell with pipefail for Alpine
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Install packages and remove default server definition
RUN apk add --no-cache \
    curl \
    nginx \
    unzip \
    wget \
    jq \
    ghostscript \
    poppler-utils \
    imagemagick \
    netcat-openbsd \
    supervisor \
    icu-libs \
    libpq \
    zlib \
    libpng \
    && apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    icu-dev \
    postgresql-dev \
    zlib-dev \
    libpng-dev \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql gd intl \
    && pecl install apcu && docker-php-ext-enable apcu \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

# JRE necessary for pdftk-java
RUN apk add --no-cache openjdk11-jre-headless bash

# Download the standalone pdftk-java JAR file
RUN wget https://gitlab.com/pdftk-java/pdftk/-/jobs/924565145/artifacts/raw/build/libs/pdftk-all.jar \
    -O /usr/local/bin/pdftk.jar

# Shell script wrapper to run pdftk globally
RUN echo '#!/bin/sh' > /usr/local/bin/pdftk && \
    echo 'exec java -jar /usr/local/bin/pdftk.jar "$@"' >> /usr/local/bin/pdftk && \
    chmod +x /usr/local/bin/pdftk

COPY config/root /
COPY config/php.ini  /usr/local/etc/php/conf.d/php.ini
COPY config/www.conf /usr/local/etc/php-fpm.d/www.conf

WORKDIR /var/www/html

RUN curl -Z --parallel-immediate -fSL \
    -o omeka-s.zip https://github.com/omeka/omeka-s/releases/download/v4.2.1/omeka-s-4.2.1.zip && \
    unzip -q omeka-s.zip && \
    mv omeka-s/* . && \
    rm omeka-s.zip

RUN curl -Z --parallel-immediate -fSL \
      -o Common.zip     https://github.com/Daniel-KM/Omeka-S-module-Common/releases/download/3.4.88/Common-3.4.88.zip \
      -o BulkImport.zip https://github.com/Daniel-KM/Omeka-S-module-Bulkimport/releases/download/3.4.65/BulkImport-3.4.65.zip \
      -o Log.zip        https://github.com/Daniel-KM/Omeka-S-module-Log/releases/download/3.4.39/Log-3.4.39.zip \
      -o Mapper.zip     https://github.com/Daniel-KM/Omeka-S-module-Mapper/releases/download/3.4.7/Mapper-3.4.7.zip \
      -o CSSEditor.zip  https://github.com/omeka-s-modules/CSSEditor/releases/download/v1.3.1/CSSEditor-1.3.1.zip \
      -o PageBlocks.zip https://github.com/ivyrze/omeka-s-module-pageblocks/releases/download/1.3/PageBlocks.zip \
      -o IiifServer.zip https://github.com/Daniel-KM/Omeka-S-module-IiifServer/releases/download/3.6.32/IiifServer-3.6.32.zip \
      -o Menu.zip       https://github.com/Daniel-KM/Omeka-s-module-Menu/releases/download/3.4.15/Menu-3.4.15.zip \
      -o Mirador.zip    https://github.com/Daniel-KM/Omeka-s-module-Mirador/releases/download/3.4.17/Mirador-3.4.17.zip \
      -o Search.zip     https://github.com/biblibre/omeka-s-module-Search/releases/download/v0.22.0/Search-v0.22.0.zip \
      -o Solr.zip       https://github.com/biblibre/omeka-s-module-Solr/releases/download/v0.25.0/Solr-v0.25.0.zip \
    && for f in *.zip; do \
         name="${f%.zip}"; \
         unzip -q "$f" -d "modules"; \
         rm "$f"; \
       done

RUN chown -R nobody:nobody . /run /var/lib/nginx /var/log/nginx

# Switch to non-privileged user
USER nobody

# Install Composer dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

EXPOSE 8080

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --interval=30s --timeout=5s --retries=10 CMD curl -fsS http://127.0.0.1:8080/ >/dev/null || exit 1

ENV nginx_root_directory=/var/www/html \

# One parameterised PHP-FPM image for every legacy/modern version (Debian 13 + Sury packages).
#   docker compose -f images/php/compose.yml build php72
ARG COMPOSER_TAG=2
FROM composer:${COMPOSER_TAG} AS composer

FROM debian:trixie-slim
ARG PHP_VERSION=7.2
ARG WITH_WKHTMLTOPDF=false

WORKDIR /var/www/html
ENV DEBIAN_FRONTEND=noninteractive \
    PHP_VERSION=${PHP_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl gnupg2 ca-certificates apt-transport-https lsb-release git unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ondrej Sury's PHP repository (provides 5.6 ... 8.x for Debian)
RUN curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ trixie main" \
      > /etc/apt/sources.list.d/php.list

RUN apt-get update && apt-get install -y --no-install-recommends \
      php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-mysql php${PHP_VERSION}-pgsql \
      php${PHP_VERSION}-mbstring php${PHP_VERSION}-zip php${PHP_VERSION}-gd php${PHP_VERSION}-xml \
      php${PHP_VERSION}-curl php${PHP_VERSION}-bcmath \
    # OPcache became part of PHP core in 8.5 (no php8.5-opcache package); older versions still need it
    && if dpkg --compare-versions "${PHP_VERSION}" lt 8.5; then \
         apt-get install -y --no-install-recommends php${PHP_VERSION}-opcache; \
       fi \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Optional: wkhtmltopdf (patched Qt) + fonts, only when WITH_WKHTMLTOPDF=true
RUN if [ "$WITH_WKHTMLTOPDF" = "true" ]; then \
      apt-get update && \
      curl -fsSL -o /tmp/wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb && \
      apt-get install -y /tmp/wkhtmltox.deb fontconfig xfonts-75dpi xfonts-base libjpeg62-turbo && \
      rm -f /tmp/wkhtmltox.deb && apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

COPY --from=composer /usr/bin/composer /usr/bin/composer

# hardening: disable session upload progress (PHP2Shell vector)
RUN echo "session.upload_progress.enabled = Off" >> /etc/php/${PHP_VERSION}/fpm/php.ini \
 && echo "session.upload_progress.enabled = Off" >> /etc/php/${PHP_VERSION}/cli/php.ini

RUN groupadd -g 1000 www && useradd -u 1000 -ms /bin/bash -g www www

# PHP-FPM on a unix socket shared with nginx through a tmpfs volume, running as "www"
RUN mkdir -p /var/run/php && chown www:www /var/run/php \
 && P=/etc/php/${PHP_VERSION}/fpm \
 && sed -i "s|listen = /run/php/php${PHP_VERSION}-fpm.sock|listen = /var/run/php/php${PHP_VERSION}-fpm.sock|" $P/pool.d/www.conf \
 && sed -i 's/^user = www-data/user = www/; s/^group = www-data/group = www/' $P/pool.d/www.conf \
 && sed -i 's/^;listen.owner = www-data/listen.owner = www/; s/^;listen.group = www-data/listen.group = www/; s/^;listen.mode = 0660/listen.mode = 0666/' $P/pool.d/www.conf \
 && sed -i "s|^error_log = .*|error_log = /proc/self/fd/2|; s/^;daemonize = yes/daemonize = no/" $P/php-fpm.conf

RUN mkdir -p /var/www/html/vendor && chown -R www:www /var/www/html

COPY start.sh /usr/local/bin/php-fpm-start
RUN sed -i 's/\r$//' /usr/local/bin/php-fpm-start && chmod +x /usr/local/bin/php-fpm-start

CMD ["/usr/local/bin/php-fpm-start"]

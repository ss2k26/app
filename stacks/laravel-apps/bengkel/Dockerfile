# 1. Start from the highly secure, actively maintained Debian 13 core image
FROM debian:trixie-slim

# Set working directory for Laravel 7
WORKDIR /var/webapps/laravel

# Prevent interactive prompts during apt package configuration
ENV DEBIAN_FRONTEND=noninteractive

# 2. Update base OS repositories and fetch crucial system layer tools
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    zip \
    unzip \
    git \
    vim \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Securely hook in Ondřej Surý's Debian DPA using modern keyrings targeting trixie
RUN curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ trixie main" \
    > /etc/apt/sources.list.d/php.list

# 4. Install fully patched PHP 7.2 core components and Laravel extensions directly via apt
RUN apt-get update && apt-get install -y \
    php7.2-fpm \
    php7.2-cli \
    php7.2-mysql \
    php7.2-mbstring \
    php7.2-zip \
    php7.2-gd \
    php7.2-xml \
    php7.2-curl \
    php7.2-bcmath \
    php7.2-opcache \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 5. Bring in an older LTS version of Composer compatible with PHP 7.2
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

# 6. Apply critical infrastructure mitigation to disable PHP2Shell attack vectors
RUN echo "session.upload_progress.enabled = Off" >> /etc/php/7.2/fpm/php.ini && \
    echo "session.upload_progress.enabled = Off" >> /etc/php/7.2/cli/php.ini

# 7. Configure PHP-FPM to listen properly on a clean network port instead of a socket file
RUN sed -i 's|listen = /run/php/php7.2-fpm.sock|listen = 0.0.0.0:9000|' /etc/php/7.2/fpm/pool.d/www.conf

# 8. Setup standard non-root application system user permissions for Laravel
RUN groupadd -g 1000 www && useradd -u 1000 -ms /bin/bash -g www www
COPY --chown=www:www . /var/webapps/laravel
USER www

# Expose port 9000 to standard proxy setups (like Nginx)
EXPOSE 9000

# Execute the packaged PHP-FPM 7.2 process directly in the foreground
CMD ["/usr/sbin/php-fpm7.2", "-F"]

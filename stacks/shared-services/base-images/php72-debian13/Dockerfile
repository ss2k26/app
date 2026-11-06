# 1. Start from the secure, actively maintained Debian 13 core image
FROM debian:trixie-slim

# Set universal root path configuration framework
WORKDIR /var/www/html

# Prevent interactive prompts during apt package configuration
ENV DEBIAN_FRONTEND=noninteractive

# 2. Update base OS repositories and fetch ONLY crucial system layer tools
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    ca-certificates \
    apt-transport-https \
    lsb-release \
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

# 5. 🚀 Fetch and Side-Load wkhtmltopdf with patched QT engine
# Downloads the verified upstream package and installs dependencies (X11 rendering & font structures)
RUN apt-get update && \
    curl -fsSL -o /tmp/wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb && \
    apt-get install -y /tmp/wkhtmltox.deb fontconfig xfonts-75dpi xfonts-base libjpeg62-turbo && \
    rm -rf /tmp/wkhtmltox.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 6. Bring in an older LTS version of Composer compatible with PHP 7.2
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

# 7. Apply critical infrastructure mitigation to disable PHP2Shell attack vectors
RUN echo "session.upload_progress.enabled = Off" >> /etc/php/7.2/fpm/php.ini && \
    echo "session.upload_progress.enabled = Off" >> /etc/php/7.2/cli/php.ini

# Setup standard system user mapping permissions
RUN groupadd -g 1000 www && useradd -u 1000 -ms /bin/bash -g www www

# 8. Reconfigured: Switch PHP-FPM from TCP to Shared Unix Socket with proper security flags
RUN mkdir -p /var/run/php && chown www:www /var/run/php && \
    sed -i 's|listen = /run/php/php7.2-fpm.sock|listen = /var/run/php/php7.2-fpm.sock|' /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i 's/;listen.owner = www-data/listen.owner = www/' /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i 's/;listen.group = www-data/listen.group = www/' /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i 's/;listen.mode = 0660/listen.mode = 0666/' /etc/php/7.2/fpm/pool.d/www.conf

# Execute the packaged PHP-FPM 7.2 process directly in the foreground
CMD ["/usr/sbin/php-fpm7.2", "-F"]

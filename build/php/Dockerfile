FROM php:7.4-fpm-alpine

#add required packages
RUN apk --update add --no-cache \
    bash \
    libjpeg libjpeg-turbo-utils libjpeg-turbo-dev libwebp-dev zlib-dev libxpm-dev libpng-dev freetype-dev \
    libxslt-dev \
    gettext-dev \
    icu-dev \
    'php7-common>=7' \
    php7-bcmath \
    php7-mcrypt \
    php7-xml \
    php7-iconv \
    php7-redis \
    php7-xsl \
    php7-zip \
    php7-pdo_mysql \
    php7-soap \
    php7-pecl-redis \
    php7-opcache \
    php7-intl \
    php7-sockets \
    libzip-dev \
    zip \
    unzip \
    nano \
    curl \
    git \
    wget \
    openssh \
    composer \
    rsync \
    patch \
    nodejs \
    npm \
    libsodium-dev \
    sudo

RUN apk upgrade \
    && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
    && docker-php-ext-configure zip \
    && docker-php-ext-configure intl

RUN docker-php-ext-install -j$(nproc) \
	gd \
	soap \
	bcmath \
	xsl \
	zip \
	intl \
	pdo_mysql \
	mysqli \
	opcache \
	sockets \
	> /dev/null

#
# PHP Configuration
#
ENV PHP_INI=/usr/local/etc/php/php.ini
RUN cp /etc/php7/php.ini $PHP_INI
RUN \
    sed 's,;always_populate_raw_post_data,always_populate_raw_post_data,g' -i $PHP_INI && \
    sed 's,memory_limit = 128M,memory_limit = 3G,g' -i $PHP_INI && \
    sed 's,;sendmail_path =,sendmail_path ="/usr/sbin/sendmail -S vendor-mailhog:1025",g' -i $PHP_INI && \
    sed 's,;max_input_vars = 1000,max_input_vars = 10000,g' -i $PHP_INI && \
    sed 's,;session.save_path = "/tmp",session.save_path = "/tmp",g' -i $PHP_INI && \
    sed 's,;zlib.output_compression = Off, zlib.output_compression = On,g' -i $PHP_INI

RUN \
	echo "alias magento='magento --no-ansi'" >> ~/.bashrc && \
    echo "alias ll='ls -alh'" >> ~/.bashrc && \
    echo "alias dir='ls -alh'" >> ~/.bashrc && \
    echo "alias pico='nano -c'" >> ~/.bashrc;

#
#  Magento 2.4.3 configuration
#
ENV M_VER=2.4.3
ENV PHP_INI=/usr/local/etc/php/php.ini
# install Magento 2
COPY auth.json /root/.composer/auth.json
RUN composer create-project --repository=https://repo.magento.com magento/project-community-edition=$M_VER /var/www/magento2 --no-install
RUN cd /var/www/magento2 && \
	composer require --dev --no-update mage2tv/magento-cache-clean
RUN cd /var/www/magento2 && composer -v install
RUN cd /var/www/magento2 && composer -v install
RUN mkdir /var/www/magento2/default-configs
# update file permissions
RUN	chmod u+x /var/www/magento2/bin/magento
RUN find /var/www/magento2 -not -user www-data -exec chown www-data. {} \+
COPY auth.json /var/www/magento2/auth.json
ENV PATH=$PATH:/var/www/bin:/var/www/html/bin:/var/www/magento2/bin
#install node_modules for grunt
COPY package.json /var/www/magento2/package.json
RUN cd /var/www/magento2 && npm install -g grunt-cli && npm -qyf install
RUN echo "alias grunt='sudo -u www-data grunt '" >> ~/.bashrc
#update permissions5
RUN	chmod u+x /var/www/magento2/bin/magento
RUN find /var/www/magento2 -not -user www-data -exec chown www-data. {} \+
RUN \
    sed 's,variables_order = "GPCS",variables_order = "EGPCS",g' -i $PHP_INI

CMD ["php-fpm"]

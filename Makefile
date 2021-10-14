# HELP
# This will output the help for each task
## thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
#.PHONY: help
#
help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
#
#.DEFAULT_GOAL := help
#
## DOCKER TASKS

#Variables
DIR= ${CURDIR}

up: ## start m2
	COMPOSE_HTTP_TIMEOUT=600 docker-compose up -d --remove-orphans
	make permissions
	docker-compose exec php-m2-local /bin/bash -c "composer install"
	#added second composer install to apply patches (cweagans/composer-patches needed to apply)
	@echo "applying custom patches"
	docker-compose exec php-m2-local /bin/bash -c "composer install"
	docker-compose exec php-m2-local /bin/bash -c "composer dump-autoload"
	docker-compose exec php-m2-local /bin/bash -c "magento deploy:mode:set developer"
	docker-compose exec php-m2-local /bin/bash -c "magento setup:di:compile"
	docker-compose exec php-m2-local /bin/bash -c "magento setup:upgrade"
	docker-compose exec php-m2-local /bin/bash -c "magento app:config:import"
	docker-compose exec php-m2-local /bin/bash -c "magento config:set catalog/search/engine elasticsearch7"
	docker-compose exec php-m2-local /bin/bash -c "magento config:set catalog/search/elasticsearch7_server_hostname elasticsearch-m2"
	docker-compose exec php-m2-local /bin/bash -c "magento config:set catalog/search/elasticsearch7_server_port 9200"
	docker-compose exec php-m2-local /bin/bash -c "magento setup:upgrade"
	docker-compose exec php-m2-local /bin/bash -c "magento indexer:reindex"
	docker-compose exec php-m2-local /bin/bash -c "magento admin:user:create --admin-user=\"admin\" --admin-password=\"newpassword1\" --admin-email=\"example@example.com\" --admin-firstname=\"Admin\" --admin-lastname=\"Admin\""
	make permissions-all

provision-containers: ## Lets build this
	#build required containers
	docker pull php:7.4-fpm-alpine
	docker pull webdevops/apache-dev:alpine
	docker pull mysql:8
	docker pull elasticsearch:7.14.1
	##build php-m2 without volumes
	docker build -t divanti/php-m2:v1 ./build/php/
	##build and bring up container as specified in docker-compose
	docker-compose up -d mysql-m2
	docker-compose up -d elasticsearch-m2
	##start php-m2 with specific volume
	docker run -d -v ${DIR}/htdocs/default-configs:/var/www/magento2/default-configs:delegated --workdir /var/www/magento2 --name  php-m2 divanti/php-m2:v1
	#get M2 installed
	##need to connect to network for mysql access
	docker network connect magento2_default-net php-m2
	##install magento 2
	docker exec -it php-m2 bash -c " \
    	magento setup:install \
    	--admin-firstname=Admin \
    	--admin-lastname=admin \
    	--admin-email=example@example.com \
    	--admin-user=admin \
    	--admin-password=Password1 \
    	--base-url=https://magento2.local/ \
    	--base-url-secure=https://magento2.local/ \
    	--use-secure-admin=1 \
    	--use-secure=1 \
    	--db-host=mysql-m2:3306 \
    	--db-name=Magento2 \
    	--db-user=magento2 \
    	--db-password=secret \
    	--currency=GBP \
    	--timezone=Europe/London \
    	--language=en_GB \
    	--use-rewrites=1 \
    	--backend-frontname=admin \
    	--search-engine=elasticsearch7 \
      	--elasticsearch-host=elasticsearch-m2 \
    	--session-save=db"
    #create directories required
	docker exec -it php-m2 bash -c "mkdir app/code/"
    #copy out files required
    ## composer files
	docker exec -it php-m2 bash -c "cp composer.json default-configs/"
	docker exec -it php-m2 bash -c "cp composer.lock default-configs/"
	## config files
	docker exec -it php-m2 bash -c "cp app/etc/config.php default-configs/"
	docker exec -it php-m2 bash -c "cp app/etc/env.php default-configs/"
	## network files
	docker exec -it php-m2 bash -c "cp .htaccess default-configs/"
	docker exec -it php-m2 bash -c "cp pub/index.php default-configs/pub/"
	##js files
	docker exec -it php-m2 bash -c "cp package.json default-configs/"
	##configure grunt
	docker exec -it php-m2 bash -c "cp Gruntfile.js.sample Gruntfile.js"
	docker exec -it php-m2 bash -c "cp Gruntfile.js default-configs/Gruntfile.js"
	docker exec -it php-m2 bash -c "cp grunt-config.json.sample grunt-config.json"
	docker exec -it php-m2 bash -c "cp grunt-config.json default-configs/grunt-config.json"
	##Copy files to local directories
	cp -rf ./htdocs/default-configs/composer.json ./htdocs/
	cp -rf ./htdocs/default-configs/composer.lock ./htdocs/
	cp -rf ./htdocs/default-configs/config.php ./htdocs/app/etc/
	cp -rf ./htdocs/default-configs/env.php ./htdocs/app/etc/
	cp -rf ./htdocs/default-configs/.htaccess ./htdocs/
	cp -rf ./htdocs/default-configs/pub/index.php ./htdocs/pub/
	cp -rf ./htdocs/default-configs/package.json ./htdocs/
	cp -rf ./htdocs/default-configs/Gruntfile.js ./htdocs/
	cp -rf ./htdocs/default-configs/grunt-config.json ./htdocs/
	##lets create an image from the build so we don't need to do this again
	docker commit php-m2 php-m2-local
	## disconnect from network
	docker network disconnect magento2_default-net php-m2
	## stop container
	docker stop php-m2
	##done provision
	@echo "✔ Provision done, local image php-m2-local created"

export-sql:
	docker-compose exec mysql-m2 /bin/bash -c "mysqldump -proot Magento2 > dump.sql"
	docker-compose exec mysql-m2 /bin/bash -c "mv dump.sql /var/lib/mysql"
	@echo "File now located at data/db/dump.sql please remove"
	@echo "You might need sudo rm data/db/dump.sql"

prune: ## reclaim space for docker
	docker system prune -f
	docker image prune -af

down: ## stop the containers
	docker-compose down -v

destroy-hard: ## destroy the containers and make sure they're removed
	docker-compose down -v --rmi all

permissions: ## reset permissions ( for those error 500's)
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2/vendor -not -user www-data -exec chown www-data. {} \+"
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2/app -not -user www-data -exec chown www-data. {} \+"
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2/var -not -user www-data -exec chown www-data. {} \+"
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2/app -type f -exec chmod g+w {} +"
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2/var -type f -exec chmod g+w {} +"
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2/app -type d -exec chmod g+ws {} +"
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2/var -type d -exec chmod g+ws {} +"

permissions-all: ## reset permissions ( for those error 500's) EMERGENCIES ONLY
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2 -not -user www-data -exec chown www-data. {} \+"
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2 -type f -exec chmod g+w {} +"
	docker-compose exec php-m2-local /bin/bash -c "find /var/www/magento2 -type d -exec chmod g+ws {} +"

dev-templates: ## development mode for template editing
	docker-compose exec php-m2-local /bin/bash -c "magento ca:dis block_html full_page"
	docker-compose exec php-m2-local /bin/bash -c "magento ca:cl"
	make permissions

logs:
	docker-compose logs

magento-logs:
	docker-compose exec php-m2-local /bin/bash -c "tail -f -n200 var/log/*.log"

login-apache: ## login apache-m2 server
	docker-compose exec apache-m2 /bin/bash

login-php: ## login php server
	docker-compose exec php-m2-local /bin/bash

login-mysql: ## login mysql server
	docker-compose exec mysql-m2 /bin/bash

tail-logs: ##Follow the logs
	docker-compose exec php-m2-local /bin/bash -c "tail -f /var/www/magento2/var/log/*"

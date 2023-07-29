# 设置基础镜像
FROM ubuntu:22.04

# 设置环境变量
ARG timezone
ENV DEBIAN_FRONTEND noninteractive
ENV TIMEZONE=${timezone:-"Asia/Shanghai"}

# 在容器中执行命令
RUN apt update && apt install -y --no-install-recommends apt-utils supervisor tree
# RUN apt install -y --no-install-recommends libboost-all-dev autoconf build-essential gdb
RUN apt install -y cron tzdata wget curl vim wrk telnet lsof iputils-ping composer redis-server nginx-core software-properties-common libprotobuf-dev protobuf-compiler

# 安装中文字体，设置 vim 编码
RUN apt-get install -y fonts-wqy-zenhei \
    && echo "set encoding=utf-8" >> /etc/vim/vimrc

# 设置时区
RUN ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
RUN echo "${TIMEZONE}" > /etc/timezone
RUN dpkg-reconfigure --frontend noninteractive tzdata

# 安装 PHP 和其他依赖
RUN add-apt-repository -y ppa:ondrej/php
RUN apt update
RUN apt install -y php8.1 php8.1-cli php8.1-common \
    php8.1-curl php8.1-mbstring php8.1-mysql php8.1-gd \
    php8.1-xml php8.1-zip php8.1-redis php8.1-swoole php8.1-intl \
    php8.1-bcmath php8.1-imagick php8.1-soap php8.1-amqp php8.1-protobuf

# 更改 PHP 设置
RUN mkdir -p /var/log/ && touch /var/log/php_errors.log && chmod 755 /var/log/php_errors.log
RUN { \
    echo "# 设置上传文件的最大尺寸为 100MB"; \
    echo "upload_max_filesize = 100M"; \
    echo ""; \
    echo "# 设置置 POST 数据的最大尺寸为 100MB"; \
    echo "post_max_size = 100M"; \
    echo ""; \
    echo "# 设置 PHP 进程可用的内存限制为 3072MB"; \
    echo "memory_limit = 3072M"; \
    echo ""; \
    echo "# 设置默认的时区"; \
    echo "date.timezone = ${TIMEZONE}"; \
    echo ""; \
    echo "# 禁止在 HTTP 响应头中公开 PHP 版本信息"; \
    echo 'expose_php = Off'; \
    echo ""; \
    echo "# 将 PHP 错误日志输出到 `/var/log/php_errors.log` 文件中"; \
    echo 'error_log = /var/log/php_errors.log'; \
    echo ""; \
    echo "# 设置套接字操作的默认超时时间为 300 秒，当进行网络操作时，这将限制 PHP 程序等待响应的最大时间"; \
    echo "default_socket_timeout = 300"; \
    echo ""; \
    echo "# 设置 PHP 脚本的最大执行时间为 300 秒。如果脚本执行时间超过此限制，PHP 将终止该脚本的执行"; \
    echo "max_execution_time = 300"; \
    echo ""; \
    echo '# 允许 PHP 显示错误信息，生产环境中，将其关闭'; \
    echo 'display_errors = On'; \
    echo ""; \
    echo "# 设置报告所有类型的错误"; \
    echo "error_reporting = E_ALL"; \
    echo ""; \
    echo "# 关闭 swoole_shortname"; \
    echo 'swoole.use_shortname = Off'; \
} >> /etc/php/8.1/cli/php.ini

# 取消 apache2 自启动
RUN systemctl disable apache2

# 使用 supervisor 管理 nginx 进程
RUN { \
    echo ''; \
    echo '[program:nginx]'; \
    echo 'command=/usr/sbin/nginx -g "daemon off;"'; \
    echo 'autostart=true'; \
    echo 'autorestart=true'; \
    echo 'stdout_events_enabled=true'; \
    echo 'stdout_logfile=/var/log/nginx/supervisord.log'; \
    echo 'stdout_logfile_maxbytes=0'; \
    echo 'stderr_events_enabled=true'; \
    echo 'stderr_logfile=/var/log/nginx/supervisord_error.log"'; \
    echo 'stderr_logfile_maxbytes=0'; \
} >> /etc/supervisor/supervisord.conf

ENTRYPOINT ["/bin/sh", "-c", "exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf"]

# 安装 nvm nodejs
ENV NVM_DIR /root/.nvm
ENV NODE_VERSION 18.17.0
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash \
    && \. $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

CMD [""]

# 设置工作目录
WORKDIR /var/www
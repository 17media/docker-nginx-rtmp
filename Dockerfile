FROM            golang:1.6-alpine

MAINTAINER      Sam Liu "sam@17.media"

ENV             NGINX_VERSION 1.10.1

ENV             GOOGLE_APPLICATION_CREDENTIALS=/.gcloud.json
ENV             GCSFUSE_USER=gcsfuse
ENV             GCSFUSE_MOUNTPOINT=/mnt/gcs
ENV             GCSFUSE_DEBUG=
ENV             GCSFUSE_DEBUG_FUSE=
ENV             GCSFUSE_DEBUG_GCS=1
ENV             GCSFUSE_DEBUG_HTTP=
ENV             GCSFUSE_DEBUG_INVARIANTS=
ENV             GCSFUSE_DIR_MODE=
ENV             GCSFUSE_FILE_MODE=
ENV             GCSFUSE_LIMIT_BPS=
ENV             GCSFUSE_LIMIT_OPS=
ENV             GCSFUSE_CACHE_STAT_TTL=
ENV             GCSFUSE_CACHE_TYPE_TTL=


RUN             apk --no-cache add --virtual .foreman-builddeps \
                    build-base ruby-dev && \
                apk --no-cache add --virtual .foreman-rundeps \
                    ruby \
                    ruby-io-console && \
                    gem install foreman --no-rdoc --no-ri && \
                    gem cleanup && \
                apk del .foreman-builddeps

RUN             export GO15VENDOREXPERIMENT=1 && \
                apk --no-cache add --virtual .gcsfuse-builddeps \
                    git && \
                go get -u github.com/googlecloudplatform/gcsfuse && \
                ln -s bin/gcsfuse /usr/local/bin && \
                rm -rf /go/pkg/ /go/src/ && \
                apk --no-cache add --virtual .gcsfuse-rundeps \
                    fuse && \
                apk del .gcsfuse-builddeps

RUN             GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
                && CONFIG="\
                    --prefix=/etc/nginx \
                    --sbin-path=/usr/sbin/nginx \
                    --modules-path=/usr/lib/nginx/modules \
                    --conf-path=/etc/nginx/nginx.conf \
                    --error-log-path=/var/log/nginx/error.log \
                    --http-log-path=/var/log/nginx/access.log \
                    --pid-path=/var/run/nginx.pid \
                    --lock-path=/var/run/nginx.lock \
                    --http-client-body-temp-path=/var/cache/nginx/client_temp \
                    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
                    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
                    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
                    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
                    --user=nginx \
                    --group=nginx \
                    --with-http_ssl_module \
                    --with-http_realip_module \
                    --with-http_addition_module \
                    --with-http_sub_module \
                    --with-http_dav_module \
                    --with-http_flv_module \
                    --with-http_mp4_module \
                    --with-http_gunzip_module \
                    --with-http_gzip_static_module \
                    --with-http_random_index_module \
                    --with-http_secure_link_module \
                    --with-http_stub_status_module \
                    --with-http_auth_request_module \
                    --with-http_xslt_module=dynamic \
                    --with-http_image_filter_module=dynamic \
                    --with-http_geoip_module=dynamic \
                    --with-http_perl_module=dynamic \
                    --with-threads \
                    --with-stream \
                    --with-stream_ssl_module \
                    --with-http_slice_module \
                    --with-mail \
                    --with-mail_ssl_module \
                    --with-file-aio \
                    --with-http_v2_module \
                    --with-ipv6 \
                    --add-module=../nginx-rtmp-module-master \
            " \
            && addgroup -S nginx \
            && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \

            && apk add --no-cache --virtual .build-deps \
                gcc \
                libc-dev \
                make \
                openssl-dev \
                pcre-dev \
                zlib-dev \
                linux-headers \
                curl \
                gnupg \
                libxslt-dev \
                gd-dev \
                geoip-dev \
                perl-dev \
            && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
            && curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
            && curl -fSL http://github.com/17media/nginx-rtmp-module/archive/master.tar.gz -o master.tar.gz\
            && export GNUPGHOME="$(mktemp -d)" \
            && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEYS" \
            && gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
            && rm -r "$GNUPGHOME" nginx.tar.gz.asc \
            && mkdir -p /usr/src \
            && tar -zxC /usr/src -f nginx.tar.gz \
            && rm nginx.tar.gz \
            && tar -zxC /usr/src -f master.tar.gz \
            && rm master.tar.gz \
            && cd /usr/src/nginx-$NGINX_VERSION \
            && ./configure $CONFIG --with-debug \
            && make -j$(getconf _NPROCESSORS_ONLN) \
            && mv objs/nginx objs/nginx-debug \
            && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
            && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
            && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
            && mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so \
            && ./configure $CONFIG \
            && make -j$(getconf _NPROCESSORS_ONLN) \
            && make install \
            && rm -rf /etc/nginx/html/ \
            && mkdir /etc/nginx/conf.d/ \
            && mkdir -p /usr/share/nginx/html/ \
            && install -m644 html/index.html /usr/share/nginx/html/ \
            && install -m644 html/50x.html /usr/share/nginx/html/ \
            && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
            && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
            && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
            && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
            && install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so \
            && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
            && strip /usr/sbin/nginx* \
            && strip /usr/lib/nginx/modules/*.so \
            && rm -rf /usr/src/nginx-$NGINX_VERSION \
            \
            # Bring in gettext so we can get `envsubst`, then throw
            # the rest away. To do this, we need to install `gettext`
            # then move `envsubst` out of the way so `gettext` can
            # be deleted completely, then move `envsubst` back.
            && apk add --no-cache --virtual .gettext gettext \
            && mv /usr/bin/envsubst /tmp/ \
            \
            && runDeps="$( \
                scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
                    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
                    | sort -u \
                    | xargs -r apk info --installed \
                    | sort -u \
            )" \
            && apk add --no-cache --virtual .nginx-rundeps $runDeps \
            && apk del .build-deps \
            && apk del .gettext \
            && mv /tmp/envsubst /usr/local/bin/ \
            \
            # forward request and error logs to docker log collector
            && ln -sf /dev/stdout /var/log/nginx/access.log \
            && ln -sf /dev/stderr /var/log/nginx/error.log

RUN         apk --no-cache add ffmpeg

COPY        /conf/.foreman /.foreman
COPY        /conf/Procfile /Procfile

COPY        /conf/nginx.conf /etc/nginx/nginx.conf

COPY        gcsfuse.sh /usr/bin/gcsfuse.sh

RUN         chmod +x /usr/bin/gcsfuse.sh
RUN         adduser $GCSFUSE_USER -D -H && \
                mkdir -p $GCSFUSE_MOUNTPOINT && \
                chown $GCSFUSE_USER $GCSFUSE_MOUNTPOINT
WORKDIR     /

EXPOSE      1935/tcp

CMD         ["foreman", "start"]

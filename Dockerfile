FROM            golang:1.6-alpine

MAINTAINER      Sam Liu "sam@17.media"

ENV             GOOGLE_APPLICATION_CREDENTIALS=/.gcloud.json
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
ENV             FUSE_USER=gcsfuse
ENV             FUSE_MOUNTPOINT=/mnt/store

# Docker Build Arguments
ARG             RESTY_VERSION="1.11.2.1"
ARG             RESTY_OPENSSL_VERSION="1.0.2h"
ARG             RESTY_PCRE_VERSION="8.39"
ARG             RESTY_J="1"
ARG             RESTY_CONFIG_OPTIONS="\
                    --with-file-aio \
                    --with-http_addition_module \
                    --with-http_auth_request_module \
                    --with-http_dav_module \
                    --with-http_flv_module \
                    --with-http_geoip_module=dynamic \
                    --with-http_gunzip_module \
                    --with-http_gzip_static_module \
                    --with-http_image_filter_module=dynamic \
                    --with-http_mp4_module \
                    --with-http_random_index_module \
                    --with-http_realip_module \
                    --with-http_secure_link_module \
                    --with-http_slice_module \
                    --with-http_ssl_module \
                    --with-http_stub_status_module \
                    --with-http_sub_module \
                    --with-http_v2_module \
                    --with-http_xslt_module=dynamic \
                    --with-ipv6 \
                    --with-mail \
                    --with-mail_ssl_module \
                    --with-md5-asm \
                    --with-pcre-jit \
                    --with-sha1-asm \
                    --with-stream \
                    --with-stream_ssl_module \
                    --with-threads \
                    --add-module=../nginx-rtmp-module-master \
                    "

# These are not intended to be user-specified
ARG             _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"


# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup


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


RUN             apk add --no-cache --virtual .build-deps \
                build-base \
                curl \
                gd-dev \
                geoip-dev \
                libxslt-dev \
                linux-headers \
                make \
                perl-dev \
                readline-dev \
                zlib-dev \
                && apk add --no-cache \
                    gd \
                    geoip \
                    libgcc \
                    libxslt \
                    zlib \
                && cd /tmp \
                && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
                && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
                && curl -fSL https://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
                && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
                && curl -fSL http://github.com/17media/nginx-rtmp-module/archive/master.tar.gz -o master.tar.gz \
                && tar xzf master.tar.gz \
                && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
                && tar xzf openresty-${RESTY_VERSION}.tar.gz \
                && cd /tmp/openresty-${RESTY_VERSION} \
                && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} \
                && make -j${RESTY_J} \
                && make -j${RESTY_J} install \
                && cd /tmp \
                && rm -rf \
                    openssl-${RESTY_OPENSSL_VERSION} \
                    openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
                    openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
                    pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
                    master.tar.gz \
                && apk del .build-deps \
                && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
                && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log


RUN             apk --no-cache add ffmpeg

COPY            /conf/.foreman /.foreman
COPY            /conf/Procfile /Procfile

# COPY            /conf/nginx.conf /nginx.conf

COPY            gcsfuse.sh /usr/bin/gcsfuse.sh
RUN             chmod +x /usr/bin/gcsfuse.sh

RUN             mkdir -p /data/nginx/cache

RUN             adduser $FUSE_USER -D -H && \
                    mkdir -p $FUSE_MOUNTPOINT && \
                    chown $FUSE_USER $FUSE_MOUNTPOINT
WORKDIR         /

EXPOSE          1935/tcp 80/tcp

CMD             ["foreman", "start"]

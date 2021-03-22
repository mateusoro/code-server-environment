FROM debian:10.8-slim

ENV USERNAME=code
ENV PUID=2000
ENV PGID=2000
ENV USERSHELL=/usr/bin/fish

### Note: Language versions defined a bit below, so we don't have
### to regenerate this first run step.
RUN echo \
  'deb http://ftp.us.debian.org/debian/ buster main restricted universe multiverse \n\
   deb http://ftp.us.debian.org/debian/ buster-updates main restricted universe multiverse \n\
   deb http://ftp.us.debian.org/debian/ buster-backports main restricted universe multiverse \n\
  ' > /etc/apt/sources.list

# Install some basic packages + docker
RUN apt-get update && apt-get install -y \
   gcc g++ \
   apt-transport-https \
   ca-certificates \
   curl \
   gnupg-agent \
   wget \
   unzip \
   software-properties-common && \
   curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - &&\
   add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable" && \
   echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_10/ /' > /etc/apt/sources.list.d/shells:fish:release:3.list && \
   wget -nv https://download.opensuse.org/repositories/shells:fish:release:3/Debian_10/Release.key -O Release.key && \
   apt-key add - < Release.key && \
   curl https://bazel.build/bazel-release.pub.gpg | apt-key add - && \
   echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && \
   apt-get update && apt-get install -y \
   docker-ce docker-ce-cli containerd.io fish python3-pip gnucobol redis-tools bazel && \
   curl -sSL "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
   chmod +x /usr/local/bin/docker-compose && \
   rm -rf /var/cache/apt/archives/*

### Define your language versions here, or pass them in to build
### with --build-arg

ARG NODE_VERSION=12.18.3
ARG GO_VERSION=1.16.2
ARG ERLANG_VERSION=22.3-1
ARG ELIXIR_VERSION=1.10.2-1
ARG JAVA_VERSION=14
ARG RUST_VERSION=1.50.0
ARG GCLOUD_VERSION=332.0.0
ARG CODE_SERVER_VERSION=3.9.1

WORKDIR /tmp

# Install Code Server
RUN wget -q -O /tmp/code-server.tar.gz \
   https://github.com/cdr/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz && \
   tar -xzf code-server.tar.gz && mv /tmp/code-server-${CODE_SERVER_VERSION}-linux-amd64 /usr/local/code-server && \
   rm /tmp/code-server.tar.gz && \
   chmod +x /usr/local/code-server/bin/code-server

# Setup our init
RUN echo \
   '#!/bin/bash \n\
   addgroup --quiet --gid ${PGID} ${USERNAME} \n\
   adduser --quiet --disabled-password --gecos "" --uid ${PUID} --gid ${PGID} --shell ${USERSHELL} ${USERNAME} \n\
   adduser --quiet ${USERNAME} docker \n\
   chown ${PUID}.{$PGID} -r /home/${USERNAME} \n\
   su - ${USERNAME} -c "/usr/local/code-server/bin/code-server --disable-telemetry --auth none --bind-addr 0.0.0.0:8080" \
   ' > /start.sh && chmod +x /start.sh

# Install node
RUN wget -q -O /tmp/node.tar.gz \
   https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz && \
   tar -xzf node.tar.gz && mv node-v${NODE_VERSION}-linux-x64 /usr/local/node && \
   ln -s /usr/local/node/bin/* /usr/local/bin/ && \
   rm -rf /tmp/node.tar.gz

# Install Go
RUN wget -q -O /tmp/go.tar.gz \
   https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && \
   tar -xzf go.tar.gz && mv go /usr/local/go && \
   ln -s /usr/local/go/bin/* /usr/local/bin/ && \
   rm -rf /tmp/go.tar.gz

# Install Erlang
RUN wget -q -O /tmp/erlang.deb \
   https://packages.erlang-solutions.com/erlang/debian/pool/esl-erlang_${ERLANG_VERSION}~debian~buster_amd64.deb && \
   dpkg -i /tmp/erlang.deb || apt-get -y install -f && \
   rm -rf /tmp/erlang.deb /var/cache/apt/archives/*

# Install Elixir
RUN wget -q -O /tmp/elixir.deb \
   https://packages.erlang-solutions.com/erlang/debian/pool/elixir_${ELIXIR_VERSION}~debian~buster_all.deb && \
   dpkg -i /tmp/elixir.deb || apt-get -y install -f && \
   rm -rf /tmp/elixir.deb /var/cache/apt/archives/*

# Install Java
RUN wget -q -O /tmp/java.tar.gz \
   https://download.java.net/java/GA/jdk14/076bab302c7b4508975440c56f6cc26a/36/GPL/openjdk-${JAVA_VERSION}_linux-x64_bin.tar.gz && \
   tar -xzf java.tar.gz && mv /tmp/jdk-${JAVA_VERSION} /usr/local/java && \
   ln -s /usr/local/java/bin/* /usr/local/bin/ && \
   rm /tmp/java.tar.gz

# Install Rust
RUN wget -q -O /tmp/rust.tar.gz \
   https://static.rust-lang.org/dist/rust-${RUST_VERSION}-x86_64-unknown-linux-gnu.tar.gz && \
   tar -xzf rust.tar.gz && \
   mv rust-${RUST_VERSION}-x86_64-unknown-linux-gnu /usr/local/rust && \
   ln -s /usr/local/rust/*/bin/* /usr/local/bin/ && \
   rm /tmp/rust.tar.gz

# Install python3 libraries
RUN pip3 install --system \
   autopep8==1.5 \
   virtualenv==20.0.16

# Install the Google Cloud SDK
RUN wget -q -O /tmp/gcloud.tar.gz \
   https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz && \
   tar -xzf gcloud.tar.gz && \
   mv google-cloud-sdk /usr/local/gcloud && \
   /usr/local/gcloud/bin/gcloud -q components list --format "csv(id)" | \ 
   grep -v '^id$' | xargs /usr/local/gcloud/bin/gcloud components install && \
   rm /tmp/gcloud.tar.gz && \
   find /usr/local/gcloud/bin -maxdepth 1 \( ! -name '*\.*' \) -type f -exec ln -s {} /usr/local/bin/ ';'

EXPOSE 8080 8081-8090
ENTRYPOINT [ "/start.sh" ]

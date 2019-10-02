#-------------------------------------------------------------------------------------------------------------
# Licensed under the MIT License.
#-------------------------------------------------------------------------------------------------------------

# You can use any Debian/Ubuntu based image as a base
FROM debian:9

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive


# This Dockerfile adds a non-root 'vscode' user with sudo access. However, for Linux,
# this user's GID/UID must match your local user UID/GID to avoid permission issues
# with bind mounts. Update USER_UID / USER_GID if yours is not 1000. See
# https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG PROXY=''

# Proxy設定
ENV no_proxy '127.0.0.1,localhost,192.168.99.100,192.168.99.101,192.168.99.102,192.168.99.103,192.168.99.104,192.168.99.105,172.17.0.1'

# 自己証明が必要な場合はここで組み込む
ADD /etc/ssl/certs/      /etc/ssl/certs/

# Configure apt and install packages
RUN set -x \
#    && echo '\n\
#        ca_directory = /etc/ssl/certs/ \n\
#        http_proxy=${PROXY:-} \n\
#        https_proxy=${PROXY:-} \n\
#    ' > /etc/wgetrc \
#    && echo '\n\
#        ca_directory = /etc/ssl/certs/ \n\
#    ' >> /etc/wgetrc \
#    && cat /etc/wgetrc \
    && apt-get update \
    && apt-get -y install --no-install-recommends apt-utils dialog 2>&1 \
    && apt-get -y install openssh-server \
    && apt-get -y install net-tools zip unzip \
    #
    # Verify git, process tools installed
    && apt-get -y install git iproute2 procps \
    #
    # Install Docker CE CLI
    && apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common lsb-release \
    && curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | (OUT=$(apt-key add - 2>&1) || echo $OUT) \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    #
    # Install kubectl
    && curl -sSL -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    #
    # Install Helm
    # && curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash - \
    #
    # Copy localhost's ~/.kube/config file into the container and swap out localhost
    # for host.docker.internal whenever a new shell starts to keep them in sync.
    && echo '\n\
        if [ "$SYNC_LOCALHOST_KUBECONFIG" == "true" ]; then\n\
            mkdir -p $HOME/.kube\n\
            cp -r $HOME/.kube-localhost/* $HOME/.kube\n\
            sed -i -e "s/localhost/host.docker.internal/g" $HOME/.kube/config\n\
        \n\
            if [ -d "$HOME/.minikube-localhost" ]; then\n\
                mkdir -p $HOME/.minikube\n\
                cp -r $HOME/.minikube-localhost/ca.crt $HOME/.minikube\n\
                sed -i -r "s|(\s*certificate-authority:\s).*|\\1$HOME\/.minikube\/ca.crt|g" $HOME/.kube/config\n\
                cp -r $HOME/.minikube-localhost/client.crt $HOME/.minikube\n\
                sed -i -r "s|(\s*client-certificate:\s).*|\\1$HOME\/.minikube\/client.crt|g" $HOME/.kube/config\n\
                cp -r $HOME/.minikube-localhost/client.key $HOME/.minikube\n\
                sed -i -r "s|(\s*client-key:\s).*|\\1$HOME\/.minikube\/client.key|g" $HOME/.kube/config\n\
            fi\n\
        fi' \
        >> $HOME/.bashrc \
    #
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    #
# java 
    && apt-get install dirmngr gnupg \
# echo $([ -n "$http_proxy" ] && echo "--keyserver-option http-proxy=$http_proxy")
#    && apt-key adv -no-tty --keyserver keyserver.ubuntu.com $([ -n "$http_proxy" ] && echo "--keyserver-option http-proxy=$http_proxy") --recv-keys A66C5D02 \
    && apt-key adv --keyserver keyserver.ubuntu.com $([ -n "$PROXY" ] && echo "--keyserver-option http-proxy=$PROXY") --recv-keys A66C5D02 \
    && echo 'deb https://rpardini.github.io/adoptopenjdk-deb-installer stable main' > /etc/apt/sources.list.d/rpardini-aoj.list \
#RUN apt-get -y install openjdk-8-jdk-headless maven
    && apt-get update \
    && apt-get install -y adoptopenjdk-8-installer maven \
    #
# nodejs
#    && curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash - \
#    && apt-get install -y nodejs npm\
    && curl -sL https://deb.nodesource.com/setup_11.x | bash - \
    && apt-get install -y nodejs \
    && npm install n -g \
    #
# 空パスワードの場合は以下をコメントアウト
    && sed -ri 's/^#PermitEmptyPasswords no/PermitEmptyPasswords yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config \
    && mkdir /var/run/sshd \
# 空パスワードの場合は以下をコメントアウト
    && passwd -d root \
# 任意のパスワードの場合は以下をコメントアウト & パスワードを書き換える
#    && echo "root:root" | chpasswd \
#
# Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=

EXPOSE 22
ENTRYPOINT [ "/usr/sbin/sshd", "-D" ]

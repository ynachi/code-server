# Start from the code-server Debian base image
FROM codercom/code-server:4.2.0

USER coder

# Apply VS Code settings
COPY deploy-container/settings.json .local/share/code-server/User/settings.json

#
# Use bash shell
ENV SHELL=/bin/bash

# Install unzip + rclone (support for remote filesystem)
RUN sudo apt-get update && sudo apt-get install unzip build-essential procps curl file git -y
RUN curl https://rclone.org/install.sh | sudo bash

# Copy rclone tasks to /tmp, to potentially be used
COPY deploy-container/rclone-tasks.json /tmp/rclone-tasks.json

# Fix permissions for code-server
RUN sudo chown -R $USER:$USER /home/coder/.local

# You can add custom software and dependencies for your environment below
# -----------

# Install a VS Code extension:
# Note: we use a different marketplace than VS Code. See https://github.com/cdr/code-server/blob/main/docs/FAQ.md#differences-compared-to-vs-code
# RUN code-server --install-extension esbenp.prettier-vscode

#-------------------------------------------------------------------
# Install apt packages:
#-----------------------------------------------

# Common packages
RUN sudo apt update && \
    sudo apt -y upgrade && \
    sudo apt install -y git wget vim zip unzip software-properties-common && \
    sudo rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=noninteractive
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG INSTALL_ZSH="false"
ARG UPGRADE_PACKAGES="true"

COPY library-scripts/base/*.sh library-scripts/base/*.env /tmp/library-scripts/
RUN sudo bash /tmp/library-scripts/common-debian-custom.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "true" "true" \
    && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

#++++++++++++++++++++++++++++++ INSTALL HOMEBREW ++++++++++++++++++++++++++
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/$USERNAME/.profile && \
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
brew doctor
# Copy files: 
# COPY deploy-container/myTool /home/coder/myTool

# -------------- GOLANG --------------------
ENV GOLANG_VERSION=1.18
RUN sudo bash /tmp/library-scripts/go-debian-prepare.sh "${GOLANG_VERSION}" \
&& sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
RUN sudo  mkdir -p "$GOPATH/src" "$GOPATH/bin" && sudo chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

# Install Go tools
ENV GO111MODULE=auto
RUN sudo bash /tmp/library-scripts/go-debian.sh "none" "/usr/local/go" "${GOPATH}" "${USERNAME}" "false" \
    && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

# ++++++++++++++++++++++ KUBERNETES TOOLS ++++++++++++++++++++++++++++++++++++++++
RUN  . /home/$USERNAME/.profile && \
      brew install operator-sdk && \
      brew install kustomize && \ 
      brew install kubectl && \
      sudo mkdir ~/.kube/
      # These two needs kube config file
#      operator-sdk olm status || \
#      operator-sdk olm install

# +++++++++++++++++++++++ NODEJS ++++++++++++++++++++++++++++++++++
# [Choice] Node.js version: none, lts/*, 16, 14, 12, 10
ARG NODE_VERSION="none"
ENV NVM_DIR=/usr/local/share/nvm
ENV NVM_SYMLINK_CURRENT=true
# ENV PATH=${NVM_DIR}/current/bin:${PATH}
RUN sudo bash /tmp/library-scripts/node-debian.sh "${NVM_DIR}" "${NODE_VERSION}" "${USERNAME}" \
    && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

# ++++++++++++++++++++++++ LLVM CLANG ++++++++++++++++++++++++++++++++++++++
ARG LLVM_VERSION=14
ARG LLVM_GPG_FINGERPRINT=6084F3CF814B57C1CF12EFD515CF4D18AF4F7421

RUN sudo bash /tmp/library-scripts/clang-cpp.sh "${LLVM_VERSION}" "${LLVM_GPG_FINGERPRINT}" \
    && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

# +++++++++++++++++++++++++++++ JAVA JAVA +++++++++++++++++++++
ARG TARGET_JAVA_VERSION=11
ENV JAVA_HOME=/usr/lib/jvm/java-${TARGET_JAVA_VERSION}-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# [Option] Install Maven
ARG INSTALL_MAVEN="false"
ARG MAVEN_VERSION=""
# [Option] Install Gradle
ARG INSTALL_GRADLE="true"
ARG GRADLE_VERSION="7.4.1"

# switch to bash to use source command
SHELL ["/bin/bash", "-c"]
RUN sudo apt update && sudo apt -y upgrade \
   && sudo apt install openjdk-"${TARGET_JAVA_VERSION}"-jre openjdk-"${TARGET_JAVA_VERSION}"-jdk -y \
   && curl -s "https://get.sdkman.io" | bash \
   && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* \
   && source $HOME/.sdkman/bin/sdkman-init.sh \
   && sdk install gradle ${GRADLE_VERSION} && sdk flush archives && sdk flush temp \
   && sdk install maven ${MAVEN_VERSION} && sdk flush archives && sdk flush temp 
# ++++++++++++++++++++++++++++ PYTHON +++++++++++++++++++++++++++++++++++++++++++
ENV PATH=/usr/local/bin:$PATH
# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG=C.UTF-8
# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION=21.2.4
# https://github.com/docker-library/python/issues/365
ENV PYTHON_SETUPTOOLS_VERSION=58.1.0
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/38e54e5de07c66e875c11a1ebbdb938854625dd8/public/get-pip.py
ENV PYTHON_GET_PIP_SHA256=e235c437e5c7d7524fbce3880ca39b917a73dc565e0c813465b7a7a329bb279a
ENV PYTHON_GPG_KEY=A035C8C19219BA821ECEA86B64E628F8D684696D
ENV PYTHON_VERSION=3.10.2
# Setup default python tools in a venv via pipx to avoid conflicts
ENV PIPX_HOME=/usr/local/py-utils \
    PIPX_BIN_DIR=/usr/local/py-utils/bin
ENV PATH=${PATH}:${PIPX_BIN_DIR}
RUN sudo bash /tmp/library-scripts/python-debian-prepare.sh "${PYTHON_VERSION}" "${PYTHON_GPG_KEY}" "${PYTHON_PIP_VERSION}" "${PYTHON_SETUPTOOLS_VERSION}" "${PYTHON_GET_PIP_URL}" "${PYTHON_GET_PIP_SHA256}" \ 
    && sudo bash /tmp/library-scripts/python-debian.sh "none" "/usr/local" "${PIPX_HOME}" "${USERNAME}" \ 
    && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

# ++++++++++++++++++++++++++++++ BAZEL ++++++++++++++++++++++++++++++++++++++++
# Install Bazel
ARG BAZELISK_VERSION=v1.11.0
ARG BAZELISK_DOWNLOAD_SHA=dev-mode
RUN sudo apt-get install -y pkg-config zip g++ zlib1g-dev unzip \
    && sudo curl -fSsL -o /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-linux-amd64 \
    && ([ "${BAZELISK_DOWNLOAD_SHA}" = "dev-mode" ] || echo "${BAZELISK_DOWNLOAD_SHA} */usr/local/bin/bazelisk" | sha256sum --check - ) \
    && sudo chmod 0755 /usr/local/bin/bazelisk \
    && sudo apt-get autoremove -y && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

# +++++++++++++++++++++++++++++ PROTOBUF ++++++++++++++++++++++++++++++++++
RUN curl -o /tmp/protoc-3.20.0-linux-x86_64.zip https://github.com/protocolbuffers/protobuf/releases/download/v3.20.0/protoc-3.20.0-linux-x86_64.zip \
    && unzip /tmp/protoc-3.20.0-linux-x86_64.zip -d /usr/local/protobuf \
    && rm -f /tmp/protoc-3.20.0-linux-x86_64.zip

# ++++++++++++++++++++++++++++ FINISH FINISH ++++++++++++++++++++++++++++
RUN sudo rm -rf /tmp/library-scripts

ENV DEBIAN_FRONTEND=dialog
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    CC="/usr/bin/clang-${LLVM_VERSION}" \
    CXX="/usr/bin/clang++-${LLVM_VERSION}" \
    COV="/usr/bin/llvm-cov-${LLVM_VERSION}" \
    LLDB="/usr/bin/lldb-${LLVM_VERSION}" \
    EDITOR=code \
    VISUAL=code \
    GIT_EDITOR="code --wait"

# Port
ENV PORT=8080
ARG PATH_APPEND="/usr/local/protobuf/bin:$GOPATH/bin:/usr/local/go/bin:${NVM_DIR}/current/bin:${JAVA_HOME}/bin:/usr/local/bin:${PIPX_BIN_DIR}:${SDKMAN_DIR}/candidates/java/current/bin:${SDKMAN_DIR}/candidates/maven/current/bin:${SDKMAN_DIR}/candidates/gradle/current/bin"
RUN echo "PATH=$PATH_APPEND":'$PATH' >> /home/$USERNAME/.profile
# Use our custom entrypoint script first
COPY deploy-container/entrypoint.sh /usr/bin/deploy-container-entrypoint.sh
RUN sudo chown -R $USERNAME:$USERNAME /home/$USERNAME
ENTRYPOINT ["/usr/bin/deploy-container-entrypoint.sh"]

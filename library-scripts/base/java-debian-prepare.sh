#!/usr/bin/env bash
set -x
TARGET_JAVA_VERSION=${1:-"11"}
JAVA_HOME=${2:-"/usr/lib/jvm/msopenjdk-${TARGET_JAVA_VERSION}"}
export PATH="${JAVA_HOME}/bin:${PATH}"

# Install Microsoft OpenJDK
arch="$(sudo dpkg --print-architecture)" \
	&& case "$arch" in \
		"amd64") \
			jdkUrl="https://aka.ms/download-jdk/microsoft-jdk-${TARGET_JAVA_VERSION}-linux-x64.tar.gz"; \
			;; \
		"arm64") \
			jdkUrl="https://aka.ms/download-jdk/microsoft-jdk-${TARGET_JAVA_VERSION}-linux-aarch64.tar.gz"; \
			;; \
		*) echo >&2 "error: unsupported architecture: '$arch'"; exit 1 ;; \
	esac \
	\
	&& wget --progress=dot:giga -O msopenjdk.tar.gz "${jdkUrl}" \
	&& wget --progress=dot:giga -O sha256sum.txt "${jdkUrl}.sha256sum.txt" \
	\
	&& sha256sumText=$(cat sha256sum.txt) \
	&& sha256=$(expr substr "${sha256sumText}" 1 64) \
	&& echo "${sha256} msopenjdk.tar.gz" | sha256sum --strict --check - \
	&& rm sha256sum.txt* \
	\
	&& sudo mkdir -p "$JAVA_HOME" \
	&& sudo tar --extract \
		--file msopenjdk.tar.gz \
		--directory "$JAVA_HOME" \
		--strip-components 1 \
		--no-same-owner \
	&& sudo rm msopenjdk.tar.gz* \
	\
	&& sudo ln -s ${JAVA_HOME} /docker-java-home \
	&& sudo ln -s ${JAVA_HOME} /usr/local/openjdk-${TARGET_JAVA_VERSION}

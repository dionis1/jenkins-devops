FROM docker:29.1.3-cli AS dockercli
FROM jenkins/jenkins:2.580.1-jdk21
USER root
RUN apt-get update && apt-get install -y --no-install-recommends python3 curl ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=dockercli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins
ARG TARGETARCH=amd64
RUN curl -fsSL "https://dl.k8s.io/release/v1.35.9/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
 && curl -fsSL "https://dl.k8s.io/release/v1.35.9/bin/linux/${TARGETARCH}/kubectl.sha256" -o /tmp/kubectl.sha256 \
 && echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum -c - \
 && curl -fsSL "https://get.helm.sh/helm-v4.3.0-linux-${TARGETARCH}.tar.gz" -o /tmp/helm.tgz \
 && curl -fsSL "https://get.helm.sh/helm-v4.3.0-linux-${TARGETARCH}.tar.gz.sha256sum" -o /tmp/helm.sha256 \
 && echo "$(cut -d ' ' -f 1 /tmp/helm.sha256)  /tmp/helm.tgz" | sha256sum -c - \
 && tar -xzf /tmp/helm.tgz -C /tmp \
 && mv "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm \
 && chmod +x /usr/local/bin/kubectl /usr/local/bin/helm \
 && rm -rf /tmp/helm* /tmp/kubectl.sha256 "/tmp/linux-${TARGETARCH}"
RUN mkdir -p /home/jenkins/agent && chown jenkins:jenkins /home/jenkins/agent
COPY infra/start-agent.sh /opt/exam/start-agent.sh
COPY infra/Jenkinsfile.production /opt/exam/Jenkinsfile.production
USER jenkins

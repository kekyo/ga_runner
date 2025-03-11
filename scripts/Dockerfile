# GitHub Actions Self-hosted immutable runner"
# Copyright (c) Kouji Matsui (@kekyo@mi.kekyo.net)"
# License under MIT.
# https://github.com/kekyo/ga_runner/

FROM ubuntu:24.04

# Environments
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_HOME=/home/runner

# Packages
RUN apt-get update && apt-get install -y \
    sudo tzdata locales curl libxml2-utils git unzip libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# Add a runner user
RUN useradd -m -d ${RUNNER_HOME} runner && \
    chown -R runner:runner ${RUNNER_HOME} && \
    { \
      echo 'Defaults:runner !env_reset'; \
      echo 'Defaults:runner !secure_path'; \
      echo 'runner ALL=(ALL) NOPASSWD:ALL'; \
    } > /etc/sudoers.d/runner && \
    chmod 0440 /etc/sudoers.d/runner

# Add execution script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set a user
USER runner

# Entry point
ENTRYPOINT ["/entrypoint.sh"]

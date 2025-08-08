FROM ubuntu:22.04

# Install basic dependencies for envi installation
RUN apt-get update && apt-get install -y \
    curl \
    git \
    zsh \
    bash \
    vim \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create test user (non-root for realistic testing)
RUN useradd -m -s /bin/bash testuser && \
    echo 'testuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Switch to test user
USER testuser
WORKDIR /home/testuser

# Entry point for testing
CMD ["/bin/bash"]
FROM n8nio/runners:2.18.5

USER root

# Install Rclone dependencies and binary
RUN apt-get update && \
    apt-get install -y rclone unzip && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies for AI workflows
COPY requirements.txt /opt/runners/task-runner-python/requirements.txt
RUN cd /opt/runners/task-runner-python && uv pip install -r requirements.txt

# Revert back to the non-root runner user for security
USER runner
# --------------------------------------------------------
# STAGE 1: Downloader
# Use a temporary, lightweight Alpine container to fetch Rclone
# --------------------------------------------------------
FROM alpine:latest AS builder

# Install standard web tools to fetch the archive
RUN apk add --no-cache curl unzip

# Download the latest Linux AMD64 binary, unzip it, and isolate the executable
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip && \
    unzip rclone-current-linux-amd64.zip && \
    mv rclone-*-linux-amd64/rclone /rclone-binary && \
    chmod +x /rclone-binary

# --------------------------------------------------------
# STAGE 2: Final Runner Image
# Build the actual n8n task runner
# --------------------------------------------------------
FROM n8nio/runners:2.18.5

USER root

# Inject the standalone Rclone binary from the builder stage
COPY --from=builder /rclone-binary /usr/local/bin/rclone

# Inject Custom Sandbox Security Policy
COPY --chown=runner:runner n8n-task-runners.json /etc/n8n-task-runners.json
RUN chmod 644 /etc/n8n-task-runners.json

# Install Python dependencies
COPY requirements.txt /opt/runners/task-runner-python/requirements.txt
RUN cd /opt/runners/task-runner-python && uv pip install -r requirements.txt

# Patch n8n task_executor.py to prevent wiping out allowed environment variables
# RUN sed -i 's/os.environ.clear()/# os.environ.clear()/g' /opt/runners/task-runner-python/src/task_executor.py
# DEBUG: Find where is the python file
# RUN find /opt/runners -name "*.py" && exit 1
RUN find /opt/runners -name "task_executor.py" -exec sed -i 's/os.environ.clear()/# os.environ.clear()/g' {} +


# Revert back to the non-root runner user for security
USER runner
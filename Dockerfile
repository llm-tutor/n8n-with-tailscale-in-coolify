FROM n8nio/runners:2.18.5

USER root

# Copy the requirements file into the Python runner's directory
COPY requirements.txt /opt/runners/task-runner-python/requirements.txt

# Install the Python dependencies using uv (which comes pre-installed in the runner image)
RUN cd /opt/runners/task-runner-python && uv pip install -r requirements.txt

# Revert back to the non-root runner user for security
USER runner
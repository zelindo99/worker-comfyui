ARG BASE_IMAGE=nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04
FROM ${BASE_IMAGE}

# --- Environment ---
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# --- System Dependencies (smallest possible set) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip \
    git wget ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Install uv + virtualenv ---
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
 && ln -s /root/.local/bin/uv /usr/local/bin/uv \
 && uv venv /opt/venv

ENV PATH="/opt/venv/bin:${PATH}"

# --- Install comfy-cli (no models) ---
RUN uv pip install --no-cache-dir comfy-cli pip setuptools wheel \
 && rm -rf /root/.cache

# --- Install ComfyUI (no models downloaded) ---
RUN /usr/bin/yes | comfy \
      --workspace /comfyui \
      install \
      --nvidia \
      --skip-models \
 && rm -rf /root/.cache

# --- Install Torch (smallest reliable build for CUDA 12.x) ---
RUN uv pip install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121 \
 && rm -rf /root/.cache

# --- Add Config and Scripts ---
ADD src/extra_model_paths.yaml /comfyui/
ADD src/start.sh handler.py test_input.json /
RUN chmod +x /start.sh

COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

ENV PIP_NO_INPUT=1

# --- Worker dependencies ---
RUN uv pip install --no-cache-dir runpod requests websocket-client \
 && rm -rf /root/.cache

# --- Custom node dependencies ---
COPY requirements-custom-nodes.txt /tmp/requirements-custom-nodes.txt
RUN uv pip install --no-cache-dir -r /tmp/requirements-custom-nodes.txt \
 && rm -rf /root/.cache /tmp/*

CMD ["/start.sh"]

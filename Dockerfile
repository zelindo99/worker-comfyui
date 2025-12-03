# ---- Stage 1: Base ----
ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04
FROM ${BASE_IMAGE} AS base

ARG COMFYUI_VERSION=latest
ARG CUDA_VERSION_FOR_COMFY
ARG ENABLE_PYTORCH_UPGRADE=false
ARG PYTORCH_INDEX_URL

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# System deps
RUN apt-get update && apt-get install -y \
    python3.12 python3.12-venv \
    git wget ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
 && ln -sf /usr/bin/python3.12 /usr/bin/python \
 && ln -sf /usr/bin/pip3 /usr/bin/pip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Install uv and create venv
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
 && ln -s /root/.local/bin/uv /usr/local/bin/uv \
 && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
 && uv venv /opt/venv

ENV PATH="/opt/venv/bin:${PATH}"

# Install comfy-cli and dependencies
RUN uv pip install --no-cache-dir comfy-cli pip setuptools wheel \
 && rm -rf /root/.cache

# Install ComfyUI (no models downloaded)
RUN if [ -n "${CUDA_VERSION_FOR_COMFY}" ]; then \
      /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cuda-version "${CUDA_VERSION_FOR_COMFY}" --nvidia --skip-models; \
    else \
      /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --nvidia --skip-models; \
    fi \
 && rm -rf /root/.cache

# Optional PyTorch upgrade
RUN if [ "$ENABLE_PYTORCH_UPGRADE" = "true" ]; then \
      uv pip install --no-cache-dir --force-reinstall torch torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}; \
    fi \
 && rm -rf /root/.cache

WORKDIR /comfyui
ADD src/extra_model_paths.yaml ./

WORKDIR /

# Copy scripts
ADD src/start.sh handler.py test_input.json ./
RUN chmod +x /start.sh

COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

ENV PIP_NO_INPUT=1

# Install worker dependencies
RUN uv pip install --no-cache-dir runpod requests websocket-client \
 && rm -rf /root/.cache

# Install custom node deps
COPY requirements-custom-nodes.txt /tmp/requirements-custom-nodes.txt
RUN uv pip install --no-cache-dir -r /tmp/requirements-custom-nodes.txt \
 && rm -rf /root/.cache /tmp/*

CMD ["/start.sh"]

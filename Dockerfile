FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

WORKDIR /app

# Install system dependencies
RUN apt update && apt install -y \
    python3 python3-pip python3-dev \
    libgl1-mesa-glx libopengl0 libglib2.0-0 \
    git wget ffmpeg git-lfs curl \
    && rm -rf /var/lib/apt/lists/*

# Create symlink for python
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Clone ComfyUI and essential extensions
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git ComfyUI/custom_nodes/ComfyUI-Manager && \
    git clone https://github.com/kijai/ComfyUI-Hunyuan3DWrapper.git ComfyUI/custom_nodes/ComfyUI-Hunyuan3DWrapper && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git ComfyUI/custom_nodes/ComfyUI_essentials && \
    git clone https://github.com/WASasquatch/was-node-suite-comfyui.git ComfyUI/custom_nodes/was-node-suite-comfyui && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git ComfyUI/custom_nodes/ComfyUI-KJNodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git ComfyUI/custom_nodes/rgthree-comfy

# Install PyTorch with CUDA support
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install ComfyUI and custom node requirements
WORKDIR /app/ComfyUI
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir opencv-python==4.10.0.82 sageattention triton trimesh pygltflib rembg[gpu] xatlas

# Install Hunyuan3D wrapper requirements
RUN pip install --no-cache-dir -r ./custom_nodes/ComfyUI-Hunyuan3DWrapper/requirements.txt

# --- DOWNLOAD MODELS (EMBEDDED IN IMAGE) ---
# Create model directories
RUN mkdir -p /app/ComfyUI/models/diffusion_models/Hunyuan3D-2/hunyuan3d-dit-v2 && \
    mkdir -p /app/ComfyUI/models/diffusion_models/Hunyuan3D-2/hunyuan3d-vae-v2 && \
    mkdir -p /app/ComfyUI/models/checkpoints

# Download Hunyuan3D-2 weights (DIT and VAE)
RUN curl -L -o /app/ComfyUI/models/diffusion_models/Hunyuan3D-2/hunyuan3d-dit-v2/model.fp16.safetensors \
        "https://huggingface.co/tencent/Hunyuan3D-2/resolve/main/hunyuan3d-dit-v2-0/model.fp16.safetensors" && \
    curl -L -o /app/ComfyUI/models/diffusion_models/Hunyuan3D-2/hunyuan3d-dit-v2/config.yaml \
        "https://huggingface.co/tencent/Hunyuan3D-2/resolve/main/hunyuan3d-dit-v2-0/config.yaml" && \
    curl -L -o /app/ComfyUI/models/diffusion_models/Hunyuan3D-2/hunyuan3d-vae-v2/model.fp16.safetensors \
        "https://huggingface.co/tencent/Hunyuan3D-2/resolve/main/hunyuan3d-vae-v2-0/model.fp16.safetensors" && \
    curl -L -o /app/ComfyUI/models/diffusion_models/Hunyuan3D-2/hunyuan3d-vae-v2/config.yaml \
        "https://huggingface.co/tencent/Hunyuan3D-2/resolve/main/hunyuan3d-vae-v2-0/config.yaml"

# Download SDXL Base model
RUN curl -L -o /app/ComfyUI/models/checkpoints/sd_xl_base_1.0.safetensors \
    "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"

# Install RunPod dependencies
RUN pip install --no-cache-dir runpod requests

# Final Setup
WORKDIR /app
COPY handler.py /app/handler.py
COPY workflow_api.json /app/workflow_api.json
RUN mkdir -p /app/input /app/ComfyUI/output

ENV COMFYUI_PATH="/app/ComfyUI"
ENV PYTHONUNBUFFERED=1

CMD ["python", "-u", "/app/handler.py"]
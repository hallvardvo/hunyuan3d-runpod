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
    git clone https://github.com/kijai/ComfyUI-KJNodes.git ComfyUI/custom_nodes/ComfyUI-KJNodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git ComfyUI/custom_nodes/rgthree-comfy

# Install PyTorch with CUDA support
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# FIX: Force NumPy 1.x and compatible OpenCV BEFORE other packages
# NumPy 2.x breaks the entire Hunyuan3D ecosystem
RUN pip install --no-cache-dir --force-reinstall "numpy<2.0" "opencv-python-headless<4.11"

# Install ComfyUI and custom node requirements
WORKDIR /app/ComfyUI
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir opencv-python==4.10.0.82 sageattention triton trimesh pygltflib rembg[gpu] xatlas

# Install Hunyuan3D wrapper requirements
RUN pip install --no-cache-dir -r ./custom_nodes/ComfyUI-Hunyuan3DWrapper/requirements.txt

# Create model directories (models will be downloaded at runtime)
RUN mkdir -p /app/ComfyUI/models/diffusion_models/Hunyuan3D-2/hunyuan3d-dit-v2 && \
    mkdir -p /app/ComfyUI/models/diffusion_models/Hunyuan3D-2/hunyuan3d-vae-v2 && \
    mkdir -p /app/ComfyUI/models/checkpoints

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
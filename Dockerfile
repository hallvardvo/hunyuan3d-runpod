FROM thelocallab/hunyuan3d-2.1-comfyui:latest

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
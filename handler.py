"""
RunPod Serverless Handler for Hunyuan3D (Standard) with ComfyUI
Generates 3D models from text prompts using an Image-to-3D pipeline
"""
import os
import sys
import json
import base64
import subprocess
import threading
import time
import requests

COMFYUI_PATH = os.environ.get("COMFYUI_PATH", "/app/ComfyUI")
COMFYUI_URL = "http://127.0.0.1:8188"
WORKFLOW_PATH = "/app/workflow_api.json"
OUTPUT_DIR = f"{COMFYUI_PATH}/output"
INPUT_DIR = f"{COMFYUI_PATH}/input"

comfyui_process = None


def start_comfyui_server():
    """Start ComfyUI server in background"""
    global comfyui_process
    
    main_py = os.path.join(COMFYUI_PATH, "main.py")
    if not os.path.isfile(main_py):
        print(f"❌ ComfyUI not found at {COMFYUI_PATH}")
        sys.exit(1)
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(INPUT_DIR, exist_ok=True)

    print(f"🚀 Starting ComfyUI from {COMFYUI_PATH}...")
    
    comfyui_process = subprocess.Popen(
        [
            sys.executable,
            "main.py",
            "--listen", "127.0.0.1",
            "--port", "8188",
            "--disable-auto-launch",
            "--disable-metadata"
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        cwd=COMFYUI_PATH,
        env=os.environ.copy()
    )
    
    def log_output():
        for line in iter(comfyui_process.stdout.readline, b''):
            print(f"[ComfyUI] {line.decode().strip()}")
    
    threading.Thread(target=log_output, daemon=True).start()
    return comfyui_process


def wait_for_server(timeout=300):
    """Wait for ComfyUI to be ready"""
    print(f"📡 Waiting for ComfyUI at {COMFYUI_URL}...")
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            if requests.get(f"{COMFYUI_URL}/system_stats", timeout=5).status_code == 200:
                print("🟢 ComfyUI ready")
                return True
        except:
            pass
        time.sleep(2)
    return False


def build_workflow(image_filename):
    """Build Hunyuan3D workflow for Image-to-3D"""
    with open(WORKFLOW_PATH, "r") as f:
        workflow = json.load(f)
    
    # Find LoadImage node and set it to use the input image
    for node_id, node in workflow.items():
        if node.get("class_type") == "LoadImage":
            node["inputs"]["image"] = image_filename
            print(f"✅ Set LoadImage node {node_id} to use {image_filename}")
            break
    
    return workflow


def handler(event):
    """Handle RunPod job - expects image_base64 for Image-to-3D conversion"""
    try:
        job_input = event.get("input", event)
        print(f"📥 Received event: {json.dumps(job_input, indent=2)[:500]}")
        
        # Get image_base64 for Image-to-3D
        image_base64 = job_input.get("image_base64")
        if not image_base64:
            return {"error": "No image_base64 provided. Send base64-encoded image for Image-to-3D conversion."}
        
        print(f"🖼️  Processing image for 3D generation...")
        
        # Decode and save image to INPUT_DIR
        try:
            image_data = base64.b64decode(image_base64)
        except Exception as e:
            return {"error": f"Invalid base64 image: {str(e)}"}
        
        image_filename = "input_image.png"
        image_path = os.path.join(INPUT_DIR, image_filename)
        with open(image_path, "wb") as f:
            f.write(image_data)
        print(f"✅ Image saved: {image_filename} ({len(image_data)} bytes)")
        
        # Build workflow with the input image
        workflow = build_workflow(image_filename)
        
        print("🚀 Sending workflow to ComfyUI...")
        response = requests.post(f"{COMFYUI_URL}/prompt", json={"prompt": workflow})
        response.raise_for_status()
        
        prompt_id = response.json()["prompt_id"]
        print(f"✅ Job queued: {prompt_id}")
        
        # Poll for completion - Hunyuan3D can take 5-15 mins
        max_wait = 900 
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            history_resp = requests.get(f"{COMFYUI_URL}/history/{prompt_id}")
            history = history_resp.json()
            
            if prompt_id in history:
                result = history[prompt_id]
                
                if "outputs" in result:
                    outputs = result["outputs"]
                    output_files = []
                    
                    for node_id, node_output in outputs.items():
                        # Check for 3D mesh outputs (GLB, GLTF)
                        for key in ["mesh", "glb", "gltf", "output"]:
                            if key in node_output:
                                for model_file in node_output[key]:
                                    fname = model_file["filename"] if isinstance(model_file, dict) else model_file
                                    file_path = os.path.join(OUTPUT_DIR, fname)
                                    if os.path.exists(file_path):
                                        output_files.append(file_path)
                        
                        # Also check for image outputs
                        if "images" in node_output:
                            for img in node_output["images"]:
                                file_path = os.path.join(OUTPUT_DIR, img["filename"])
                                if os.path.exists(file_path):
                                    output_files.append(file_path)

                    if output_files:
                        print(f"✅ Generation complete! Files: {output_files}")
                        return {
                            "status": "success",
                            "files": output_files
                        }
                    else:
                        return {"error": "Workflow finished but no output files found"}
                else:
                    return {"error": "No outputs in workflow result"}
            
            time.sleep(5)
        
        return {"error": "Timeout waiting for Hunyuan3D generation (max 15 mins)"}
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return {"error": str(e)}


if __name__ == "__main__":
    start_comfyui_server()
    if wait_for_server():
        import runpod
        runpod.serverless.start({"handler": handler})
    else:
        print("❌ ComfyUI failed to start")
        sys.exit(1)
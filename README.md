# Hunyuan3D 2.1 on RunPod Serverless

[![Runpod](https://api.runpod.io/badge/hallvardvo/hunyuan3d-runpod)](https://console.runpod.io/hub/hallvardvo/hunyuan3d-runpod)

This setup runs the Hunyuan3D 2.1 model on RunPod serverless infrastructure.

## Build and Push (on Mac M1)

```bash
# Build for linux/amd64 platform
docker build --platform=linux/amd64 -t YOUR_DOCKERHUB_USERNAME/hunyuan3d-2.1:latest .

# Push to Docker Hub
docker push YOUR_DOCKERHUB_USERNAME/hunyuan3d-2.1:latest
```

## RunPod Setup

1. Go to [RunPod Serverless](https://www.runpod.io/console/serverless)
2. Create a new template:
   - Container Image: `YOUR_DOCKERHUB_USERNAME/hunyuan3d-2.1:latest`
   - Container Disk: 20 GB (or more depending on model size)
   - Expose HTTP Ports: 8188 (for ComfyUI)
3. Create a new endpoint using this template
4. Note your endpoint ID and API key

## API Usage

### Input Format

```json
{
  "input": {
    "image": "base64_encoded_image_or_url",
    "steps": 30,
    "seed": -1
  }
}
```

### Example with Python

```python
import runpod
import base64

runpod.api_key = "YOUR_RUNPOD_API_KEY"

# Read and encode image
with open("input.png", "rb") as f:
    image_data = base64.b64encode(f.read()).decode('utf-8')

# Run inference
endpoint = runpod.Endpoint("YOUR_ENDPOINT_ID")

run_request = endpoint.run({
    "input": {
        "image": image_data,
        "steps": 30,
        "seed": 42
    }
})

# Wait for completion
result = run_request.output()
print(result)
```

### Example with cURL

```bash
curl -X POST https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_RUNPOD_API_KEY" \
  -d '{
    "input": {
      "image": "https://example.com/image.png",
      "steps": 30,
      "seed": -1
    }
  }'
```

## n8n Integration

### n8n Workflow Setup

1. **HTTP Request Node** to send image to RunPod:
   - Method: POST
   - URL: `https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync`
   - Authentication: Header Auth
     - Name: `Authorization`
     - Value: `Bearer YOUR_RUNPOD_API_KEY`
   - Body:
     ```json
     {
       "input": {
         "image": "{{ $json.image_url }}",
         "steps": 30,
         "seed": -1
       }
     }
     ```

2. **Process Response** - Extract the generated 3D model from the response

### Example n8n Workflow JSON

```json
{
  "nodes": [
    {
      "parameters": {
        "method": "POST",
        "url": "https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "sendBody": true,
        "bodyParameters": {
          "parameters": [
            {
              "name": "input",
              "value": "={\"image\": \"{{ $json.image_url }}\", \"steps\": 30, \"seed\": -1}"
            }
          ]
        },
        "options": {}
      },
      "name": "RunPod Hunyuan3D",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.1,
      "position": [250, 300]
    }
  ]
}
```

## Parameters

- **image** (required): Base64 encoded image or URL to an image
- **steps** (optional): Number of generation steps (default: 30)
- **seed** (optional): Random seed for reproducibility (default: -1 for random)

## Output Format

```json
{
  "status": "completed",
  "outputs": [
    {
      "filename": "output.glb",
      "data": "base64_encoded_3d_model"
    }
  ],
  "prompt_id": "unique_prompt_id"
}
```

## Notes

- The first request may take longer as ComfyUI initializes
- Adjust the workflow in `handler.py` based on your specific Hunyuan3D ComfyUI setup
- For large models, consider increasing container disk size
- Use `/run` endpoint for async execution, `/runsync` for synchronous

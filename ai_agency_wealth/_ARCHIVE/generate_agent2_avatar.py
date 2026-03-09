import os
import argparse

def generate_avatar_local(prompt, output_path):
    """Generates the avatar using local GPU and diffusers (State of the Art OSS)."""
    try:
        import torch
        from diffusers import StableDiffusionXLPipeline
    except ImportError:
        print("❌ Missing required libraries. Install them via:")
        print("   pip install diffusers transformers accelerate torch")
        return

    print("🚀 Loading SOTA Open-Source Model (SDXL)...")
    pipe = StableDiffusionXLPipeline.from_pretrained(
        "stabilityai/stable-diffusion-xl-base-1.0", 
        torch_dtype=torch.float16, 
        use_safetensors=True
    )
    
    # Check for GPU
    if torch.cuda.is_available():
        pipe.to("cuda")
        print("✅ Using GPU (CUDA)")
    else:
        # Fallback to CPU (very slow, but works)
        pipe.to("cpu")
        print("⚠️ No GPU detected. Using CPU (this will take a while)...")
    
    print(f"🎨 Generating avatar with prompt: '{prompt}'")
    image = pipe(prompt, num_inference_steps=40).images[0]
    
    image.save(output_path)
    print(f"✅ Avatar successfully saved to: {os.path.abspath(output_path)}")

def generate_avatar_api(prompt, output_path, hf_token):
    """Generates the avatar using Hugging Face Serverless Inference API."""
    try:
        from huggingface_hub import InferenceClient
    except ImportError:
        print("❌ Missing required libraries. Install them via:")
        print("   pip install huggingface_hub pillow")
        return

    print("🚀 Calling Hugging Face API (State of the Art OSS Models)...")
    client = InferenceClient(model="black-forest-labs/FLUX.1-dev", token=hf_token)
    
    print(f"🎨 Generating avatar with prompt: '{prompt}'")
    try:
        image = client.text_to_image(prompt)
        image.save(output_path)
        print(f"✅ Avatar successfully saved to: {os.path.abspath(output_path)}")
    except Exception as e:
        print(f"❌ API generation failed: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Automated SOTA OSS AI Avatar Generator for Agent 2")
    parser.add_argument("--mode", choices=["local", "api"], default="api", help="Use local GPU (diffusers) or HF API")
    parser.add_argument("--token", type=str, help="Hugging Face API token (required for api mode if HF_TOKEN env var is not set)")
    parser.add_argument("--output", type=str, default="agent2_public_image.png", help="Output file path")
    
    args = parser.parse_args()
    
    # SOTA prompt for Yani Meziani's Digital Twin (Agent 2)
    PROMPT = (
        "A state-of-the-art futuristic AI avatar of Yani Meziani, the independent AI researcher. "
        "A professional cybernetic headshot, blending photorealistic human features with advanced "
        "holographic interfaces. Subtle glowing data streams and geometric overlays representing "
        "Hamiltonian state spaces and Akasha 2 neural architectures. Sleek, high-tech 'Pro and PR' "
        "aesthetic, 8k resolution, cinematic lighting, photorealistic, Unreal Engine 5 render style."
    )
    
    output_file = args.output
    
    if args.mode == "local":
        generate_avatar_local(PROMPT, output_file)
    else:
        token = args.token or os.environ.get("HF_TOKEN")
        if not token:
            print("❌ API Mode requires a Hugging Face Token.")
            print("   Set it via the --token argument or HF_TOKEN environment variable.")
            print("   Get a free token at: https://huggingface.co/settings/tokens")
            print("\n   Alternatively, use local mode: python generate_agent2_avatar.py --mode local")
            exit(1)
        generate_avatar_api(PROMPT, output_file, token)

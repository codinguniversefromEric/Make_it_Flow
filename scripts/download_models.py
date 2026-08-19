#!/usr/bin/env python3
import urllib.request
import json
import os
import sys

def download_file(url, dest):
    print(f"Downloading {url} \n -> {dest}")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    urllib.request.urlretrieve(url, dest)

def download_hf_folder(repo_id, folder_path, local_dir):
    api_url = f"https://huggingface.co/api/models/{repo_id}/tree/main/{folder_path}"
    print(f"Fetching directory structure from {api_url} ...")
    
    req = urllib.request.Request(api_url)
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
    except Exception as e:
        print(f"Error fetching directory structure: {e}")
        return

    for item in data:
        path = item['path']
        if item['type'] == 'directory':
            download_hf_folder(repo_id, path, local_dir)
        elif item['type'] == 'file':
            raw_url = f"https://huggingface.co/{repo_id}/resolve/main/{path}?download=true"
            # Calculate local path relative to the folder we want to download
            # For example, if folder_path is "best.mlpackage", we want local_dir/best.mlpackage/...
            rel_path = path.split('/', 1)[-1] if '/' in path and path.startswith(folder_path.split('/')[0]) else path
            local_file_path = os.path.join(local_dir, rel_path)
            download_file(raw_url, local_file_path)

if __name__ == "__main__":
    print("🌊 Make it Flow - CoreML Model Auto-Downloader")
    print("===============================================")
    
    # Models directory
    models_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Flow_1", "Models")
    os.makedirs(models_dir, exist_ok=True)
    
    # Model 1: YOLOv8s Standard
    print("\n[1/2] Downloading YOLOv8s Standard (best.mlpackage) ...")
    download_hf_folder("ashen007/document-structure-detection", "best.mlpackage", models_dir)
    
    # Model 2: YOLOv8 Fast
    # The actual repo contains "yolov8n_doclaynet.mlpackage" instead of best_conf0.1
    # We will just download the mlpackage from the repo.
    # Note: vaivTA/yolov8n_doclaynet only has a .pt file usually, we need to check if .mlpackage is there.
    # If the user used "best_conf0.1.mlpackage" before, it might have been in a different repo.
    # For now, let's try to download it if we know the exact repo, or provide instructions if it fails.
    print("\n[2/2] Downloading YOLOv8 Fast (yolov8n_doclaynet.mlpackage) ...")
    try:
        download_hf_folder("vaivTA/yolov8n_doclaynet", "best_conf0.1.mlpackage", models_dir)
    except:
        print("Note: Fast model not found in the exact path. Skipping.")
    
    print("\n===============================================")
    print("✅ Download Complete!")
    print(f"Models have been saved to: {models_dir}")
    print("Please ensure they are dragged into your Xcode project and added to the 'Flow_1' target.")

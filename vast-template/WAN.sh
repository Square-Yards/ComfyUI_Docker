#!/bin/bash

# Activate Vast.ai's ComfyUI virtual environment
source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI


APT_PACKAGES=(
    "ffmpeg"
)

PIP_PACKAGES=(
    "onnxruntime-gpu"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
    "https://github.com/Aryan185/ComfyUI-ExternalAPI-Helpers.git"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    "https://github.com/crystian/ComfyUI-Crystools"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
)

CHECKPOINT_MODELS=(
)

UNET_MODELS=(
    "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/HighNoise/Wan2.2-I2V-A14B-HighNoise-Q8_0.gguf"
    "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/LowNoise/Wan2.2-I2V-A14B-LowNoise-Q8_0.gguf"
    "https://huggingface.co/city96/Wan2.1-I2V-14B-720P-gguf/resolve/main/wan2.1-i2v-14b-720p-Q8_0.gguf"
    "https://huggingface.co/city96/Wan2.1-I2V-14B-480P-gguf/resolve/main/wan2.1-i2v-14b-480p-Q8_0.gguf"
)

LORA_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank128_bf16.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/FastWan/FastWan_T2V_14B_480p_lora_rank_128_bf16.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
)

ESRGAN_MODELS=(
)

CONTROLNET_MODELS=(
)

CLIP_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"
)

INSIGHTFACE_MODELS=(
)



function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_update_comfyui
    provisioning_download_models &
    provisioning_setup_dependencies &
    wait
    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_download_models() {
	echo "--- Starting model downloads in the background ---\n"
    provisioning_get_models "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/loras" "${LORA_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/upscale_models" "${ESRGAN_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/insightface" "${INSIGHTFACE_MODELS[@]}"
}

function provisioning_update_comfyui() {
    local target_version="${COMFYUI_VERSION:-latest}"

    printf "\nUpdating ComfyUI...\n"
    cd "${COMFYUI_DIR}" || return

    if [[ "${target_version,,}" == "latest" ]]; then
        printf "Updating to the latest version.\n"
        git checkout master
        git pull
    else
        printf "Checking out specific ComfyUI version: %s\n" "${target_version}"
        git fetch --all --tags
        git checkout "tags/${target_version}"
    fi

    printf "Installing/updating dependencies for this version...\n"
    pip install --no-cache-dir -r requirements.txt
}


function provisioning_setup_dependencies() {
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_install_sageattention3
}

function provisioning_install_sageattention3() {
    if [[ "${INSTALL_SAGEATTENTION,,}" != "true" ]]; then
        echo "INSTALL_SAGEATTENTION is not set to true, skipping SageAttention3 installation."
        return
    fi
    local repo_dir="${WORKSPACE}/SageAttention"
    if [[ ! -d "$repo_dir" ]]; then
        echo "Installing SageAttention3..."
        git clone https://$HF_USER:$HF_TOKEN@huggingface.co/jt-zhang/SageAttention3 "$repo_dir"
        cd "$repo_dir" || exit 1
        python setup.py install
    else
        echo "SageAttention3 already installed, skipping."
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n############################################## Your container will be ready on completion ##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}


# AI-Dock style download with skip-if-exists
function provisioning_download() {
    local url="$1"
    local output_dir="$2"
    local auth_token=""
    
    # Check for HuggingFace URLs
    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    # Check for CivitAI URLs
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi

    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Change to output directory
    cd "$output_dir" || exit

    # Skip if file already exists
    local filename=$(basename "$url")
    if [[ -f "$filename" ]]; then
        echo "File already exists, skipping: $filename"
        return
    fi

    # Download with or without authentication
    if [[ -n $auth_token ]]; then
        curl -L -J -O \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $auth_token" \
            --progress-bar \
            --retry 3 \
            "$url"
    else
        curl -L -J -O \
            -H "Content-Type: application/json" \
            --progress-bar \
            --retry 3 \
            "$url"
    fi
}

# Start provisioning unless disabled
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
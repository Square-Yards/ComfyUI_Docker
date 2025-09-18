#!/bin/bash

# Activate Vast.ai's ComfyUI virtual environment
source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI


APT_PACKAGES=(
    "ffmpeg"
)

PIP_PACKAGES=(

)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/Aryan185/ComfyUI-ExternalAPI-Helpers.git"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/crystian/ComfyUI-Crystools"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
)


VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro-2.0/resolve/main/diffusion_pytorch_model.safetensors"
)

DIFFUSION_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-Krea-dev/resolve/main/flux1-krea-dev.safetensors"
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors"
)

CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
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
    provisioning_get_models "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}"
}


function provisioning_setup_dependencies() {
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_install_sageattention2
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

function provisioning_install_sageattention2() {
    if [[ "${INSTALL_SAGEATTENTION,,}" != "true" ]]; then
        echo "INSTALL_SAGEATTENTION is not set to true, skipping SageAttention2 installation."
        return
    fi
    local repo_dir="${WORKSPACE}/SageAttention"
    if [[ ! -d "$repo_dir" ]]; then
        echo "Installing SageAttention2..."
        git clone https://github.com/thu-ml/SageAttention.git "$repo_dir"
        cd "$repo_dir" || exit 1
        pip install .
    else
        echo "SageAttention2 already installed, skipping."
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
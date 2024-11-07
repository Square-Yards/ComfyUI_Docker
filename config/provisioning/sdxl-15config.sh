#!/bin/bash

# This file will be sourced in init.sh

# https://raw.githubusercontent.com/ai-dock/comfyui/main/config/provisioning/default.sh

# Packages are installed after nodes so we can fix them...

#DEFAULT_WORKFLOW="https://..."

APT_PACKAGES=(
    "ffmpeg"
)

PIP_PACKAGES=(
    "xformers"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/Extraltodeus/ComfyUI-AutomaticCFG"
    "https://github.com/Extraltodeus/Skimmed_CFG"
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/replicate/comfyui-replicate"
    "https://github.com/storyicon/comfyui_segment_anything"
    "https://github.com/BadCafeCode/masquerade-nodes-comfyui"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/crystian/ComfyUI-Crystools"
)

CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/50722?type=Model&format=PickleTensor&size=full&fp=fp32"
    "https://civitai.com/api/download/models/50722?type=Model&format=PickleTensor&size=full&fp=fp32"
    "https://civitai.com/api/download/models/274039?type=Model&format=SafeTensor&size=pruned&fp=fp16"
    "https://civitai.com/api/download/models/479285?type=Model&format=SafeTensor&size=full&fp=fp16"
    "https://civitai.com/api/download/models/782002?type=Model&format=SafeTensor&size=full&fp=fp16"
    "https://civitai.com/api/download/models/920957?type=Model&format=SafeTensor&size=full&fp=fp16"
)


UNET_MODELS=(

)

LORA_MODELS=(
    "https://huggingface.co/digiplay/LORA/resolve/main/more_details.safetensors"
    "https://civitai.com/api/download/models/236130?type=Model&format=SafeTensor" #https://civitai.com/models/171159/sdxlrender
    "https://civitai.com/api/download/models/135867?type=Model&format=SafeTensor" #https://civitai.com/models/122359/detail-tweaker-xl
    "https://civitai.com/api/download/models/383563?type=Model&format=SafeTensor" #https://civitai.com/models/229213/extremely-detailed-no-trigger-slidersntcaixyz
    "https://civitai.com/api/download/models/678485?type=Model" #https://civitai.com/models/251417/midjourney-mimic
    "https://civitai.com/api/download/models/623945?type=Model&format=SafeTensor" #https://civitai.com/models/430687?modelVersionId=623945
)

VAE_MODELS=(
    # "https://huggingface.co/stabilityai/sd-vae-ft-ema-original/resolve/main/vae-ft-ema-560000-ema-pruned.safetensors"
    # "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors"
    # "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors"
)

ESRGAN_MODELS=(
    "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth"
    "https://huggingface.co/datasets/jibopabo/upscalers/resolve/main/4xNomosUniDAT_otf.pth"

)

CONTROLNET_MODELS=(
    "https://huggingface.co/abovzv/sdxl_segmentation_controlnet_ade20k/resolve/main/sdxl_segmentation_ade20k_controlnet.safetensors"
    "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11f1e_sd15_tile_fp16.safetensors"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui
    git config --local core.excludesfile ~/.config/git/ignore
    git config --local core.excludesfile ~/.config/git/attributes
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/ckpt" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    provisioning_print_end
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
            "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
        else
            micromamba run -n comfyui pip install --no-cache-dir "$@"
        fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_default_workflow() {
    if [[ -n $DEFAULT_WORKFLOW ]]; then
        workflow_json=$(curl -s "$DEFAULT_WORKFLOW")
        if [[ -n $workflow_json ]]; then
            echo "export const defaultGraph = $workflow_json;" > /opt/ComfyUI/web/scripts/defaultGraph.js
        fi
    fi
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
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
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

provisioning_start
git lfs install;
git clone https://Sidd065:$HF_TOKEN@huggingface.co/squareyards/Diffusion_Models;
# rm -r -f /workspace/ComfyUI/models/*;
mkdir -p /workspace/ComfyUI/models;
mv -f Diffusion_Models/* /workspace/ComfyUI/models/;
rm -r -f Diffusion_Models;
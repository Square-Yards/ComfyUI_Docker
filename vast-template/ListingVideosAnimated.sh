#!/bin/bash
set -eo pipefail

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

APT_PACKAGES=(
    "ffmpeg"
	"libgl1"
    "libvulkan1"
)

PIP_PACKAGES=(
    "onnxruntime"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
    "https://github.com/Aryan185/ComfyUI-ExternalAPI-Helpers.git"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    "https://github.com/crystian/ComfyUI-Crystools"
    "https://github.com/Extraltodeus/ComfyUI-AutomaticCFG.git"
    "https://github.com/shiimizu/ComfyUI-TiledDiffusion.git"
    "https://github.com/ClownsharkBatwing/RES4LYF.git"
	"https://github.com/ltdrdata/was-node-suite-comfyui.git"
    "https://github.com/cubiq/ComfyUI_essentials.git"
)

DIFFUSION_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Multi_fp8_e4m3fn_scaled_KJ.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-720P_fp8_e4m3fn.safetensors"
    "https://huggingface.co/theunlikely/Qwen-Image-Edit-2509/resolve/main/qwen_image_edit_2509_fp8_e4m3fn.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_fun_camera_high_noise_14B_fp8_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_fun_camera_low_noise_14B_fp8_scaled.safetensors"

)

LORA_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank128_bf16.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/FastWan/FastWan_T2V_14B_480p_lora_rank_128_bf16.safetensors"
    "https://civitai.com/api/download/models/2159983?type=Model&format=SafeTensor"
    "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V1.0.safetensors"
    "https://civitai.com/api/download/models/87153?type=Model&format=SafeTensor"
    "https://civitai.com/api/download/models/236130?type=Model&format=SafeTensor"
)

VAE_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"
)

CLIP_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
)

CLIP_VISION=(
	"https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)

ESRGAN_MODELS=(
    "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x2.pth"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/comfyanonymous/ControlNet-v1-1_fp16_safetensors/resolve/main/control_v11f1e_sd15_tile_fp16.safetensors"
)

CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/274039?type=Model&format=SafeTensor&size=pruned&fp=fp16"
)

function provisioning_start() {
    rm -f /etc/supervisor/conf.d/cron.conf
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_update_comfyui
    provisioning_download_models &
    provisioning_setup_dependencies &
    provisioning_install_custom_code &
    provisioning_start_comfy_5000
    wait
    supervisorctl reload
    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo apt-get update
        sudo apt-get install -y ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}


function provisioning_download_models() {
	echo "--- Starting model downloads in the background ---\n"
    provisioning_get_models "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}" &
    provisioning_get_models "${COMFYUI_DIR}/models/loras" "${LORA_MODELS[@]}" &
    provisioning_get_models "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}" &
    provisioning_get_models "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}" &
    provisioning_get_models "${COMFYUI_DIR}/models/clip_vision" "${CLIP_VISION[@]}" &
    provisioning_get_models "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}" &
    provisioning_get_models "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}" &
    provisioning_get_models "${COMFYUI_DIR}/models/upscale_models" "${ESRGAN_MODELS[@]}" &
}


function provisioning_install_rife() {
    wget -q https://github.com/nihui/rife-ncnn-vulkan/releases/download/20221029/rife-ncnn-vulkan-20221029-ubuntu.zip
    unzip -q rife-ncnn-vulkan-20221029-ubuntu.zip
    mv rife-ncnn-vulkan-20221029-ubuntu/rife-ncnn-vulkan /usr/local/bin/
    chmod +x /usr/local/bin/rife-ncnn-vulkan
    mv rife-ncnn-vulkan-20221029-ubuntu/rife-v4.6 .
    rm -rf rife-ncnn-vulkan-20221029-ubuntu*
}


function provisioning_start_comfy_5000() {
    cat <<EOF > /etc/supervisor/conf.d/comfyui-5000.conf
[program:comfyui-5000]
directory=${COMFYUI_DIR}
command=/venv/main/bin/python main.py --listen --normalvram --reserve-vram 16 --port 5000 --disable-xformers --use-pytorch-cross-attention
autostart=true
autorestart=true
stdout_logfile=/var/log/comfyui-5000.log
stderr_logfile=/var/log/comfyui-5000.err.log
environment=PYTHONUNBUFFERED=1
EOF
}

function provisioning_setup_dependencies() {
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_install_sageattention3
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

function provisioning_install_custom_code() {
    cd /root/
	git clone https://$GITHUB_API_TOKEN@github.com/Square-Yards/ListingVideos-LS.git
	cd ListingVideos-LS
    git checkout Animated
    provisioning_install_rife
    python3 -m venv venv
    ./venv/bin/pip install -r requirements.txt
    echo -e "GOOGLE_API_KEY=${GOOGLE_API_KEY}\nGOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS}\nCOMFY_ENDPOINT_1=127.0.0.1:8188\nCOMFY_ENDPOINT_2=127.0.0.1:5000" > .env
    mv /root/params.json .
}

function run_custom_code_with_supervisor() {
    echo '#!/bin/bash
while [ -f "/.provisioning" ]; do
    echo "Waiting for instance provisioning to complete..."
    sleep 5
done
echo "Provisioning complete. Starting ListingVideos-LS pipeline..."
cd /root/ListingVideos-LS
./venv/bin/python3 main.py
' > /opt/supervisor-scripts/listingvideos.sh

    chmod +x /opt/supervisor-scripts/listingvideos.sh

    echo '[program:listingvideos]
command=/opt/supervisor-scripts/listingvideos.sh
autostart=true
autorestart=true
stdout_logfile=/var/log/portal/listingvideos.log
stderr_logfile=/var/log/portal/listingvideos.err.log
' > /etc/supervisor/conf.d/listingvideos.conf
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
    done
}

function provisioning_print_header() {
    printf "\n############################################## Your container will be ready on completion ##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

function provisioning_download() {
    local url="$1"
    local output_dir="$2"
    local auth_token=""
    
    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi

    mkdir -p "$output_dir"
    cd "$output_dir" || exit

    local filename=$(basename "$url")
    if [[ -f "$filename" ]]; then
        echo "File already exists, skipping: $filename"
        return
    fi

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

if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
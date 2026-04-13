#!/bin/bash
set -eo pipefail
 
source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI
 
APT_PACKAGES=(
    "ffmpeg"
	"libgl1"
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
	"https://github.com/ltdrdata/was-node-suite-comfyui.git"
    "https://github.com/cubiq/ComfyUI_essentials.git"
	"https://github.com/Aryan185/ComfyUI-VertexAPI.git"
)
 
DIFFUSION_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Multi_fp8_e4m3fn_scaled_KJ.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-720P_fp8_e4m3fn.safetensors"
    "https://huggingface.co/black-forest-labs/FLUX.2-klein-4b-fp8/resolve/main/flux-2-klein-4b-fp8.safetensors"
	"https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/diffusion_models/ltx-2.3-22b-distilled_transformer_only_fp8_input_scaled_v3.safetensors"
 
)
 
LORA_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank128_bf16.safetensors"
	"https://huggingface.co/squareyards/LTX-2.3-camera-lora/resolve/main/ltx-2.3-22b-lora-camera-arcshot.safetensors"
	"https://huggingface.co/squareyards/LTX-2.3-camera-lora/resolve/main/ltx-2.3-22b-lora-camera-kenburn.safetensors"
	"https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-In/resolve/main/ltx-2-19b-lora-camera-control-dolly-in.safetensors"
)
 
VAE_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors"
	"https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_audio_vae_bf16.safetensors"
	"https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_video_vae_bf16.safetensors"
)
 
CLIP_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors"
	"https://huggingface.co/GitMylo/LTX-2-comfy_gemma_fp8_e4m3fn/resolve/main/gemma_3_12B_it_fp8_e4m3fn.safetensors"
	"https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/text_encoders/ltx-2.3_text_projection_bf16.safetensors"
)
 
CLIP_VISION=(
	"https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)
 
function provisioning_start() {
    rm -f /etc/supervisor/conf.d/cron.conf
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_update_comfyui
    provisioning_download_models &
    provisioning_setup_dependencies &
    provisioning_start_comfy_5000 &
    provisioning_start_comfy_5001 &
    provisioning_setup_vibevoice
    provisioning_setup_projectvideos
    provisioning_supervisor_vibevoice
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
    provisioning_get_models "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/loras" "${LORA_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}"
    provisioning_get_models "${COMFYUI_DIR}/models/clip_vision" "${CLIP_VISION[@]}"
}
 
 
function provisioning_start_comfy_5000() {
    cat <<EOF > /etc/supervisor/conf.d/comfyui-5000.conf
[program:comfyui-5000]
directory=${COMFYUI_DIR}
command=/venv/main/bin/python main.py --listen --normalvram --port 5000 --use-sage-attention
autostart=true
autorestart=true
stdout_logfile=/var/log/comfyui-5000.log
stderr_logfile=/var/log/comfyui-5000.err.log
environment=PYTHONUNBUFFERED=1
EOF
}

function provisioning_start_comfy_5001() {
    cat <<EOF > /etc/supervisor/conf.d/comfyui-5001.conf
[program:comfyui-5001]
directory=${COMFYUI_DIR}
command=/venv/main/bin/python main.py --listen --normalvram --port 5001 --use-sage-attention
autostart=true
autorestart=true
stdout_logfile=/var/log/comfyui-5001.log
stderr_logfile=/var/log/comfyui-5001.err.log
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

function provisioning_setup_vibevoice() {
    cd /root/
    git clone https://$GITHUB_API_TOKEN@github.com/Square-Yards/VibeVoiceTTS.git
    cd VibeVoiceTTS
    git clone https://huggingface.co/vibevoice/VibeVoice-7B
    conda create -n vibe python=3.11 -y
    conda run -n vibe pip install -r requirements.txt
}

function provisioning_setup_projectvideos() {
    cd /root/
    git clone https://$GITHUB_API_TOKEN@github.com/Square-Yards/ProjectVideos-Adobe.git
    cd ProjectVideos-Adobe
    if [[ "${is_portrait,,}" == "true" ]]; then
        git checkout PortraitServer
    else
        git checkout LandscapeServer
    fi
    conda create -n proj python=3.10 -y
    conda run -n proj pip install -r requirements.txt
    
    # Setup .env
    echo -e "GOOGLE_API_KEY=${GOOGLE_API_KEY}\nGOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS}\nCOMFY_ENDPOINT_1=127.0.0.1:8188\nCOMFY_ENDPOINT_2=127.0.0.1:5000\nCOMFY_ENDPOINT_3=127.0.0.1:5001\nADOBE_ENDPOINT=${ADOBE_ENDPOINT}\nVIBETTS_ENDPOINT=127.0.0.1:8000" > .env
}

function provisioning_supervisor_vibevoice() {
    echo '#!/bin/bash
while [ -f "/.provisioning" ]; do
    sleep 5
done
cd /root/VibeVoiceTTS
/venv/vibe/bin/python app.py
' > /opt/supervisor-scripts/vibevoice.sh
    chmod +x /opt/supervisor-scripts/vibevoice.sh

    echo '[program:vibevoice]
command=/opt/supervisor-scripts/vibevoice.sh
autostart=true
autorestart=true
stdout_logfile=/var/log/vibevoice.log
stderr_logfile=/var/log/vibevoice.err.log
' > /etc/supervisor/conf.d/vibevoice.conf
}

function provisioning_supervisor_projectvideos() {
    echo '#!/bin/bash
while [ -f "/.provisioning" ]; do
    sleep 5
done
cd /root/ProjectVideos-Adobe
/venv/proj/bin/python main.py
' > /opt/supervisor-scripts/projectvideos.sh
    chmod +x /opt/supervisor-scripts/projectvideos.sh

    echo '[program:projectvideos]
command=/opt/supervisor-scripts/projectvideos.sh
autostart=true
autorestart=true
stdout_logfile=/var/log/projectvideos.log
stderr_logfile=/var/log/projectvideos.err.log
' > /etc/supervisor/conf.d/projectvideos.conf
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

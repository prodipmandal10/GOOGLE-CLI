#!/bin/bash

# ---------- Colors ----------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD='\033[1m'
RESET="\e[0m"

# ---------- Function: Header with new design ----------
print_header() {
    clear
    echo -e "${YELLOW}${BOLD}=====================================================${RESET}"
    echo -e "${YELLOW}${BOLD}      🌟 GOOGLE GCP VM CREATOR 🌟      ${RESET}"
    echo -e "${YELLOW}${BOLD}      # # # # # MADE BY PRODI # # # # #      ${RESET}"
    echo -e "${YELLOW}${BOLD}=====================================================${RESET}"
    echo ""
}

# ---------- Function: Fresh Install + CLI Setup ----------
fresh_install() {
    echo -e "${CYAN}Running Fresh Install + CLI Setup...${RESET}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git unzip python3 python3-pip docker.io
    sudo systemctl enable docker --now

    if ! command -v gcloud &> /dev/null
    then
        echo -e "${YELLOW}Gcloud CLI not found. Installing...${RESET}"
        curl https://sdk.cloud.google.com | bash
        exec -l $SHELL
    else
        echo -e "${GREEN}Gcloud CLI already installed.${RESET}"
    fi

    echo -e "${YELLOW}Now login to your Google Account:${RESET}"
    gcloud auth login
    echo -e "${GREEN}Setup complete!${RESET}"
    read -p "Press Enter to continue..."
}

# ---------- Function: Create VM (pre-filled defaults) ----------
create_vm() {
    echo -e "${YELLOW}Create a new VM:${RESET}"
    read -p "Enter VM Name: " vmname
    read -p "Enter SSH Public Key (username:ssh-rsa ...): " sshkey

    # Default values
    zone="asia-southeast1-b"
    mtype="n2d-custom-4-20480"
    disksize="60"

    echo -e "${GREEN}Creating VM $vmname in zone $zone with default settings...${RESET}"
    gcloud compute instances create $vmname \
        --zone=$zone \
        --machine-type=$mtype \
        --image-family=ubuntu-2404-lts-amd64 \
        --image-project=ubuntu-os-cloud \
        --boot-disk-size=${disksize}GB \
        --boot-disk-type=pd-balanced \
        --metadata ssh-keys="$sshkey"

    echo -e "${GREEN}VM $vmname created successfully!${RESET}"
    read -p "Press Enter to continue..."
}

# ---------- Function: Create New Project (auto ID) ----------
create_project() {
    echo -e "${YELLOW}Create a new GCP Project:${RESET}"
    read -p "Enter Project Name: " projname

    # Auto-generate base project ID: lowercase, replace spaces with hyphens
    baseid=$(echo "$projname" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # Add random 3-digit suffix to avoid ID clash
    projid="${baseid}-$(shuf -i 100-999 -n 1)"

    gcloud projects create "$projid" --name="$projname" --set-as-default

    echo -e "${GREEN}Project created successfully!${RESET}"
    echo "Project ID: $projid"
    echo "Project Name: $projname"
    read -p "Press Enter to continue..."
}

# ---------- Main Menu ----------
while true; do
    print_header
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${YELLOW}${BOLD}║      GCP CLI ONE-CLICK MENU      ║${RESET}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════╣${RESET}"
    echo -e "${YELLOW}${BOLD}║ [${CYAN}1${YELLOW}${BOLD}] ${RESET}Fresh Install + CLI Setup               ${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║ [${CYAN}2${YELLOW}${BOLD}] ${RESET}Change Google Account                   ${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║ [${CYAN}3${YELLOW}${BOLD}] ${RESET}Create New Project                      ${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║ [${CYAN}4${YELLOW}${BOLD}] ${RESET}Switch Project                          ${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║ [${CYAN}5${YELLOW}${BOLD}] ${RESET}List VMs                                ${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║ [${CYAN}6${YELLOW}${BOLD}] ${RESET}Show SSH Keys Metadata                  ${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║ [${CYAN}7${YELLOW}${BOLD}] ${RESET}Show Entire SSH Key for a VM            ${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║ [${CYAN}8${YELLOW}${BOLD}] ${RESET}Create VM (pre-filled defaults)         ${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}║ [${CYAN}9${YELLOW}${BOLD}] ${RESET}Exit                                    ${YELLOW}${BOLD}║${RESET}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
    echo ""
    read -p "Choose an option [1-9]: " choice

    case $choice in
        1) fresh_install ;;
        2)
            echo -e "${YELLOW}Logging into new Google Account...${RESET}"
            gcloud auth login
            read -p "Press Enter to continue..."
            ;;
        3) create_project ;;
        4)
            echo -e "${YELLOW}Available Projects:${RESET}"
            gcloud projects list --format="table(projectId,name)"
            read -p "Enter PROJECT_ID to switch: " projid
            gcloud config set project $projid
            echo -e "${GREEN}Project switched to $projid${RESET}"
            read -p "Press Enter to continue..."
            ;;
        5)
            echo -e "${YELLOW}Listing all VMs in current project:${RESET}"
            gcloud compute instances list --format="table(name,zone,machineType,STATUS,INTERNAL_IP,EXTERNAL_IP)"
            read -p "Press Enter to continue..."
            ;;
        6)
            echo -e "${YELLOW}SSH Keys Metadata:${RESET}"
            gcloud compute project-info describe --format="value(commonInstanceMetadata.items)"
            read -p "Press Enter to continue..."
            ;;
        7)
            echo -e "${YELLOW}Enter VM Name to show entire SSH Key:${RESET}"
            read -p "VM Name: " vmname
            zone=$(gcloud compute instances list --filter="name=$vmname" --format="value(zone)")
            if [ -z "$zone" ]; then
                echo -e "${RED}VM not found!${RESET}"
            else
                echo -e "${GREEN}SSH Key for $vmname:${RESET}"
                gcloud compute instances describe $vmname --zone $zone --format="get(metadata.ssh-keys)"
            fi
            read -p "Press Enter to continue..."
            ;;
        8) create_vm ;;
        9)
            echo -e "${RED}Exiting...${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice!${RESET}"
            read -p "Press Enter to continue..."
            ;;
    esac
done

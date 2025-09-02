#!/bin/bash

# ---------- Colors ----------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

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
    projid="${baseid}-$(shuf -i 100-999 -n 1)"

    gcloud projects create "$projid" --name="$projname" --set-as-default

    echo -e "${GREEN}Project created successfully!${RESET}"
    echo "Project ID: $projid"
    echo "Project Name: $projname"
    read -p "Press Enter to continue..."
}

# ---------- Function: Delete VM (with disk) ----------
delete_vm() {
    echo -e "${YELLOW}Listing available VMs...${RESET}"
    gcloud compute instances list --format="table(name,zone,status)"

    read -p "Enter VM NAME to delete: " VM_NAME
    read -p "Enter ZONE of the VM: " VM_ZONE

    if [ -z "$VM_NAME" ] || [ -z "$VM_ZONE" ]; then
        echo -e "${RED}VM Name or Zone missing!${RESET}"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "${CYAN}Deleting VM '$VM_NAME' and its boot disk in zone '$VM_ZONE'...${RESET}"
    gcloud compute instances delete "$VM_NAME" --zone="$VM_ZONE" --quiet

    echo -e "${GREEN}VM Deleted Successfully along with its disk!${RESET}"
    read -p "Press Enter to continue..."
}

# ---------- Function: Check Free Trial Credit ----------
check_credit() {
    echo -e "${YELLOW}Checking Free Trial Credit (in USD)...${RESET}"

    BILLING_ACCOUNT=$(gcloud beta billing accounts list --format="value(name)" --limit=1)
    if [ -z "$BILLING_ACCOUNT" ]; then
        echo -e "${RED}No billing account found!${RESET}"
    else
        CREDIT=$(gcloud beta billing accounts describe $BILLING_ACCOUNT \
            --format="value(balance.amount)")

        if [ -z "$CREDIT" ]; then
            echo -e "${RED}Unable to fetch credit. Maybe free trial expired or no billing enabled.${RESET}"
        else
            echo -e "${GREEN}Your Free Trial Credit: $CREDIT USD${RESET}"
        fi
    fi
    read -p "Press Enter to continue..."
}

# ---------- Main Menu ----------
while true; do
    clear
    echo -e "${CYAN}===== GCP CLI ONE-CLICK MENU =====${RESET}"
    echo "1) Fresh Install + CLI Setup"
    echo "2) Change Google Account"
    echo "3) Create New Project"
    echo "4) Switch Project"
    echo "5) List VMs"
    echo "6) Show SSH Keys Metadata"
    echo "7) Show Entire SSH Key for a VM"
    echo "8) Create VM (pre-filled defaults)"
    echo "9) Delete VM (with disk)"
    echo "10) Check Free Trial Credit (USD)"
    echo "11) Exit"
    echo
    read -p "Choose an option [1-11]: " choice

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
        9) delete_vm ;;
        10) check_credit ;;
        11)
            echo -e "${RED}Exiting...${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice!${RESET}"
            read -p "Press Enter to continue..."
            ;;
    esac
done

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

    # Add random 3-digit suffix to avoid ID clash
    projid="${baseid}-$(shuf -i 100-999 -n 1)"

    gcloud projects create "$projid" --name="$projname" --set-as-default

    echo -e "${GREEN}Project created successfully!${RESET}"
    echo "Project ID: $projid"
    echo "Project Name: $projname"

    echo -e "${YELLOW}Do you want to link a billing account now? (y/n):${RESET}"
    read choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        link_billing $projid
    fi

    read -p "Press Enter to continue..."
}

# ---------- Function: Switch Project ----------
switch_project() {
    echo -e "${YELLOW}Available Projects:${RESET}"
    gcloud projects list --format="table(projectId,name)"
    read -p "Enter PROJECT_ID to switch: " projid
    gcloud config set project $projid
    echo -e "${GREEN}Project switched to $projid${RESET}"
    read -p "Press Enter to continue..."
}

# ---------- Function: List VMs ----------
list_vms() {
    echo -e "${YELLOW}Listing all VMs in current project:${RESET}"
    gcloud compute instances list --format="table(name,zone,machineType,STATUS,INTERNAL_IP,EXTERNAL_IP)"
    read -p "Press Enter to continue..."
}

# ---------- Function: Show SSH Keys Metadata ----------
show_ssh_metadata() {
    echo -e "${YELLOW}SSH Keys Metadata:${RESET}"
    gcloud compute project-info describe --format="value(commonInstanceMetadata.items)"
    read -p "Press Enter to continue..."
}

# ---------- Function: Show Entire SSH Key ----------
show_ssh_key() {
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
}

# ---------- Function: Show Billing Accounts ----------
show_billing_accounts() {
    echo -e "${YELLOW}Available Billing Accounts:${RESET}"
    gcloud beta billing accounts list
    read -p "Press Enter to continue..."
}

# ---------- Function: Link Billing to Project ----------
link_billing() {
    project_id=$1
    echo -e "${YELLOW}Link a billing account to project $project_id:${RESET}"
    gcloud beta billing accounts list --format="table(name,accountId)"
    read -p "Enter ACCOUNT_ID to link: " account_id
    gcloud beta billing projects link $project_id --billing-account $account_id
    echo -e "${GREEN}Billing linked successfully!${RESET}"
    read -p "Press Enter to continue..."
}

# ---------- Function: Delete VM ----------
delete_vm() {
    read -p "Enter VM Name to delete: " vmname
    zone=$(gcloud compute instances list --filter="name=$vmname" --format="value(zone)")
    if [ -z "$zone" ]; then
        echo -e "${RED}VM not found!${RESET}"
    else
        gcloud compute instances delete $vmname --zone $zone --quiet
        echo -e "${GREEN}VM $vmname deleted successfully!${RESET}"
    fi
    read -p "Press Enter to continue..."
}

# ---------- Function: Check Free Trial Credit ----------
check_credit() {
    echo -e "${YELLOW}Checking remaining Free Trial credit:${RESET}"
    gcloud alpha billing accounts list --format="table(displayName,name,open,creditAmount,creditBalance)"
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
    echo "9) Delete VM"
    echo "10) Show Billing Accounts / Link Billing"
    echo "11) Check Free Trial Credit"
    echo "12) Exit"
    echo
    read -p "Choose an option [1-12]: " choice

    case $choice in
        1) fresh_install ;;
        2)
            echo -e "${YELLOW}Logging into new Google Account...${RESET}"
            gcloud auth login
            read -p "Press Enter to continue..."
            ;;
        3) create_project ;;
        4) switch_project ;;
        5) list_vms ;;
        6) show_ssh_metadata ;;
        7) show_ssh_key ;;
        8) create_vm ;;
        9) delete_vm ;;
        10)
            echo -e "${CYAN}1) Show Billing Accounts"
            echo "2) Link Billing to Project"
            read -p "Choose an option [1-2]: " subchoice
            case $subchoice in
                1) show_billing_accounts ;;
                2)
                    read -p "Enter Project ID to link billing: " projid
                    link_billing $projid
                    ;;
                *) echo -e "${RED}Invalid choice!${RESET}" ; read -p "Press Enter to continue..." ;;
            esac
            ;;
        11) check_credit ;;
        12) echo -e "${RED}Exiting...${RESET}" ; exit 0 ;;
        *) echo -e "${RED}Invalid choice!${RESET}" ; read -p "Press Enter to continue..." ;;
    esac
done

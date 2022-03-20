#!/bin/bash
#set -e
##################################################################################################################
# Author    : Erik Dubois
# Website : https://www.erikdubois.be
# Website : https://www.alci.online
# Website   : https://www.arcolinux.info
# Website   : https://www.arcolinux.com
# Website   : https://www.arcolinuxd.com
# Website   : https://www.arcolinuxb.com
# Website   : https://www.arcolinuxiso.com
# Website   : https://www.arcolinuxforum.com
##################################################################################################################
#
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
##################################################################################################################
#tput setaf 0 = black 
#tput setaf 1 = red 
#tput setaf 2 = green
#tput setaf 3 = yellow 
#tput setaf 4 = dark blue 
#tput setaf 5 = purple
#tput setaf 6 = cyan 
#tput setaf 7 = gray 
#tput setaf 8 = light blue
##################################################################################################################


set -euo pipefail
IFS=$'\n\t'

GRUB_THEME='poly-dark'
INSTALLER_LANG='English'

# Check dependencies
INSTALLER_DEPENDENCIES=(
    'mktemp'
    'sed'
    'sort'
    'sudo'
    'tar'
    'tee'
    'tr'
    'wget'
)

for i in "${INSTALLER_DEPENDENCIES[@]}"; do
    command -v $i > /dev/null 2>&1 || {
        echo >&2 "'$i' command is required, but not available. Aborting.";
        exit 1;
    }
done

# Change to temporary directory
cd $(mktemp -d)

# Pre-authorise sudo
sudo echo

# Select language, optional
declare -A INSTALLER_LANGS=(
    [Chinese]=zh_CN
    [English]=EN
    [French]=FR
    [German]=DE
    [Italian]=IT
    [Norwegian]=NO
    [Portuguese]=PT
    [Russian]=RU
    [Spanish]=ES
    [Turkish]=TR
    [Ukrainian]=UA
)

INSTALLER_LANG_NAMES=($(echo ${!INSTALLER_LANGS[*]} | tr ' ' '\n' | sort -n))

PS3='Please select language #: '
select l in "${INSTALLER_LANG_NAMES[@]}"; do
    if [[ -v INSTALLER_LANGS[$l] ]]; then
        INSTALLER_LANG=$l
        break
    else
        echo 'No such language, try again'
    fi
done < /dev/tty

echo 'Fetching and unpacking theme'
wget -O - https://github.com/shvchk/${GRUB_THEME}/archive/master.tar.gz | tar -xzf - --strip-components=1

if [[ "$INSTALLER_LANG" != "English" ]]; then
    echo "Changing language to ${INSTALLER_LANG}"
    sed -i -r -e '/^\s+# EN$/{n;s/^(\s*)/\1# /}' \
              -e '/^\s+# '"${INSTALLER_LANGS[$INSTALLER_LANG]}"'$/{n;s/^(\s*)#\s*/\1/}' theme.txt
fi

# Detect distro and set GRUB location and update method
GRUB_DIR='grub'
UPDATE_GRUB=''
BOOT_MODE='legacy'

if [[ -d /boot/efi && -d /sys/firmware/efi ]]; then
    BOOT_MODE='UEFI'
fi

echo "Boot mode: ${BOOT_MODE}"

if [[ -e /etc/os-release ]]; then

    ID=""
    ID_LIKE=""
    source /etc/os-release

    if [[ "$ID" =~ (debian|ubuntu|solus|void) || \
          "$ID_LIKE" =~ (debian|ubuntu|void) ]]; then

        UPDATE_GRUB='update-grub'

    elif [[ "$ID" =~ (arch|gentoo) || \
            "$ID_LIKE" =~ (archlinux|gentoo) ]]; then

        UPDATE_GRUB='grub-mkconfig -o /boot/grub/grub.cfg'

    elif [[ "$ID" =~ (centos|fedora|opensuse) || \
            "$ID_LIKE" =~ (fedora|rhel|suse) ]]; then

        GRUB_DIR='grub2'
        GRUB_CFG='/boot/grub2/grub.cfg'

        if [[ "$BOOT_MODE" = "UEFI" ]]; then
            GRUB_CFG="/boot/efi/EFI/${ID}/grub.cfg"
        fi

        UPDATE_GRUB="grub2-mkconfig -o ${GRUB_CFG}"

        # BLS etries have 'kernel' class, copy corresponding icon
        if [[ -d /boot/loader/entries && -e icons/${ID}.png ]]; then
            cp icons/${ID}.png icons/kernel.png
        fi
    fi
fi

echo 'Creating GRUB themes directory'
sudo mkdir -p /boot/${GRUB_DIR}/themes/${GRUB_THEME}

echo 'Copying theme to GRUB themes directory'
sudo cp -r * /boot/${GRUB_DIR}/themes/${GRUB_THEME}

echo 'Removing other themes from GRUB config'
sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub

echo 'Making sure GRUB uses graphical output'
sudo sed -i 's/^\(GRUB_TERMINAL\w*=.*\)/#\1/' /etc/default/grub

echo 'Removing empty lines at the end of GRUB config' # optional
sudo sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /etc/default/grub

echo 'Adding new line to GRUB config just in case' # optional
echo | sudo tee -a /etc/default/grub

echo 'Adding theme to GRUB config'
echo "GRUB_THEME=/boot/${GRUB_DIR}/themes/${GRUB_THEME}/theme.txt" | sudo tee -a /etc/default/grub

echo 'Removing theme installation files'
rm -rf "$PWD"
cd

echo 'Updating GRUB'
if [[ $UPDATE_GRUB ]]; then
    eval sudo "$UPDATE_GRUB"
else
    cat << '    EOF'
    --------------------------------------------------------------------------------
    Cannot detect your distro, you will need to run `grub-mkconfig` (as root) manually.

    Common ways:
    - Debian, Ubuntu, Solus and derivatives: `update-grub` or `grub-mkconfig -o /boot/grub/grub.cfg`
    - RHEL, CentOS, Fedora, SUSE and derivatives: `grub2-mkconfig -o /boot/grub2/grub.cfg`
    - Arch, Gentoo and derivatives: `grub-mkconfig -o /boot/grub/grub.cfg`
    --------------------------------------------------------------------------------
    EOF
fi

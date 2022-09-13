#!/bin/bash
#             black	  red   green	  yellow  blue  magenta cyan  white
# foreground  30    	31	  32	    33	    34	  35	    36	  37
# background	40	    41	  42	    43	    44	  45	    46	  47

# mount --mkdir /dev/nvme0n1p4 /os_install
# ./install.sh s1

# shellcheck disable=SC2002
# shellcheck disable=SC2162
# shellcheck disable=SC2166
# shellcheck disable=SC2181

red="1;31m"
green="1;32m"
yellow="1;33m"
blue="1;34m"

function detect_network() {
  url="www.bing.com"
  stats=$(ping -c 3 $url | grep "packet loss" | awk '{printf("%d\n",$3)}')
  if [ "$stats" -lt 100 ]; then
    return 1
  else # connect wifi
    echo -e "\033[${blue}[iwd]# device list                                --show device name\033[0m"
    echo -e "\033[${blue}[iwd]# station device_name get-networks           --show network name\033[0m"
    echo -e "\033[${blue}[iwd]# station device_name connect network_name   --connect network\033[0m"
    echo -e "\033[${blue}[iwd]# known-networks network_name forget         --forget network\033[0m"
    iwctl
    # detect network again
    stats=$(ping -c 3 $url | grep "packet loss" | awk '{printf("%d\n",$3)}')
    if [ "$stats" -lt 100 ]; then
      echo "network work well"
      return 1
    else
      echo -e "\033[${red}Network work exception, Exit...\033[0m"
      exit
    fi
  fi
}

function disk_format_and_mount() {
  echo "disk format and mount"
  mkswap "$SWAP"
  mkfs.fat -F 32 "$ESP"
  mkfs.ext4 "$ROOT"

  echo "mount disk and swapon linux swap"
  swapon "$SWAP"
  mount "$ROOT" /mnt
  mount --mkdir "$ESP" /mnt/boot

  echo -e "\033[${green}Disk format done! \033[0m"
}

function read_disk_path() {
  echo -en "\033[${yellow}WARNING! $1 partition (default=$2): \033[0m"
  read disk
  if [ x"$disk" != x"" -a -b x"$disk" ]; then
    temp=$disk
  else
    temp=$disk
  fi
  return "$temp"
}

function disk_partition() {
  lsblk | grep " disk "
  default_disk=$(lsblk | grep " disk " | awk '{printf("%s\n",$1)} | head -n 1')
  echo -en "\033[${yellow}WARNING! disk partition, Input target disk (default=$default_disk): \033[0m"
  read in
  if [ x"$in" == x"" -a -b "$default_disk" ]; then
    target_disk=$default_disk
  elif [ x"$in" != x"" -a -b "$in" ]; then
    target_disk=$in
  fi

  cfdisk /dev/"$target_disk"
  fdisk -l | grep /dev

  ESP=$(fdisk -l | grep "EFI System" | awk '{printf($1)}')
  SWAP=$(fdisk -l | grep "Linux swap" | awk '{printf($1)}')
  ROOT=$(fdisk -l | grep "Linux filesystem" | awk '{printf($1)}')

  echo -en "\033[${yellow}WARNING! Disk partition correct? Y/N: \033[0m"
  read string
  if [ "$string" == "Y" -o "$string" == "y" -o "$string" == "yes" ]; then
    echo -e "\033[${green}Esp=$ESP SWAP=$SWAP ROOT=$ROOT\033[0m"
    disk_format_and_mount "$ESP" "$SWAP" "$ROOT"
  else
    read_disk_path "esp" "$ESP"
    new_esp=$?
    read_disk_path "swap" "$SWAP"
    new_swap=$?
    read_disk_path "root" "$ROOT"
    new_root=$?
    echo -e "\033[${green}Esp=$new_esp SWAP=$new_swap ROOT=$new_root\033[0m"
    disk_format_and_mount "$new_esp" "$new_swap" "$new_root"
  fi
  echo -e "\033[${green}Disk partition done! \033[0m"
}

function base_install() {
  echo "Update mirror for China..."
  echo "Server = https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch" >/etc/pacman.d/mirrorlist
  #reflector --country China --age 72 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
  echo "[archlinuxcn]
Server = https://mirrors.ustc.edu.cn/archlinuxcn/\$arch" >>/etc/pacman.conf
  sed -i 's/#Color/Color/g' /etc/pacman.conf
  pacman -Sy --noconfirm
  pacman -S archlinuxcn-keyring

  ## Update the system clock
  timedatectl set-ntp true

  disk_partition

  echo -e "\033[${green}Start installation, 1-min install, 2-base install(without de), 3-full install(without nvidia) 4-full install (default=4): \033[0m"
  read method
  if [ "$method" == 1 ]; then # min install
    pacstrap /mnt base linux linux-firmware grub efibootmgr efivar intel-ucode iwd dhcpcd
  elif [ "$method" == 2 ]; then # base install(without de)
    pacstrap /mnt base base-devel linux linux-firmware grub efibootmgr efivar intel-ucode iwd dhcpcd vim openssh bash-completion wget rsync ntfs-3g
  elif [ "$method" == 3 ]; then # full install(without nvidia)
    pacstrap /mnt base base-devel linux linux-firmware linux-headers xorg lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings xfce4 xfce4-goodies alsa-utils pulseaudio pulseaudio-bluetooth cups grub efibootmgr efivar intel-ucode iwd dhcpcd ttf-dejavu wqy-zenhei wqy-microhei adobe-source-code-pro-fonts adobe-source-sans-fonts adobe-source-serif-fonts adobe-source-han-serif-cn-fonts adobe-source-han-sans-cn-fonts ttf-jetbrains-mono vim bat unzip openssh tree neofetch bash-completion zsh htop rsync fcitx fcitx-im fcitx-configtool ntfs-3g gvfs gvfs-afc gvfs-mtp gvfs-gphoto2 git wget python-pip tk xclip minicom lrzsz catfish plank meld vlc xed galculator gnome-disk-utility yay xray xray-domain-list-community xray-geoip yt-dlp thunderbird sshpass
  elif [ "$method" == 4 ]; then # full install
    pacstrap /mnt base base-devel linux linux-firmware linux-headers xorg lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings nvidia-dkms xfce4 xfce4-goodies alsa-utils pulseaudio pulseaudio-bluetooth cups grub efibootmgr efivar intel-ucode iwd dhcpcd ttf-dejavu wqy-zenhei wqy-microhei adobe-source-code-pro-fonts adobe-source-sans-fonts adobe-source-serif-fonts adobe-source-han-serif-cn-fonts adobe-source-han-sans-cn-fonts ttf-jetbrains-mono vim bat unzip openssh tree neofetch bash-completion zsh htop rsync fcitx fcitx-im fcitx-configtool ntfs-3g gvfs gvfs-afc gvfs-mtp gvfs-gphoto2 git wget python-pip tk xclip minicom lrzsz catfish plank meld vlc xed galculator gnome-disk-utility yay xray xray-domain-list-community xray-geoip yt-dlp thunderbird sshpass
  fi

  # save install method
  echo "$method" >install_method.txt

  ## Configure the system
  genfstab -U /mnt >/mnt/etc/fstab

  ## Copy pacman config to install dir /mnt/etc
  cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
  cp /etc/pacman.conf /mnt/etc/pacman.conf
  cp install.sh /mnt
  mv install_method.txt /mnt

  echo -e "\033[${blue}Archlinux 1st stage install finished!\033[0m"
  arch-chroot /mnt
}

function install_ohmyzsh() {
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /home/"$USER"/.oh-my-zsh
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /home/"$USER"/.oh-my-zsh/custom/themes/powerlevel10k
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions /home/"$USER"/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git /home/"$USER"/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
  echo -e "\033[${green}Install oh-my-zsh to $USER done!\033[0m"
}

function install_python_packages() {
  pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
  pip install requests
  echo -e "\033[${green}Install python packages done!\033[0m"
}

function fix_fcitx_input() {
  echo 'export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"' >/home/"$USER"/.xprofile
  echo -e "\033[${green}Fix $USER fcitx input done!\033[0m"
}

function fix_other() {
  # fix keybord_fn
  # echo options hid_apple fnmode=2 | tee -a /etc/modprobe.d/hid_apple.conf

  # fix wechat font
  # cp fake_simsun.ttc /home/$USER/.deepinwine/Deepin-WeChat/drive_c/windows/Fonts
  # chmod 644 /home/$USER/.deepinwine/Deepin-WeChat/drive_c/windows/Fonts/fake_simsun.ttc

  # fix jetbrain fctix input cursor issue:
  if [ ! -f jbr.tar.gz ]; then
    echo "download JetBrainsRuntime-for-Linux-x64..."
    curl -LJ https://github.com/RikudouPatrickstar/JetBrainsRuntime-for-Linux-x64/releases/download/jbr-release-17.0.4b469.46/jbr_jcef-17.0.4-linux-x64-b469.46.tar.gz -o jbr.tar.gz
  fi
  sudo rm -rf /usr/share/pycharm/jbr
  sudo tar -xvf jbr.tar.gz -C /usr/share/pycharm

  clear
  sudo mv /usr/share/pycharm/jbr_* /usr/share/pycharm/jbr
  cat /usr/share/pycharm/jbr/release | grep "IMPLEMENTOR_VERSION="
}

function yay_software() {
  #  yay -S --noconfirm --needed whitesur-gtk-theme
  yay -S --noconfirm --needed whitesur-icon-theme
  yay -S --noconfirm --needed xfce4-multiload-ng-plugin # xfce4-multiload-ng
  yay -S --noconfirm --needed xfce4-places-plugin
  yay -S --noconfirm --needed fcitx-sogoupinyin
  yay -S --noconfirm --needed pycharm-community-jre
  yay -S --noconfirm --needed microsoft-edge-stable-bin
  yay -S --noconfirm --needed yesplaymusic
  yay -S --noconfirm --needed wps-office-cn
  yay -S --noconfirm --needed wps-office-mui-zh-cn
  yay -S --noconfirm --needed wps-office-mime-cn
  yay -S --noconfirm --needed wps-office-fonts
  yay -S --noconfirm --needed ttf-wps-fonts
  yay -S --noconfirm --needed ttf-ms-fonts
  yay -S --noconfirm --needed sqlitestudio
  yay -S --noconfirm --needed siyuan-note-bin
  yay -S --noconfirm --needed angrysearch
  yay -S --noconfirm --needed keeweb-desktop-bin
  yay -S --noconfirm --needed makepasswd

  ## Remove software
  sudo pacman -Rsu mousepad xfburn parole xfce4-dict

  ## Clean apt cache
  yay -Scc --noconfirm
  rm -rf ~/.cache/yay/*
  echo -e "\033[${green}Yay software install done!\033[0m"
}

function stage1() {
  detect_network
  if [ $? == 1 ]; then
    base_install
    echo -e "\033[${green}Base install done! \033[0m"
  fi
}

function stage2() {
  ## Time zone
  echo -en "\033[${green}Select system language [America/New_York, Asia/Shanghai] (default=Asia/Shanghai): \033[0m"
  read zone
  if [ x"$zone" != x"Asia/Shanghai" ]; then
    ln -sf /usr/share/zoneinfo/"$zone" /etc/localtime
  else
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  fi
  hwclock --systohc

  ## Localization
  echo "en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8" >/etc/locale.gen
  locale-gen

  echo -en "\033[${green}Select system language [en_US, zh_CN] (default=zh_CN): \033[0m"
  read language
  if [ x"$language" == x"en_US" ]; then
    echo "LANG=en_US.UTF-8
LC_TIME=en_US.UTF-8" >/etc/locale.conf
  else
    echo "LANG=zh_CN.UTF-8
LC_TIME=zh_CN.UTF-8" >/etc/locale.conf
  fi

  ## Hosts and Hostname configuration
  echo -en "\033[${green}Input hostname (default=archlinux): \033[0m"
  read hostname
  if [ x"$hostname" != x"archlinux" ]; then
    echo "$hostname" >/etc/hostname
    echo "127.0.0.1   localhost
::1         localhost
127.0.0.1   $hostname" >/etc/hosts
  else
    echo "archlinux" >/etc/hostname
    echo "127.0.0.1   localhost
::1         localhost
127.0.0.1   archlinux" >/etc/hosts
  fi

  ## Modify wheel user sudo permisson
  sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g" /etc/sudoers

  ## create new user
  echo -en "\033[${green}Create new user: \033[0m"
  read USER
  useradd --create-home "$USER"
  usermod -aG wheel,users,storage,power,lp,adm,optical "$USER"

  ## setting user and root passwd
  echo -en "\033[${green}Setting $USER passwd: \033[0m"
  passwd "$USER"
  echo -en "\033[${green}Setting root passwd: \033[0m"
  passwd

  ## Setting Font engine
  echo 'export FREETYPE_PROPERTIES="truetype:interpuuider-version=40"' >/etc/profile.d/freetype2.sh

  install_method=$(cat install_method.txt)
  ## Init system service
  systemctl enable iwd.service
  systemctl enable dhcpcd.service
  systemctl enable sshd.service
  if [ "$install_method" -gt 2 ]; then
    systemctl enable lightdm.service
    systemctl enable xray.service
  fi

  ## Install nvidia driver
  if [ "$install_method" == 4 ]; then # full install with nvidia
    pacman -Rsu xf86-video-vesa
    mkdir -p /etc/pacman.d/hooks
    echo "[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=linux
# Change the linux part above and in the Exec line if a different kernel is used

[Action]
Description=Update Nvidia module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case \$trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'" >/etc/pacman.d/hooks/nvidia.hook
  fi
  echo -e "\033[${green}Config etc file done!\033[0m"

  ## Setting bootloader
  echo -e "Install bootloader"
  mkdir -p /boot/grub /boot/EFI
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB # if error, quit arch-root,remount /boot, then arch-chroot
  grub-mkconfig -o /boot/grub/grub.cfg

  ## Initramfs
  echo -e "Update archlinux initramfs"
  mkinitcpio -P

  echo -e "\033[${blue}Archlinux 2nd stage install finished, reboot now \033[0m"
}

function stage3() {
  install_method=$(cat install_method.txt)
  if [ "$install_method" -lt 3 ]; then
    echo -e "\033[${yellow}WARNING! 1-min install, 2-base install(without de) not support 3rd stage install!\033[0m"
    sudo rm /install.sh /install_method.txt
    exit
  fi

  detect_network
  if [ $? == 0 ]; then
    ## xray config
    sudo cp xray.json /etc/xray/config.json
    sudo systemctl restart xray.service
    export ALL_PROXY=socks://127.0.0.1:10800
    install_ohmyzsh
    yay_software
  fi

  install_python_packages
  fix_fcitx_input
  fix_other
  tar -xvf yeapht.tar.gz -C /home/"$USER"
  clear
  sudo rm /install.sh /install_method.txt
  echo -e "\033[${blue}Archlinux 3rd stage install finished!\033[0m"
}

function main() {
  cmd=$1
  clear
  if [ "$cmd" == "s1" ]; then
    stage1
  elif [ "$cmd" == "s2" ]; then
    stage2
  elif [ "$cmd" == "s3" ]; then
    stage3
  elif [ "$cmd" == "h" ]; then
    echo -e "Example: bash install.sh s1|s2|s3|h"
    echo -e "  s1    archlinux first stage install"
    echo -e "  s2    archlinux second stage install"
    echo -e "  s3    archlinux third stage install, but 1-min install, 2-base install(without de) not support"
    echo -e "  h     show help info"
  else
    echo -e "\033[${red}Error! use '$0 h' show help info\033[0m"
  fi
}

if [ "$#" != 1 ]; then
  echo -e "\033[${red}Error! use '$0 h' show help info\033[0m"
else
  main "$1"
fi

####################### TIPS #######################
# makepkg -si # deepin-wine-wechat 手动编译
# tar -uvf disk_data/01-software/linux/yeapht.tar.gz .config .ssh .p10k.zsh .zshrc Desktop Documents project software # backup

function install_virtualbox() {
  sudo pacman -S --noconfirm --needed virtualbox virtualbox-ext-oracle
  sudo modprobe vboxdrv
  # virtualbox-ext-oracle 位置/usr/share/licenses/virtualbox-ext-oracle
}

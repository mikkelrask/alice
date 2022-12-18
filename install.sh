#!/bin/bash

# Set up variables
disk=""
filesystem=""
timezone=""
locale=""
keymap=""
hostname=""
username=""
user_password=""
root_password=""
packages=""

# Read the config file
echo "Reading configuration file..."
while read line; do
  if [[ $line =~ ^disk: ]]; then
    disk=$(echo "$line" | cut -d':' -f2)
  elif [[ $line =~ ^filesystem: ]]; then
    filesystem=$(echo "$line" | cut -d':' -f2)
  elif [[ $line =~ ^timezone: ]]; then
    timezone=$(echo "$line" | cut -d':' -f2)
  elif [[ $line =~ ^locale: ]]; then
    locale=$(echo "$line" | cut -d':' -f2)
  elif [[ $line =~ ^keymap: ]]; then
    keymap=$(echo "$line" | cut -d':' -f2)
  elif [[ $line =~ ^hostname: ]]; then
    hostname=$(echo "$line" | cut -d':' -f2)
  elif [[ $line =~ ^username: ]]; then
    username=$(echo "$line" | cut -d':' -f2)
  elif [[ $line =~ ^user_password: ]]; then
    user_password=$(echo "$line" | cut -d':' -f2)
  elif [[ $line =~ ^root_password: ]]; then
    root_password=$(echo "$line" | cut -d':' -f2)
  elif [[ $line =~ ^packages: ]]; then
    packages=$(echo "$line" | cut -d':' -f2)
  fi
done < "config"

# Set the keyboard layout
echo "Setting keyboard layout..."
loadkeys "$keymap"

# Connect to the Internet
echo "Connecting to the Internet..."
wifi-menu

# Update the system clock
echo "Updating system clock..."
timedatectl set-ntp true

# Partition the disk
echo "Partitioning disk $disk..."
parted -s "$disk" mklabel msdos
parted -s "$disk" mkpart primary "$filesystem" 1MiB 100%
parted -s "$disk" set 1 boot on

# Format the partition
echo "Formatting partition ${disk}1 with filesystem $filesystem..."
mkfs."$filesystem" "${disk}1"

# Mount the partition
echo "Mounting partition ${disk}1 to /mnt..."
mount "${disk}1" /mnt

# Install the base system
echo "Installing base system..."
pacstrap /mnt

# Generate the fstab file
echo "Generating fstab file..."
genfstab -U /mnt >> /mnt/etc/fstab

# Change root into the new system
echo "Entering new system..."
arch-chroot /mnt

# Set the time zone
echo "Setting time zone to $timezone..."
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime

# Generate the locale
echo "Generating locale $locale..."
echo "$locale" >> /etc/locale.gen
locale-gen
echo "LANG=$locale" >> /etc/locale.conf

# Set the hostname
echo "Setting hostname to $hostname..."
echo "$hostname" >> /etc/hostname

# Set the root password
echo "Setting root password..."
echo "root:$root_password" | chpasswd

# Create a new user
echo "Creating new user $username..."
useradd -m -G wheel "$username"
echo "$username:$user_password" | chpasswd

# Install additional packages
echo "Installing additional packages: $packages"
pacman -S $packages

# Install and configure the bootloader
echo "Installing and configuring bootloader..."
pacman -S grub
grub-install "$disk"
grub-mkconfig -o /boot/grub/grub.cfg

# Reboot the system
echo "Rebooting system..."
exit
umount -R /mnt
reboot
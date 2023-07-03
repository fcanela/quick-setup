#!/bin/sh
set -eu

#
# Required tooling
#
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

if ! command_exists lpass || ! command_exists git; then
  sudo apt update
  sudo apt install -y lastpass-cli git unzip || { echo "Error: Failed to install dependencies." >&2; exit 1; }
fi


#
# Temporal key to read the private repos with the config. It is not that this repos contain any secret, but
# better to avoid giving too many details about my internal systems
#

temp_dir=$(mktemp -d) || { echo "Error: Failed to create temporary directory." >&2; exit 1; }
read -p "Enter your lpass email: " lpass_email

DEPLOY_KEYS_NOTE_ID=5247608367483238149
DEPLOY_KEYS_ATTACHMENT_ID=att-5247608367483238149-1618

lpass login "$lpass_email" || { echo "Error: Failed to log in using 'lpass'." >&2; exit 1; }

mkdir "$temp_dir/keys"
lpass show --note $DEPLOY_KEYS_NOTE_ID --attach=$DEPLOY_KEYS_ATTACHMENT_ID -q > "$temp_dir/keys/all.zip" || { echo "Error: Failed to download deploy keys." >&2; exit 1; }
unzip "$temp_dir/keys/all.zip" -d "$temp_dir/keys"
chmod 600 "$temp_dir/*" || { echo "Error: Failed to set file permissions for the downloaded key files." >&2; exit 1; }

#
# SYSTEM SETUP
#
GIT_SSH_COMMAND="ssh -i $temp_dir/system-config -o IdentitiesOnly=yes" git clone git@github.com:fcanela/system-config.git "$temp_dir/system-config" || { echo "Error: Failed to clone the repository." >&2; exit 1; }
cd "$temp_dir/system-config"
./setup.sh || { echo "Error: Failed to run setup.sh." >&2; exit 1; }

#
# USER SETUP
#
GIT_SSH_COMMAND="ssh -i $temp_dir/dotfiles -o IdentitiesOnly=yes" sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply git@github.com:fcanela/dotfiles.git

#
# Clean up
#
lpass logout -f
rm -rf "$temp_dir"

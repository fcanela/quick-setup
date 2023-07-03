#!/bin/bash
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

TEMP_DIR=$(mktemp -d) || { echo "Error: Failed to create temporary directory." >&2; exit 1; }
read -p "Enter your lpass email: " lpass_email

DEPLOY_KEYS_NOTE_ID=5247608367483238149
DEPLOY_KEYS_ATTACHMENT_ID=att-5247608367483238149-1618

lpass login "$lpass_email" || { echo "Error: Failed to log in using 'lpass'." >&2; exit 1; }

mkdir "$TEMP_DIR/keys"
lpass show --note $DEPLOY_KEYS_NOTE_ID --attach=$DEPLOY_KEYS_ATTACHMENT_ID -q > "$TEMP_DIR/keys/all.zip" || { echo "Error: Failed to download deploy keys." >&2; exit 1; }
unzip "$TEMP_DIR/keys/all.zip" -d "$TEMP_DIR/keys"
chmod 600 $TEMP_DIR/keys/* || { echo "Error: Failed to set file permissions for the downloaded key files." >&2; exit 1; }

#
# SYSTEM SETUP
#
GIT_SSH_COMMAND="ssh -i $TEMP_DIR/keys/system-config -o IdentitiesOnly=yes" git clone git@github.com:fcanela/system-config.git "$TEMP_DIR/system-config" || { echo "Error: Failed to clone the repository." >&2; exit 1; }
cd "$TEMP_DIR/system-config"
./setup.sh || { echo "Error: Failed to run setup.sh." >&2; exit 1; }

#
# USER SETUP
#
GIT_SSH_COMMAND="ssh -i $TEMP_DIR/keys/dotfiles -o IdentitiesOnly=yes" sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply git@github.com:fcanela/dotfiles.git

#
# Clean up
#
lpass logout -f
rm -rf "$TEMP_DIR"

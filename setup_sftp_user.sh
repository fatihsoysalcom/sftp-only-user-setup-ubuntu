#!/bin/bash

# --- Configuration --- 
SFTP_USER="sftpuser"
SFTP_GROUP="sftpusers"
SFTP_ROOT="/var/sftp"
SFTP_UPLOAD_DIR="${SFTP_ROOT}/${SFTP_USER}/upload"
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_BACKUP="${SSHD_CONFIG}.bak_$(date +%Y%m%d%H%M%S)"

# --- Functions ---
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Script ---

# 1. Check for root privileges
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root. Please use 'sudo'."
fi

log_info "Starting SFTP-only user setup for user: ${SFTP_USER}"

# 2. Create SFTP group if it doesn't exist
if ! getent group "${SFTP_GROUP}" > /dev/null; then
    log_info "Creating SFTP group: ${SFTP_GROUP}"
    groupadd "${SFTP_GROUP}" || log_error "Failed to create group ${SFTP_GROUP}"
else
    log_info "Group ${SFTP_GROUP} already exists."
fi

# 3. Create SFTP user if it doesn't exist
if ! id -u "${SFTP_USER}" > /dev/null 2>&1; then
    log_info "Creating SFTP user: ${SFTP_USER}"
    # Create user without shell access, with a home directory inside the future chroot, and add to SFTP_GROUP
    useradd -m -d "${SFTP_ROOT}/${SFTP_USER}" -s /usr/sbin/nologin -g "${SFTP_GROUP}" "${SFTP_USER}" || log_error "Failed to create user ${SFTP_USER}"
    log_info "Please set a password for user ${SFTP_USER}:"
    passwd "${SFTP_USER}" || log_error "Failed to set password for user ${SFTP_USER}"
else
    log_info "User ${SFTP_USER} already exists."
fi

# 4. Create SFTP root directory and upload directory
log_info "Creating SFTP root directory: ${SFTP_ROOT}"
mkdir -p "${SFTP_ROOT}" || log_error "Failed to create directory ${SFTP_ROOT}"

log_info "Creating user's upload directory: ${SFTP_UPLOAD_DIR}"
mkdir -p "${SFTP_UPLOAD_DIR}" || log_error "Failed to create directory ${SFTP_UPLOAD_DIR}"

# 5. Set appropriate permissions for ChrootDirectory
# The ChrootDirectory and its parents must be owned by root and not writable by others.
log_info "Setting permissions for SFTP directories."
chown root:root "${SFTP_ROOT}" || log_error "Failed to set ownership for ${SFTP_ROOT}"
chmod 755 "${SFTP_ROOT}" || log_error "Failed to set permissions for ${SFTP_ROOT}"

# The user's home directory inside the chroot should be owned by the user.
chown "${SFTP_USER}:${SFTP_GROUP}" "${SFTP_ROOT}/${SFTP_USER}" || log_error "Failed to set ownership for ${SFTP_ROOT}/${SFTP_USER}"
chmod 755 "${SFTP_ROOT}/${SFTP_USER}" || log_error "Failed to set permissions for ${SFTP_ROOT}/${SFTP_USER}"

# The actual upload directory should be owned by the user.
chown "${SFTP_USER}:${SFTP_GROUP}" "${SFTP_UPLOAD_DIR}" || log_error "Failed to set ownership for ${SFTP_UPLOAD_DIR}"
chmod 755 "${SFTP_UPLOAD_DIR}" || log_error "Failed to set permissions for ${SFTP_UPLOAD_DIR}"


# 6. Modify sshd_config
log_info "Backing up ${SSHD_CONFIG} to ${SSHD_CONFIG_BACKUP}"
cp "${SSHD_CONFIG}" "${SSHD_CONFIG_BACKUP}" || log_error "Failed to backup sshd_config"

# Check if the Match block already exists
if grep -q "Match User ${SFTP_USER}" "${SSHD_CONFIG}"; then
    log_info "SFTP configuration for ${SFTP_USER} already exists in ${SSHD_CONFIG}. Skipping modification."
else
    log_info "Adding SFTP-only configuration for user ${SFTP_USER} to ${SSHD_CONFIG}"
    cat << EOF >> "${SSHD_CONFIG}"

# --- SFTP-only configuration for user ${SFTP_USER} (added by script) ---
Match User ${SFTP_USER}
    # Forces the user into a chroot jail at ${SFTP_ROOT}
    ChrootDirectory ${SFTP_ROOT}
    # Forces SFTP protocol only, no shell access
    ForceCommand internal-sftp
    # Disable other SSH features for security
    X11Forwarding no
    AllowTcpForwarding no
    PermitTunnel no
    AgentForwarding no
    # Allow password authentication (or public key if configured elsewhere)
    PasswordAuthentication yes
EOF
    log_info "SFTP configuration added to ${SSHD_CONFIG}."
fi

# Ensure Subsystem sftp internal-sftp is present and not commented out
if ! grep -qE "^Subsystem\s+sftp\s+internal-sftp" "${SSHD_CONFIG}"; then
    log_info "Adding/uncommenting 'Subsystem sftp internal-sftp' in ${SSHD_CONFIG}"
    # Try to uncomment first, then add if not found
    sed -i '/^#\?\s*Subsystem\s\+sftp\s\+.*$/cSubsystem sftp internal-sftp' "${SSHD_CONFIG}"
    if ! grep -qE "^Subsystem\s+sftp\s+internal-sftp" "${SSHD_CONFIG}"; then
        echo "Subsystem sftp internal-sftp" >> "${SSHD_CONFIG}"
    fi
fi


# 7. Restart SSH service
log_info "Restarting SSH service to apply changes."
systemctl restart ssh || log_error "Failed to restart SSH service. Please check logs for errors."
log_info "SSH service restarted successfully."

log_info "SFTP-only user setup for ${SFTP_USER} completed."
log_info "You can now test the SFTP connection using:"
log_info "sftp ${SFTP_USER}@localhost"
log_info "or from another machine:"
log_info "sftp ${SFTP_USER}@<your_server_ip>"
log_info "The user's upload directory is: ${SFTP_UPLOAD_DIR}"
log_info "Files uploaded will appear in /upload within the SFTP client's view."

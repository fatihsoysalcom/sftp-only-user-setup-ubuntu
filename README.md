# sftp-only-user-setup-ubuntu
This Bash script automates the creation of a new user on an Ubuntu system, configuring SSH to restrict this user to SFTP access only, without shell capabilities. It sets up a chroot jail for the user, ensuring they can only access their designated home directory for secure file transfers.

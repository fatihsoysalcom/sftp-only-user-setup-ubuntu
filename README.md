# SFTP Only User Setup Ubuntu

This Bash script automates the creation of a new user on an Ubuntu system, configuring SSH to restrict this user to SFTP access only, without shell capabilities. It sets up a chroot jail for the user, ensuring they can only access their designated home directory for secure file transfers.

## Language

`bash`

## How to Run

1. Save the script as `setup_sftp_user.sh`.
2. Make it executable: `chmod +x setup_sftp_user.sh`.
3. Run as root: `sudo ./setup_sftp_user.sh`. Follow the prompts to set a password for the new user.
4. Test the SFTP connection: `sftp sftpuser@localhost` (or replace `localhost` with your server's IP).

## Original Article

This example accompanies the Turkish article: [Ubuntu 18.04 Üzerinde Shell Erişimi Olmadan SFTP Nasıl Etkinleştirilir?](https://fatihsoysal.com/blog/?p=42068).

## License

MIT — see [LICENSE](LICENSE).

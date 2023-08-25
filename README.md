# What's this?
A simple bash script that can create, remove, or limit the server users from accessing a specific country's IP ranges. While created users with this script can not access the server's shell remotely, they can still use it as a secure proxy to tunnel traffic.

# Features
1. Create a new user.
2. Remove a current user.
3. Limit user's access to a specific country IP ranges.
4. Remove the user's limitations.
5. List all the current users.

# How to use?
```
# Using git:

git clone https://github.com/alireza1219/simple-ssh-proxy-manager.git

cd simple-ssh-proxy-manager

# Using curl:

curl https://raw.githubusercontent.com/alireza1219/simple-ssh-proxy-manager/main/manage.sh -o manage.sh

# Executing the script:

chmod +x manage.sh

sudo ./manage.sh
```
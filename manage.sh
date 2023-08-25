#!/bin/bash

# Check for the root privileges.
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Get the server IP address.
serverip=$(ip -o -4 addr show | awk '/scope global/ {print $4}' | cut -d'/' -f1)

function check_package_installation() {
    local package_name="$1"

    if ! command -v $package_name &>/dev/null; then
        echo "$package_name is not installed. Installing..."
        if [ -f /etc/debian_version ]; then
            apt update
            apt install -y $package_name
        elif [ -f /etc/redhat-release ]; then
            yum install -y $package_name
        else
            echo "Unsupported distribution. Please install '$package_name' manually."
            return 1
        fi
    fi
}

function create_user() {
    echo "Creating a new user..."
    read -p "Enter username: " username

    # Exit if the entered username is empty.
    if [ -z "$username" ]; then
        echo "Username can not be empty! Press any key to return to the main menu..."
        read -n 1 -s
        main_menu
        return
    fi

    # Check if the user already exists.
    if id "$username" &>/dev/null; then
        echo "User '$username' already exists."
    else
        read -s -p "Enter a password for $username: " password
        echo
        useradd -m -s /bin/false $username
        echo "$username:$password" | chpasswd
        echo "User '$username' has been created with SSH proxy access. Use '$username@$serverip' to connect."
    fi

    echo "Press any key to return to the main menu..."
    read -n 1 -s
    main_menu
}

function remove_user() {
    echo "Deleting a user..."
    read -p "Enter username to delete: " username

    # Exit if the entered username is empty.
    if [ -z "$username" ]; then
        echo "Username can not be empty! Press any key to return to the main menu..."
        read -n 1 -s
        main_menu
        return
    fi

    if id "$username" &>/dev/null; then
        userdel -r $username
        echo "User '$username' has been deleted."
    else
        echo "User '$username' does not exist."
    fi

    echo "Press any key to return to the main menu..."
    read -n 1 -s
    main_menu
}

function add_user_rules_menu() {
    echo "Applying new IP range limitation for user..."
    read -p "Enter username to set up IP range limitation: " username
    read -p "Enter country code for IP ranges (e.g., ir): " country_code
    # Exit if the entered username and country code were empty.
    if [ -z "$username" ] && [ -z "$country_code" ]; then
        echo "Username/Country Code can not be empty! Press any key to return to the main menu..."
        read -n 1 -s
        main_menu
        return
    fi
    check_package_installation iptables
    add_user_rules "$username" "$country_code"

    echo "Press any key to return to the main menu..."
    read -n 1 -s
    main_menu
}

function add_user_rules() {
    local username="$1"
    local country_code="$2"
    local uid
    local ip_ranges_url="https://www.ipdeny.com/ipblocks/data/countries/${country_code}.zone"

    # Check if the user exists.
    id "$username" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "User '$username' does not exist."
        return 1
    fi

    # Get the UID of the user.
    uid=$(id -u "$username")

    # Fetch IP ranges from the IPDeny.
    ip_ranges=$(curl -s -f "$ip_ranges_url")

    if [ $? -eq 0 ]; then
        # Create iptables rules to block outgoing traffic from user within fetched IP ranges.
        for ip_range in $ip_ranges; do
            iptables -A OUTPUT -m owner --uid-owner "$uid" -d "$ip_range" -j DROP
        done

        # Save the current iptables rules.
        save_rules

        echo "User '$username' has been limited to access IP ranges from country code '$country_code'."
    else
        echo "Error fetching IP ranges. Please try again later."
    fi
}

function flush_user_rules_menu() {
    echo "Removing IP range limitation for user..."
    read -p "Enter username to remove IP range limitation: " username

    # Exit if the entered username is empty.
    if [ -z "$username" ]; then
        echo "Username can not be empty! Press any key to return to the main menu..."
        read -n 1 -s
        main_menu
        return
    fi

    check_package_installation iptables
    flush_user_rules "$username"

    echo "Press any key to return to the main menu..."
    read -n 1 -s
    main_menu
}

function flush_user_rules() {
    local username="$1"
    local uid

    # Check if the user exists.
    id "$username" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "User '$username' does not exist."
        return 1
    fi

    # Get the UID of the user.
    uid=$(id -u "$username")

    # Flush iptables rules for the user's UID.
    iptables -L OUTPUT --line-numbers -n | awk -v uid="$uid" '$0 ~ "owner UID match " uid { print $1 }' | tac | while read line_number; do
        iptables -D OUTPUT "$line_number"
    done

    # Save the current iptables rules.
    save_rules

    echo "IP range limitation has been removed for user '$username'."
}

function save_rules() {
    if [ -f /etc/debian_version ]; then
        iptables-save >/etc/iptables/rules.v4
        ip6tables-save >/etc/iptables/rules.v6
    elif [ -f /etc/redhat-release ]; then
        iptables-save >/etc/sysconfig/iptables
        ip6tables-save >/etc/sysconfig/ip6tables
    else
        echo "Unsupported distribution. Please save iptables rules manually."
        echo "Remember you have to install iptables-persistent to automatically load saved rules on each boot!"
    fi

}

function list_users() {
    # List all the users except for root and nobody.
    getent passwd | awk -F: '$3 >= 1000 && $1 != "root" && $1 != "nobody" { print $1 }'

    echo "Press any key to return to the main menu..."
    read -n 1 -s
    main_menu
}

function main_menu() {
    clear
    echo "Simple SSH Proxy Manage:"
    echo "1. Add User with Proxy Access"
    echo "2. Delete User"
    echo "3. Set Up IP Range Limitation for User"
    echo "4. Remove IP Range Limitation for User"
    echo "5. List current users"
    echo "6. Exit"
    read -p "Enter your choice: " choice

    case $choice in
    1)
        create_user
        ;;
    2)
        remove_user
        ;;
    3)
        add_user_rules_menu
        ;;
    4)
        flush_user_rules_menu
        ;;
    5)
        list_users
        ;;
    6)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid choice. Please select a valid option."
        ;;
    esac
}

# Call the main menu at the first run.
main_menu

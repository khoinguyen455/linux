#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║           fxTunnel Installer - HopingBoyz Edition            ║
# ║                  Created by: HopingBoyz                      ║
# ║            YouTube: https://www.youtube.com/@hopingboyz      ║
# ╚══════════════════════════════════════════════════════════════╝

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
SERVICE_DIR="/etc/systemd/system"
FXTUNNEL_BIN=""

# Function to find fxtunnel binary
find_fxtunnel() {
    if [ -f "/usr/local/bin/fxtunnel" ]; then
        FXTUNNEL_BIN="/usr/local/bin/fxtunnel"
    elif [ -f "/root/.local/bin/fxtunnel" ]; then
        FXTUNNEL_BIN="/root/.local/bin/fxtunnel"
    elif command -v fxtunnel &> /dev/null; then
        FXTUNNEL_BIN=$(command -v fxtunnel)
    else
        FXTUNNEL_BIN=""
    fi
}

# Function to print banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║         ██╗  ██╗ ██████╗ ██████╗ ██╗███╗   ██╗ ██████╗     ║"
    echo "║         ██║  ██║██╔═══██╗██╔══██╗██║████╗  ██║██╔════╝     ║"
    echo "║         ███████║██║   ██║██████╔╝██║██╔██╗ ██║██║  ███╗    ║"
    echo "║         ██╔══██║██║   ██║██╔═══╝ ██║██║╚██╗██║██║   ██║    ║"
    echo "║         ██║  ██║╚██████╔╝██║     ██║██║ ╚████║╚██████╔╝    ║"
    echo "║         ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝ ╚═════╝     ║"
    echo "║                                                              ║"
    echo "║              ██████╗  ██████╗ ██╗   ██╗███████╗              ║"
    echo "║              ██╔══██╗██╔═══██╗╚██╗ ██╔╝╚══███╔╝              ║"
    echo "║              ██████╔╝██║   ██║ ╚████╔╝   ███╔╝               ║"
    echo "║              ██╔══██╗██║   ██║  ╚██╔╝   ███╔╝                ║"
    echo "║              ██████╔╝╚██████╔╝   ██║   ███████╗              ║"
    echo "║              ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝              ║"
    echo "║                                                              ║"
    echo "║                   fxTunnel Manager v1.0                      ║"
    echo "║           YouTube: https://www.youtube.com/@hopingboyz       ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to print section headers
print_section() {
    echo ""
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BOLD}  $1${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ This script must be run as root!${NC}"
        echo -e "${BLUE}ℹ Please run: sudo bash $0${NC}"
        exit 1
    fi
}

# Fix stuck services
fix_stuck_services() {
    print_section "Checking & Fixing Services"
    
    local stuck_services=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -i fxtunnel | grep "activating" | awk '{print $1}' | sed 's/.service//')
    
    if [ -n "$stuck_services" ]; then
        print_warning "Found stuck services in 'activating' state"
        echo ""
        
        while IFS= read -r service; do
            if [ -n "$service" ]; then
                print_info "Fixing: $service"
                
                # Kill any hanging processes
                systemctl stop "$service" 2>/dev/null
                pkill -f "fxtunnel.*$service" 2>/dev/null || true
                sleep 2
                
                # Reset failed state
                systemctl reset-failed "$service" 2>/dev/null || true
                
                # Get service file content
                local service_file="${SERVICE_DIR}/${service}.service"
                
                if [ -f "$service_file" ]; then
                    # Update with correct binary path
                    find_fxtunnel
                    if [ -n "$FXTUNNEL_BIN" ]; then
                        # Get current config
                        local port=$(grep "ExecStart" "$service_file" | grep -oP 'tcp \K[0-9]+' | head -1)
                        local token=$(grep "ExecStart" "$service_file" | grep -oP '\-t \K[^\s]+' | head -1)
                        
                        # Recreate service file with correct settings
                        cat > "$service_file" << EOF
[Unit]
Description=fxTunnel SSH Tunnel - ${service}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="HOME=/root"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin"
ExecStart=${FXTUNNEL_BIN} tcp ${port:-22} -t ${token}
Restart=on-failure
RestartSec=10
TimeoutStartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
                        print_success "Updated service file for $service"
                    fi
                fi
                
                # Reload and try to start
                systemctl daemon-reload
                systemctl start "$service" 2>/dev/null &
                
                # Wait and check
                sleep 5
                
                local status=$(systemctl is-active "$service" 2>/dev/null)
                if [ "$status" = "active" ]; then
                    print_success "$service is now ACTIVE ✓"
                else
                    print_error "$service still failing - check logs: journalctl -u $service -n 20"
                fi
                echo ""
            fi
        done <<< "$stuck_services"
        
        systemctl daemon-reload
    else
        print_success "No stuck services found"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Install fxTunnel
install_fxtunnel() {
    print_section "Installing fxTunnel"
    
    # Check if already installed
    find_fxtunnel
    if [ -n "$FXTUNNEL_BIN" ]; then
        print_info "fxTunnel is already installed at: $FXTUNNEL_BIN"
        read -p "Do you want to reinstall? (y/n): " reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            return
        fi
        # Remove old binary
        rm -f "$FXTUNNEL_BIN"
    fi
    
    print_info "Downloading and installing fxTunnel..."
    
    # Install using official script
    curl -fsSL https://fxtun.dev/install.sh | sh
    
    if [ $? -eq 0 ]; then
        print_success "fxTunnel installed successfully!"
        
        # Find installed binary
        find_fxtunnel
        if [ -n "$FXTUNNEL_BIN" ]; then
            print_success "Binary location: $FXTUNNEL_BIN"
        else
            # Manual check
            if [ -f "/root/.local/bin/fxtunnel" ]; then
                FXTUNNEL_BIN="/root/.local/bin/fxtunnel"
                chmod +x "$FXTUNNEL_BIN"
            fi
        fi
        
        # AUTO PATH SETUP
        print_section "Configuring PATH Environment"
        
        print_info "Adding /root/.local/bin to PATH..."
        
        # Add to root's .bashrc
        if ! grep -q "/root/.local/bin" /root/.bashrc 2>/dev/null; then
            echo 'export PATH=$PATH:/root/.local/bin' >> /root/.bashrc
            print_success "Added to /root/.bashrc"
        fi
        
        # Also add to /etc/profile for all users
        if ! grep -q "/root/.local/bin" /etc/profile 2>/dev/null; then
            echo 'export PATH=$PATH:/root/.local/bin' >> /etc/profile
        fi
        
        # Source for current session
        export PATH=$PATH:/root/.local/bin
        source /root/.bashrc 2>/dev/null || true
        
        print_success "PATH configured successfully!"
        
        # Test fxtunnel
        if [ -x "$FXTUNNEL_BIN" ]; then
            print_success "fxtunnel is executable"
            echo -e "${CYAN}Location: ${YELLOW}$FXTUNNEL_BIN${NC}"
            
            # Try to get version
            local version=$("$FXTUNNEL_BIN" --version 2>&1 || echo "version check skipped")
            echo -e "${CYAN}Version: ${YELLOW}$version${NC}"
        else
            print_warning "fxtunnel found but not executable, fixing permissions..."
            chmod +x "$FXTUNNEL_BIN" 2>/dev/null || true
        fi
        
    else
        print_error "Failed to install fxTunnel"
        print_info "Please check your internet connection and try again"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Test fxtunnel with token
test_fxtunnel() {
    print_section "Test fxTunnel Connection"
    
    find_fxtunnel
    if [ -z "$FXTUNNEL_BIN" ]; then
        print_error "fxTunnel not installed!"
        print_info "Please install fxTunnel first (Option 1)"
        sleep 2
        return
    fi
    
    read -p "Enter token to test: " test_token
    if [ -z "$test_token" ]; then
        print_error "Token cannot be empty!"
        return
    fi
    
    read -p "Enter port to test (default: 22): " test_port
    test_port=${test_port:-22}
    
    print_info "Testing connection..."
    print_info "Command: $FXTUNNEL_BIN tcp $test_port -t $test_token"
    echo ""
    
    # Run fxtunnel in background for 10 seconds to test
    timeout 10 "$FXTUNNEL_BIN" tcp "$test_port" -t "$test_token" 2>&1 &
    local pid=$!
    
    sleep 8
    
    if kill -0 $pid 2>/dev/null; then
        print_success "Connection test successful! fxTunnel is running"
        kill $pid 2>/dev/null
    else
        print_warning "Connection test completed or failed"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# List all existing services
list_services() {
    print_section "Existing fxTunnel Services"
    
    # Find all fxtunnel services
    local services=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -i fxtunnel | awk '{print $1}' | sed 's/.service//')
    
    if [ -z "$services" ]; then
        print_info "No fxTunnel services found"
    else
        local stuck_count=0
        echo -e "${CYAN}${BOLD}Current services:${NC}"
        echo -e "${WHITE}────────────────────────────────────────────────────────────${NC}"
        
        while IFS= read -r service; do
            if [ -n "$service" ]; then
                # Get service status
                local status=$(systemctl is-active "$service" 2>/dev/null)
                
                case $status in
                    active)
                        status_color="${GREEN}● ACTIVE${NC}"
                        ;;
                    failed)
                        status_color="${RED}● FAILED${NC}"
                        ;;
                    activating)
                        status_color="${YELLOW}● ACTIVATING (STUCK)${NC}"
                        ((stuck_count++))
                        ;;
                    inactive)
                        status_color="${YELLOW}● INACTIVE${NC}"
                        ;;
                    *)
                        status_color="${RED}● $status${NC}"
                        ;;
                esac
                
                # Get port from service file
                local port=$(systemctl cat "$service" 2>/dev/null | grep "ExecStart" | grep -oP 'tcp \K[0-9]+' | head -1)
                [ -z "$port" ] && port="N/A"
                
                # Get token from service file
                local token=$(systemctl cat "$service" 2>/dev/null | grep "ExecStart" | grep -oP '\-t \K[^\s]+' | head -1)
                [ -z "$token" ] && token="N/A"
                
                # Get service uptime if active
                local uptime=""
                if [ "$status" = "active" ]; then
                    local pid=$(systemctl show -p MainPID "$service" 2>/dev/null | cut -d'=' -f2)
                    if [ -n "$pid" ] && [ "$pid" != "0" ]; then
                        uptime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
                        [ -n "$uptime" ] && uptime=" (Uptime: $uptime)"
                    fi
                fi
                
                echo -e "  ${YELLOW}Service:${NC} $service"
                echo -e "  ${YELLOW}Status:${NC}  $status_color$uptime"
                echo -e "  ${YELLOW}Port:${NC}    $port"
                echo -e "  ${YELLOW}Token:${NC}   ${token:0:20}..."
                echo -e "${WHITE}────────────────────────────────────────────────────────────${NC}"
            fi
        done <<< "$services"
        
        if [ $stuck_count -gt 0 ]; then
            echo ""
            print_warning "Found $stuck_count stuck service(s) in 'activating' state!"
            echo -e "${CYAN}Use Option 10 to fix stuck services${NC}"
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Create new service
create_service() {
    print_section "Create New fxTunnel Service"
    
    find_fxtunnel
    if [ -z "$FXTUNNEL_BIN" ]; then
        print_error "fxTunnel not installed!"
        print_info "Please install fxTunnel first (Option 1)"
        sleep 2
        return
    fi
    
    # Get service name
    while true; do
        read -p "Enter service name (e.g., ssh-tunnel): " service_name
        if [[ -z "$service_name" ]]; then
            print_error "Service name cannot be empty"
        elif [[ ! "$service_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            print_error "Service name can only contain letters, numbers, hyphens and underscores"
        elif systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -q "fxtunnel-${service_name}.service"; then
            print_error "Service name already exists! Please choose another name."
        else
            break
        fi
    done
    
    # Get port number
    while true; do
        read -p "Enter port number to tunnel (default: 22): " port
        port=${port:-22}
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            print_error "Invalid port number! Please enter a number between 1-65535"
        else
            break
        fi
    done
    
    # Get token
    while true; do
        read -p "Enter your fxTunnel token: " token
        if [[ -z "$token" ]]; then
            print_error "Token cannot be empty"
        else
            break
        fi
    done
    
    # Create service
    local full_service_name="fxtunnel-${service_name}"
    local service_file="${SERVICE_DIR}/${full_service_name}.service"
    
    print_info "Creating service: $full_service_name"
    print_info "Binary: $FXTUNNEL_BIN"
    print_info "Port: $port"
    print_info "Token: ${token:0:10}..."
    
    cat > "$service_file" << EOF
[Unit]
Description=fxTunnel SSH Tunnel - ${full_service_name}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="HOME=/root"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin"
ExecStart=${FXTUNNEL_BIN} tcp ${port} -t ${token}
Restart=on-failure
RestartSec=10
TimeoutStartSec=30
TimeoutStopSec=10
StandardOutput=journal
StandardError=journal
KillMode=process
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    # Stop any existing instance
    systemctl stop "$full_service_name" 2>/dev/null
    pkill -f "fxtunnel.*${service_name}" 2>/dev/null || true
    sleep 2
    
    # Enable and start service
    systemctl enable "$full_service_name" 2>/dev/null
    systemctl start "$full_service_name" 2>/dev/null
    
    # Wait and check status
    print_info "Waiting for service to start..."
    sleep 5
    
    # Check status
    local status=$(systemctl is-active "$full_service_name" 2>/dev/null)
    
    if [ "$status" = "active" ]; then
        print_success "Service created and running successfully! 🚀"
        echo ""
        echo -e "${GREEN}${BOLD}Service Details:${NC}"
        echo -e "  ${YELLOW}Name:${NC}   $full_service_name"
        echo -e "  ${YELLOW}Port:${NC}   $port"
        echo -e "  ${YELLOW}Token:${NC}  $token"
        echo -e "  ${YELLOW}Status:${NC} ${GREEN}ACTIVE ✓${NC}"
        echo -e "  ${YELLOW}Command:${NC} systemctl status $full_service_name"
    elif [ "$status" = "activating" ]; then
        print_warning "Service is still starting... checking logs:"
        echo ""
        journalctl -u "$full_service_name" --no-pager -n 10
        echo ""
        print_info "If service doesn't become active, use Option 10 to fix"
    else
        print_error "Service failed to start. Status: $status"
        echo ""
        print_info "Checking logs:"
        journalctl -u "$full_service_name" --no-pager -n 20
        echo ""
        print_info "You can also use Option 10 to fix stuck services"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Edit existing service
edit_service() {
    print_section "Edit fxTunnel Service"
    
    local services=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -i fxtunnel | awk '{print $1}' | sed 's/.service//')
    
    if [ -z "$services" ]; then
        print_error "No fxTunnel services found!"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Available services:${NC}"
    echo ""
    
    local i=1
    local service_array=()
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            local status=$(systemctl is-active "$service" 2>/dev/null)
            echo -e "  ${YELLOW}$i)${NC} $service (${status})"
            service_array+=("$service")
            ((i++))
        fi
    done <<< "$services"
    
    echo ""
    read -p "Select service to edit (1-${#service_array[@]}): " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#service_array[@]} ]; then
        print_error "Invalid selection!"
        sleep 2
        return
    fi
    
    local selected_service="${service_array[$selection-1]}"
    local service_file="${SERVICE_DIR}/${selected_service}.service"
    
    print_info "Editing: $selected_service"
    echo ""
    
    # Get current values
    local current_port=$(grep "ExecStart" "$service_file" | grep -oP 'tcp \K[0-9]+' | head -1)
    local current_token=$(grep "ExecStart" "$service_file" | grep -oP '\-t \K[^\s]+' | head -1)
    
    echo -e "${CYAN}Current configuration:${NC}"
    echo -e "  Port: ${YELLOW}$current_port${NC}"
    echo -e "  Token: ${YELLOW}${current_token:0:15}...${NC}"
    echo ""
    
    # Get new values
    read -p "Enter new port number (leave blank to keep $current_port): " new_port
    read -p "Enter new token (leave blank to keep current): " new_token
    
    new_port=${new_port:-$current_port}
    new_token=${new_token:-$current_token}
    
    # Stop service
    print_info "Stopping service..."
    systemctl stop "$selected_service" 2>/dev/null
    pkill -f "fxtunnel.*${selected_service}" 2>/dev/null || true
    sleep 2
    
    # Update service file
    find_fxtunnel
    if [ -n "$FXTUNNEL_BIN" ]; then
        cat > "$service_file" << EOF
[Unit]
Description=fxTunnel SSH Tunnel - ${selected_service}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="HOME=/root"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin"
ExecStart=${FXTUNNEL_BIN} tcp ${new_port} -t ${new_token}
Restart=on-failure
RestartSec=10
TimeoutStartSec=30
TimeoutStopSec=10
StandardOutput=journal
StandardError=journal
KillMode=process
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Reload and start
    systemctl daemon-reload
    systemctl start "$selected_service" 2>/dev/null
    
    sleep 5
    
    if systemctl is-active --quiet "$selected_service"; then
        print_success "Service updated and running! ✓"
    else
        print_warning "Service updated but may not be running"
        echo ""
        journalctl -u "$selected_service" --no-pager -n 10
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Delete service
delete_service() {
    print_section "Delete fxTunnel Service"
    
    local services=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -i fxtunnel | awk '{print $1}' | sed 's/.service//')
    
    if [ -z "$services" ]; then
        print_error "No fxTunnel services found!"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Available services:${NC}"
    echo ""
    
    local i=1
    local service_array=()
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            local status=$(systemctl is-active "$service" 2>/dev/null)
            echo -e "  ${YELLOW}$i)${NC} $service (${status})"
            service_array+=("$service")
            ((i++))
        fi
    done <<< "$services"
    
    echo ""
    read -p "Select service to delete (1-${#service_array[@]}): " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#service_array[@]} ]; then
        print_error "Invalid selection!"
        sleep 2
        return
    fi
    
    local selected_service="${service_array[$selection-1]}"
    
    echo ""
    read -p "$(echo -e ${RED}"DELETE $selected_service? This cannot be undone! (y/n): "${NC})" confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_info "Stopping and removing $selected_service..."
        
        # Stop and kill
        systemctl stop "$selected_service" 2>/dev/null
        systemctl disable "$selected_service" 2>/dev/null
        pkill -f "fxtunnel.*${selected_service}" 2>/dev/null || true
        
        # Remove file
        rm -f "${SERVICE_DIR}/${selected_service}.service"
        
        # Reload
        systemctl daemon-reload
        systemctl reset-failed 2>/dev/null || true
        
        print_success "Service deleted permanently! ✓"
    else
        print_info "Deletion cancelled"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# View service logs
view_logs() {
    print_section "View fxTunnel Service Logs"
    
    local services=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -i fxtunnel | awk '{print $1}' | sed 's/.service//')
    
    if [ -z "$services" ]; then
        print_error "No fxTunnel services found!"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Available services:${NC}"
    echo ""
    
    local i=1
    local service_array=()
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            echo -e "  ${YELLOW}$i)${NC} $service"
            service_array+=("$service")
            ((i++))
        fi
    done <<< "$services"
    
    echo ""
    read -p "Select service for logs (1-${#service_array[@]}): " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#service_array[@]} ]; then
        print_error "Invalid selection!"
        sleep 2
        return
    fi
    
    local selected_service="${service_array[$selection-1]}"
    
    echo ""
    echo -e "${CYAN}${BOLD}Live logs for: ${YELLOW}$selected_service${NC}"
    echo -e "${PURPLE}Press Ctrl+C to exit log view${NC}"
    echo ""
    sleep 1
    
    journalctl -u "$selected_service" -f --no-hostname
}

# Manage service (Start/Stop/Restart)
manage_service() {
    print_section "Service Management"
    
    local services=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -i fxtunnel | awk '{print $1}' | sed 's/.service//')
    
    if [ -z "$services" ]; then
        print_error "No fxTunnel services found!"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Available services:${NC}"
    echo ""
    
    local i=1
    local service_array=()
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            local status=$(systemctl is-active "$service" 2>/dev/null)
            if [ "$status" = "active" ]; then
                status_color="${GREEN}$status${NC}"
            elif [ "$status" = "activating" ]; then
                status_color="${YELLOW}$status${NC}"
            else
                status_color="${RED}$status${NC}"
            fi
            echo -e "  ${YELLOW}$i)${NC} $service (${status_color})"
            service_array+=("$service")
            ((i++))
        fi
    done <<< "$services"
    
    echo ""
    read -p "Select service (1-${#service_array[@]}): " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#service_array[@]} ]; then
        print_error "Invalid selection!"
        sleep 2
        return
    fi
    
    local selected_service="${service_array[$selection-1]}"
    
    echo ""
    echo -e "${CYAN}Manage: ${YELLOW}$selected_service${NC}"
    echo -e "${WHITE}────────────────────────${NC}"
    echo -e "  ${YELLOW}1)${NC} Start"
    echo -e "  ${YELLOW}2)${NC} Stop"
    echo -e "  ${YELLOW}3)${NC} Restart"
    echo -e "  ${YELLOW}4)${NC} Enable on boot"
    echo -e "  ${YELLOW}5)${NC} Disable on boot"
    echo -e "  ${YELLOW}6)${NC} Show status"
    echo ""
    read -p "Select action (1-6): " action
    
    case $action in
        1)
            systemctl stop "$selected_service" 2>/dev/null
            pkill -f "fxtunnel.*${selected_service}" 2>/dev/null || true
            sleep 1
            systemctl start "$selected_service"
            sleep 3
            if systemctl is-active --quiet "$selected_service"; then
                print_success "Started successfully ✓"
            else
                print_error "Failed to start"
            fi
            ;;
        2)
            systemctl stop "$selected_service" 2>/dev/null
            pkill -f "fxtunnel.*${selected_service}" 2>/dev/null || true
            sleep 1
            print_success "Stopped ✓"
            ;;
        3)
            systemctl stop "$selected_service" 2>/dev/null
            pkill -f "fxtunnel.*${selected_service}" 2>/dev/null || true
            sleep 2
            systemctl start "$selected_service"
            sleep 3
            if systemctl is-active --quiet "$selected_service"; then
                print_success "Restarted successfully ✓"
            else
                print_error "Failed to restart"
            fi
            ;;
        4)
            systemctl enable "$selected_service"
            print_success "Enabled on boot ✓"
            ;;
        5)
            systemctl disable "$selected_service"
            print_success "Disabled on boot ✓"
            ;;
        6)
            systemctl status "$selected_service" --no-pager
            ;;
        *)
            print_error "Invalid action!"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Show fxTunnel servers
show_servers() {
    print_section "fxTunnel Available Servers"
    
    echo -e "${CYAN}${BOLD}Global Server Regions:${NC}"
    echo ""
    echo -e "${WHITE}────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}●${NC} ${WHITE}US East (N. Virginia)${NC}      ${YELLOW}us-east-1.fxtun.dev${NC}"
    echo -e "  ${GREEN}●${NC} ${WHITE}US West (Oregon)${NC}           ${YELLOW}us-west-2.fxtun.dev${NC}"
    echo -e "  ${GREEN}●${NC} ${WHITE}Europe (Ireland)${NC}           ${YELLOW}eu-west-1.fxtun.dev${NC}"
    echo -e "  ${GREEN}●${NC} ${WHITE}Europe (Frankfurt)${NC}         ${YELLOW}eu-central-1.fxtun.dev${NC}"
    echo -e "  ${GREEN}●${NC} ${WHITE}Asia Pacific (Singapore)${NC}   ${YELLOW}ap-southeast-1.fxtun.dev${NC}"
    echo -e "  ${GREEN}●${NC} ${WHITE}Asia Pacific (Tokyo)${NC}       ${YELLOW}ap-northeast-1.fxtun.dev${NC}"
    echo -e "  ${GREEN}●${NC} ${WHITE}South America (Sao Paulo)${NC}  ${YELLOW}sa-east-1.fxtun.dev${NC}"
    echo -e "${WHITE}────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${CYAN}Connection Formats:${NC}"
    echo -e "  ${YELLOW}TCP:${NC}   tcp://{region}.fxtun.dev:{port}"
    echo -e "  ${YELLOW}HTTP:${NC}  https://{region}.fxtun.dev"
    echo -e "  ${YELLOW}UDP:${NC}   udp://{region}.fxtun.dev:{port}"
    echo ""
    echo -e "${CYAN}Example:${NC}"
    echo -e "  fxtunnel tcp 22 -t YOUR_TOKEN"
    
    echo ""
    read -p "Press Enter to continue..."
}

# Create bulk services
create_bulk_services() {
    print_section "Create Multiple Services (Bulk)"
    
    find_fxtunnel
    if [ -z "$FXTUNNEL_BIN" ]; then
        print_error "fxTunnel not installed!"
        print_info "Please install fxTunnel first (Option 1)"
        return
    fi
    
    read -p "Enter token for all services: " token
    if [ -z "$token" ]; then
        print_error "Token cannot be empty!"
        return
    fi
    
    read -p "Enter starting port number: " start_port
    read -p "Enter ending port number: " end_port
    
    if ! [[ "$start_port" =~ ^[0-9]+$ ]] || ! [[ "$end_port" =~ ^[0-9]+$ ]]; then
        print_error "Ports must be numbers!"
        return
    fi
    
    if [ "$start_port" -gt "$end_port" ]; then
        print_error "Start port must be less than end port!"
        return
    fi
    
    read -p "Enter base service name (default: tunnel): " base_name
    base_name=${base_name:-tunnel}
    
    local total=$((end_port - start_port + 1))
    echo ""
    echo -e "${CYAN}Creating $total services from port $start_port to $end_port...${NC}"
    echo ""
    
    local success_count=0
    local fail_count=0
    
    for port in $(seq "$start_port" "$end_port"); do
        local service_name="fxtunnel-${base_name}-${port}"
        local service_file="${SERVICE_DIR}/${service_name}.service"
        
        cat > "$service_file" << EOF
[Unit]
Description=fxTunnel SSH Tunnel - ${service_name}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="HOME=/root"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin"
ExecStart=${FXTUNNEL_BIN} tcp ${port} -t ${token}
Restart=on-failure
RestartSec=10
TimeoutStartSec=30
StandardOutput=journal
StandardError=journal
KillMode=process
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl enable "$service_name" 2>/dev/null
        systemctl start "$service_name" 2>/dev/null
        
        sleep 1
        
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $service_name (Port: $port) - ACTIVE"
            ((success_count++))
        else
            echo -e "  ${RED}✗${NC} $service_name (Port: $port) - Check logs"
            ((fail_count++))
        fi
    done
    
    systemctl daemon-reload
    
    echo ""
    echo -e "${GREEN}${BOLD}Success: $success_count services${NC}"
    if [ $fail_count -gt 0 ]; then
        echo -e "${RED}${BOLD}Failed: $fail_count services${NC}"
        echo -e "${CYAN}Use Option 10 to fix failed services${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# One-click fix for all services
fix_all_services() {
    print_section "Fix All fxTunnel Services"
    
    find_fxtunnel
    if [ -z "$FXTUNNEL_BIN" ]; then
        print_error "fxTunnel not installed! Cannot fix services."
        print_info "Please install fxTunnel first (Option 1)"
        sleep 2
        return
    fi
    
    print_info "Using fxtunnel binary: $FXTUNNEL_BIN"
    echo ""
    
    local services=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -i fxtunnel | awk '{print $1}' | sed 's/.service//')
    
    if [ -z "$services" ]; then
        print_error "No fxTunnel services found to fix!"
        sleep 2
        return
    fi
    
    print_info "Fixing all services..."
    echo ""
    
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            print_info "Processing: $service"
            
            # Stop service completely
            systemctl stop "$service" 2>/dev/null
            pkill -f "fxtunnel.*${service}" 2>/dev/null || true
            sleep 2
            
            # Reset failed state
            systemctl reset-failed "$service" 2>/dev/null || true
            
            local service_file="${SERVICE_DIR}/${service}.service"
            
            if [ -f "$service_file" ]; then
                local port=$(grep "ExecStart" "$service_file" | grep -oP 'tcp \K[0-9]+' | head -1)
                local token=$(grep "ExecStart" "$service_file" | grep -oP '\-t \K[^\s]+' | head -1)
                
                [ -z "$port" ] && port=22
                
                # Recreate service with correct settings
                cat > "$service_file" << EOF
[Unit]
Description=fxTunnel SSH Tunnel - ${service}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="HOME=/root"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin"
ExecStart=${FXTUNNEL_BIN} tcp ${port} -t ${token}
Restart=on-failure
RestartSec=10
TimeoutStartSec=30
TimeoutStopSec=10
StandardOutput=journal
StandardError=journal
KillMode=process
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF
                print_success "Updated config for $service"
            fi
            
            # Reload and start
            systemctl daemon-reload
            systemctl enable "$service" 2>/dev/null
            systemctl start "$service" 2>/dev/null &
            
            sleep 3
            
            local status=$(systemctl is-active "$service" 2>/dev/null)
            if [ "$status" = "active" ]; then
                echo -e "  ${GREEN}✓ $service - ACTIVE${NC}"
            elif [ "$status" = "activating" ]; then
                echo -e "  ${YELLOW}⚠ $service - Still activating${NC}"
                print_info "  Checking logs:"
                journalctl -u "$service" --no-pager -n 3
            else
                echo -e "  ${RED}✗ $service - $status${NC}"
                print_info "  Checking logs:"
                journalctl -u "$service" --no-pager -n 3
            fi
            echo ""
        fi
    done <<< "$services"
    
    systemctl daemon-reload
    
    echo ""
    print_success "All services processed!"
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        print_banner
        
        # Check if fxtunnel is installed
        find_fxtunnel
        if [ -n "$FXTUNNEL_BIN" ]; then
            echo -e "  ${GREEN}● fxTunnel: Installed (${FXTUNNEL_BIN})${NC}"
        else
            echo -e "  ${RED}● fxTunnel: Not Installed${NC}"
        fi
        
        # Count services
        local service_count=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | grep -c -i fxtunnel || echo "0")
        echo -e "  ${CYAN}● Active Services: $service_count${NC}"
        echo ""
        
        echo -e "${CYAN}${BOLD}Main Menu:${NC}"
        echo -e "${WHITE}────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${YELLOW}1)${NC}  Install/Update fxTunnel"
        echo -e "  ${YELLOW}2)${NC}  Create New Service"
        echo -e "  ${YELLOW}3)${NC}  List All Services"
        echo -e "  ${YELLOW}4)${NC}  Edit Service"
        echo -e "  ${YELLOW}5)${NC}  Delete Service"
        echo -e "  ${YELLOW}6)${NC}  Manage Services (Start/Stop/Restart)"
        echo -e "  ${YELLOW}7)${NC}  View Service Logs (Live)"
        echo -e "  ${YELLOW}8)${NC}  Show Available Servers"
        echo -e "  ${YELLOW}9)${NC}  Create Bulk Services"
        echo -e "  ${YELLOW}10)${NC} Fix All Services (Repair)"
        echo -e "  ${YELLOW}11)${NC} Test fxTunnel Connection"
        echo -e "  ${YELLOW}0)${NC}  Exit"
        echo -e "${WHITE}────────────────────────────────────────────────────────────${NC}"
        echo ""
        read -p "$(echo -e ${CYAN}"Enter choice [0-11]: "${NC})" choice
        
        case $choice in
            1) install_fxtunnel ;;
            2) create_service ;;
            3) list_services ;;
            4) edit_service ;;
            5) delete_service ;;
            6) manage_service ;;
            7) view_logs ;;
            8) show_servers ;;
            9) create_bulk_services ;;
            10) fix_all_services ;;
            11) test_fxtunnel ;;
            0)
                print_banner
                echo -e "${GREEN}${BOLD}Thank you for using HopingBoyz fxTunnel Manager!${NC}"
                echo -e "${CYAN}YouTube: https://www.youtube.com/@hopingboyz${NC}"
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid option! Please select 0-11"
                sleep 2
                ;;
        esac
    done
}

# Main execution
check_root
main_menu

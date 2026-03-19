#!/bin/bash
# AVB Re-signer TUI
# Interactive menu for re-signing Android partitions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$SCRIPT_DIR/scripts"
OUTPUT="$SCRIPT_DIR/output"
STOCK="$SCRIPT_DIR/firmware/stock"
CUSTOM="$SCRIPT_DIR/firmware/custom"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

clear_screen() {
    clear
}

print_header() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              AVB Re-signer for Locked Bootloader           ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_status() {
    echo ""
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}Status:${NC}"

    # Check stock firmware
    if [ -f "$STOCK/vbmeta.img" ]; then
        echo -e "  Stock firmware:  ${GREEN}Loaded${NC}"
    else
        echo -e "  Stock firmware:  ${RED}Not loaded${NC}"
    fi

    # Check custom ROM
    if [ -f "$CUSTOM/super.img" ]; then
        echo -e "  Custom ROM:      ${GREEN}Loaded${NC}"
    else
        echo -e "  Custom ROM:      ${YELLOW}Not loaded${NC}"
    fi

    # Check unpacked
    if [ -f "$OUTPUT/super_unpacked/system_a.img" ]; then
        echo -e "  Super unpacked:  ${GREEN}Yes${NC}"
    else
        echo -e "  Super unpacked:  ${RED}No${NC}"
    fi

    # Check mounted
    if mount | grep -q "$OUTPUT/mnt"; then
        echo -e "  Partitions:      ${GREEN}Mounted${NC}"
    else
        echo -e "  Partitions:      ${RED}Not mounted${NC}"
    fi

    # Check output
    if [ -f "$OUTPUT/vbmeta.img" ]; then
        echo -e "  Output ready:    ${GREEN}Yes${NC}"
    else
        echo -e "  Output ready:    ${RED}No${NC}"
    fi

    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

pause() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Menu functions
load_stock_firmware() {
    print_header
    echo -e "${BOLD}Load Stock Firmware${NC}"
    echo ""
    echo "Enter path to stock firmware directory:"
    echo "(should contain super.img, vbmeta.img, scatter file, etc.)"
    echo ""
    read -e -p "> " fw_path

    if [ -z "$fw_path" ]; then
        echo -e "${RED}No path entered${NC}"
        pause
        return
    fi

    if [ ! -d "$fw_path" ]; then
        echo -e "${RED}Directory not found: $fw_path${NC}"
        pause
        return
    fi

    echo ""
    echo "Copying stock firmware..."
    rm -rf "$STOCK"/*
    mkdir -p "$STOCK"
    cp -r "$fw_path"/* "$STOCK"/

    echo -e "${GREEN}Stock firmware loaded!${NC}"

    # Auto-check testkey
    if [ -f "$STOCK/vbmeta.img" ]; then
        echo ""
        echo "Checking for AOSP testkey..."
        "$SCRIPTS/check_testkey.sh" "$STOCK/vbmeta.img"
    fi

    pause
}

load_custom_rom() {
    print_header
    echo -e "${BOLD}Load Custom ROM${NC}"
    echo ""
    echo "Load a custom ROM to re-sign for locked bootloader."
    echo "The super.img will be unpacked, signed with AVB hashtrees, and repacked."
    echo ""
    echo "Enter path to custom ROM directory:"
    echo "(must contain super.img, optionally boot.img)"
    echo ""
    read -e -p "> " rom_path

    if [ -z "$rom_path" ]; then
        echo -e "${RED}No path entered${NC}"
        pause
        return
    fi

    if [ ! -d "$rom_path" ]; then
        # Maybe they provided a super.img directly
        if [ -f "$rom_path" ] && [[ "$rom_path" == *super.img ]]; then
            echo "Copying super.img..."
            rm -rf "$CUSTOM"/*
            mkdir -p "$CUSTOM"
            cp "$rom_path" "$CUSTOM/"
            echo -e "${GREEN}Custom ROM loaded!${NC}"
        else
            echo -e "${RED}Directory not found: $rom_path${NC}"
            pause
            return
        fi
    else
        echo ""
        echo "Copying custom ROM..."
        rm -rf "$CUSTOM"/*
        mkdir -p "$CUSTOM"
        cp -r "$rom_path"/* "$CUSTOM"/

        echo -e "${GREEN}Custom ROM loaded!${NC}"
        echo ""
        ls -lh "$CUSTOM/"
    fi

    # Check if stock is loaded, prompt if not
    echo ""
    if [ ! -f "$STOCK/vbmeta.img" ]; then
        echo -e "${YELLOW}Stock firmware also required (for scatter file and testkey).${NC}"
        echo "Enter path to stock firmware directory:"
        echo ""
        read -e -p "> " stock_path

        if [ -n "$stock_path" ] && [ -d "$stock_path" ]; then
            echo "Loading stock firmware..."
            rm -rf "$STOCK"/*
            mkdir -p "$STOCK"
            cp -r "$stock_path"/* "$STOCK"/
            echo -e "${GREEN}Stock firmware loaded!${NC}"
        else
            echo -e "${RED}Stock firmware not loaded. Load it before re-signing.${NC}"
        fi
    fi

    pause
}

check_testkey() {
    print_header
    echo -e "${BOLD}Check Testkey${NC}"
    echo ""

    if [ ! -f "$STOCK/vbmeta.img" ]; then
        echo -e "${RED}No stock firmware loaded. Load stock firmware first.${NC}"
        pause
        return
    fi

    "$SCRIPTS/check_testkey.sh" "$STOCK/vbmeta.img"
    pause
}

unpack_super() {
    print_header
    echo -e "${BOLD}Unpack Super.img${NC}"
    echo ""

    echo "Which super.img to unpack?"
    echo "  1) Stock (firmware/stock/super.img)"
    echo "  2) Custom (firmware/custom/super.img)"
    echo "  0) Back"
    echo ""
    read -p "Choice: " choice

    case $choice in
        1)
            if [ ! -f "$STOCK/super.img" ]; then
                echo -e "${RED}No stock super.img found.${NC}"
                pause
                return
            fi
            "$SCRIPTS/unpack_super.sh" "$STOCK/super.img"
            ;;
        2)
            if [ ! -f "$CUSTOM/super.img" ]; then
                echo -e "${RED}No custom super.img found.${NC}"
                pause
                return
            fi
            "$SCRIPTS/unpack_super.sh" "$CUSTOM/super.img"
            ;;
        0) return ;;
    esac

    pause
}

mount_partitions() {
    print_header
    echo -e "${BOLD}Mount Partitions${NC}"
    echo ""

    if [ ! -f "$OUTPUT/super_unpacked/system_a.img" ]; then
        echo -e "${RED}Super not unpacked. Unpack first.${NC}"
        pause
        return
    fi

    echo "Mount options:"
    echo "  1) Mount all with resize (+50MB)"
    echo "  2) Mount all without resize"
    echo "  3) Mount system_a only"
    echo "  4) Mount vendor_a only"
    echo "  5) Mount product_a only"
    echo "  0) Back"
    echo ""
    read -p "Choice: " choice

    case $choice in
        1)
            echo ""
            echo "Mounting all partitions with resize..."
            sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/system_a.img" --resize
            sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/vendor_a.img" --resize
            sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/product_a.img" --resize
            ;;
        2)
            echo ""
            echo "Mounting all partitions..."
            sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/system_a.img"
            sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/vendor_a.img"
            sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/product_a.img"
            ;;
        3)
            sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/system_a.img" --resize
            ;;
        4)
            sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/vendor_a.img" --resize
            ;;
        5)
            sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/product_a.img" --resize
            ;;
        0) return ;;
    esac

    pause
}

open_file_manager() {
    print_header
    echo -e "${BOLD}Open File Manager${NC}"
    echo ""

    if [ ! -d "$OUTPUT/mnt/system_a" ] && [ ! -d "$OUTPUT/mnt/vendor_a" ] && [ ! -d "$OUTPUT/mnt/product_a" ]; then
        echo -e "${RED}No partitions mounted.${NC}"
        pause
        return
    fi

    echo "Opening file manager at: $OUTPUT/mnt/"
    echo ""

    # Try various file managers
    if command -v nautilus &> /dev/null; then
        nautilus "$OUTPUT/mnt/" &
    elif command -v dolphin &> /dev/null; then
        dolphin "$OUTPUT/mnt/" &
    elif command -v thunar &> /dev/null; then
        thunar "$OUTPUT/mnt/" &
    elif command -v nemo &> /dev/null; then
        nemo "$OUTPUT/mnt/" &
    elif command -v pcmanfm &> /dev/null; then
        pcmanfm "$OUTPUT/mnt/" &
    else
        echo "No graphical file manager found."
        echo "Mounted partitions:"
        ls -la "$OUTPUT/mnt/"
    fi

    pause
}

unmount_partitions() {
    print_header
    echo -e "${BOLD}Unmount Partitions${NC}"
    echo ""

    echo "Unmounting all partitions..."
    "$SCRIPTS/unmount_partition.sh" system_a 2>/dev/null
    "$SCRIPTS/unmount_partition.sh" vendor_a 2>/dev/null
    "$SCRIPTS/unmount_partition.sh" product_a 2>/dev/null

    echo -e "${GREEN}Done!${NC}"
    pause
}

repack_super() {
    print_header
    echo -e "${BOLD}Repack Super.img${NC}"
    echo ""

    if [ ! -f "$OUTPUT/super_unpacked/system_a.img" ]; then
        echo -e "${RED}No unpacked partitions found.${NC}"
        pause
        return
    fi

    # Check if still mounted
    if mount | grep -q "$OUTPUT/mnt"; then
        echo -e "${YELLOW}Warning: Partitions still mounted. Unmounting first...${NC}"
        "$SCRIPTS/unmount_partition.sh" system_a 2>/dev/null
        "$SCRIPTS/unmount_partition.sh" vendor_a 2>/dev/null
        "$SCRIPTS/unmount_partition.sh" product_a 2>/dev/null
    fi

    "$SCRIPTS/repack_super.sh"
    pause
}

resign_boot() {
    print_header
    echo -e "${BOLD}Re-sign Boot.img${NC}"
    echo ""

    echo "Options:"
    echo "  1) Sign stock boot (firmware/stock/boot.img)"
    echo "  2) Sign custom boot (firmware/custom/boot*.img)"
    echo "  3) Sign other boot.img"
    echo "  0) Back"
    echo ""
    read -p "Choice: " choice

    case $choice in
        1)
            if [ ! -f "$STOCK/boot.img" ]; then
                echo -e "${RED}No boot.img in stock firmware.${NC}"
                pause
                return
            fi
            "$SCRIPTS/resign_boot.sh" "$STOCK/boot.img"
            ;;
        2)
            # Try boot.img or boot_a.img
            if [ -f "$CUSTOM/boot.img" ]; then
                "$SCRIPTS/resign_boot.sh" "$CUSTOM/boot.img"
            elif [ -f "$CUSTOM/boot_a.img" ]; then
                "$SCRIPTS/resign_boot.sh" "$CUSTOM/boot_a.img"
            else
                echo -e "${RED}No boot image in custom ROM.${NC}"
                pause
                return
            fi
            ;;
        3)
            echo ""
            echo "Enter path to boot.img:"
            read -e -p "> " boot_path
            if [ ! -f "$boot_path" ]; then
                echo -e "${RED}File not found.${NC}"
                pause
                return
            fi
            "$SCRIPTS/resign_boot.sh" "$boot_path"
            ;;
        0) return ;;
    esac

    pause
}

rebuild_vbmeta() {
    print_header
    echo -e "${BOLD}Rebuild vbmeta.img${NC}"
    echo ""

    "$SCRIPTS/rebuild_vbmeta.sh"
    pause
}

verify_chain() {
    print_header
    echo -e "${BOLD}Verify AVB Chain${NC}"
    echo ""

    "$SCRIPTS/verify_chain.sh"
    pause
}

show_output() {
    print_header
    echo -e "${BOLD}Output Files${NC}"
    echo ""

    if [ ! -d "$OUTPUT" ] || [ -z "$(ls -A $OUTPUT 2>/dev/null)" ]; then
        echo -e "${RED}Output directory is empty.${NC}"
        pause
        return
    fi

    echo "Files in output/:"
    echo ""
    ls -lh "$OUTPUT"/*.img "$OUTPUT"/*.txt 2>/dev/null

    echo ""
    echo -e "${CYAN}These files are ready for flashing with SP Flash Tool.${NC}"
    echo -e "${YELLOW}After flashing, do a factory reset from recovery.${NC}"
    pause
}

full_process_stock() {
    print_header
    echo -e "${BOLD}Full Process - Modify Stock${NC}"
    echo ""

    if [ ! -f "$STOCK/super.img" ]; then
        echo -e "${RED}No stock firmware loaded. Load stock firmware first.${NC}"
        pause
        return
    fi

    echo "This will run the full re-signing process on STOCK firmware:"
    echo "  1. Check testkey"
    echo "  2. Unpack super.img"
    echo "  3. Mount all partitions (with resize)"
    echo "  4. [PAUSE for modifications]"
    echo "  5. Unmount partitions"
    echo "  6. Repack super.img"
    echo "  7. Re-sign boot.img"
    echo "  8. Rebuild vbmeta.img"
    echo "  9. Verify chain"
    echo ""
    read -p "Continue? (y/n): " confirm

    if [ "$confirm" != "y" ]; then
        return
    fi

    echo ""
    echo -e "${CYAN}Step 1: Check testkey${NC}"
    "$SCRIPTS/check_testkey.sh" "$STOCK/vbmeta.img"

    echo ""
    echo -e "${CYAN}Step 2: Unpack super.img${NC}"
    "$SCRIPTS/unpack_super.sh" "$STOCK/super.img"

    echo ""
    echo -e "${CYAN}Step 3: Mount partitions${NC}"
    sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/system_a.img" --resize
    sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/vendor_a.img" --resize
    sudo "$SCRIPTS/modify_partition.sh" "$OUTPUT/super_unpacked/product_a.img" --resize

    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Partitions mounted at: $OUTPUT/mnt/${NC}"
    echo -e "${YELLOW}  Make your modifications now!${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Press Enter when done with modifications..."

    echo ""
    echo -e "${CYAN}Step 5: Unmount partitions${NC}"
    "$SCRIPTS/unmount_partition.sh" system_a
    "$SCRIPTS/unmount_partition.sh" vendor_a
    "$SCRIPTS/unmount_partition.sh" product_a

    echo ""
    echo -e "${CYAN}Step 6: Repack super.img${NC}"
    "$SCRIPTS/repack_super.sh"

    echo ""
    echo -e "${CYAN}Step 7: Re-sign boot.img${NC}"
    "$SCRIPTS/resign_boot.sh" "$STOCK/boot.img"

    echo ""
    echo -e "${CYAN}Step 8: Rebuild vbmeta.img${NC}"
    "$SCRIPTS/rebuild_vbmeta.sh"

    echo ""
    echo -e "${CYAN}Step 9: Verify chain${NC}"
    "$SCRIPTS/verify_chain.sh"

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Process complete! Output files ready in: $OUTPUT/${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}After flashing with SP Flash Tool, do a factory reset from recovery.${NC}"

    pause
}

resign_existing_rom() {
    print_header
    echo -e "${BOLD}Re-sign Existing ROM${NC}"
    echo ""
    echo "Re-sign a custom ROM for locked bootloader."
    echo ""
    echo "Process: Unpack super.img → Add AVB hashtrees → Repack → Sign"
    echo ""
    echo -e "${YELLOW}Requires: Stock firmware (scatter/testkey) + Custom ROM (super.img)${NC}"
    echo ""

    # Check/load stock firmware
    if [ ! -f "$STOCK/vbmeta.img" ]; then
        echo -e "${YELLOW}Stock firmware not loaded.${NC}"
        echo "Enter path to stock firmware directory:"
        echo "(needed for scatter file and testkey)"
        echo ""
        read -e -p "> " stock_path

        if [ -z "$stock_path" ] || [ ! -d "$stock_path" ]; then
            echo -e "${RED}Invalid path${NC}"
            pause
            return
        fi

        echo "Loading stock firmware..."
        rm -rf "$STOCK"/*
        mkdir -p "$STOCK"
        cp -r "$stock_path"/* "$STOCK"/
        echo -e "${GREEN}Stock firmware loaded.${NC}"
        echo ""
    else
        echo -e "Stock firmware: ${GREEN}Loaded${NC}"
    fi

    # Check/load custom ROM
    if [ ! -f "$CUSTOM/super.img" ]; then
        echo -e "${YELLOW}Custom ROM not loaded.${NC}"
        echo "Enter path to custom ROM directory (or super.img):"
        echo ""
        read -e -p "> " custom_path

        if [ -z "$custom_path" ]; then
            echo -e "${RED}No path entered${NC}"
            pause
            return
        fi

        rm -rf "$CUSTOM"/*
        mkdir -p "$CUSTOM"

        if [ -f "$custom_path" ] && [[ "$custom_path" == *super.img ]]; then
            cp "$custom_path" "$CUSTOM/"
        elif [ -d "$custom_path" ]; then
            cp -r "$custom_path"/* "$CUSTOM"/
        else
            echo -e "${RED}Invalid path${NC}"
            pause
            return
        fi
        echo -e "${GREEN}Custom ROM loaded.${NC}"
        echo ""
    else
        echo -e "Custom ROM:     ${GREEN}Loaded${NC}"
    fi

    echo ""
    echo "Stock firmware: $STOCK"
    echo "Custom ROM:     $CUSTOM"

    # Determine boot image
    if [ -f "$CUSTOM/boot.img" ]; then
        BOOT_IMG="$CUSTOM/boot.img"
    elif [ -f "$CUSTOM/boot_a.img" ]; then
        BOOT_IMG="$CUSTOM/boot_a.img"
    else
        BOOT_IMG="$STOCK/boot.img"
    fi
    echo "Boot image:     $BOOT_IMG"
    echo ""

    read -p "Continue with re-signing? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        return
    fi

    echo ""
    "$SCRIPTS/resign_existing_rom.sh"

    pause
}

cleanup() {
    print_header
    echo -e "${BOLD}Cleanup${NC}"
    echo ""

    echo "Options:"
    echo "  1) Clean output only"
    echo "  2) Clean everything (output + firmware)"
    echo "  0) Back"
    echo ""
    read -p "Choice: " choice

    case $choice in
        1)
            "$SCRIPTS/cleanup.sh"
            ;;
        2)
            echo -e "${YELLOW}This will remove all output files AND firmware.${NC}"
            read -p "Are you sure? (y/n): " confirm
            if [ "$confirm" = "y" ]; then
                "$SCRIPTS/cleanup.sh" --all
            fi
            ;;
        0) return ;;
    esac

    pause
}

shrink_partitions() {
    print_header
    echo -e "${BOLD}Shrink Partitions${NC}"
    echo ""

    if [ ! -f "$OUTPUT/super_unpacked/system_a.img" ]; then
        echo -e "${RED}No unpacked partitions found.${NC}"
        pause
        return
    fi

    echo "This will shrink filesystems to minimum size."
    echo "(Only removes unused space, does NOT delete files)"
    echo ""
    read -p "Continue? (y/n): " confirm

    if [ "$confirm" != "y" ]; then
        return
    fi

    echo ""
    for img in "$OUTPUT/super_unpacked/system_a.img" "$OUTPUT/super_unpacked/vendor_a.img" "$OUTPUT/super_unpacked/product_a.img"; do
        if [ -f "$img" ]; then
            echo -e "${CYAN}=== $(basename $img) ===${NC}"
            "$SCRIPT_DIR/tools/android-bins/e2fsck" -f -y "$img" 2>&1 | tail -1
            "$SCRIPT_DIR/tools/android-bins/resize2fs" -M "$img" 2>&1 | tail -2
            echo ""
        fi
    done

    echo -e "${GREEN}Done! Verifying integrity...${NC}"
    echo ""
    for img in "$OUTPUT/super_unpacked/system_a.img" "$OUTPUT/super_unpacked/vendor_a.img" "$OUTPUT/super_unpacked/product_a.img"; do
        if [ -f "$img" ]; then
            echo -n "$(basename $img): "
            "$SCRIPT_DIR/tools/android-bins/e2fsck" -n "$img" 2>&1 | grep -E "clean|errors"
        fi
    done

    pause
}

# Main menu
main_menu() {
    while true; do
        print_header
        print_status

        echo -e "${BOLD}Main Menu:${NC}"
        echo ""
        echo -e "  ${CYAN}Setup:${NC}"
        echo "    1) Load stock firmware"
        echo "    2) Load custom ROM"
        echo "    3) Check testkey"
        echo ""
        echo -e "  ${CYAN}Modify:${NC}"
        echo "    4) Unpack super.img"
        echo "    5) Mount partitions"
        echo "    6) Open file manager"
        echo "    7) Unmount partitions"
        echo ""
        echo -e "  ${CYAN}Build (all required):${NC}"
        echo "    8) Repack super.img"
        echo "    9) Re-sign boot.img"
        echo "   10) Rebuild vbmeta.img (REQUIRED)"
        echo ""
        echo -e "  ${CYAN}Verify & Output:${NC}"
        echo "   11) Verify chain"
        echo "   12) Show output files"
        echo ""
        echo -e "  ${CYAN}Automated:${NC}"
        echo "   13) Full process (modify stock)"
        echo "   14) Re-sign existing ROM"
        echo ""
        echo -e "  ${CYAN}Tools:${NC}"
        echo "   15) Shrink partitions"
        echo "   16) Cleanup"
        echo ""
        echo "    0) Exit"
        echo ""
        read -p "Choice: " choice

        case $choice in
            1) load_stock_firmware ;;
            2) load_custom_rom ;;
            3) check_testkey ;;
            4) unpack_super ;;
            5) mount_partitions ;;
            6) open_file_manager ;;
            7) unmount_partitions ;;
            8) repack_super ;;
            9) resign_boot ;;
            10) rebuild_vbmeta ;;
            11) verify_chain ;;
            12) show_output ;;
            13) full_process_stock ;;
            14) resign_existing_rom ;;
            15) shrink_partitions ;;
            16) cleanup ;;
            0)
                clear_screen
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                sleep 1
                ;;
        esac
    done
}

# Check if running as root (warn but allow)
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Warning: Running as root. Some operations may have permission issues.${NC}"
    echo "It's recommended to run as normal user (sudo will be used when needed)."
    sleep 2
fi

# Start
main_menu

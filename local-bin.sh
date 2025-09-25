#!/bin/bash

LOCAL_BIN_DIR="$HOME/.local/bin"
BINARIES_DIR="./binaries"

check_local_bin_in_path() {
  case ":$PATH:" in
  *":$LOCAL_BIN_DIR:"*)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

add_local_bin_to_path() {
  local shell_name
  local rc_file
  local export_statement="export PATH=\"\$HOME/.local/bin:\$PATH\""

  shell_name=$(basename "$SHELL")

  case "$shell_name" in
  bash)
    rc_file="$HOME/.bashrc"
    ;;
  zsh)
    rc_file="$HOME/.zshrc"
    ;;
  *)
    echo "Shell '$shell_name' not automatically supported"
    return 1
    ;;
  esac

  if [ ! -f "$rc_file" ]; then
    echo "Configuration file $rc_file does not exist"
    return 1
  fi

  if echo "" >>"$rc_file" && echo "$export_statement" >>"$rc_file"; then
    echo "✓ Added PATH export to $rc_file"
    echo "Please restart your shell or run: source $rc_file"
    return 0
  else
    echo "✗ Failed to write to $rc_file"
    return 1
  fi
}

get_available_binaries() {
  available_binaries=()

  if [ ! -d "$BINARIES_DIR" ]; then
    echo "Error: Binaries directory '$BINARIES_DIR' does not exist"
    exit 1
  fi

  for file in "$BINARIES_DIR"/*; do
    if [ -f "$file" ] && [ -x "$file" ]; then
      available_binaries+=("$(basename "$file")")
    fi
  done

  if [ ${#available_binaries[@]} -eq 0 ]; then
    echo "No executable binaries found in '$BINARIES_DIR'"
    exit 1
  fi
}

select_binaries() {
  selected_binaries=()

  get_available_binaries

  echo ""
  echo "=== Local Binary Installer ==="
  echo "Available binaries in $BINARIES_DIR:"
  echo "1. Install all binaries"

  for i in "${!available_binaries[@]}"; do
    echo "$((i + 2)). ${available_binaries[i]}"
  done

  echo ""
  echo "You can select multiple options (e.g., 2,3 for specific binaries)"
  echo "Note: If option 1 is included, it will install all binaries"
  echo ""

  read -p "Enter your choice(s): " user_input

  if [ -z "$user_input" ]; then
    echo "No valid input provided. Exiting."
    exit 1
  fi

  install_all_flag=false
  valid_choices=()

  IFS=',' read -ra choices <<<"$user_input"

  for choice in "${choices[@]}"; do
    choice=$(echo "$choice" | tr -d ' ')

    if [ "$choice" = "1" ]; then
      install_all_flag=true
    elif [ "$choice" -ge 2 ] 2>/dev/null && [ "$choice" -le $((${#available_binaries[@]} + 1)) ] 2>/dev/null; then
      duplicate=false
      for existing in "${valid_choices[@]}"; do
        if [ "$existing" = "$choice" ]; then
          duplicate=true
          break
        fi
      done
      if [ "$duplicate" = false ]; then
        valid_choices+=("$choice")
      fi
    else
      echo "Warning: Invalid choice '$choice' ignored"
    fi
  done

  if [ "$install_all_flag" = true ]; then
    selected_binaries=("${available_binaries[@]}")
    echo "Selected: All binaries"
  else
    if [ ${#valid_choices[@]} -eq 0 ]; then
      echo "No valid choices provided. Exiting."
      exit 1
    fi

    for choice in "${valid_choices[@]}"; do
      binary_index=$((choice - 2))
      selected_binaries+=("${available_binaries[binary_index]}")
    done

    echo -n "Selected binaries: "
    for binary in "${selected_binaries[@]}"; do
      echo -n "$binary "
    done
    echo ""
  fi
}

install_binary() {
  local binary_name="$1"
  local source_path="$BINARIES_DIR/$binary_name"
  local dest_path="$LOCAL_BIN_DIR/$binary_name"

  if [ ! -f "$source_path" ]; then
    echo "✗ Source binary '$source_path' not found"
    return 1
  fi

  if [ -f "$dest_path" ]; then
    echo "! Binary '$binary_name' already exists in $LOCAL_BIN_DIR"
    read -p "Overwrite? (y/N): " -r
    case "$REPLY" in
    [Yy] | [Yy][Ee][Ss]) ;;
    *)
      echo "Skipping $binary_name"
      return 0
      ;;
    esac
  fi

  if cp "$source_path" "$dest_path" && chmod +x "$dest_path"; then
    echo "✓ Successfully installed '$binary_name'"
    return 0
  else
    echo "✗ Failed to install '$binary_name'"
    return 1
  fi
}

install_selected_binaries() {
  local success_count=0
  local total_count=${#selected_binaries[@]}

  if [ "$total_count" -eq 0 ]; then
    echo "No binaries selected for installation"
    return 1
  fi

  echo ""
  echo "Installing selected binaries..."

  for binary in "${selected_binaries[@]}"; do
    if install_binary "$binary"; then
      success_count=$((success_count + 1))
    fi
  done

  echo ""
  echo "Installation complete: $success_count/$total_count binaries installed successfully"

  if [ "$success_count" -gt 0 ]; then
    return 0
  else
    return 1
  fi
}

binary_handler() {
  echo "=== Local Binary Installer ==="
  echo ""

  if [ ! -d "$LOCAL_BIN_DIR" ]; then
    echo "Creating local bin directory: $LOCAL_BIN_DIR"
    if mkdir -p "$LOCAL_BIN_DIR"; then
      echo "✓ Created $LOCAL_BIN_DIR"
    else
      echo "✗ Failed to create $LOCAL_BIN_DIR"
      exit 1
    fi
  else
    echo "✓ Local bin directory exists: $LOCAL_BIN_DIR"
  fi

  select_binaries
  if ! install_selected_binaries; then
    echo "Binary installation failed"
    exit 1
  fi

  echo ""
  echo "Checking PATH configuration..."

  if check_local_bin_in_path; then
    echo "✓ $LOCAL_BIN_DIR is already in your PATH"
    echo "Installation completed successfully!"
    exit 0
  fi

  echo "! $LOCAL_BIN_DIR is not in your PATH"
  echo "Attempting to add to shell configuration..."

  if add_local_bin_to_path; then
    echo ""
    echo "Installation completed successfully!"
    echo "Please restart your shell to use the installed binaries."
  else
    echo ""
    echo "Unable to automatically configure PATH."
    echo "Please manually add the following line to your shell configuration file:"
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "For bash: add to ~/.bashrc"
    echo "For zsh: add to ~/.zshrc"
    echo "For fish: add to ~/.config/fish/config.fish (syntax may differ)"
    echo ""
    echo "After adding the line, restart your shell or source the config file."
  fi
}

available_binaries=()
selected_binaries=()

if [ "${BASH_SOURCE[0]}" = "${0}" ] 2>/dev/null || [ "$0" = "$(basename "$0")" ]; then
  binary_handler "$@"
fi

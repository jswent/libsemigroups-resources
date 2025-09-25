packages_core=(
  automake
)

packages_doc=(
  doxygen
  graphviz
  inkscape
  mactex
)

check_homebrew() {
  if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew is not installed!"
    echo "Please install Homebrew first: https://brew.sh/"
    exit 1
  fi
  echo "✓ Homebrew is installed"
}

install_packages() {
  local -n package_array=$1
  local package_type=$2

  if [ ${#package_array[@]} -eq 0 ]; then
    echo "No packages found in $package_type array"
    return 0
  fi

  echo "Installing $package_type packages..."
  echo "Packages: ${package_array[*]}"

  for package in "${package_array[@]}"; do
    echo "Installing $package..."
    if brew install "$package"; then
      echo "✓ Successfully installed $package"
    else
      echo "✗ Failed to install $package"
      echo "  Please try manually with: brew install $package"
    fi
  done

  echo "Finished installing $package_type packages"
  echo ""
}

install_all_packages() {
  echo "Installing all packages..."
  install_packages packages_core "core"
  install_packages packages_doc "doc"
}

homebrew_handler() {
  check_homebrew

  echo ""
  echo "=== Homebrew Package Installer ==="
  echo "Available options:"
  echo "1. Install everything (core + documentation)"
  echo "2. Install core packages only"
  echo "3. Install documentation packages only"
  echo ""
  echo "You can select multiple options (e.g., 2,3 for core and docs)"
  echo "Note: If option 1 is included, it will override all other selections"
  echo ""

  read -p "Enter your choice(s): " user_input

  IFS=',' read -ra choices <<<"${user_input// /}"

  if [ ${#choices[@]} -eq 0 ]; then
    echo "No valid input provided. Exiting."
    exit 1
  fi

  install_everything_flag=false
  valid_choices=()

  for choice in "${choices[@]}"; do
    case "$choice" in
    1)
      install_everything_flag=true
      ;;
    2 | 3)
      valid_choices+=("$choice")
      ;;
    *)
      echo "Warning: Invalid choice '$choice' ignored"
      ;;
    esac
  done

  if [ "$install_everything_flag" = true ]; then
    echo "Installing everything (option 1 overrides other selections)..."
    install_everything
  else
    if [ ${#valid_choices[@]} -eq 0 ]; then
      echo "No valid choices provided. Exiting."
      exit 1
    fi

    # Remove duplicates and sort
    IFS=$'\n' sorted_choices=($(sort -u <<<"${valid_choices[*]}"))
    unset IFS

    for choice in "${sorted_choices[@]}"; do
      case "$choice" in
      2)
        install_packages packages_core "core"
        ;;
      3)
        install_packages packages_doc "documentation"
        ;;
      esac
    done
  fi

  echo "Package installation process completed!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  homebrew_handler "$@"
fi

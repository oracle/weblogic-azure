# Check environment and tools required to run the script

# ANSI color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

## Check if the required tools are installed and logged in
echo -e "${GREEN}To run this script, you need to have the following tools installed:${NC}"
echo -e "${GREEN}1. yq${NC}"
echo -e "${GREEN}2. Github CLI (gh)${NC}"
echo -e "${GREEN}3. Azure CLI (az)${NC}"
echo -e "${GREEN}And you need to be logged in to GitHub CLI (gh), and Azure CLI (az).${NC}"

echo "Checking if the required tools are installed..."
echo "Checking progress started..."

if ! command -v yq &> /dev/null; then
    echo "Check required tools and environment failed."
    echo "yq is not installed. Please install it to proceed."
    exit 1
fi
echo "1/6...yq is installed."

if ! command -v jq &> /dev/null; then
    echo "Check required tools and environment failed."
    echo "jq is not installed. Please install it to proceed."
    exit 1
fi
echo "2/6...jq is installed."

# Check gh installed
if ! command -v gh &> /dev/null; then
    echo "Check required tools and environment failed."
    echo "GitHub CLI (gh) is not installed. Please install it to proceed."
    exit 1
fi
echo "3/6...GitHub CLI (gh) is installed."


# Check if the GitHub CLI (gh) is logged in
if ! gh auth status &> /dev/null; then
    echo "Check required tools and environment failed."
    echo "You are not logged in to GitHub CLI (gh). Please log in with `gh auth login` to proceed."
    exit 1
fi
echo "4/6...You are logged in to GitHub CLI (gh)."

# check if az is installed
if ! command -v az &> /dev/null; then
    echo "Check required tools and environment failed."
    echo "Azure CLI (az) is not installed. Please install it to proceed."
    exit 1
fi
echo "5/6...Azure CLI (az) is installed."


# check if az is logged in
if ! az account show &> /dev/null; then
    echo "Check required tools and environment failed."
    echo "You are not logged in to Azure CLI (az). Please log in with command `az login` to proceed."
    exit 1
fi
echo "6/6...You are logged in to Azure CLI (az)."

echo "Checking progress completed..."

echo "Select default repository for this project"
gh repo set-default

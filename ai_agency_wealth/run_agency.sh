#!/bin/bash

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Check if venv_agency exists, create it if not
if [ ! -d "venv_agency" ]; then
    echo "Creating virtual environment..."
    uv venv --python 3.12 venv_agency
fi

# Activate venv
source venv_agency/bin/activate

# Install requirements quietly
echo "Installing dependencies (this might take a minute the first time)..."
pip install -r requirements.txt -q

# Run the agency
echo "Booting up AI Agency..."
python3 main.py
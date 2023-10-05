#!/bin/bash

# Function to add an alias if it doesn't exist
add_alias() {
    local alias_name="$1"
    local alias_command="$2"

    # Check if the alias already exists in .bashrc
    if grep -q "alias ${alias_name}=" ~/.bash_aliases; then
        echo "Alias ${alias_name} already exists."
    else
        # Add the alias to .bashrc
        echo "alias ${alias_name}='${alias_command}'" >> ~/.bash_aliases
        echo "Alias ${alias_name} added."
    fi
}

# Examples of adding aliases
#add_alias ll "ls -la"
#add_alias md "mkdir -p"



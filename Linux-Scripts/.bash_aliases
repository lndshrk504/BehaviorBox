# ~/.bash_aliases: shared aliases.

# ---- Shell aliases ----
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CAF'
alias up='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'

# ---- Exit shortcuts ----
alias q='exit'
alias bye='exit'

# ---- Quick checks ----
alias gst='git status'
alias gl='git log --oneline --decorate --graph --all'
alias lg='ls -lah'
alias du1='du -h --max-depth=1'

# ---- BehaviorBox / MATLAB ----
alias bb='matlab -nosplash -nodesktop -r "BehaviorBox_App"'
alias bbwheel='matlab -nosplash -nodesktop -r "BehaviorBox_App Wheel"'
alias bbnose='matlab -nosplash -nodesktop -r "BehaviorBox_App Nose"'
alias bbb='matlab -batch "BehaviorBox_App"'
alias bblog='tail -n 200 -f "$HOME/BehaviorBox.log"'
alias fixset='chmod guo+rw "$HOME"/ComputerSettingsACM*.mat'
alias gltest="matlab -batch 'rendererinfo'"
alias cuda-env='echo "CUDA_HOME=$CUDA_HOME"; echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"; which nvcc'
alias gpu='nvidia-smi'

# ---- Notifications ----
# Add an "alert" alias for long running commands. Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

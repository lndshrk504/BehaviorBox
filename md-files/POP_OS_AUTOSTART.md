## Pop!_OS: run BehaviorBox on login

1) Make the scripts executable:

`chmod +x BBatStartup_popos.sh install_popos_autostart.sh`

2) Install the GNOME autostart entry:

`./install_popos_autostart.sh`

This creates `~/.config/autostart/behaviorbox.desktop` which runs `BBatStartup_popos.sh` at login.

### Notes

- If MATLAB isn’t found at login, either add it to a login shell PATH (e.g. `~/.profile`) or set an explicit path:
  - Example: `MATLAB_BIN=/usr/local/MATLAB/R2024b/bin/matlab ./install_popos_autostart.sh`
- To add a delay before starting, set `STARTUP_DELAY_SECONDS` (default `0`):
  - Example: `STARTUP_DELAY_SECONDS=20 ./BBatStartup_popos.sh`


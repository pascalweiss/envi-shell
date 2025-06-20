#!/usr/bin/env bash

# Set internal display (MacBook Retina) to 200% scaling (0.5x0.5)
# Set external display to 100% scaling (1x1)
xrandr --output eDP-1 --scale 0.5x0.5 --output HDMI-2 --scale 1x1

# If you need to reposition displays, add --pos parameter
# Example: xrandr --output eDP-1 --scale 0.5x0.5 --pos 0x0 --output HDMI-2 --scale 1x1 --pos 2560x0

# Note: you might need to adjust these values based on your specific setup

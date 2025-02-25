#!/bin/bash

current_brightness=$(brightnessctl --device='dell::kbd_backlight' get)

if [ "$current_brightness" = "0" ]; then
  brightnessctl --device='dell::kbd_backlight' set 2
else
  brightnessctl --device='dell::kbd_backlight' set 0
fi

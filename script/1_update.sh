#!/bin/bash
echo "[1]Updating apt..."
echo set debconf to Noninteractive
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y unzip
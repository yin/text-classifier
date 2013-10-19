#!/bin/bash

tcl_bin=tcl8.5
tcl_pkg=$tcl_bin
tk_bin=tk8.5
tk_pkg=$tk_bin

if ! command -v $tcl_bin &>2; then 
	sudo apt-get install $tcl_pkg
fi

if ! command -v $tk_bin &>2; then 
	sudo apt-get install $tk_pkg
fi


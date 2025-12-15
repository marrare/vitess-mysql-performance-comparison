#!/usr/bin/env bash

echo "***** STOPPING PORT-FORWARDS *****"
pkill -f "kubectl port-forward"
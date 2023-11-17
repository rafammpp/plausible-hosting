#!/bin/bash

source write-logs.sh;
docker compose down --remove-orphans && docker compose up --build -d

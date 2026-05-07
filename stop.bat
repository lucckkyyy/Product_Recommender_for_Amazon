@echo off
title Stop All Services
echo.
echo  Stopping all Docker Compose services...
docker compose down
echo.
echo  All services stopped.
echo  To restart: run setup.bat
echo.
pause

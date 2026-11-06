@echo off
cd /d "%~dp0"
echo === Problema 1: rutas de entrega ===
call elixir "01_Rutas\rutas.exs"
echo.
echo === Problema 3: expresiones ===
call elixir "03_Expresiones\expresiones.exs"
echo.
pause

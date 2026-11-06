#!/bin/sh
cd "$(dirname "$0")" || exit 1
printf '%s\n' '=== Problema 1: rutas de entrega ==='
elixir 01_Rutas/rutas.exs
printf '%s\n' '=== Problema 3: expresiones ==='
elixir 03_Expresiones/expresiones.exs

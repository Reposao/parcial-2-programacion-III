# Parcial 2 - Programación III

Este proyecto resuelve los problemas **1 (rutas de entrega)** y **3 (expresiones infijas)**.
Esta combinación está permitida por el enunciado: el problema 1 incluye
`struct` y un Stream infinito. Cada problema se ejecuta por separado.

## Abrir y ejecutar en VS Code

1. Clonar este repositorio o descargarlo como ZIP y abrir la carpeta del proyecto en VS Code.
2. Abrir **Terminal > New Terminal**. Con Elixir instalado, desde la carpeta
   del proyecto se puede ejecutar `./ejecutar.bat` en PowerShell. También se
   puede ejecutar uno por uno:

   ```powershell
   elixir .\01_Rutas\rutas.exs
   elixir .\03_Expresiones\expresiones.exs
   ```

3. Los resultados aparecen en las mismas carpetas de los programas. Cada
   ejecución sustituye los reportes anteriores. No se necesita Mix ni instalar
   dependencias.

En Linux o macOS se puede usar `sh ejecutar.sh`.

## Problema 1: rutas

**Entradas:** `01_Rutas/tramos.csv` y `01_Rutas/consultas.txt`.

**Reportes:** `itinerarios.txt` (caminos, tramos, totales y mejores rutas),
`errores_tramos.txt` (datos mal formados), `depuracion_tramos.txt` (bucles y
parejas repetidas) y `alcance_centros.txt` (estados del Stream hasta la
estabilización).

`Tramo.parse/1` comprueba cada línea antes de usarla. La validación
`depurar/3` recorre recursivamente los tramos válidos y conserva la primera
pareja dirigida; no usa `Enum` ni `Stream` en sus funciones recursivas.
Después se arma el grafo y el Stream de alcance decide si hay posibilidad de
llegar al destino. Solo cuando sí la hay, `buscar/10` recorre caminos simples
sin repetir centros y escribe cada itinerario al encontrarlo. Conserva en
memoria solo los valores mínimos y sus empates para el resumen final.
Los centros se obtienen de los tramos que sobrevivieron a la depuración.

## Problema 3: expresiones

**Entrada:** `03_Expresiones/expresiones.txt`.

**Reportes:** `resultado_expresiones.csv` (resultado o error por línea) y
`errores_expresiones.txt` (expresión y motivo del fallo).

`validar_estructura/1` recorre los caracteres recursivamente antes de
convertir la expresión: localiza caracteres ajenos a la gramática y
paréntesis sin pareja. No usa `Enum` ni `Stream`. `tokenizar/3` separa
literales y operadores, respetando los de dos caracteres. `convertir/4`
ordena los tokens en postfija con una pila y `evaluar/2` calcula con otra
pila, comprobando los tipos y la división por cero. No ejecuta el texto como
código Elixir.

Se aceptan enteros sin signo, `true`, `false`, paréntesis, `!`, `*`, `/`, `+`,
`-`, `<`, `<=`, `>`, `>=`, `==`, `!=`, `&&` y `||`. Los números decimales sí
pueden aparecer como **resultado** de una división. No se aceptan variables,
decimales escritos en la entrada, signo negativo unario ni evaluación con
cortocircuito. Cada línea se resuelve inmediatamente al consumir el flujo.

## Cómo probar otros datos

Las carpetas `casos_prueba` tienen entradas inválidas y de límite. Guardar una
copia del archivo de entrada original, copiar sobre él el caso deseado y
volver a ejecutar el programa. Por ejemplo, en PowerShell:

```powershell
Copy-Item .\01_Rutas\tramos.csv .\01_Rutas\tramos_original.csv
Copy-Item .\01_Rutas\casos_prueba\tramos_invalidos.csv .\01_Rutas\tramos.csv
elixir .\01_Rutas\rutas.exs
Move-Item -Force .\01_Rutas\tramos_original.csv .\01_Rutas\tramos.csv
```

Hacer lo mismo con `consultas.txt` o `expresiones.txt` para los demás casos.
Los nombres de los reportes permanecen iguales, por eso hay que guardar una
copia si se quiere conservar un resultado anterior. Las líneas vacías y las
que empiezan con `#` después de espacios se omiten, pero cuentan para el
número de línea física informado en un error.

En `PRUEBAS.md` se registran los casos probados y sus resultados. El informe PDF y el video se entregan por separado según las indicaciones del profesor.
# Pruebas realizadas

La tabla registra los casos de prueba del proyecto. En este equipo ejecutamos con Elixir 1.18.4 las entradas principales de ambos programas y el caso de tramos inválidos con consultas límite. Después restauramos las entradas principales.

| Escenario | Entradas usadas | Resultado observado |
| --- | --- | --- |
| Red del enunciado | `01_Rutas/tramos.csv` y `consultas.txt` | A -> D: 4 rutas. Menos tramos: 1 y 3; menor tiempo: 1; menor costo: 3. B -> A: 0 rutas. El alcance desde A se estabiliza en el paso 3. |
| Tramos incorrectos y casos límite | `casos_prueba/tramos_invalidos.csv` y `consultas_limite.txt` | Dos tramos descartados (líneas 3 y 4), dos inválidos (líneas 5 y 6), rutas A -> B y B -> A; A -> A tiene una ruta de cero tramos; Z se informa como inexistente. |
| Red más grande | `casos_prueba/tramos_cadena_40.csv` y `consultas_cadena_40.txt` | Una ruta de N0 a N40, con 40 tramos. |
| Falta una entrada | Se retira temporalmente `consultas.txt` | El programa informa cuál archivo falta sin lanzar una excepción. |
| Expresiones del enunciado | `03_Expresiones/expresiones.txt` | Tres expresiones correctas (24, false, true) y una con error por división por cero. |
| Expresiones incorrectas | `casos_prueba/expresiones_invalidas.txt` | Una correcta y seis errores (carácter, paréntesis, operando, tipo, división y falta de operador). |
| Expresiones límite | `casos_prueba/expresiones_limite.txt` | Siete correctas, entre ellas `!!true`, `9 / 2 = 4.5`, `0` y resultados negativos intermedios. |
| Entradas vacías | `casos_prueba/tramos_vacios.csv` / `expresiones_vacias.txt` | Los programas terminan sin excepciones; las consultas reportan centros inexistentes y el CSV de expresiones conserva únicamente su encabezado. |

Para repetir un caso, seguir el procedimiento de copia indicado en `README.md`.
Los archivos `*.txt` y `*.csv` de salida muestran el detalle; esta tabla solo
resume los resultados para que sea fácil comprobarlos al abrir el proyecto.

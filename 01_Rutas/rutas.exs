defmodule Tramo do
  @moduledoc """
  Guarda los datos de un tramo y la línea de donde salió. Esa línea permite
  explicar por qué se descartó un registro sin perder la referencia al CSV.
  """
  defstruct [:origen, :destino, :minutos, :costo, :linea, :texto]

  @doc """
  Convierte una línea física del CSV en un tramo. No interrumpe la lectura
  cuando un dato está mal: devuelve el motivo para escribirlo en el reporte.
  """
  def parse({linea, texto}) do
    case String.split(texto, ",") |> Enum.map(&String.trim/1) do
      [origen, destino, minutos, costo] ->
        with true <- origen != "" and destino != "",
             {m, ""} <- Integer.parse(minutos),
             {c, ""} <- Integer.parse(costo),
             true <- m > 0 and c > 0 do
          {:ok, %Tramo{origen: origen, destino: destino, minutos: m,
                       costo: c, linea: linea, texto: texto}}
        else
          _ -> {:error, "centros vacíos o tiempo/costo no enteros positivos"}
        end

      _ -> {:error, "se esperaban origen,destino,minutos,costo"}
    end
  end
end

defmodule Itinerario do
  @moduledoc """
  Conserva el orden de los centros y tramos de una ruta completa, además de
  los acumulados que se comparan al elegir los mejores itinerarios.
  """
  defstruct centros: [], tramos: [], minutos: 0, costo: 0
end

defmodule RutasEntrega do
  @moduledoc """
  Lee una red dirigida, elimina sus tramos repetidos o circulares y busca
  recursivamente caminos simples para cada consulta. Primero verifica con un
  Stream de alcance si vale la pena iniciar la búsqueda de itinerarios.
  """

  @doc """
  Ejecuta el problema desde esta carpeta. Cada reporte se crea de nuevo para
  que la información de una ejecución anterior no se mezcle con la actual.
  """
  def main do
    tramos = Path.join(__DIR__, "tramos.csv")
    consultas = Path.join(__DIR__, "consultas.txt")

    File.open!(Path.join(__DIR__, "errores_tramos.txt"), [:write, :utf8], fn errores ->
      File.open!(Path.join(__DIR__, "depuracion_tramos.txt"), [:write, :utf8], fn depuracion ->
        File.open!(Path.join(__DIR__, "itinerarios.txt"), [:write, :utf8], fn salida ->
          File.open!(Path.join(__DIR__, "alcance_centros.txt"), [:write, :utf8], fn alcance ->
            if File.regular?(tramos) and File.regular?(consultas) do
              tramos_validos = leer_tramos(tramos, errores)
              tramos_limpios = depurar(tramos_validos, MapSet.new(), depuracion)
                |> Enum.reverse()
              {grafo, centros} = armar_grafo(tramos_limpios)
              leer_consultas(consultas, grafo, centros, salida, alcance)
            else
              if not File.regular?(tramos) do
                mensaje = "Falta el archivo requerido: #{tramos}"
                IO.puts(mensaje)
                IO.write(errores, mensaje <> "\n")
              end

              if not File.regular?(consultas) do
                mensaje = "Falta el archivo requerido: #{consultas}"
                IO.puts(mensaje)
                IO.write(salida, mensaje <> "\n")
              end
            end
          end)
        end)
      end)
    end)
  end

  # La limpieza del archivo es perezosa: solo se construye la lista de tramos
  # después de que Stream.map y Stream.reject terminen su trabajo por línea.
  defp lineas(ruta) do
    ruta
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {texto, numero} ->
      {numero, texto |> String.trim_trailing("\n") |> String.trim_trailing("\r")}
    end)
    |> Stream.reject(fn {_numero, texto} ->
      String.trim(texto) == "" or String.starts_with?(String.trim_leading(texto), "#")
    end)
  end

  defp leer_tramos(ruta, errores) do
    ruta
    |> lineas()
    |> Stream.map(fn {numero, texto} -> {numero, texto, Tramo.parse({numero, texto})} end)
    |> Enum.reduce([], fn {numero, texto, resultado}, acumulados ->
      case resultado do
        {:ok, tramo} -> [tramo | acumulados]
        {:error, motivo} ->
          IO.write(errores, "Línea #{numero}: #{texto} | #{motivo}\n")
          acumulados
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Recorre la lista mediante dos cláusulas propias. Una pareja de centros se
  identifica por su dirección, así que A,B y B,A pueden coexistir. Conserva
  la primera aparición de cada pareja aunque otra cambie minutos o costo.
  """
  def depurar(tramos, vistos, archivo), do: depurar(tramos, vistos, archivo, [])

  # Devuelve la acumulación invertida; la llamada principal la invierte fuera
  # de la validación recursiva para conservar el orden de lectura.
  defp depurar([], _vistos, _archivo, resultado), do: resultado

  defp depurar([tramo | resto], vistos, archivo, resultado) do
    pareja = {tramo.origen, tramo.destino}

    cond do
      tramo.origen == tramo.destino ->
        IO.write(archivo, "Línea #{tramo.linea}: #{tramo.texto} | sale y llega al mismo centro\n")
        depurar(resto, vistos, archivo, resultado)

      MapSet.member?(vistos, pareja) ->
        IO.write(archivo, "Línea #{tramo.linea}: #{tramo.texto} | pareja dirigida repetida\n")
        depurar(resto, vistos, archivo, resultado)

      true ->
        depurar(resto, MapSet.put(vistos, pareja), archivo, [tramo | resultado])
    end
  end

  defp armar_grafo(tramos) do
    {invertido, centros} = Enum.reduce(tramos, {%{}, MapSet.new()}, fn tramo, {grafo, centros} ->
      nuevo_grafo = Map.update(grafo, tramo.origen, [tramo], fn lista -> [tramo | lista] end)
      {nuevo_grafo, centros |> MapSet.put(tramo.origen) |> MapSet.put(tramo.destino)}
    end)

    grafo = Map.new(invertido, fn {origen, salientes} -> {origen, Enum.reverse(salientes)} end)
    {grafo, centros}
  end

  defp leer_consultas(ruta, grafo, centros, salida, alcance) do
    ruta
    |> lineas()
    |> Stream.map(fn {numero, texto} ->
      {numero, texto, String.split(texto, ",") |> Enum.map(&String.trim/1)}
    end)
    |> Enum.each(fn {numero, texto, campos} ->
      case campos do
        [origen, destino] when origen != "" and destino != "" ->
          procesar_consulta(origen, destino, grafo, centros, salida, alcance)

        _ ->
          mensaje = "Línea #{numero}: consulta inválida (#{texto}); se espera origen,destino"
          IO.puts(mensaje)
          IO.write(salida, mensaje <> "\n\n")
          IO.write(alcance, mensaje <> "\n\n")
      end
    end)
  end

  defp procesar_consulta(origen, destino, grafo, centros, salida, alcance) do
    titulo = "=== #{origen} -> #{destino} ===\n"
    IO.write(salida, titulo)
    IO.write(alcance, titulo)

    if MapSet.member?(centros, origen) and MapSet.member?(centros, destino) do
      alcanzados = estados_alcanzables(origen, grafo, alcance)

      if MapSet.member?(alcanzados, destino) do
        {total, mejores} =
          buscar(origen, destino, grafo, MapSet.new([origen]), [origen], [], 0, 0,
                 salida, {0, %{}})

        escribir_resumen(total, mejores, salida)
        IO.puts("#{origen} -> #{destino}: #{total} itinerarios")
      else
        IO.write(salida, "Sin itinerarios: el destino no es alcanzable.\nTotal: 0 itinerarios\n")
        IO.puts("#{origen} -> #{destino}: 0 itinerarios")
      end
    else
      faltantes = Enum.filter([origen, destino], fn centro -> not MapSet.member?(centros, centro) end)
      mensaje = "Centro consultado inexistente: #{Enum.join(faltantes, ", ")}"
      IO.write(salida, mensaje <> "\nTotal: 0 itinerarios\n")
      IO.write(alcance, mensaje <> "\n")
      IO.puts("#{origen} -> #{destino}: 0 itinerarios. #{mensaje}")
    end

    IO.write(salida, "\n")
    IO.write(alcance, "\n")
  end

  @doc """
  Stream.iterate genera tantos estados como se le pidan. La reducción termina
  al comparar dos estados consecutivos iguales; nunca se intenta convertir
  el Stream infinito completo en una lista.
  """
  def estados_alcanzables(origen, grafo, archivo) do
    Stream.iterate(MapSet.new([origen]), fn alcanzados -> expandir(alcanzados, grafo) end)
    |> Enum.reduce_while({nil, 0}, fn estado, {anterior, paso} ->
      if anterior != nil and MapSet.equal?(estado, anterior) do
        IO.write(archivo, "Se estabiliza en el paso #{paso}.\n")
        {:halt, estado}
      else
        nombres = estado |> MapSet.to_list() |> Enum.sort() |> Enum.join(", ")
        IO.write(archivo, "Paso #{paso}: #{nombres}\n")
        {:cont, {estado, paso + 1}}
      end
    end)
  end

  defp expandir(alcanzados, grafo) do
    Enum.reduce(alcanzados, alcanzados, fn centro, estado ->
      Enum.reduce(Map.get(grafo, centro, []), estado, fn tramo, nuevos ->
        MapSet.put(nuevos, tramo.destino)
      end)
    end)
  end

  @doc """
  Explora los tramos salientes en orden. El conjunto visitados pertenece a
  cada camino, lo que evita ciclos sin impedir que otro camino use ese centro.
  """
  def buscar(actual, destino, _grafo, _visitados, centros, tramos, minutos, costo,
             archivo, {contador, mejores})
      when actual == destino do
    ruta = %Itinerario{centros: Enum.reverse(centros), tramos: Enum.reverse(tramos),
                      minutos: minutos, costo: costo}
    numero = contador + 1
    escribir_itinerario(ruta, numero, archivo)

    nuevos_mejores =
      mejores
      |> actualizar_mejor(:tramos, length(ruta.tramos), numero)
      |> actualizar_mejor(:tiempo, ruta.minutos, numero)
      |> actualizar_mejor(:costo, ruta.costo, numero)

    {numero, nuevos_mejores}
  end

  def buscar(actual, destino, grafo, visitados, centros, tramos, minutos, costo,
             archivo, estado) do
    grafo
    |> Map.get(actual, [])
    |> Enum.reduce(estado, fn tramo, acumulado ->
      if MapSet.member?(visitados, tramo.destino) do
        acumulado
      else
        buscar(tramo.destino, destino, grafo, MapSet.put(visitados, tramo.destino),
               [tramo.destino | centros], [tramo | tramos],
               minutos + tramo.minutos, costo + tramo.costo, archivo, acumulado)
      end
    end)
  end

  # Guarda únicamente el menor valor y los números de los itinerarios empatados.
  # Los números se acumulan al revés y se invierten al terminar cada consulta.
  defp actualizar_mejor(mejores, criterio, valor, numero) do
    case Map.get(mejores, criterio) do
      nil -> Map.put(mejores, criterio, {valor, [numero]})
      {menor, _numeros} when valor < menor -> Map.put(mejores, criterio, {valor, [numero]})
      {menor, numeros} when valor == menor -> Map.put(mejores, criterio, {menor, [numero | numeros]})
      _ -> mejores
    end
  end

  defp escribir_itinerario(ruta, numero, archivo) do
    IO.write(archivo,
      "Itinerario #{numero}: #{Enum.join(ruta.centros, " -> ")} | " <>
      "tramos: #{length(ruta.tramos)} | #{ruta.minutos} min | costo: #{ruta.costo}\n")

    IO.write(archivo, "  Tramos usados: ")
    ruta.tramos
    |> Enum.with_index()
    |> Enum.each(fn {t, indice} ->
      if indice > 0, do: IO.write(archivo, "; ")
      IO.write(archivo,
        "#{t.origen}->#{t.destino} (#{t.minutos} min, costo #{t.costo}, línea #{t.linea})")
    end)
    IO.write(archivo, "\n")
  end

  defp escribir_resumen(0, _mejores, archivo) do
    IO.write(archivo, "Sin itinerarios.\nTotal: 0 itinerarios\n")
  end

  defp escribir_resumen(total, mejores, archivo) do
    IO.write(archivo, "Total: #{total} itinerarios\n")
    escribir_mejores(mejores, archivo, "Menos tramos", :tramos)
    escribir_mejores(mejores, archivo, "Menor tiempo", :tiempo)
    escribir_mejores(mejores, archivo, "Menor costo", :costo)
  end

  defp escribir_mejores(mejores, archivo, titulo, criterio) do
    {_valor, invertidos} = Map.fetch!(mejores, criterio)
    numeros = invertidos |> Enum.reverse() |> Enum.map(&Integer.to_string/1)
    IO.write(archivo, "#{titulo}: #{Enum.join(numeros, ", ")}\n")
  end
end

RutasEntrega.main()

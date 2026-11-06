defmodule Expresiones do
  @moduledoc """
  Convierte expresiones a postfija con una pila de operadores y después
  calcula el resultado con otra pila. Cada expresión se resuelve al leer su
  línea, sin almacenar el archivo entero ni ejecutar código de la entrada.

  La entrada acepta enteros sin signo, true, false, paréntesis, !, *, /, +,
  -, <, <=, >, >=, ==, !=, && y ||. No admite variables, decimales escritos
  por el usuario, signo negativo unario ni cortocircuito lógico.
  """

  @doc """
  Reemplaza los dos reportes y procesa el archivo línea por línea. La
  numeración procede del archivo físico, incluso si hay comentarios.
  """
  def main do
    entrada = Path.join(__DIR__, "expresiones.txt")

    File.open!(Path.join(__DIR__, "resultado_expresiones.csv"), [:write, :utf8], fn csv ->
      File.open!(Path.join(__DIR__, "errores_expresiones.txt"), [:write, :utf8], fn errores ->
        IO.write(csv, "linea;infija;postfija;resultado;estado\n")

        if File.regular?(entrada) do
          {correctas, fallidas} =
            entrada
            |> File.stream!()
            |> Stream.with_index(1)
            |> Stream.map(fn {texto, numero} ->
              {numero, texto |> String.trim_trailing("\n") |> String.trim_trailing("\r")}
            end)
            |> Stream.reject(fn {_numero, texto} ->
              String.trim(texto) == "" or String.starts_with?(String.trim_leading(texto), "#")
            end)
            |> Enum.reduce({0, 0}, fn {numero, texto}, conteo ->
              resolver_linea(numero, texto, csv, errores, conteo)
            end)

          IO.puts("Expresiones correctas: #{correctas}; expresiones con error: #{fallidas}")
        else
          mensaje = "Falta el archivo requerido: #{entrada}"
          IO.puts(mensaje)
          IO.write(errores, mensaje <> "\n")
        end
      end)
    end)
  end

  defp resolver_linea(numero, texto, csv, errores, {correctas, fallidas}) do
    # La validación de caracteres y paréntesis ocurre ANTES de la conversión.
    with :ok <- validar_estructura(String.graphemes(texto)),
         {:ok, tokens} <- tokenizar(String.graphemes(texto), 1, []),
         {:ok, postfija} <- convertir(tokens, [], [], :operando),
         {:ok, valor} <- evaluar(postfija, []) do
      post = Enum.map_join(postfija, " ", &texto_token/1)
      fila_csv(csv, [numero, texto, post, mostrar_valor(valor), "OK"])
      {correctas + 1, fallidas}
    else
      {:error, motivo} ->
        # Si la postfija existe, se conserva incluso si evaluar falla.
        post = postfija_si_existe(texto)
        fila_csv(csv, [numero, texto, post, motivo, "ERROR"])
        IO.write(errores, "Línea #{numero}: #{texto} | #{motivo}\n")
        {correctas, fallidas + 1}
    end
  end

  # Esta segunda pasada solo construye el texto de la postfija para el reporte
  # de errores; no modifica el resultado ni vuelve a evaluar la expresión.
  defp postfija_si_existe(texto) do
    with :ok <- validar_estructura(String.graphemes(texto)),
         {:ok, tokens} <- tokenizar(String.graphemes(texto), 1, []),
         {:ok, post} <- convertir(tokens, [], [], :operando) do
      Enum.map_join(post, " ", &texto_token/1)
    else
      _ -> ""
    end
  end

  defp fila_csv(archivo, campos) do
    texto = campos |> Enum.map(&campo_csv/1) |> Enum.join(";")
    IO.write(archivo, texto <> "\n")
  end

  defp campo_csv(valor) do
    texto = to_string(valor)
    if String.contains?(texto, [";", "\"", "\n"]) do
      "\"" <> String.replace(texto, "\"", "\"\"") <> "\""
    else
      texto
    end
  end

  @doc """
  Comprueba los caracteres y los paréntesis con recursión propia. La pila
  conserva la posición de cada apertura para señalar el primer error.
  No usa Enum ni Stream durante esta validación.
  """
  def validar_estructura(caracteres), do: validar(caracteres, 1, [])

  defp validar([], _pos, []), do: :ok
  defp validar([], _pos, aperturas), do: {:error, "paréntesis sin cerrar en posición #{primera(aperturas)}"}

  defp validar([caracter | resto], pos, aperturas) do
    cond do
      caracter == "(" -> validar(resto, pos + 1, [pos | aperturas])
      caracter == ")" and aperturas == [] ->
        {:error, "paréntesis de cierre sin apertura en posición #{pos}"}
      caracter == ")" ->
        [_apertura | pendientes] = aperturas
        validar(resto, pos + 1, pendientes)
      permitido?(caracter) -> validar(resto, pos + 1, aperturas)
      true -> {:error, "carácter no permitido en posición #{pos}: #{caracter}"}
    end
  end

  defp primera([pos]), do: pos
  defp primera([_pos | resto]), do: primera(resto)

  defp permitido?(c) do
    (c >= "0" and c <= "9") or
      (c >= "a" and c <= "z") or
      (c >= "A" and c <= "Z") or
      c in [" ", "\t", "!", "*", "/", "+", "-", "<", ">", "=", "&", "|"]
  end

  @doc """
  Separa números y operadores conservando posiciones de caracteres. Revisa
  primero los operadores de dos caracteres para no dividir <= en < y =.
  """
  def tokenizar([], _pos, acumulados), do: {:ok, Enum.reverse(acumulados)}

  def tokenizar([c | resto], pos, acumulados) when c in [" ", "\t"] do
    tokenizar(resto, pos + 1, acumulados)
  end

  def tokenizar([c | _] = chars, pos, acumulados) when c >= "0" and c <= "9" do
    {numero, pendientes, siguiente} = tomar_digitos(chars, pos, "")
    tokenizar(pendientes, siguiente, [{:numero, String.to_integer(numero), numero, pos} | acumulados])
  end

  def tokenizar([c | _] = chars, pos, acumulados)
      when (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") do
    {palabra, pendientes, siguiente} = tomar_letras(chars, pos, "")
    case palabra do
      "true" -> tokenizar(pendientes, siguiente, [{:booleano, true, pos} | acumulados])
      "false" -> tokenizar(pendientes, siguiente, [{:booleano, false, pos} | acumulados])
      _ -> {:error, "literal desconocido en posición #{pos}: #{palabra}"}
    end
  end

  def tokenizar([a, b | resto], pos, acumulados)
      when {a, b} in [{"<", "="}, {">", "="}, {"=", "="}, {"!", "="},
                      {"&", "&"}, {"|", "|"}] do
    tokenizar(resto, pos + 2, [{:operador, a <> b, pos} | acumulados])
  end

  def tokenizar(["(" | resto], pos, acumulados),
    do: tokenizar(resto, pos + 1, [{:abre, pos} | acumulados])

  def tokenizar([")" | resto], pos, acumulados),
    do: tokenizar(resto, pos + 1, [{:cierra, pos} | acumulados])

  def tokenizar([c | resto], pos, acumulados) when c in ["!", "*", "/", "+", "-", "<", ">"] do
    tokenizar(resto, pos + 1, [{:operador, c, pos} | acumulados])
  end

  def tokenizar([c | _], pos, _acumulados), do: {:error, "operador inválido en posición #{pos}: #{c}"}

  defp tomar_digitos([c | resto], pos, texto) when c >= "0" and c <= "9",
    do: tomar_digitos(resto, pos + 1, texto <> c)
  defp tomar_digitos(resto, pos, texto), do: {texto, resto, pos}

  defp tomar_letras([c | resto], pos, texto)
       when (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"),
       do: tomar_letras(resto, pos + 1, texto <> c)
  defp tomar_letras(resto, pos, texto), do: {texto, resto, pos}

  @doc """
  Aplica precedencia y asociatividad mediante una pila. La salida se guarda
  al revés mientras se recorre y se invierte una sola vez al terminar.
  El estado esperado distingue dónde puede aparecer un operando u operador.
  """
  def convertir([], pila, salida, :operador), do: terminar(pila, salida)
  def convertir([], _pila, _salida, :operando), do: {:error, "expresión incompleta: falta un operando"}

  def convertir([{:numero, _, _, _pos} = t | resto], pila, salida, :operando),
    do: convertir(resto, pila, [t | salida], :operador)
  def convertir([{:booleano, _, _pos} = t | resto], pila, salida, :operando),
    do: convertir(resto, pila, [t | salida], :operador)
  def convertir([{:abre, _} = t | resto], pila, salida, :operando),
    do: convertir(resto, [t | pila], salida, :operando)

  def convertir([{:cierra, pos} | resto], pila, salida, :operador) do
    case sacar_hasta_apertura(pila, salida) do
      {:ok, nueva_pila, nueva_salida} -> convertir(resto, nueva_pila, nueva_salida, :operador)
      :error -> {:error, "paréntesis de cierre inesperado en posición #{pos}"}
    end
  end

  def convertir([{:operador, "!", _} = t | resto], pila, salida, :operando),
    do: convertir(resto, [t | pila], salida, :operando)

  def convertir([{:operador, operador, _} = t | resto], pila, salida, :operador)
      when operador != "!" do
    {nueva_pila, nueva_salida} = sacar_anteriores(pila, salida, prioridad(operador))
    convertir(resto, [t | nueva_pila], nueva_salida, :operando)
  end

  def convertir([t | _], _pila, _salida, esperado) do
    {:error, "token fuera de lugar en posición #{posicion(t)}: se esperaba #{esperado}"}
  end

  defp sacar_hasta_apertura([], _salida), do: :error
  defp sacar_hasta_apertura([{:abre, _} | pila], salida), do: {:ok, pila, salida}
  defp sacar_hasta_apertura([operador | pila], salida),
    do: sacar_hasta_apertura(pila, [operador | salida])

  defp sacar_anteriores([{:operador, op, _} = t | pila] = operadores, salida, prioridad_nueva) do
    if prioridad(op) >= prioridad_nueva do
      sacar_anteriores(pila, [t | salida], prioridad_nueva)
    else
      {operadores, salida}
    end
  end
  defp sacar_anteriores(pila, salida, _prioridad_nueva), do: {pila, salida}

  defp terminar([], salida), do: {:ok, Enum.reverse(salida)}
  defp terminar([{:abre, pos} | _], _salida), do: {:error, "paréntesis sin cerrar en posición #{pos}"}
  defp terminar([operador | resto], salida), do: terminar(resto, [operador | salida])

  defp prioridad("!"), do: 7
  defp prioridad(op) when op in ["*", "/"], do: 6
  defp prioridad(op) when op in ["+", "-"], do: 5
  defp prioridad(op) when op in ["<", "<=", ">", ">="], do: 4
  defp prioridad(op) when op in ["==", "!="], do: 3
  defp prioridad("&&"), do: 2
  defp prioridad("||"), do: 1

  defp posicion({:numero, _, _, pos}), do: pos
  defp posicion({:booleano, _, pos}), do: pos
  defp posicion({_, pos}), do: pos
  defp posicion({:operador, _, pos}), do: pos

  defp texto_token({:numero, _, texto, _}), do: texto
  defp texto_token({:booleano, valor, _}), do: to_string(valor)
  defp texto_token({:operador, texto, _}), do: texto

  @doc """
  Reduce la postfija con una pila de valores. Cada operación comprueba los
  tipos antes de calcular: así un dato incorrecto se convierte en un mensaje
  de error en vez de producir una excepción sin explicar.
  """
  def evaluar([], [valor]), do: {:ok, valor}
  def evaluar([], _pila), do: {:error, "sobran operandos o falta un operador"}
  def evaluar([{:numero, valor, _, _} | resto], pila), do: evaluar(resto, [valor | pila])
  def evaluar([{:booleano, valor, _} | resto], pila), do: evaluar(resto, [valor | pila])

  def evaluar([{:operador, "!", _pos} | resto], [valor | pila]) when is_boolean(valor),
    do: evaluar(resto, [not valor | pila])

  def evaluar([{:operador, "!", pos} | _], _pila),
    do: {:error, "! requiere un booleano en posición #{pos}"}

  def evaluar([{:operador, operador, pos} | resto], [derecha, izquierda | pila]) do
    case operar(operador, izquierda, derecha, pos) do
      {:ok, valor} -> evaluar(resto, [valor | pila])
      {:error, _} = error -> error
    end
  end

  def evaluar([{:operador, _op, pos} | _], _pila),
    do: {:error, "faltan operandos en posición #{pos}"}

  defp operar(op, a, b, pos) when op in ["+", "-", "*", "/"] do
    cond do
      not is_number(a) or not is_number(b) -> {:error, "#{op} requiere números en posición #{pos}"}
      op == "/" and b == 0 -> {:error, "división por cero en posición #{pos}"}
      op == "+" -> {:ok, a + b}
      op == "-" -> {:ok, a - b}
      op == "*" -> {:ok, a * b}
      true -> {:ok, a / b}
    end
  end

  defp operar(op, a, b, pos) when op in ["<", "<=", ">", ">="] do
    if is_number(a) and is_number(b) do
      case op do
        "<" -> {:ok, a < b}
        "<=" -> {:ok, a <= b}
        ">" -> {:ok, a > b}
        ">=" -> {:ok, a >= b}
      end
    else
      {:error, "#{op} requiere números en posición #{pos}"}
    end
  end

  defp operar(op, a, b, pos) when op in ["==", "!="] do
    if mismo_tipo?(a, b) do
      {:ok, if(op == "==", do: a == b, else: a != b)}
    else
      {:error, "#{op} requiere valores del mismo tipo en posición #{pos}"}
    end
  end

  defp operar(op, a, b, pos) when op in ["&&", "||"] do
    if is_boolean(a) and is_boolean(b) do
      {:ok, if(op == "&&", do: a and b, else: a or b)}
    else
      {:error, "#{op} requiere booleanos en posición #{pos}"}
    end
  end

  defp mismo_tipo?(a, b), do: (is_number(a) and is_number(b)) or (is_boolean(a) and is_boolean(b))
  defp mostrar_valor(valor) when is_float(valor), do: :erlang.float_to_binary(valor, [:compact, decimals: 10])
  defp mostrar_valor(valor), do: to_string(valor)
end

Expresiones.main()

defmodule BoomNotifier.MailNotifier do
  @moduledoc false

  @doc """
  Checks given mail notifier config contains all required keys.
  """
  @spec validate_config(keyword(String.t())) :: :ok | {:error, String.t()}
  def validate_config(options) do
    with :ok <- validate_required_config_keys(options),
         :ok <- validate_config_values(options) do
      :ok
    end
  end

  @doc """
  Creates mail subject line from a subject prefix and error reason message.
  """
  @spec build_subject(String.t(), list(%ErrorInfo{}), non_neg_integer()) :: String.t()
  def build_subject(prefix, [%ErrorInfo{reason: reason} | _], max_length) do
    String.slice("#{prefix}: #{reason}", 0..(max_length - 1))
  end

  defp validate_required_config_keys(options) do
    missing_keys = Enum.reject([:mailer, :from, :to, :subject], &Keyword.has_key?(options, &1))

    case missing_keys do
      [] -> :ok
      [missing_key] -> {:error, "#{inspect(missing_key)} parameter is missing"}
      _ -> {:error, "The following parameters are missing: #{inspect(missing_keys)}"}
    end
  end

  #
  # :mailer option
  #

  defp validate_config_values([{:mailer, val} | rest])
       when is_atom(val) and not is_nil(val) do
    case Code.ensure_loaded?(val) do
      true ->
        validate_config_values(rest)

      false ->
        {:error, ":mailer module could not be loaded, got #{inspect(val)}"}
    end
  end

  defp validate_config_values([{:mailer, val} | _rest]) do
    {:error, ":mailer must be a module, got #{inspect(val)}"}
  end

  #
  # :from option
  #

  defp validate_config_values([{:from, val} | rest]) do
    # from: must be a single address
    case valid_address?(val) do
      true ->
        validate_config_values(rest)

      false ->
        {:error,
         ":from did not match required format `addr` or `{name, addr}`, got #{inspect(val)}"}
    end
  end

  #
  # :to option
  #

  defp validate_config_values([{:to, val} | rest]) when is_list(val) do
    # to: can be a single address or a list of addresses
    case Enum.all?(val, &valid_address?/1) do
      true ->
        validate_config_values(rest)

      false ->
        {:error,
         ":to did not match required format `addr` or `{name, addr}` or a list, got #{inspect(val)}"}
    end
  end

  defp validate_config_values([{:to, val} | rest]) do
    # delegate to ":to as list" check
    validate_config_values([{:to, [val]} | rest])
  end

  #
  # :subject option
  #

  defp validate_config_values([{:subject, val} | rest])
       when is_binary(val) do
    validate_config_values(rest)
  end

  defp validate_config_values([{:subject, val} | _rest]) do
    {:error, ":subject must be a string, got #{inspect(val)}"}
  end

  #
  # :max_subject_length option
  #

  defp validate_config_values([{:max_subject_length, val} | rest])
       when is_integer(val) and val > 0 do
    validate_config_values(rest)
  end

  defp validate_config_values([{:max_subject_length, val} | _rest]) do
    {:error, ":max_subject_length must be non-negative integer, got #{inspect(val)}"}
  end

  #
  # fallthrough unknowns, assume valid
  #

  defp validate_config_values([{_, _} | rest]) do
    # unknown key, dont attempt to validate
    validate_config_values(rest)
  end

  defp validate_config_values([]) do
    # nothing else to validate
    :ok
  end

  defp valid_address?(addr) do
    # check addr is string or {name, addr} string tuple
    case addr do
      {a, b} when is_binary(a) and is_binary(b) -> true
      a when is_binary(a) -> true
      _ -> false
    end
  end
end

defmodule Cased.Request do
  @moduledoc false

  import Norm

  @enforce_keys [:client, :id, :method, :path, :key]
  defstruct [
    :client,
    :id,
    :method,
    :path,
    :key,
    query: %{},
    body: %{}
  ]

  @type t :: %__MODULE__{
          client: Cased.Client.t(),
          id: atom(),
          method: :get | :post,
          path: String.t(),
          key: String.t(),
          query: map(),
          body: map()
        }

  ##
  # Request processing

  @type response_processing_strategy :: :raw | :decoded | :transformed
  @type run_opts :: [run_opt()]
  @type run_opt :: {:response, response_processing_strategy()}

  @type run_result :: {:ok, any()} | {:error, Cased.ResponseError.t() | Cased.RequestError.t()}

  @default_run_opts [response: :transformed]

  @doc """
  Execute the request and return optionally decoded/transformed response data.

  ## Options

  - `:response` — Select the processing strategy used on responses (default: `#{
    inspect(@default_run_opts[:response])
  }`)
    - `:raw` — Return the raw response.
    - `:decoded` — Return the decoded body of the response.
    - `:transformed` — Return data after endpoint-specific transformation.
  """
  @spec run(request :: Cased.Request.t(), opts :: run_opts()) ::
          run_result()
  def run(request, opts \\ []) do
    opts =
      @default_run_opts
      |> Keyword.merge(opts)

    case validate_run_opts(opts) do
      {:ok, _} ->
        do_run(request, opts)

      {:error, details} ->
        {:error, %Cased.RequestError{message: "invalid request options", details: details}}
    end
  end

  @spec do_run(request :: Cased.Request.t(), opts :: run_opts()) ::
          {:ok, any()} | {:error, Cased.ResponseError.t() | Cased.RequestError.t()}
  defp do_run(request, opts) do
    url =
      request.client.url
      |> URI.merge(request.path)
      |> Map.put(:query, Plug.Conn.Query.encode(request.query))
      |> to_string()

    body =
      if request.body do
        Jason.encode!(request.body)
      else
        ""
      end

    Mojito.request(
      request.method,
      url,
      Cased.Headers.create(request.key),
      body,
      timeout: request.client.timeout
    )
    |> case do
      {:ok, %{status_code: status} = response} ->
        cond do
          Enum.member?(200..299, status) or status == 302 ->
            request
            |> response_processor(opts[:response])
            |> process(response)

          true ->
            {:error, %Cased.ResponseError{response: response}}
        end

      err ->
        err
    end
  end

  @doc """
  Execute the request and return optionally decoded/transformed response data,
  raising an exception if an error occurs.

  See `run/2` for more information.
  """
  @spec run!(request :: Cased.Request.t(), opts :: run_opts()) ::
          any() | no_return()
  def run!(request, opts \\ []) do
    case run(request, opts) do
      {:ok, response} ->
        response

      {:error, err} ->
        raise %Cased.ResponseError{details: err}
    end
  end

  # Ensure the options given to `run/2` are correct.
  @spec validate_run_opts(opts :: run_opts()) :: {:ok, any()} | {:error, any()}
  defp validate_run_opts(opts) do
    opts
    |> Map.new()
    |> conform(
      schema(%{
        response: spec(&(&1 in ~w(raw decoded transformed)a))
      })
      |> selection()
    )
  end

  ##
  # Response Processing

  @type response_processor :: nil | :json | {:request, t()}

  # Find the response processor given a request and a selected processing strategy.
  @spec response_processor(
          request :: Cased.Request.t(),
          strategy :: response_processing_strategy()
        ) :: response_processor()
  defp response_processor(request, :transformed), do: {:request, request}
  defp response_processor(_request, :raw), do: nil
  defp response_processor(_request, :decoded), do: :json

  # Process a response with a response processor.
  @spec process(processor :: response_processor(), response :: Mojito.response()) :: any()
  defp process(nil, response), do: {:ok, response}

  defp process(:json, response) do
    case Jason.decode(response.body) do
      {:error, err} ->
        {:error,
         %Cased.ResponseError{message: "invalid JSON body", details: err, response: response}}

      result ->
        result
    end
  end

  defp process({:request, %{id: id}}, response) when id in [:events, :audit_trail_events] do
    case process(:json, response) do
      {:ok, contents} ->
        {:ok, Enum.map(Map.get(contents, "results", []), &Cased.Event.from_json!/1)}

      err ->
        err
    end
  end

  defp process({:request, %{id: :audit_trail_event}}, response) do
    case process(:json, response) do
      {:ok, contents} ->
        {:ok, Cased.Event.from_json!(contents)}

      err ->
        err
    end
  end

  defp process({:request, %{id: :export_create}}, response) do
    case process(:json, response) do
      {:ok, raw_export} ->
        {:ok, Cased.Export.from_json!(raw_export)}

      err ->
        err
    end
  end

  defp process({:request, %{id: :export_download}}, response) do
    case response.status_code do
      202 ->
        {:ok, :pending}

      302 ->
        export_download(response)

      unknown ->
        {:error,
         %Cased.ResponseError{message: "unexpected status code #{unknown}", response: response}}
    end
  end

  defp process({:request, %{id: :export}}, response) do
    case process(:json, response) do
      {:ok, raw_export} ->
        {:ok, Cased.Export.from_json!(raw_export)}

      err ->
        err
    end
  end

  defp process({:request, %{id: :policies}}, response) do
    case process(:json, response) do
      {:ok, contents} ->
        {:ok, Enum.map(Map.get(contents, "results", []), &Cased.Policy.from_json!/1)}

      err ->
        err
    end
  end

  defp process({:request, %{id: id}}, response) when id in [:policy, :policy_create] do
    case process(:json, response) do
      {:ok, raw_policy} ->
        {:ok, Cased.Policy.from_json!(raw_policy)}

      err ->
        err
    end
  end

  ##
  # Stream

  @spec stream(request :: Cased.Request.t(), opts :: run_opts()) :: any()
  def stream(request, opts \\ []) do
    request_fun = fn page ->
      opts =
        opts
        |> Keyword.put(:page, page)

      run(request, opts)
    end

    first_page = Map.get(request.query, :page, Keyword.get(opts, :page, 1))

    Stream.resource(
      fn -> {request_fun, first_page} end,
      fn
        :quit ->
          {:halt, nil}

        {fun, page} ->
          case fun.(page) do
            {:ok, []} ->
              {[], :quit}

            {:ok, data} when is_list(data) ->
              {data, {fun, page + 1}}

            {:ok, data} ->
              {[data], :quit}

            {:error, err} ->
              raise err
          end
      end,
      & &1
    )
  end

  @spec export_download(response :: Mojito.response()) :: run_result()
  defp export_download(response) do
    case Mojito.Headers.get(response.headers, "location") do
      nil ->
        {:error,
         %Cased.ResponseError{
           message: "no location header found in HTTP 302 response",
           response: response
         }}

      location ->
        Mojito.request(
          :get,
          location
        )
        |> case do
          {:ok, %{status_code: 200} = response} ->
            {:ok, response.body}

          {:error, other} ->
            {:error, %Cased.ResponseError{response: other}}
        end
    end
  end
end

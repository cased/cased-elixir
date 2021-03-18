defmodule Cased.CLI.Session do
  @moduledoc false

  use GenServer

  @session_url "https://api.cased.com/cli/sessions"
  @request_timeout 15_000
  @poll_timer 1_000

  defmodule State do
    defstruct id: nil,
              url: nil,
              api_url: nil,
              api_record_url: nil,
              state: nil,
              metadata: nil,
              reason: nil,
              command: nil,
              guard_application: nil

    def from_session(state, session) do
      %{
        state
        | id: Map.get(session, "id"),
          url: Map.get(session, "url"),
          api_url: Map.get(session, "api_url"),
          api_record_url: Map.get(session, "api_record_url"),
          state: Map.get(session, "state"),
          metadata: Map.get(session, "metadata"),
          reason: Map.get(session, "reason"),
          command: Map.get(session, "command"),
          guard_application: Map.get(session, "guard_application")
      }
    end
  end

  ## Client API

  def start() do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      pid -> {:ok, pid}
    end
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # def retrive_session(id) do
  # end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def create(console_pid, attrs \\ %{}) do
    GenServer.cast(__MODULE__, {:create, console_pid, attrs})
  end

  def record() do
    :ok
  end

  ## Server callback
  @impl true
  def init(opts) do
    {:ok, State.__struct__(opts)}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:create, console_pid, attrs}, state) do
    case do_create_session(Cased.CLI.Identity.get(), attrs) do
      {:ok, session} ->
        new_state = State.from_session(state, session)

        with %{state: "requested"} <- new_state do
          Process.send_after(self(), {:wait_approval, console_pid, 0}, @poll_timer)
        end

        send(console_pid, {:session, new_state, 0})
        {:noreply, new_state}

      {:invalid, %{"error" => error}} ->
        send(console_pid, {:error, error, state})
        {:noreply, state}

      {_, _reason} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:wait_approval, console_pid, counter}, %{id: id} = state) do
    case do_retrive_session(Cased.CLI.Identity.get(), id) do
      {:ok, session} ->
        new_state = State.from_session(state, session)

        with %{state: "requested"} <- new_state do
          Process.send_after(self(), {:wait_approval, console_pid, counter + 1}, @poll_timer)
        end

        send(console_pid, {:session, new_state, counter})
        {:noreply, new_state}

      {:error, error} ->
        send(console_pid, {:error, error, state})
        {:noreply, state}
    end
  end

  ## Cased API

  def do_retrive_session(%{api_key: key, user: %{"id" => user_token}} = _identity, session_id) do
    Mojito.get(
      @session_url <> "/#{session_id}" <> "?user_token=#{user_token}",
      build_headers(key)
    )
    |> case do
      {:ok, %{status_code: code, body: body}} when code in 200..299 ->
        Jason.decode(body)

      {:ok, %{status_code: code, body: body}} when code in 400..499 ->
        {:error, Jason.decode!(body)}

      {_, %{body: body}} ->
        {:error, body}
    end
  end

  def do_create_session(%{api_key: key, user: %{"id" => user_token}} = _identity, attrs \\ %{}) do
    Mojito.post(
      @session_url <> "?user_token=#{user_token}",
      build_headers(key),
      Jason.encode!(attrs),
      timeout: @request_timeout
    )
    |> case do
      {:ok, %{status_code: code, body: body}} when code in 200..299 ->
        Jason.decode(body)

      {:ok, %{status_code: code, body: body}} when code in 400..499 ->
        {:invalid, Jason.decode!(body)}

      {_, %{body: body}} ->
        {:error, body}
    end
  end

  defp build_headers(key) do
    [{"Accept", "application/json"} | Cased.Headers.create(key)]
  end
end

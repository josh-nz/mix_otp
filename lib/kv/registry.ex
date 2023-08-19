defmodule KV.Registry do
  use GenServer

  # Client API

  @doc """
  Starts the registry with the given options.

  `:name` is always required.
  """
  def start_link(opts) do
    # 1. Pass the name to GenServer's init
    server = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, server, opts)
  end

  @doc """
  Looks up the bucket pid for `name` stored in `server`.

  Returns `{:ok, pid}` if the bucket exists, `:error` otherwise.
  """
  def lookup(server, name) do
    # 2. Lookup is now done directly in ETS, without accessing the server
    case :ets.lookup(server, name) do
      [{^name, pid}] -> {:ok, pid}
      [] -> :error
    end
    # GenServer.call(server, {:lookup, name})
  end

  @doc """
  Ensures there is a bucket associated with the given `name` in `server`.
  """
  def create(server, name) do
    GenServer.call(server, {:create, name})
  end


  # GenServer callbacks

  @impl true
  def init(table) do
    # 3. We have replaced the names map by the ETS table
    names = :ets.new(table, [:named_table, read_concurrency: true])
    # names = %{}
    refs = %{}
    {:ok, {names, refs}}
  end

  # 4. The previous handle_call callback for lookup was removed
  # @impl true
  # def handle_call({:lookup, name}, _from, state) do
  #   {names, _} = state
  #   {:reply, Map.fetch(names, name), state}
  # end

  @impl true
  def handle_call({:create, name}, _from, {names, refs}) do
    # 5. Read and write to the ETS table instead of the map
    case lookup(names, name) do
      {:ok, bucket_pid} ->
        {:reply, bucket_pid, {names, refs}}
      :error ->
        {:ok, bucket_pid} = DynamicSupervisor.start_child(KV.BucketSupervisor, KV.Bucket)
        ref = Process.monitor(bucket_pid)
        refs = Map.put(refs, ref, name)
        :ets.insert(names, {name, bucket_pid})
        {:reply, bucket_pid, {names, refs}}
    end

    # if Map.has_key?(names, name) do
    #   {:noreply, {names, refs}}
    # else
    #   {:ok, bucket_pid} = DynamicSupervisor.start_child(KV.BucketSupervisor, KV.Bucket)
    #   ref = Process.monitor(bucket_pid)
    #   refs = Map.put(refs, ref, name)
    #   names = Map.put(names, name, bucket_pid)
    #   {:noreply, {names, refs}}
    # end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    # 6. Delete from the ETS table instead of the map
    {name, refs} = Map.pop(refs, ref)
    :ets.delete(names, name)
    # names = Map.delete(names, name)
    {:noreply, {names, refs}}
  end

  @impl true
  def handle_info(msg, state) do
    require Logger
    Logger.debug("Unexpected message in KV.Registry: #{inspect(msg)}")
    {:noreply, state}
  end
end

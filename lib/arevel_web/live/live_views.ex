defmodule ArevelWeb.CounterLive do
  use Phoenix.LiveView
  # def render(assigns) do
  #   ArevelWeb.PageView.render("index.html", assigns)
  # end

  # def mount(%{expression: expression}, socket) do
  #   # case Thermostat.get_user_reading(user_id, id) do
  #   #   {:ok, temperature} ->
  #   #     {:ok, assign(socket, :temperature, temperature)}
  #   #   {:error, reason} ->
  #   #     {:error, reason}

  #   {:ok, assign(socket, :expression, expression)}
  # end

  def render(assigns) do
    ~L"""
    <div>
      <h1 phx-click="boom">The count is: <%= @val %></h1>
      <button phx-click="boom" class="alert-danger">BOOM</button>
      <button phx-click="dec">-</button>
      <button phx-click="inc">+</button>
    </div>
    """
  end

  def mount(_session, socket) do
    {:ok, assign(socket, :val, 0)}
  end

  def handle_event("inc", _, socket) do
    {:noreply, update(socket, :val, &(&1 + 1))}
  end

  def handle_event("dec", _, socket) do
    {:noreply, update(socket, :val, &(&1 - 1))}
  end


end



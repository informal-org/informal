defmodule ArevelWeb.CounterLive do
  use Phoenix.LiveView
  alias ArevelWeb.CounterView

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
    CounterView.render("index.html", assigns)
  end

  def mount(_session, socket) do
    {:ok, assign(socket, :val, 0)}
  end

  def handle_event("inc", _, socket) do
    {:noreply, update(socket, :val, &(&1 + 1))}
  end

  def handle_event("dec", _, socket) do
    {:noreply, assign(socket, :val, 5 )}
  end


end



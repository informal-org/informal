defmodule ArevelWeb.PageController do
  use ArevelWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end

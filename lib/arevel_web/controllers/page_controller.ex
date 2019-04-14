defmodule ArevelWeb.PageController do
  use ArevelWeb, :controller

  plug :push, "/js/app.js"
  plug :push, "/css/app.css"

  def index(conn, _params) do
    render(conn, "index.html")
  end
end

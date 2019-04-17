defmodule ArevelWeb.PageController do
  use ArevelWeb, :controller

  plug :push, "/js/app.js"
  plug :push, "/css/app.css"

  def index(conn, _params) do
    json(conn, %{hello: "world"})
  end
end



defmodule ArevelWeb.HealthCheckController do
  use ArevelWeb, :controller

  def healthcheck(conn, _params) do
    json(conn, %{status: "OK"})
  end
end

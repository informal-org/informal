defmodule ArevelWeb.PageController do
  use ArevelWeb, :controller
  import VM

  # plug :push, "/js/app.js"
  # plug :push, "/css/app.css"

  def index(conn, _params) do
    # json(conn, %{hello: "world"})
    code = %{
      body: [
        %{
          id: 1,
          value: "=1 + 1"
        }
      ]
    }

    result = VM.eval(code)
    json(conn, %{code: code, result: result})

  end
end



defmodule ArevelWeb.HealthCheckController do
  use ArevelWeb, :controller

  # Currently configured to just look for any response.
  # TODO: Status based and giving more output.
  # TODO: Restrict to internal network?
  def healthcheck(conn, _params) do
    json(conn, %{status: "OK"})
  end
end

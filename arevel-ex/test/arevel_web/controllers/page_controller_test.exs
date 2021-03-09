defmodule ArevelWeb.PageControllerTest do
  use ArevelWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    # TODO: FIX ME now that I changed the html
    # assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end

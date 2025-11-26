defmodule ChurchappWeb.PageController do
  use ChurchappWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

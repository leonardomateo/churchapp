defmodule ChurchappWeb.PageController do
  use ChurchappWeb, :controller

  def home(conn, _params) do
    # Redirect web domain root to congregants page
    redirect(conn, to: ~p"/congregants")
  end
end

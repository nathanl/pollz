defmodule PollzWeb.PageController do
  use PollzWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

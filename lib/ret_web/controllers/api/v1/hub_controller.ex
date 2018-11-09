defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller

  alias Ret.{Hub, Scene, Repo}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

  def create(conn, %{"hub" => %{"scene_id" => scene_id}} = params) do
    scene = Scene |> Repo.get_by(scene_sid: scene_id)

    %Hub{}
    |> Hub.changeset(scene, params["hub"])
    |> exec_create(conn)
  end

  def create(conn, %{"hub" => _hub_params} = params) do
    %Hub{}
    |> Hub.changeset(nil, params["hub"])
    |> exec_create(conn)
  end

  defp exec_create(hub_changeset, conn) do
    {result, hub} = hub_changeset |> Repo.insert()

    case result do
      :ok -> 
        account = conn |> Guardian.Plug.current_resource()
        account |> add_host_role(hub)
        render(conn, "create.json", hub: hub)
      :error -> conn |> send_resp(422, "invalid hub")
    end
  end

  defp add_host_role(account, hub) when not is_nil(account) do
    %HubAccountRole{}
    |> HubAccountRole.changeset(account, hub, ${roles: })
    |> Repo.insert()
  end

  def delete(conn, %{"id" => hub_sid}) do
    Hub
    |> Repo.get_by(hub_sid: hub_sid)
    |> Hub.changeset_to_deny_entry()
    |> Repo.update!()

    conn |> send_resp(200, "OK")
  end
end

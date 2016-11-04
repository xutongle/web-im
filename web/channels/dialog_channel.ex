defmodule Zheye.DialogChannel do
  use Zheye.Web, :channel

  alias Zheye.{WebChatUser, WebChatDialog}

  def join("dialog:" <> _user_info, _, socket) do
    {:ok, socket}
  end

  def handle_in("shout", payload, socket) do
    {:ok, dialog} = %WebChatDialog{
      domain: socket.assigns.domain,
    }
    |> WebChatDialog.changeset(payload)
    |> Repo.insert

    user = WebChatUser |> Repo.get_by(origin_id: dialog.from_id)

    dialog_data = %{
      from_id: dialog.from_id,
      to_id: dialog.to_id,
      content: dialog.content,
      inserted_at: dialog.inserted_at,
      user: %{
        id: user.origin_id,
        name: user.name,
        avatar: user.avatar,
        bio: user.bio,
      }
    }

    broadcast socket, "shout", dialog_data

    self_topic = "self:" <> dialog.to_id <> "@" <> socket.assigns.domain
    socket.endpoint.broadcast self_topic, "notification:dialog", dialog_data
    {:noreply, socket}
  end

  def handle_in("get_notes", _, socket) do
    [_, user_info] = socket.topic |> String.split(":")
    [user_info, _] = user_info |> String.split("@")
    [user_1, user_2] = user_info |> String.split("&")

    list = WebChatDialog
      |> where([d], d.domain == ^socket.assigns.domain)
      |> where([d], (d.from_id == ^user_1 and d.to_id == ^user_2) or (d.from_id == ^user_2 and d.to_id == ^user_1))
      |> order_by([desc: :inserted_at])
      |> limit(20)
      |> Repo.all
      |> Enum.reverse

    list_data = Enum.map(list, fn item ->
      %{
        from_id: item.from_id,
        to_id: item.to_id,
        content: item.content,
        inserted_at: item.inserted_at
      }
    end)

    push socket, "get_notes", %{data: list_data}

    {:noreply, socket}
  end
end
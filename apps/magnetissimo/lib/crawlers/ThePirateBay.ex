defmodule Magnetissimo.Crawlers.ThePirateBay do
  use GenServer
  import SweetXml
  require Logger
  alias Magnetissimo.{Repo, Torrent}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(state) do
    schedule_rss_fetch()
    {:ok, state}
  end

  def handle_info(:rss_fetch, state) do
    rss_body = rss()

    %{torrents: torrents} =
      rss_body
      |> xmap(
        torrents: [
          ~x"//channel/item"l,
          name: ~x"./title/text()",
          canonical_url: ~x"./comments/text()",
          published_at: ~x"./pubDate/text()",
          magnet_url: ~x"./link/text()"
        ]
      )

    Enum.each(torrents, fn torrent_data ->
      save_torrent(torrent_data)
    end)

    schedule_rss_fetch()
    {:noreply, state}
  end

  defp save_torrent(data) do
    name = List.to_string(data.name)
    canonical_url = List.to_string(data.canonical_url)
    magnet_url = List.to_string(data.magnet_url)

    torrent =
      Torrent.changeset(%Torrent{}, %{
        name: name,
        canonical_url: canonical_url,
        magnet_url: magnet_url,
        leechers: 0,
        seeds: 0,
        website_source: "ThePirateBay",
        size: 0
      })

    Repo.insert(torrent, on_conflict: :nothing)
  end

  defp rss do
    Logger.debug("[ThePirateBay] Downloading url: https://thepiratebay1.top/rss//top100/0")

    "https://thepiratebay1.top/rss//top100/0"
    |> HTTPoison.get!()
    |> Map.get(:body)
  end

  defp schedule_rss_fetch do
    Process.send_after(self(), :rss_fetch, 15_000)
  end
end

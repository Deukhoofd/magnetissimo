defmodule Magnetissimo.Crawlers.EZTV do
  use GenServer
  import SweetXml
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(state) do
    Logger.info("[leetx] Performing crawl for latest")
    schedule_rss_fetch()
    {:ok, state}
  end

  def handle_info(:rss_fetch, state) do
    rss_body = rss()

    result =
      rss_body
      |> xmap(
        torrents: [
          ~x"//channel/item"l,
          name: ~x"./title/text()",
          canonical_url: ~x"./link/text()",
          published_at: ~x"./pubDate/text()",
          magnet_url: ~x"./torrent:magnetURI/text()",
          seeds: ~x"./torrent:seeds/text()",
          leechers: ~x"./torrent:peers/text()"
        ]
      )

    # TODO - Persist torrents into database.

    schedule_rss_fetch()
    {:noreply, state}
  end

  defp rss do
    Logger.info("[EZTV] Downloading url: https://eztv.io/ezrss.xml")

    "https://eztv.io/ezrss.xml"
    |> HTTPoison.get!()
    |> Map.get(:body)
  end

  defp schedule_rss_fetch do
    Process.send_after(self(), :rss_fetch, 5_000)
  end
end

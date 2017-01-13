class SummonersController < ApplicationController
  include RiotApi
  before_action :load_summoner

  BEST_CHAMPION_SIZE = 3

  def show
    name = @summoner.name
    id = @summoner.id
    region = @region.region

    summoner_stats = RiotApi.get_summoner_stats(id: id, region: region)
    summoner_champions = RiotApi.get_summoner_champions(id: id, region: region)

    render json: {
      speech: (
        "#{name} #{summoner_stats_message(summoner_stats)}. Playing " \
        "#{name}'s most common champions, the summoner has a " \
        "#{summoner_champions_message(summoner_champions)}."
      )
    }
  end

  private

  def summoner_stats_message(summoner_stats)
    hot_streak = false
    message = summoner_stats.map do |stats|
      hot_streak ||= stats[:isHotStreak]
      "is ranked #{stats[:tier]} #{stats[:division]} with " \
      "#{stats[:leaguePoints]}LP in #{stats[:queue]}"
    end.en.conjunction(article: false)

    message.tap do
      message.prepend('is on a hot streak. The player ') if hot_streak
    end
  end

  def summoner_champions_message(summoner_champions)
    champions = Rails.cache.read(:champions)
    summoner_champions.first(BEST_CHAMPION_SIZE).each do |champion|
      details = champions.detect { |_, data| data[:id] == champion[:id] }
      champion[:name] = details.last[:name]
    end.map do |champion|
      stats = champion[:stats]
      winrate = stats[:totalSessionsWon] / stats[:totalSessionsPlayed].to_f * 100
      "#{winrate.round(2)}% win rate on #{champion[:name]} in " \
      "#{stats[:totalSessionsPlayed]} games"
    end.en.conjunction
  end

  def summoner_params
    params.require(:result).require(:parameters).permit(:summoner, :region)
  end

  def load_summoner
    @region = Region.new(region: summoner_params[:region])
    unless @region.valid?
      render json: { speech: @region.error_message }
      return false
    end

    @summoner = Summoner.new(name: summoner_params[:summoner])
    @summoner.id = RiotApi.get_summoner_id(
      name: @summoner.name,
      region: @region.region
    )

    unless @summoner.valid?
      render json: { speech: @summoner.error_message }
      return false
    end
  end
end
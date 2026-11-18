# The Issuer rules section on the Cards page: a tile per major issuer with its
# rules and how this holder's cards stand against them today.
class RewardCard::IssuerRules
  FEATURED = %w[capital_one chase citi bofa amex].freeze

  Line = Data.define(:label, :statuses, :next_on) do
    def clear? = next_on.nil?
  end

  Tile = Data.define(:issuer, :cards, :lines) do
    def open_cards = cards.select(&:open?)
    def closed_cards = cards.reject(&:open?)
    def blocked? = lines.any? { |line| !line.clear? }
    def next_on = lines.filter_map(&:next_on).max
  end

  attr_reader :eligibility, :today

  def initialize(eligibility)
    @eligibility = eligibility
    @today = eligibility.today
  end

  def tiles
    @tiles ||= FEATURED.filter_map do |key|
      issuer = RewardCard::Catalog.issuers[key]
      next unless issuer

      Tile.new(issuer: issuer, cards: eligibility.cards.select { |card| card.issuer == key }, lines: lines_for(key))
    end
  end

  private
    # A personal line always; a business line when the catalog has a business
    # card from this issuer and its rules differ from the personal ones.
    def lines_for(key)
      personal = line("personal", eligibility.issuer_rule_statuses(key))
      return [ personal ] unless business_cards?(key)

      business = line("business", eligibility.issuer_rule_statuses(key, business: true))
      shape = ->(line) { line.statuses.map { |status| [ status.note, status.blocker&.until ] } }
      shape.(business) == shape.(personal) ? [ personal ] : [ personal, business ]
    end

    def line(label, statuses)
      dates = statuses.filter_map { |status| status.blocker.until if status.blocker&.active?(today) && status.blocker.until.is_a?(Date) }
      Line.new(label: label, statuses: statuses, next_on: dates.max)
    end

    def business_cards?(key)
      RewardCard::Catalog.products.values.any? { |product| product.issuer == key && product.business }
    end
end

# Current sign-up offers per catalog product, from config/reward_bonuses.yml.
# That file is not part of the image: sure-oci mounts it on the VM and a weekly
# job (sure-oci/bonuses/refresh.py) rewrites it from Doctor of Credit's best
# bonuses page. Missing or empty file means no offers, and the Cards page
# hides the "best to get next" list.
class RewardCard::Bonuses
  Extra = Data.define(:label, :amount, :unit, :kind) do
    def cash? = unit == "cash"
    def portal? = kind == "portal"
  end

  Offer = Data.define(:product_key, :amount, :unit, :spend, :months, :fee, :extras, :note, :value, :value_note) do
    def cash? = unit == "cash"

    # Cash from the bonus itself plus every cash extra (statement credits,
    # Rakuten and other portal cash), for ranking cash offers.
    def cash_total = (cash? ? amount : 0) + extras.select(&:cash?).sum(&:amount)

    # Cash on top of a points bonus (Rakuten, travel credits), the tiebreak
    # among offers of the same points amount.
    def extra_cash = extras.select(&:cash?).sum(&:amount)

    # Rough dollar worth of the whole offer (bonus plus extras) before the
    # annual fee, used ONLY to put offers in one order. The Cards page shows the
    # actual points or cash; this comes from the offers file (the page's own
    # dollar figure when it gives one, else a typical value for that currency).
    # Without it, cash offers use their cash and points count a cent each.
    def worth = value || (cash? ? cash_total : amount / 100 + extra_cash)

    # First-year worth: the offer minus its annual fee.
    def net = worth - (fee || 0)

    def product = RewardCard::Catalog.product(product_key)
  end

  PATH = Rails.root.join("config/reward_bonuses.yml")
  SOURCE_URL = "https://www.doctorofcredit.com/best-current-credit-card-sign-bonuses/"

  class << self
    delegate :offer, :offers, :reviewed_on, :source, to: :instance

    # Reloads when the mounted file changes, so a refresh needs no restart.
    def instance
      mtime = File.exist?(PATH) ? File.mtime(PATH) : nil
      return @instance if @instance && @mtime == mtime

      @mtime = mtime
      @instance = new(mtime ? YAML.load_file(PATH, permitted_classes: [ Date ]) : {})
    end
  end

  attr_reader :offers, :reviewed_on, :source

  def initialize(data)
    @reviewed_on = data["reviewed_on"] && Date.parse(data["reviewed_on"].to_s)
    @source = data["source"]
    @offers = (data["offers"] || {}).filter_map do |key, attrs|
      next unless RewardCard::Catalog.product(key)

      Offer.new(
        product_key: key,
        amount: attrs.fetch("amount").to_i,
        unit: attrs.fetch("unit"),
        spend: attrs["spend"]&.to_i,
        months: attrs["months"]&.to_i,
        fee: attrs["fee"]&.to_i,
        extras: Array(attrs["extras"]).map do |extra|
          Extra.new(label: extra.fetch("label"), amount: extra.fetch("amount").to_i, unit: extra.fetch("unit"), kind: extra["kind"])
        end,
        note: attrs["note"],
        value: attrs["value"]&.to_i,
        value_note: attrs["value_note"]
      )
    end.index_by(&:product_key)
  end

  def offer(key) = offers[key.to_s]
  def any? = offers.any?
end

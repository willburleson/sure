# Card products, reward programs and issuer rules from config/reward_cards.yml.
class RewardCard::Catalog
  Product = Data.define(:key, :name, :issuer, :family, :business, :counts_toward_524, :program, :earn, :rules, :watch)
  Program = Data.define(:key, :name, :unit) do
    def cash? = unit == "cash"
  end
  Issuer = Data.define(:key, :name, :rules)

  PATH = Rails.root.join("config/reward_cards.yml")

  class << self
    def instance
      @instance = nil if Rails.env.development?
      @instance ||= new(YAML.load_file(PATH, aliases: true))
    end

    delegate :products, :programs, :issuers, :product, :program, :issuer, :watched_products,
             :category_keywords, :reviewed_on, :sources, to: :instance
  end

  attr_reader :products, :programs, :issuers, :category_keywords, :reviewed_on, :sources

  def initialize(data)
    @programs = data.fetch("programs").to_h do |key, attrs|
      [ key, Program.new(key: key, name: attrs.fetch("name"), unit: attrs.fetch("unit", "points")) ]
    end
    @issuers = data.fetch("issuers").to_h do |key, attrs|
      [ key, Issuer.new(key: key, name: attrs.fetch("name"), rules: Array(attrs["rules"]).map(&:freeze).freeze) ]
    end
    @products = data.fetch("products").to_h do |key, attrs|
      business = attrs.fetch("business", false)
      [ key, Product.new(
        key: key,
        name: attrs.fetch("name"),
        issuer: attrs.fetch("issuer"),
        family: attrs["family"],
        business: business,
        counts_toward_524: attrs.fetch("counts_toward_524", !business),
        program: attrs["program"],
        earn: attrs.fetch("earn", { "base" => 1 }).transform_values(&:to_d).freeze,
        rules: Array(attrs["rules"]).map(&:freeze).freeze,
        watch: attrs.fetch("watch", true)
      ) ]
    end
    @reviewed_on = data["reviewed_on"] && Date.parse(data["reviewed_on"].to_s)
    @sources = Array(data["sources"]).map { |source| source.slice("name", "url").freeze }.freeze
    @category_keywords = data.fetch("categories").transform_values { |words| words.map(&:downcase) }
  end

  def product(key) = products[key.to_s]
  def program(key) = programs[key.to_s]
  def issuer(key) = issuers[key.to_s] || issuers.fetch("other")

  def watched_products
    products.values.select(&:watch)
  end
end

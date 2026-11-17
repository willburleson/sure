# A credit card a family member holds or held, for Chase 5/24 counting, issuer
# application/bonus rules and points estimates. Personal history, not an Account:
# most of these cards were closed long before Sure existed. Linking an Account
# lets PointBalance::Estimator count its spend.
class RewardCard < ApplicationRecord
  belongs_to :family
  belongs_to :account, optional: true

  normalizes :holder, :name, :product, :program, with: ->(value) { value.strip.presence }

  validates :holder, :name, :issuer, :opened_on, presence: true
  validates :issuer, inclusion: { in: ->(_) { RewardCard::Catalog.issuers.keys } }
  validates :product, inclusion: { in: ->(_) { RewardCard::Catalog.products.keys } }, allow_nil: true
  validates :program, inclusion: { in: ->(_) { RewardCard::Catalog.programs.keys } }, allow_nil: true
  validates :base_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :account_belongs_to_family
  validate :closed_after_opened

  before_validation :apply_product_defaults

  scope :for_holder, ->(holder) { where(holder: holder) }
  scope :chronological, -> { order(:opened_on, :created_at) }
  scope :open, -> { where(closed: false) }

  def catalog_product
    RewardCard::Catalog.product(product)
  end

  def issuer_name
    RewardCard::Catalog.issuer(issuer).name
  end

  def open?
    !closed?
  end

  def open_on?(date)
    opened_on <= date && (open? || (closed_on.present? && closed_on > date))
  end

  # Personal cards count; business cards count only when the issuer reports
  # them to personal credit (Capital One, Discover). Overridable per card.
  def counts_toward_524?
    return counts_toward_524 unless counts_toward_524.nil?

    catalog_product ? catalog_product.counts_toward_524 : !business?
  end

  # When the sign-up bonus posted. Unknown dates assume about 3 months after
  # opening, which is when most minimum spends complete.
  def bonus_on
    return nil unless bonus_received?

    bonus_received_on || (opened_on + 3.months)
  end

  def effective_program
    program || catalog_product&.program
  end

  def earn_rates
    rates = catalog_product&.earn || { "base" => 1.to_d }
    base_rate ? rates.merge("base" => base_rate.to_d) : rates
  end

  def age_in_months(today = Date.current)
    (today.year * 12 + today.month) - (opened_on.year * 12 + opened_on.month) - (today.day < opened_on.day ? 1 : 0)
  end

  private
    def apply_product_defaults
      return unless (catalog = catalog_product)

      self.issuer = catalog.issuer if issuer.blank?
      self.name = catalog.name if name.blank?
      self.business = catalog.business if new_record? && !business_changed?
    end

    def account_belongs_to_family
      errors.add(:account, :invalid) if account && account.family_id != family_id
    end

    def closed_after_opened
      errors.add(:closed_on, :invalid) if closed_on && opened_on && closed_on < opened_on
    end
end

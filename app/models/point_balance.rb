# A points balance as read off an issuer or airline site. Each update adds a
# row; the newest row per holder + program is the current balance and the
# anchor PointBalance::Estimator adds earned points to.
class PointBalance < ApplicationRecord
  belongs_to :family

  normalizes :holder, :program, :note, with: ->(value) { value.strip.presence }

  validates :holder, :program, :as_of, presence: true
  validates :balance, numericality: { greater_than_or_equal_to: 0 }
  validates :program, inclusion: { in: ->(_) { RewardCard::Catalog.programs.keys } }

  scope :for_holder, ->(holder) { where(holder: holder) }

  # Newest row per program for a holder.
  def self.latest
    where(id: select("DISTINCT ON (holder, program) id").order(:holder, :program, as_of: :desc, created_at: :desc))
  end

  def catalog_program
    RewardCard::Catalog.program(program)
  end
end

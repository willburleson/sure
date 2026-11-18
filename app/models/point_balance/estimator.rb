# Estimated current balance of one holder's reward program: the last balance
# entered plus what linked cards earned since, from their Sure transactions
# and the catalog earn rates (portal and rotating bonuses are not modelled).
class PointBalance::Estimator
  Estimate = Data.define(:holder, :program, :balance, :earned, :cards, :transaction_count) do
    def as_of = balance&.as_of
    def recorded = balance&.balance || 0
    def total = recorded + earned
    def catalog_program = RewardCard::Catalog.program(program)
    def cash? = catalog_program&.cash?
  end

  attr_reader :family, :today

  def initialize(family, today: Date.current)
    @family = family
    @today = today
  end

  # One estimate per program that has a recorded balance or a linked card.
  def estimates_for(holder)
    balances = family.point_balances.for_holder(holder).latest.index_by(&:program)
    cards = family.reward_cards.for_holder(holder).where.not(account_id: nil).group_by(&:effective_program)
    programs = (balances.keys + cards.keys.compact).uniq

    programs.map { |program| estimate(holder, program, balances[program], cards.fetch(program, [])) }
            .sort_by { |estimate| [ estimate.cash? ? 1 : 0, -estimate.total.to_d ] }
  end

  private
    def estimate(holder, program, balance, cards)
      since = balance&.as_of
      unit_divisor = RewardCard::Catalog.program(program)&.cash? ? 100 : 1
      earned = 0.to_d
      count = 0

      if since
        cards.each do |card|
          from = [ since, card.opened_on - 1.day ].max
          to = [ today, card.closed_on || today ].min
          rows(card.account_id, from, to).each do |amount, category, parent|
            earned += amount.to_d * rate(card.earn_rates, category, parent) / unit_divisor
            count += 1
          end
        end
      end

      earned = unit_divisor == 1 ? earned.floor : earned.round(2)
      Estimate.new(holder: holder, program: program, balance: balance, earned: earned, cards: cards, transaction_count: count)
    end

    # Purchases (positive) and refunds (negative) after `from`, excluding
    # transfers and card payments.
    def rows(account_id, from, to)
      Entry.where(account_id: account_id, entryable_type: "Transaction", excluded: false)
           .where("entries.date > ? AND entries.date <= ?", from, to)
           .excluding_split_parents
           .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id")
           .joins("LEFT JOIN categories ON categories.id = transactions.category_id")
           .joins("LEFT JOIN categories parent_categories ON parent_categories.id = categories.parent_id")
           .where.not(transactions: { kind: Transaction::TRANSFER_KINDS })
           .pluck("entries.amount", "categories.name", "parent_categories.name")
    end

    def rate(rates, category, parent)
      names = [ category, parent ].compact.map(&:downcase)
      bonus = rates.except("base").filter_map do |earn_category, multiplier|
        keywords = RewardCard::Catalog.category_keywords.fetch(earn_category, [ earn_category ])
        multiplier if names.any? { |name| keywords.any? { |keyword| name.include?(keyword) } }
      end
      [ rates.fetch("base", 1.to_d), *bonus ].max
    end
end

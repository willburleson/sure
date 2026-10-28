class BalanceSheet::ClassificationGroup
  include Monetizable

  monetize :total, as: :total_money

  attr_reader :classification, :currency

  # group_order: accountable keys in display order (the user's manual group
  # order); defaults to Accountable::TYPES.
  def initialize(classification:, currency:, accounts:, group_order: nil)
    @classification = normalize_classification!(classification)
    @name = name
    @currency = currency
    @accounts = accounts
    @group_order = group_order || Accountable::TYPES.map(&:underscore)
  end

  def name
    I18n.t("pages.dashboard.balance_sheet.classifications.#{classification}", default: classification.titleize.pluralize)
  end

  def icon
    classification == "asset" ? "plus" : "minus"
  end

  # Accounts that count towards totals: included in the viewer's finances and
  # not excluded from reports. Account groups use the same rule.
  def self.counted_accounts(accounts)
    accounts.select { |a| a.respond_to?(:included_in_finances?) ? a.included_in_finances? : true }
            .reject { |a| a.respond_to?(:exclude_from_reports?) && a.exclude_from_reports? }
  end

  def total
    self.class.counted_accounts(accounts).sum(&:converted_balance)
  end

  def syncing?
    accounts.any?(&:syncing?)
  end

  # For now, we group by accountable type. This can be extended in the future to support arbitrary user groupings.
  def account_groups
    groups = accounts.group_by(&:accountable_type)
                     .transform_keys { |at| Accountable.from_type(at) }
                     .map do |accountable, account_rows|
                       BalanceSheet::AccountGroup.new(
                         name: accountable.display_name,
                         color: accountable.color,
                         accountable_type: accountable,
                         accounts: account_rows,
                         classification_group: self
                       )
                     end

    # Sort the groups by the user's manual group order, or the order defined by
    # Accountable::TYPES, so the UI displays them in a predictable sequence.
    groups.sort_by do |group|
      group_order.index(group.key) || Float::INFINITY
    end
  end

  private
    attr_reader :accounts, :group_order

    def normalize_classification!(classification)
      raise ArgumentError, "Invalid classification: #{classification}" unless %w[asset liability].include?(classification)
      classification
    end
end

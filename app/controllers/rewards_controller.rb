# Cards & points: 5/24, issuer eligibility and point balances per holder,
# plus a Household tab that sums balances across holders.
class RewardsController < ApplicationController
  HOUSEHOLD = "household".freeze

  def index
    @summary = RewardCard::Summary.new(Current.family)
    @household = params[:holder] == HOUSEHOLD && @summary.holder_names.size > 1
    unless @household
      @holder_name = @summary.holder_names.include?(params[:holder]) ? params[:holder] : @summary.holder_names.first
      @holder = @summary.holder(@holder_name) if @holder_name
    end
    @show_closed = params[:closed] == "1"
    @breadcrumbs = [ [ t("breadcrumbs.home"), root_path ], [ t(".title"), nil ] ]
  end
end

# Cards & points: 5/24, issuer eligibility and point balances per holder.
class RewardsController < ApplicationController
  def index
    @summary = RewardCard::Summary.new(Current.family)
    @holder_name = @summary.holder_names.include?(params[:holder]) ? params[:holder] : @summary.holder_names.first
    @holder = @summary.holder(@holder_name) if @holder_name
    @breadcrumbs = [ [ t("breadcrumbs.home"), root_path ], [ t(".title"), nil ] ]
  end
end

# Records a balance read off an issuer or airline site. Each write is a new
# row dated today, which resets the estimate's starting point.
class PointBalancesController < ApplicationController
  def create
    balance = Current.family.point_balances.new(point_balance_params.with_defaults(as_of: Date.current))

    if balance.save
      redirect_back_or_to rewards_path(holder: balance.holder), notice: t(".saved", program: balance.catalog_program.name)
    else
      redirect_back_or_to rewards_path(holder: balance.holder), alert: balance.errors.full_messages.to_sentence
    end
  end

  def index
    @holder = params.require(:holder)
    @program = params.require(:program)
    @balances = Current.family.point_balances.where(holder: @holder, program: @program).order(as_of: :desc, created_at: :desc)
  end

  def destroy
    balance = Current.family.point_balances.find(params[:id])
    balance.destroy!
    redirect_back_or_to rewards_path(holder: balance.holder), notice: t(".deleted")
  end

  private
    def point_balance_params
      params.require(:point_balance).permit(:holder, :program, :balance, :as_of, :note).tap do |permitted|
        permitted[:balance] = permitted[:balance].to_s.delete(",$ ") if permitted.key?(:balance)
      end
    end
end

class RewardCardsController < ApplicationController
  before_action :set_reward_card, only: %i[edit update destroy]

  def new
    @reward_card = Current.family.reward_cards.new(holder: params[:holder], opened_on: Date.current)
  end

  def create
    @reward_card = Current.family.reward_cards.new(reward_card_params)

    if @reward_card.save
      redirect_to rewards_path(holder: @reward_card.holder), notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @reward_card.update(reward_card_params)
      redirect_to rewards_path(holder: @reward_card.holder), notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @reward_card.destroy!
    redirect_to rewards_path(holder: @reward_card.holder), notice: t(".deleted")
  end

  private
    def set_reward_card
      @reward_card = Current.family.reward_cards.find(params[:id])
    end

    def reward_card_params
      permitted = params.require(:reward_card).permit(
        :holder, :name, :issuer, :product, :business, :counts_toward_524, :opened_on, :closed_on, :closed,
        :bonus_received, :bonus_received_on, :program, :base_rate, :notes
      )
      permitted[:counts_toward_524] = nil if permitted[:counts_toward_524] == ""
      # Turning "Closed" off on a closed card reopens it (and drops the close
      # date); otherwise a close date implies closed.
      if permitted[:closed] == "0" && @reward_card&.closed?
        permitted[:closed_on] = nil
      elsif permitted[:closed_on].present?
        permitted[:closed] = "1"
      end

      # Only the family's own accounts can be linked.
      if params[:reward_card].key?(:account_id)
        account_id = params[:reward_card][:account_id].presence
        permitted[:account] = account_id && Current.family.accounts.find(account_id)
      end
      permitted
    end
end

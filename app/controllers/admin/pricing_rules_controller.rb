module Admin
  class PricingRulesController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin!
    before_action :set_pricing_rule, only: [ :show, :edit, :update, :destroy ]

    def index
      @pricing_rules = PricingRule.all.order(vehicle_type: :asc, created_at: :desc)
    end

    def show
    end

    def new
      @pricing_rule = PricingRule.new
    end

    def create
      @pricing_rule = PricingRule.new(pricing_rule_params)

      if @pricing_rule.save
        redirect_to admin_pricing_rules_path, notice: t('pricing_rules.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @pricing_rule.update(pricing_rule_params)
        redirect_to admin_pricing_rules_path, notice: t('pricing_rules.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @pricing_rule.destroy
      redirect_to admin_pricing_rules_path, notice: t('pricing_rules.destroyed')
    end

    private

    def set_pricing_rule
      @pricing_rule = PricingRule.find(params[:id])
    end

    def pricing_rule_params
      params.require(:pricing_rule).permit(
        :vehicle_type,
        :rate_per_km,
        :minimum_price,
        :weekend_surcharge_percent,
        :express_surcharge_percent,
        :active
      )
    end

    def ensure_admin!
      unless current_user&.admin? || current_user&.dispatcher?
        redirect_to root_path, alert: t('flash.access_denied')
      end
    end
  end
end

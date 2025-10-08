module Pricing
  class Calculator
    attr_reader :transport_request, :pricing_rule, :errors

    def initialize(transport_request)
      @transport_request = transport_request
      @pricing_rule = nil
      @errors = []
    end

    # Calculate and create a quote for the transport request
    # Returns the created Quote object or nil if calculation fails
    def calculate
      return nil unless validate_request

      # Find applicable pricing rule
      @pricing_rule = find_pricing_rule
      unless @pricing_rule
        @errors << "No pricing rule found for vehicle type: #{transport_request.vehicle_type}"
        return nil
      end

      # Calculate base price
      base_price = calculate_base_price

      # Calculate surcharges
      surcharges = calculate_surcharges(base_price)

      # Calculate total
      total = base_price + surcharges.sum { |s| s[:amount] }

      # Create quote with line items
      create_quote(base_price, surcharges, total)
    rescue StandardError => e
      @errors << "Quote calculation failed: #{e.message}"
      Rails.logger.error("Pricing calculation error: #{e.message}\n#{e.backtrace.join("\n")}")
      nil
    end

    private

    def validate_request
      unless transport_request.distance_km.present? && transport_request.distance_km > 0
        @errors << "Distance must be calculated before pricing"
        return false
      end

      unless transport_request.vehicle_type.present?
        @errors << "Vehicle type must be specified"
        return false
      end

      true
    end

    def find_pricing_rule
      # Try to find exact match for vehicle type
      rule = PricingRule.find_for_vehicle_type(transport_request.vehicle_type)

      # If vehicle_type is "either" or "lkw", try common fallbacks
      if rule.nil?
        if transport_request.vehicle_type == 'either'
          rule = PricingRule.find_for_vehicle_type('transporter')
        elsif transport_request.vehicle_type == 'lkw'
          rule = PricingRule.find_for_vehicle_type('lkw_7_5t')
        end
      end

      rule
    end

    def calculate_base_price
      distance = transport_request.distance_km
      rate = pricing_rule.rate_per_km
      calculated = distance * rate

      # Apply minimum price
      [ calculated, pricing_rule.minimum_price ].max
    end

    def calculate_surcharges(base_price)
      surcharges = []

      # Weekend surcharge
      if weekend_pickup? && pricing_rule.weekend_surcharge_percent > 0
        amount = (base_price * pricing_rule.weekend_surcharge_percent / 100.0).round(2)
        surcharges << {
          description: I18n.t('quotes.line_items.weekend_surcharge'),
          calculation: "#{pricing_rule.weekend_surcharge_percent}% #{I18n.t('quotes.line_items.surcharge')}",
          amount: amount
        }
      end

      # Express surcharge
      if express_delivery? && pricing_rule.express_surcharge_percent > 0
        amount = (base_price * pricing_rule.express_surcharge_percent / 100.0).round(2)
        surcharges << {
          description: I18n.t('quotes.line_items.express_surcharge'),
          calculation: "#{pricing_rule.express_surcharge_percent}% #{I18n.t('quotes.line_items.surcharge')}",
          amount: amount
        }
      end

      surcharges
    end

    def weekend_pickup?
      return false unless transport_request.pickup_date_from

      # Check if pickup is on Saturday (6) or Sunday (0)
      [ 0, 6 ].include?(transport_request.pickup_date_from.wday)
    end

    def express_delivery?
      return false unless transport_request.pickup_date_from && transport_request.delivery_date_from

      # Express if delivery is within 24 hours of pickup
      (transport_request.delivery_date_from - transport_request.pickup_date_from) <= 1.day
    end

    def create_quote(base_price, surcharges, total)
      quote = Quote.new(
        transport_request: transport_request,
        status: 'pending',
        base_price: base_price.round(2),
        surcharge_total: surcharges.sum { |s| s[:amount] }.round(2),
        total_price: total.round(2),
        currency: 'EUR'
      )

      # Create line items
      # 1. Base transport cost
      quote.quote_line_items.build(
        description: I18n.t('quotes.line_items.base_transport'),
        calculation: "#{transport_request.distance_km} km × €#{pricing_rule.rate_per_km}/km",
        amount: base_price.round(2),
        line_order: 0
      )

      # 2. Surcharges
      surcharges.each_with_index do |surcharge, index|
        quote.quote_line_items.build(
          description: surcharge[:description],
          calculation: surcharge[:calculation],
          amount: surcharge[:amount],
          line_order: index + 1
        )
      end

      # Save quote with line items
      if quote.save
        # Update transport request status
        transport_request.update(status: 'quoted')
        quote
      else
        @errors += quote.errors.full_messages
        nil
      end
    end
  end
end

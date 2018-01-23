module IB
  module Messages
    module Incoming

      # OpenOrder is the longest message with complex processing logics
      OpenOrder =
          def_message [5, 34],		# updated to v. 34 according to python (decoder.py processOpenOrder)
                      [:order, :local_id, :int],

                      [:contract, :con_id, :int],
                      [:contract, :symbol, :string],
                      [:contract, :sec_type, :string],
                      [:contract, :expiry, :string],
                      [:contract, :strike, :decimal],
                      [:contract, :right, :string],
                      [:contract, :multiplier, :int],
                      [:contract, :exchange, :string],
                      [:contract, :currency, :string],
                      [:contract, :local_symbol, :string],
                      [:contract, :trading_class, :string],

                      [:order, :action, :string],
                      [:order, :total_quantity, :decimal],
                      [:order, :order_type, :string],
                      [:order, :limit_price, :decimal],
                      [:order, :aux_price, :decimal],
                      [:order, :tif, :string],
                      [:order, :oca_group, :string],
                      [:order, :account, :string],
                      [:order, :open_close, :string],
                      [:order, :origin, :int],
                      [:order, :order_ref, :string],
                      [:order, :client_id, :int],
                      [:order, :perm_id, :int],
                      [:order, :outside_rth, :boolean], # (@socket.read_int == 1)
                      [:order, :hidden, :boolean], # (@socket.read_int == 1)
                      [:order, :discretionary_amount, :decimal],
                      [:order, :good_after_time, :string],
                      [:shares_allocation, :string], # deprecated! field

                      [:order, :fa_group, :string],
                      [:order, :fa_method, :string],
                      [:order, :fa_percentage, :string],
                      [:order, :fa_profile, :string],
                      [:order, :model_code, :string],
                      [:order, :good_till_date, :string],
                      [:order, :rule_80a, :string],
                      [:order, :percent_offset, :decimal],
                      [:order, :settling_firm, :string],
                      [:order, :short_sale_slot, :int],
                      [:order, :designated_location, :string],
                      [:order, :exempt_code, :int],
                      [:order, :auction_strategy, :int],
                      [:order, :starting_price, :decimal],
                      [:order, :stock_ref_price, :decimal],
                      [:order, :delta, :decimal],
                      [:order, :stock_range_lower, :decimal],
                      [:order, :stock_range_upper, :decimal],
                      [:order, :display_size, :int],
                      #@order.rth_only = @socket.read_boolean
                      [:order, :block_order, :boolean],
                      [:order, :sweep_to_fill, :boolean],
                      [:order, :all_or_none, :boolean],
                      [:order, :min_quantity, :int],
                      [:order, :oca_type, :int],
                      [:order, :etrade_only, :boolean],
                      [:order, :firm_quote_only, :boolean],
                      [:order, :nbbo_price_cap, :decimal],
                      [:order, :parent_id, :int],
                      [:order, :trigger_method, :int],
                      [:order, :volatility, :decimal],
                      [:order, :volatility_type, :int],
                      [:order, :delta_neutral_order_type, :string],
                      [:order, :delta_neutral_aux_price, :decimal]

      class OpenOrder

        # Accessors to make OpenOrder API-compatible with OrderStatus message

        def client_id
          order.client_id
        end

        def parent_id
          order.parent_id
        end

        def perm_id
          order.perm_id
        end

         def local_id
          order.local_id
        end

        alias order_id local_id

        def status
          order.status
        end

        # Object accessors

        def order
          @order ||= IB::Order.new @data[:order].merge(:order_state => order_state)
        end

        def order_state
          @order_state ||= IB::OrderState.new(
              @data[:order_state].merge(
                  :local_id => @data[:order][:local_id],
                  :perm_id => @data[:order][:perm_id],
                  :parent_id => @data[:order][:parent_id],
                  :client_id => @data[:order][:client_id]))
        end

        def contract
          @contract ||= IB::Contract.build(
              @data[:contract].merge(:underlying => underlying)
          )
        end

        def underlying
          @underlying = @data[:underlying_present] ? IB::Underlying.new(@data[:underlying]) : nil
        end

        alias under_comp underlying

        def load
          super

#          load_map [proc { | | filled?(@data[:order][:delta_neutral_order_type]) }, # todo Testcase!
          load_map [proc { | | (@data[:order][:delta_neutral_order_type] != 'None') },
                      # As of client v.52, we may receive delta... params in openOrder
                     [:order, :delta_neutral_con_id, :int],
                     [:order, :delta_neutral_settling_firm, :string],
                     [:order, :delta_neutral_clearing_account, :string],
                     [:order, :delta_neutral_open_close, :string],
                     [:order, :delta_neutral_short_sale, :bool],
		     [:order, :delta_neutral_short_sale_slot, :int],
		     [:order, :delta_neutral_designated_location, :string] ],  # end proc
		   [:order, :continuous_update, :int],
                   [:order, :reference_price_type, :int],
                   [:order, :trail_stop_price, :decimal],
                   [:order, :trailing_percent, :decimal],
                   [:order, :basis_points, :decimal],
                   [:order, :basis_points_type, :int],
                   [:contract, :legs_description, :string],

                   # As of client v.55, we receive in OpenOrder for Combos:
                   #    Contract.orderComboLegs Array
                   #    Order.leg_prices Array
                   [:contract, :legs, :array, proc do |_|
                     IB::ComboLeg.new :con_id => buffer.read_int,
                                      :ratio => buffer.read_int,
                                      :action => buffer.read_string,
                                      :exchange => buffer.read_string,
                                      :open_close => buffer.read_int,
                                      :short_sale_slot => buffer.read_int,
                                      :designated_location => buffer.read_string,
                                      :exempt_code => buffer.read_int
                   end],
                   [:order, :leg_prices, :array, proc { |_| buffer.read_decimal }],   #  needs testing
                   [:order, :combo_params, :array , proc do |_|
				      { tag: buffer.read_string, value: buffer.read_string }  # needs testing
		   end],

                   [:order, :scale_init_level_size, :int],
                   [:order, :scale_subs_level_size, :int],

                   [:order, :scale_price_increment, :decimal],
                   [proc { | | filled?(@data[:order][:scale_price_increment]) },
                     # As of client v.54, we may receive scale order fields
                     [:order, :scale_price_adjust_value, :decimal],
                     [:order, :scale_price_adjust_interval, :int],
                     [:order, :scale_profit_offset, :decimal],
                     [:order, :scale_auto_reset, :boolean],
                     [:order, :scale_init_position, :int],
                     [:order, :scale_init_fill_qty, :decimal],
                     [:order, :scale_random_percent, :boolean]
                   ],

                   [:order, :hedge_type, :string],
                   [proc { | | filled?(@data[:order][:hedge_type]) },
                     # As of client v.49/50, we can receive hedgeType, hedgeParam
                     [:order, :hedge_param, :string]
                   ],

                   [:order, :opt_out_smart_routing, :boolean],
                   [:order, :clearing_account, :string],
                   [:order, :clearing_intent, :string],
                   [:order, :not_held, :boolean],

                   [:underlying_present, :boolean],
                   [proc { | | filled?(@data[:underlying_present]) },
                    [:underlying, :con_id, :int],
                    [:underlying, :delta, :decimal],
                    [:underlying, :price, :decimal]
                   ],

                   # TODO: Test Order with algo_params, scale and legs!
                   [:order, :algo_strategy, :string],
                   [proc { | | filled?(@data[:order][:algo_strategy]) },
                    [:order, :algo_params, :hash]  #---->  this does not work  ## todo fix in abstract message
                   ],

                   [:order, :solicided, :boolean],
                   [:order, :what_if, :boolean],

                   [:order_state, :status, :string],
                   # IB uses weird String with Java Double.MAX_VALUE to indicate no value here
                   [:order_state, :init_margin, :decimal], # :string],
                   [:order_state, :maint_margin, :decimal], # :string],
                   [:order_state, :equity_with_loan, :decimal], # :string],
                   [:order_state, :commission, :decimal], # May be nil!
                   [:order_state, :min_commission, :decimal], # May be nil!
                   [:order_state, :max_commission, :decimal], # May be nil!
                   [:order_state, :commission_currency, :string],
                   [:order_state, :warning_text, :string],


                   [:order, :random_size, :boolean],
                   [:order, :random_price, :boolean],

		   ## todo: ordertype = PEG BENCH  --  -> test!
		   [proc{ @data[:order][:order_type] == 'PEG BENCH' },
		      [:order, :reference_contract_id, :int ],
		      [:order, :is_pegged_change_amount_decrease, :bool ],
		      [:order, :pegged_change_amount, :decimal ],
		      [:order, :reference_change_amount, :decimal ],
		      [:order, :reference_exchange_id, :string ]
		   ],
                   [:order, :conditions, :array , proc do |_|
				      { tag: buffer.read_string, value: buffer.read_string }  # needs modification 
		   end],
		    ## todo : process conditions
		    #394             if order.conditionsSize > 0:
		    # 395                 order.conditions = []
		    #  396                 for idxCond in range(order.conditionsSize):
		    #   397                     order.conditionType = decode(int, fields)
		    #    398                     condition = order_condition.Create(order.conditionType)
		    #     399                     condition.decode(fields)
		    #      400                     order.conditions.append(condition)
		    #       401 
		    #        402                 order.conditionsIgnoreRth = decode(bool, fields)
		    #         403                 order.conditionsCancelOrder = decode(bool, fields)
		    #          404 
		    #          
		    [:order, :adjusted_order_type, :string],
		    [:order, :trigger_price,  :decimal],
		    [:order, :trail_stop_price,  :decimal],
		    [:order, :adjusted_stop_limit_price,  :decimal],
		    [:order, :adjusted_trailing_amount,  :decimal],
		    [:order, :adjustable_trailing_unit,  :int]

## todo inlcude soft_dollar_tier's
		    #[:order, :soft_dollar_tier_params,:name  :decimal]
		    #[:order, :soft_dollar_tier_params,:value  :decimal]
		    #[:order, :soft_dollar_tier_params,:display_name  :decimal]
		    #[:order, :cash_qty,  :decimal]
		    
        end

        # Check if given value was set by TWS to something vaguely "positive"
        def filled? value
#	  puts "filled: #{value.class} --> #{value.to_s}"
          case value
            when String
              (!value.empty?) && (value !='None')
            when Float, Integer
              value > 0
            else
              !!value # to_bool
          end
        end

        def to_human
          "<OpenOrder: #{contract.to_human} #{order.to_human}>"
        end

      end # class OpenOrder
    end # module Incoming
  end # module Messages
end # module IB

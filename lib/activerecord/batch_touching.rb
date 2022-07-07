# frozen_string_literal: true

require "activerecord/batch_touching/version"
require "activerecord/batch_touching/state"

module ActiveRecord
  module BatchTouchingAbstractAdapter
    # Batches up +touch+ calls for the duration of a transaction.
    # +after_touch+ callbacks are also delayed until the transaction is committed.
    #
    # ==== Examples
    #
    #   # Touches Person.first and Person.last in a single database round-trip.
    #   Person.transaction do
    #     Person.first.touch
    #     Person.last.touch
    #   end
    #
    #   # Touches Person.first once, not twice, right before the transaction is committed.
    #   Person.transaction do
    #     Person.first.touch
    #     Person.first.touch
    #   end
    def transaction(requires_new: nil, isolation: nil, joinable: true, &block)
      result = super(requires_new: requires_new, isolation: isolation, joinable: joinable) do
        BatchTouching.start(requires_new: requires_new, &block)
      end

      if BatchTouching.should_apply_touches?
        super() do
          BatchTouching.apply_touches
        end
      end

      result
    end
  end

  module ConnectionAdapters
    class AbstractAdapter
      prepend BatchTouchingAbstractAdapter
    end
  end

  # = Active Record Batch Touching
  module BatchTouching # :nodoc:
    extend ActiveSupport::Concern

    # Override ActiveRecord::Base#touch_later.  This will effectively disable the current built-in mechanism AR uses
    # to delay touching in favor of our method of batch touching.
    def touch_later(*names)
      BatchTouching.batch_touching? ? touch(*names) : super
    end

    # Override ActiveRecord::Base#touch.  If currently batching touches, always return
    # true because there's no way to tell if the write would have failed.
    def touch(*names, time: nil)
      if BatchTouching.batch_touching? && !no_touching?
        add_to_transaction
        BatchTouching.add_record(self, names)
        true
      else
        super
      end
    end

    class << self
      # Disable batch touching globally
      def disable!
        @disabled = true
      end

      # Enable batch touching globally
      def enable!
        @disabled = false
      end

      # Disable batch touching for a block
      def disable
        Thread.current[:batch_touching_disabled] = true
        yield
      ensure
        Thread.current[:batch_touching_disabled] = false
      end

      def disabled?
        Thread.current[:batch_touching_disabled] || @disabled
      end

      # Start batching all touches. When done, apply them. (Unless nested.)
      def start(requires_new:)
        states.push State.new
        yield.tap do
          gather_touches if states.length == 1
        end
      ensure
        merge_transactions unless $! && requires_new

        # Decrement nesting even if +gather_touches+ raised an error. To ensure the stack of States
        # is empty after the top-level transaction exits.
        states.pop
      end

      delegate :add_record, to: :current_state

      def batch_touching?
        states.present? && !disabled?
      end

      def should_apply_touches?
        batched_touches.present?
      end

      def apply_touches
        batched_touches&.each do |(klass, columns), records|
          records.reject!(&:destroyed?)
          touch_records klass, columns, records, batched_touches_time
        end

        reset!
      end

      private

      def reset!
        Thread.current[:batch_touching_batch] = nil
        Thread.current[:batch_touching_time] = nil
      end

      def batched_touches
        Thread.current[:batch_touching_batch]
      end

      def batched_touches_time
        Thread.current[:batch_touching_time]
      end

      def states
        Thread.current[:batch_touching_states] ||= []
      end

      def current_state
        states.last
      end

      # When exiting a nested transaction, merge the nested transaction's
      # touched records with the outer transaction's touched records.
      def merge_transactions
        states[-2].merge!(current_state) if states.length > 1
      end

      # Gather all the touches that were batched.
      def gather_touches
        current_time = ActiveRecord::Base.current_time_from_proper_timezone
        already_touched = Set.new
        all_states = State.new
        while current_state.more_records?
          all_states.merge!(current_state)
          state_records = current_state.records
          current_state.clear_records!
          state_records.each do |(_klass, columns), records|
            soft_touch_records(columns, records, current_time, already_touched)
          end
        end

        # Sort by class name. Having a consistent order can help mitigate deadlocks.
        sorted_records = all_states.records.keys.sort_by { |k| k.first.name }.to_h { |k| [k, all_states.records[k]] }

        # Save results to a thread so that we can reference these later in their own transaction.
        Thread.current[:batch_touching_batch] = sorted_records
        Thread.current[:batch_touching_time] = current_time
      end

      # Perform DB update to touch records
      def touch_records(klass, columns, records, time)
        return if columns.blank? || records.blank?

        sql = columns.map { |column| "#{klass.connection.quote_column_name(column)} = :time" }.join(", ")
        sql += ", #{klass.locking_column} = #{klass.locking_column} + 1" if klass.locking_enabled?

        klass.unscoped.where(klass.primary_key => records.to_a).update_all([sql, time: time])
      end

      # Set new timestamp in memory, without updating the DB just yet.
      def soft_touch_records(columns, records, time, already_touched)
        return if columns.blank? || records.blank?

        records.each do |record|
          next if record.destroyed? || already_touched.include?(record)

          soft_touch_record(columns, record, time)

          # Running callbacks also allows us to collect more touches (i.e. touch: true for associations).
          record._run_touch_callbacks
          already_touched.add(record)
        end
      end

      def soft_touch_record(columns, record, time)
        columns.each { |column| record.write_attribute column, time }
        if record.locking_enabled?
          record[record.class.locking_column] += 1
          record.clear_attribute_changes(columns + [record.class.locking_column])
        else
          record.clear_attribute_changes(columns)
        end
      end
    end
  end
end

ActiveRecord::Base.include ActiveRecord::BatchTouching

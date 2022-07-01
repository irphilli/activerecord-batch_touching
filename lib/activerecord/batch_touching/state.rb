module ActiveRecord
  # = Active Record Batch Touching
  module BatchTouching
    # Tracking of the touch state. This class has no class-level data, so you can
    # store per-thread instances in thread-local variables.
    class State # :nodoc:
      # Return the records grouped by class and columns that were touched:
      #
      #   {
      #     [Owner, [:updated_at]]               => Set.new([owner1, owner2]),
      #     [Pet,   [:neutered_at, :updated_at]] => Set.new([pet1]),
      #     [Pet,   [:updated_at]]               => Set.new([pet2])
      #   }
      #
      attr_reader :records

      def initialize
        @records = Hash.new { Set.new }
      end

      def clear_records!
        @records = Hash.new { Set.new }
      end

      def more_records?
        @records.present?
      end

      def add_record(record, columns)
        # Include the standard updated_at column and any additional specified columns
        columns += record.send(:timestamp_attributes_for_update_in_model)
        columns = columns.map(&:to_sym).sort

        key = [record.class, columns]
        @records[key] += [record]
      end

      # Merge another state into this one
      def merge!(other_state)
        merge_records!(@records, other_state.records)
      end

      protected

      # Merge from_records into into_records
      def merge_records!(into_records, from_records)
        from_records.each do |key, records|
          into_records[key] += records
        end
      end
    end
  end
end

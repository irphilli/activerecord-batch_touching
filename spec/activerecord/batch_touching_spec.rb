# frozen_string_literal: true

require "spec_helper"

describe Activerecord::BatchTouching do
  let!(:owner) { Owner.create name: "Rosey" }
  let!(:pet1) { Pet.create(name: "Bones", owner: owner) }
  let!(:pet2) { Pet.create(name: "Ema", owner: owner) }
  let!(:car) { Car.create(name: "Ferrari", lock_version: 1) }

  it "has a version number" do
    expect(Activerecord::BatchTouching::VERSION).not_to be_nil
  end

  it "touch returns true when not in a batch_touching block" do
    expect(owner.touch).to equal(true)
  end

  it "touch returns true in a batch_touching block" do
    ActiveRecord::Base.transaction do
      expect(owner.touch).to equal(true)
    end
  end

  it "consolidates touches on a single record when inside a transaction" do
    expect_updates [{ "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        owner.touch
        owner.touch
      end
    end
  end

  it "calls touch callbacks just once when there are multiple touches" do
    allow(owner).to receive(:_run_touch_callbacks).and_call_original

    ActiveRecord::Base.transaction do
      owner.touch
      owner.touch
    end

    expect(owner).to have_received(:_run_touch_callbacks).once
  end

  it "sets updated_at on the in-memory instance when it eventually touches the record" do
    original_time = new_time = nil

    Timecop.freeze(2014, 7, 4, 12, 0, 0) do
      original_time = Time.current
      owner.touch
    end

    Timecop.freeze(2014, 7, 10, 12, 0, 0) do
      new_time = Time.current
      ActiveRecord::Base.transaction do
        owner.touch
        expect(owner.updated_at).to eq(original_time)
        expect(owner).not_to be_changed
      end
    end

    expect(owner.updated_at).to eq(new_time)
    expect(owner).not_to be_changed
  end

  it "does not mark the instance as changed when touch is called" do
    ActiveRecord::Base.transaction do
      owner.touch
      expect(owner).not_to be_changed
    end
  end

  it "does not mark the instance as changed, even if its lock_version is incremented" do
    ActiveRecord::Base.transaction do
      car.touch
    end
    expect(car).not_to be_changed
  end

  it "consolidates touch: true touches" do
    expect_updates [{ "pets" => { ids: [pet1, pet2] } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        pet2.touch
      end
    end
  end

  it "does nothing if no_touching is on" do
    allow(owner).to receive(:_run_touch_callbacks)

    expect_updates [] do
      ActiveRecord::Base.no_touching do
        ActiveRecord::Base.transaction do
          owner.touch
        end
      end
    end

    expect(owner).not_to have_received(:_run_touch_callbacks)
  end

  it "only applies touches for which no_touching is off" do
    allow(owner).to receive(:_run_touch_callbacks).and_call_original
    allow(pet1).to receive(:_run_touch_callbacks).and_call_original

    expect_updates ["pets" => { ids: pet1 }] do
      Owner.no_touching do
        ActiveRecord::Base.transaction do
          owner.touch
          pet1.touch
        end
      end
    end

    expect(owner).not_to have_received(:_run_touch_callbacks)
    expect(pet1).to have_received(:_run_touch_callbacks).once
  end

  it "does not apply nested touches if no_touching was turned on inside batch_touching" do
    allow(owner).to receive(:_run_touch_callbacks).and_call_original
    allow(pet1).to receive(:_run_touch_callbacks).and_call_original

    expect_updates ["owners" => { ids: owner }] do
      ActiveRecord::Base.transaction do
        owner.touch
        ActiveRecord::Base.no_touching do
          pet1.touch
        end
      end
    end

    expect(owner).to have_received(:_run_touch_callbacks)
    expect(pet1).not_to have_received(:_run_touch_callbacks)
  end

  it "can update nonstandard columns" do
    expect_updates ["owners" => { ids: owner, columns: %w[updated_at happy_at] }] do
      ActiveRecord::Base.transaction do
        owner.touch :happy_at
      end
    end
  end

  it "treats string column names and symbol column names as the same" do
    expect_updates ["owners" => { ids: owner, columns: %w[updated_at happy_at] }] do
      ActiveRecord::Base.transaction do
        owner.touch :happy_at
        owner.touch "happy_at"
      end
    end
  end

  it "splits up nonstandard column touches and standard column touches" do
    owner2 = Owner.create name: "Guybrush"

    expect_updates [{ "owners" => { ids: owner, columns: %w[updated_at happy_at] } },
                    { "owners" => { ids: owner2, columns: ["updated_at"] } }] do
      ActiveRecord::Base.transaction do
        owner.touch :happy_at
        owner2.touch
      end
    end
  end

  it "can update multiple nonstandard columns of a single record in different calls to touch" do
    expect_updates [{ "owners" => { ids: owner, columns: %w[updated_at happy_at] } },
                    { "owners" => { ids: owner, columns: %w[updated_at sad_at] } }] do
      ActiveRecord::Base.transaction do
        owner.touch :happy_at
        owner.touch :sad_at
      end
    end
  end

  it "can update multiple nonstandard columns of a single record in a single call to touch" do
    expect_updates [{ "owners" => { ids: owner, columns: %w[updated_at happy_at sad_at] } }] do
      ActiveRecord::Base.transaction do
        owner.touch :happy_at, :sad_at
      end
    end
  end

  it "does not touch the owning record via touch: true if it was already touched explicitly" do
    allow(owner).to receive(:_run_touch_callbacks).and_call_original
    allow(pet1).to receive(:_run_touch_callbacks).and_call_original
    allow(pet2).to receive(:_run_touch_callbacks).and_call_original

    expect_updates [{ "pets" => { ids: [pet1, pet2] } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        owner.touch
        pet1.touch
        pet2.touch
      end
    end

    expect(owner).to have_received(:_run_touch_callbacks).once
    expect(pet1).to have_received(:_run_touch_callbacks).once
    expect(pet2).to have_received(:_run_touch_callbacks).once
  end

  it "does not consolidate touches when outside a transaction" do
    expect_updates [{ "owners" => { ids: owner } },
                    { "owners" => { ids: owner } }] do
      owner.touch
      owner.touch
    end
  end

  it "nested transactions get consolidated into a single set of touches" do
    allow(owner).to receive(:_run_touch_callbacks).and_call_original
    allow(pet1).to receive(:_run_touch_callbacks).and_call_original
    allow(pet2).to receive(:_run_touch_callbacks).and_call_original

    expect_updates [{ "pets" => { ids: [pet1, pet2] } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction do
          pet2.touch
        end
      end
    end

    expect(owner).to have_received(:_run_touch_callbacks).once
    expect(pet1).to have_received(:_run_touch_callbacks).once
    expect(pet2).to have_received(:_run_touch_callbacks).once
  end

  it "rolling back from a nested transaction without :requires_new touches the records in the inner transaction" do
    expect_updates [{ "pets" => { ids: [pet1, pet2] } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction do
          pet2.touch
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  it "rolling back from a nested transaction with :requires_new does not touch the records in the inner transaction" do
    expect_updates [{ "pets" => { ids: pet1 } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction(requires_new: true) do
          pet2.touch
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  it "touching a record in an outer and inner new transaction, then rolling back the inner one, still touches the record" do
    expect_updates [{ "pets" => { ids: pet1 } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction(requires_new: true) do
          pet1.touch
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  it "rolling back from an outer transaction does not touch any records" do
    expect_updates [] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction do
          pet2.touch :neutered_at
        end
        raise ActiveRecord::Rollback
      end
    end
  end

  it "consolidates touch: :column_name touches" do
    pet_klass = Class.new(ActiveRecord::Base) do
      def self.name
        "Pet"
      end
      belongs_to :owner, touch: :happy_at
      after_touch :after_touch_callback
      def after_touch_callback; end
    end

    pet = pet_klass.first
    owner = pet.owner

    expect_updates [{ "owners" => { ids: owner, columns: %w[updated_at happy_at] } }, { "pets" => { ids: pet } }] do
      ActiveRecord::Base.transaction do
        pet.touch
        pet.touch
      end
    end
  end

  it "keeps iterating as long as after_touch keeps causing more records to be touched" do
    pet_klass = Class.new(ActiveRecord::Base) do
      def self.name
        "Pet"
      end
      belongs_to :owner

      # Touch the owner in after_touch instead of using touch: true
      after_touch :touch_owner
      def touch_owner
        owner.touch
      end
    end

    pet = pet_klass.first
    owner = pet.owner

    expect_updates [{ "owners" => { ids: owner } }, { "pets" => { ids: pet } }] do
      ActiveRecord::Base.transaction do
        pet.touch
      end
    end
  end

  it "increments the optimistic lock column in memory and in the DB" do
    car1 = Car.create(name: "Ferrari", lock_version: 1)
    car2 = Car.create(name: "Lambo", lock_version: 2)

    ActiveRecord::Base.transaction do
      car1.touch
      car2.touch
    end

    expect(car1.lock_version).to equal(2)
    expect(car2.lock_version).to equal(3)

    expect(car1.reload.lock_version).to equal(2)
    expect(car2.reload.lock_version).to equal(3)
  end

  it "can be disabled and enabled globally" do
    ActiveRecord::BatchTouching.disable!

    ActiveRecord::Base.transaction do
      expect(ActiveRecord::BatchTouching.batch_touching?).to be(false)
    end

    ActiveRecord::BatchTouching.enable!
    ActiveRecord::Base.transaction do
      expect(ActiveRecord::BatchTouching.batch_touching?).to be(true)
    end
  ensure
    ActiveRecord::BatchTouching.enable!
  end

  it "can be disabled within a block" do
    ActiveRecord::BatchTouching.disable do
      ActiveRecord::Base.transaction do
        expect(ActiveRecord::BatchTouching.batch_touching?).to be(false)
      end
    end
  end

  context "with dependent deletes" do
    let(:post) { Post.create }
    let(:user) { User.create }
    let(:comment) { Comment.create(post: post, user: user) }

    it "does not attempt to touch deleted records" do
      expect do
        post.destroy
      end.not_to raise_error
      expect(post.destroyed?).to be true
    end
  end

  private

  def expect_updates(tables_ids_and_columns)
    expected_sql = expected_sql_for(tables_ids_and_columns)

    # rubocop:disable RSpec/MessageSpies
    expect(ActiveRecord::Base.connection).to receive(:update).exactly(expected_sql.length).times do |stmt, _, _|
      if /UPDATE /i.match?(stmt.to_sql)
        index = expected_sql.index { |expected_stmt| stmt.to_sql =~ expected_stmt }
        expect(index).to be, "An unexpected touch occurred: #{stmt.to_sql}"
        expected_sql.delete_at(index)
      end
    end
    # rubocop:enable RSpec/MessageSpies

    yield

    expect(expected_sql).to be_empty, "Some of the expected updates were not executed."
  end

  # Creates an array of regular expressions to match the SQL statements that we expect
  # to execute.
  #
  # Each element in the tables_ids_and_columns array is in this form:
  #
  #   { "table_name" => { ids: id_or_array_of_ids, columns: column_name_or_array } }
  #
  # 'columns' is optional. If it's missing it is assumed that "updated_at" is the only
  # column that gets touched.
  def expected_sql_for(tables_ids_and_columns)
    tables_ids_and_columns.map do |entry|
      entry.map do |table, options|
        ids = Array.wrap(options[:ids])
        columns = Array.wrap(options[:columns]).presence || ["updated_at"]
        columns = columns.sort
        Regexp.new(touch_sql(table, columns, ids))
      end
    end.flatten
  end

  # in:  array of records or record ids
  # out: "( = 1|= \?|= \$1)" or " IN (1, 2)"
  #
  # In some cases, such as SQLite3 when outside a transaction, the logged SQL uses ? instead of record ids.
  def ids_sql(ids)
    ids = ids.map { |id| id.class.respond_to?(:primary_key) ? id.send(id.class.primary_key) : id }
    ids.length > 1 ? %{ IN \\(#{Array.new(ids.length, '\?').join(', ')}\\)} : %{( = #{ids.first}|= \\?|= \\$1)}
  end

  def touch_sql(table, columns, ids)
    %(UPDATE \\"#{table}"\\ SET #{columns.map { |column| %(\\"#{column}\\" =.+) }.join(', ')} .+#{ids_sql(ids)}\\Z)
  end
end

# frozen_string_literal: true

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :owners, force: true do |t|
    t.string :name

    t.timestamps
    t.datetime :happy_at
    t.datetime :sad_at
  end

  create_table :pets, force: true do |t|
    t.string :name
    t.integer :owner_id
    t.datetime :neutered_at

    t.timestamps
  end

  create_table :cars, force: true do |t|
    t.string :name
    t.column :lock_version, :integer, null: false, default: 0

    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.timestamps null: false
  end

  create_table :users, force: true do |t|
    t.timestamps null: false
  end

  create_table :comments, force: true do |t|
    t.integer :post_id
    t.integer :user_id
    t.timestamps null: false
  end
end

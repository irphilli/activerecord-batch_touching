class Owner < ActiveRecord::Base
  has_many :pets, inverse_of: :owner
end

class Pet < ActiveRecord::Base
  belongs_to :owner, touch: true, inverse_of: :pets
end

class Car < ActiveRecord::Base; end

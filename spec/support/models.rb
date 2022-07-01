class Owner < ActiveRecord::Base
  has_many :pets, inverse_of: :owner
end

class Pet < ActiveRecord::Base
  belongs_to :owner, touch: true, inverse_of: :pets
end

class Car < ActiveRecord::Base; end

class Post < ActiveRecord::Base
  has_many :comments, dependent: :destroy
end

class User < ActiveRecord::Base
  has_many :comments, dependent: :destroy
end

class Comment < ActiveRecord::Base
  belongs_to :post, touch: true
  belongs_to :user, touch: true
end

# ActiveRecord::BatchTouching
 [![Gem Version](https://badge.fury.io/rb/activerecord-batch_touching.svg)](http://badge.fury.io/rb/activerecord-batch_touching)
[![Build Status](https://github.com/irphilli/activerecord-batch_touching/actions/workflows/ruby-tests.yml/badge.svg?branch=main)](https://github.com/irphilli/activerecord-batch_touching/actions)
[![Maintainability](https://api.codeclimate.com/v1/badges/fe8338b7307fb5044f40/maintainability)](https://codeclimate.com/github/irphilli/activerecord-batch_touching/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/fe8338b7307fb5044f40/test_coverage)](https://codeclimate.com/github/irphilli/activerecord-batch_touching/test_coverage)
 
Batch up your ActiveRecord "touch" operations for better performance.

This gem is derivative of [activerecord-delay_touching](https://github.com/godaddy/activerecord-delay_touching) and [@BMorearty](https://github.com/BMorearty)'s subsequent PR to merge this functionality into Rails with https://github.com/rails/rails/pull/18824.
 
## Why?
Doesn't ActiveRecord already consolidate touches?

Yes, and no! Let's dig in!

The examples below build upon the following setup:

```
class Person < ActiveRecord::Base
  has_many :pets
  accepts_nested_attributes_for :pets
end

class Pet < ActiveRecord::Base
   belongs_to :person, touch: true
end
```

### One touch per object
Just like with the current ActiveModel functionality, `batch_touching` will prevent this simple `update` in the controller from calling`@person.touch` N times, where N is the number of pets that were updated via nested attributes. That's N-1 unnecessary round-trips to the database:

```
class PeopleController < ApplicationController
  def update
    ...
    @person.update(person_params)
    ...
  end
end

# SQL (0.1ms)  UPDATE "people" SET "updated_at" = '2014-07-09 19:48:07.137158' WHERE "people"."id" = 1
# SQL (0.1ms)  UPDATE "people" SET "updated_at" = '2014-07-09 19:48:07.138457' WHERE "people"."id" = 1
# SQL (0.1ms)  UPDATE "people" SET "updated_at" = '2014-07-09 19:48:07.140088' WHERE "people"."id" = 1
```

With `batch_touching`, @person is touched only once:

    @person.update(person_params)
	# SQL (0.1ms)  UPDATE "people" SET "updated_at" = '2014-07-09 19:48:07.140088' WHERE "people"."id" = 1

Nothing to see here! The next two sections are where this gem differentiates itself from the current ActiveRecord implementation.

### Consolidate Touches Per Table

In the following example, a person gives his pet to another person. ActiveRecord automatically touches the old person and the new person. The current ActiveRecord implementation has a SQL UPDATE _per_ individual record touched. With  `batch_touching`, this will only make a  _single_  round-trip to the database, setting  `updated_at`  for all Person records in a single SQL UPDATE statement. Not a big deal when there are only two touches, but when you're updating records en masse and have a cascade of hundreds touches, it really is a big deal.

```
class Pet < ActiveRecord::Base
  belongs_to :person, touch: true

  def give(to_person)
    self.person = to_person
    save! # touches old person and new person in a single SQL UPDATE.
  end
end
```
### Deadlock Prevention
`batch_touching` will sort the consolidated SQL updates by model name. The predictable order for updates should help mitigate potential database deadlocking.

For example, if two transactions happen to touch records in the following order, there is a potential for a deadlock:

**Transaction 1:**
```
ActiveRecord::Base.transaction do
  person1.touch
  pet1.touch
end
# SQL (0.1ms)  UPDATE "people" SET "updated_at" = '2014-07-09 19:48:07.140088' WHERE "people"."id" = 1
# SQL (0.1ms)  UPDATE "pets" SET "updated_at" = '2014-07-09 19:48:07.140088' WHERE "pets"."id" = 1
```

**Transaction 2**:
```
ActiveRecord::Base.transaction do
  pet1.touch
  person1.touch
end
# SQL (0.1ms)  UPDATE "pets" SET "updated_at" = '2014-07-09 19:48:07.140088' WHERE "pets"."id" = 1
# SQL (0.1ms)  UPDATE "people" SET "updated_at" = '2014-07-09 19:48:07.140088' WHERE "people"."id" = 1
```

`batch_touching` will have both transactions update in the same order, regardless of the order `.touch` was called.

It's dangerous to go alone! Take `batch_touching`.

## Installation

Add this line to your application's Gemfile:

    gem 'activerecord-batch_touching'

And then execute:

    $ bundle

Or install it yourself:

    $ gem install activerecord-batch_touching

## Usage

Once installed, all transactions will automatically have `batch_touching` enabled.

## Other tidbits

Some additional information or gotchas to be aware of!

### Cascading Touches

When `batch_touching` runs through and touches everything, it captures additional  `touch` calls that might be called as side-effects. (E.g., in `after_touch`  handlers.) Then it makes a second pass, batching up those touches as well.

It keeps doing this until there are no more touches, or until the sun swallows up the earth. Whichever comes first.

### Gotchas

* `after_touch` callbacks are still fired for every instance, but not until the block is exited. As a result, the ordering of the callbacks may be different than the default ActiveRecord implementation.
* If you call `person1.touch` and then `person2.touch`, and they are two separate instances with the same id, only person1's `after_touch` handler will be called.

## Contributing

1. Fork it ( [https://github.com/irphilli/activerecord-batch_touching/fork](https://github.com/irphilli/activerecord-batch_touching/fork) )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

# -*- encoding : utf-8 -*-
class Foobar < ActiveRecord::Base

  look_up_table :id
  look_up_table :foo
  look_up_table :bar
  look_up_table :foobar

end


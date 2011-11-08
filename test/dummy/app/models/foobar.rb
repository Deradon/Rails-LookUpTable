class Foobar < ActiveRecord::Base

  look_up_table :id, :batch_size => 500000
  look_up_table :foo
  look_up_table :bar, :sql_mode => false do |lut|
    lut[1] = []
    500000.times { |key| lut[1] << Random.rand }
    lut[1].sort!
  end
  #look_up_table :foobar

end


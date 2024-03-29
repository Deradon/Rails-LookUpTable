# -*- encoding : utf-8 -*-
# TODO:
# * use symbols freely
# * add some locking on CacheWriting
# * may find a solution for non-static data
# * add method_added listener

require 'look_up_table'

module LookUpTable
  extend ActiveSupport::Autoload
  extend ActiveSupport::Concern

  require 'look_up_table/base' # HACK
  #autoload :Base # CHECK
end

ActiveRecord::Base.send :include, LookUpTable


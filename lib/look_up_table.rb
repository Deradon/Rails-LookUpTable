# TODO:
# * move Methods to different modules
# * add private/protected
# * add class_names to CacheKey per default
# * if key allready used, transform values to array
# * somehow handle "cache-overflow"
# * use symbols freely

# FIXME:
# * Avoid @class_variables, issues if "subclassed"


require 'look_up_table'

module LookUpTable
  extend ActiveSupport::Autoload
  extend ActiveSupport::Concern

  require 'look_up_table/base'
  #autoload :Base # CHECK
end

ActiveRecord::Base.send :include, LookUpTable


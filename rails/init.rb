require 'alphabar'
ActiveRecord::Base.extend Alphabar::AlphaScope
ActionView::Base.send :include, Alphabar::Helper

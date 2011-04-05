# The Alphabar object is like a standard paginator but instead of
# splitting based on a certain number of records it splits based on
# the first letter of the object name.
#
# It keeps track of all the meta-data about the desired behavior and
# executes the searches in the most optimal way. This object can be
# used in the controller like the following:
#
#   @paginator = Alphabar.new
#   @paginator.field = :last_name
#   @paginator.group = params[:ltr]
#   @users = @paginator.scope(User, :order => 'last_name')
#
# See Alphabar::AlphaScope to reduce the amount of code in your
# controller for the common case.
class Alphabar

  # The current group being searched on that the results should be
  # returned for. Currently this should be a letter A-Z or 'Blank' but
  # eventually we might support different types of alphabars such
  # as those that group several letters under one page or those that
  # split a single letter into multiple pages. This is why we use
  # the terminology "group" instead of "letter"
  attr_accessor :group

  # The field used to divide the objects into the different groups (letters)
  attr_accessor :field

  # Is there an "All" option? Defaults to false
  attr_accessor :all_option

  # The minimum number of records that must exist in the database before
  # the alphbar is used. An application can alternatively define
  # ALPHABAR_MINIMUM_RECORDS to provide a global default.
  attr_accessor :min_records

  # Create a new alphabar to execute a letter based search.
  def initialize
    self.all_option = false
    self.min_records = ALPHABAR_MINIMUM_RECORDS if
      Object.const_defined? 'ALPHABAR_MINIMUM_RECORDS'
  end

  # Will execute the actual scoping on the given model. To further
  # limit the records pass in a scope instead of the actual model.
  def scope(model)
    raise ActiveRecord::ActiveRecordError, 'invalid column' unless
      model.column_names.include? field.to_s

    # Find out how many are in each bucket
    # FIXME: This may be database specific. Work on MySQL and SQLite
    @counts = model.count :all, :group => "SUBSTR(LOWER(#{field.to_s}), 1, 1)"
    @counts = @counts.inject(HashWithIndifferentAccess.new()) do |m,grp|
      grp[0] = grp[0].blank? ? 'Blank' : grp[0]
      m[grp[0].upcase] = grp[1]
      m
    end
    @counts['All'] = total if all_option

    # Reset to default group if group has not records
    self.group = nil unless @counts.has_key? group

    # Find the first group that has records
    all_groups = ('A'..'Z').to_a + ['Blank']
    all_groups << 'All' if all_option
    self.group = all_groups.detect(proc {'A'}) do |ltr|
      @counts.has_key? ltr
    end if group.blank?

    quoted_field = model.connection.quote_column_name field.to_s
    unless (min_records && total >= min_records) || group == 'All'
      # Determine conditions. '' or NULL shows up under "Blank"
      operator = if group == 'Blank'
        "= '' OR #{quoted_field} IS NULL"
      else
        'LIKE ?'
      end
      conditions = [
        "#{model.table_name}.#{quoted_field} #{operator}",
        "#{group}%"
      ]
    end

    # Find results for this page
    model.where conditions
  end

  # Given a group will return the number of results in that group.
  # Only valid AFTER scope has been executed
  def count(grp)
    @counts[grp] || 0
  end

  # Will return the total records found in all groups.
  # Only valid AFTER scope has been executed
  def total
    @total ||= @counts.inject(0) {|total, (group, count)| total += count}
  end

  # Will return all groups that have results.
  # Only valid AFTER scope has been executed
  def populated_groups
    @counts.keys
  end

  # This helper module is automatically mixed into your views to
  # provide an easy way to display the alphabar.
  module Helper

    # Basic alphabar generator. Just give it the paginator and any
    # options needed. The only current option is :letter_field which
    # indicates the name of the param that will be used to submit the
    # new search. By default it will be ltr.
    #
    # This helper will link all letters that have results. It will
    # also mark the "current" letter with a CSS class 'current'.
    # Finally if there are any "Blank" records a "Blank" group
    # will be appended.
    #
    # If only one letter would show or it doesn't meet the min_records
    # requirement this helper will return an empty string.
    def alphabar(paginator, options={})
      return '' if paginator.min_records && paginator.total < paginator.min_records
      return '' if paginator.populated_groups.size <= 1
      slots = ('A'..'Z').to_a
      slots << 'Blank' if paginator.count('Blank') > 0
      slots << 'All' if paginator.count('All') > 0
      letters = slots.collect do |ltr|
        html_options = {}
        html_options[:class] = 'current' if ltr == paginator.group.to_s
        options = params.dup
        options[options[:letter_field] || 'ltr'] = ltr
        link_to_if paginator.count(ltr) > 0, ltr, options, html_options
      end.compact.join ' '
      content_tag 'div', letters.html_safe, :class => 'alphabar'
    end
  end

  module AlphaScope

    # A simple wrapper around the Alphabar interface to make usage
    # easier and more integrated in to ActiveRecord. Will use the first
    # two parameters to create the Alphabar object for you and execute
    # the find returning both the resulting scope as well as the
    # populated paginator object.
    #
    # You can also pass this method a block which allows you to
    # configure the #Alphabar paginator object before the scope is
    # applied. The argument to the block is the paginator object.
    #
    #   @users, @paginator = User.alpha_scope :last_name, params[:ltr]
    def alpha_scope(field, group=nil)
      paginator = Alphabar.new
      paginator.field = field
      paginator.group = group
      yield paginator if block_given?
      results = paginator.scope self
      [results, paginator]
    end
  end

  class Railtie < Rails::Railtie
    initializer 'alphabar.integration' do
      ActiveRecord::Base.extend Alphabar::AlphaScope
      ActionController::Base.helper Alphabar::Helper
    end
  end if defined? Rails
end

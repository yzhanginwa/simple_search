class SimpleSearch 
  def initialize(criteria, config={})
    @criteria = criteria.nil? ? {} : criteria
    sanitize_criteria
    @config = {:exact_match => []}
    @config.merge!(config)
    @join_mappings = {}
    @joins = {}
  end

  def method_missing(method)
    @criteria[method.to_s]
  end

  def add_join_mappings(h={})
    @join_mappings.merge!(h)
  end

  def add_conditions(h={})
    @criteria.merge!(h)
  end

  def joins
    result = ''
    @joins.each do |table, constrain|
      result << " inner join  #{table} on #{constrain}" 
    end
    result
  end

  def conditions
    return @conditions unless @conditions.nil? 
    @criteria.each do |key, value|
      insert_condition(key, value)
      insert_join(key, value)
    end
    @conditions
  end


  private

  def insert_condition(key, value)
    @conditions ||= []
    if !value.is_a?(String) || @config[:exact_match].include?(key)
      verb = '='
    else
      verb = 'like'
      value = "%#{value}%"
    end

    if @conditions.size < 1
      @conditions[0] = "#{key} #{verb} ?"
      @conditions[1] = value
    else
      @conditions[0] += " and #{key} #{verb} ?"
      @conditions << value
    end
  end     

  def insert_join(key, value)
    if key =~ /\./
      table, field = key.split(/\./)
      if @join_mappings[table] && @joins[table].nil?
        @joins[table] = @join_mappings[table]
      end
    end
  end

  def sanitize_criteria
    @criteria.keys.each do |key|
      if @criteria[key].nil? || @criteria[key].blank?
        @criteria.delete(key)
      end
    end
  end
end

module SimpleSearch
  class Base
    def initialize(model_class, criteria, config={})
      @model_class = (model_class.is_a?(Symbol) || model_class.is_a?(String))? model_class.to_s.capitalize.constantize : model_class
      @table_name = @model_class.table_name
      @criteria = criteria.nil? ? {} : criteria
      sanitize_criteria
      @config = {:exact_match => []}
      @config.merge!(config)
      @joins = {}
    end
  
    def method_missing(method)
      @criteria[method.to_s]
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
        table, field, ass_ref = parse_attribute(key)
        insert_condition(table, field, ass_ref, value)
        insert_join(table, field, ass_ref, value)
      end
      @conditions
    end
  
    def run(option={})
      @model_class.all({:select => "distinct #{@model_class.table_name}.*", :conditions => self.conditions, :joins => self.joins}.merge(option))
    end
  
    private
  
    def insert_condition(table, field, ass_ref, value)
      key = "#{table}.#{field}"
  
      @conditions ||= []
      model_class = ass_ref.nil? ? @model_class : ass_ref.klass
      column = model_class.columns_hash[field.to_s]
  
      if column.number? || @config[:exact_match].include?((@table_name == table)? field : key)
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
  
    def insert_join(table, field, ass_ref, value)
      unless table == @table_name
        if @joins[table].nil?
          if ass_ref.belongs_to?
            @joins[table] = "#{@table_name}.#{ass_ref.primary_key_name} = #{table}.#{ass_ref.klass.primary_key}"
          else
            @joins[table] = "#{@table_name}.#{@model_class.primary_key} = #{table}.#{ass_ref.primary_key_name}"
          end
        end
      end
    end
  
    def parse_attribute(attribute)
      if attribute =~ /\./
        association, field = attribute.split(/\./)
      else
        association, field = nil, attribute
      end
      
      if association.nil?
        association_reflection = nil
        table = @model_class.table_name
      else
        association_reflection = @model_class.reflect_on_association(association.to_sym)
        table = association_reflection.klass.table_name    
      end
      [table, field, association_reflection]
    end
  
    def sanitize_criteria
      @criteria.keys.each do |key|
        if @criteria[key].nil? || @criteria[key].blank?
          @criteria.delete(key)
        end
      end
    end
  end
end

require 'dnsruby'

RSpec::Matchers.define :have_dns do
  match do |dns|
    @dns = dns
    @number_matched = 0

    matched = _options.all? do |opt|
      opt.each_pair do |option, value|
        if @authority
          records = _records.authority
        else
          records = _records.answer
        end
        if option == :at_least
          @at_least = true
          @number_matched = records.count
          records.count >= value
        else
          records = records.find_all do |record|
            # To distinguish types because not all Resolv returns have type
            if value.is_a? String
              record.send(option).to_s == value
            elsif value.is_a? Regexp
              record.send(option).to_s =~ value
            else
              record.send(option) == value
            end
            records.count > 0
          end
        end
      end
    end
  end

  failure_message_for_should do |actual|
    if @at_least
      "expected #{actual} to have: #{@at_least} records of #{_pretty_print_options}, but found #{@number_matched}. Other records were: #{_pretty_print_records}"
    else
      "expected #{actual} to have: #{_pretty_print_options}, but did not. other records were: #{_pretty_print_records}"
    end
  end

  failure_message_for_should_not do |actual|
    "expected #{actual} not to have #{_pretty_print_options}, but it did"
  end

  def description
    "have the correct dns entries with #{_options}"
  end

  chain :in_authority do
    @authority = true
  end

  chain :at_least do |actual|
    _options.push(:at_least => actual)
  end

  def method_missing(m, *args, &block)
    if m.to_s =~ /(and\_with|and|with)?\_(.*)$/
      _options.push($2.to_sym => args.first)
      self
    else
      super
    end
  end

  def _config
    @config ||= if File.exists?(_config_file)
      require 'yaml'
      config = _symbolize_keys(YAML::load(ERB.new(File.read(_config_file) ).result))
    else
      nil
    end
  end

  def _config_file
    File.join('config', 'dns.yml')
  end

  def _symbolize_keys(hash)
    hash.inject({}){|result, (key, value)|
      new_key = case key
                when String then key.to_sym
                else key
                end
      new_value = case value
                  when Hash then _symbolize_keys(value)
                  else value
                  end
      result[new_key] = new_value
      result
    }
  end

  def _options
    @_options ||= []
  end

  def _pretty_print_options
    "\n  (#{_options.sort.collect{ |k,v| "#{k}:#{v.inspect}" }.join(', ')})\n"
  end

  def _records
    @_records ||= begin
      Timeout::timeout(1) {
        if _config.nil?
          Dnsruby::Resolver.new.query(@dns, Dnsruby::Types.ANY)
        else
          Dnsruby::Resolver.new(_config).query(@dns, Dnsruby::Types.ANY)
        end
      }
    rescue Timeout::Error
      $stderr.puts "Connection timed out for #{@dns}"
      []
    end
  end

  def _pretty_print_records
    "\n" + _records.collect { |record| _pretty_print_record(record) }.join("\n")
  end

  def _pretty_print_record(record)
    '  (' + %w(address bitmap cpu data emailbx exchange expire minimum mname name os port preference priority protocol refresh retry rmailbx rname serial target ttl type weight).collect do |method|
      "#{method}:#{record.send(method.to_sym).to_s.inspect}" if record.respond_to?(method.to_sym)
    end.compact.join(', ') + ')'
  end
end

#
# Fluentd
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

module Fluent
  class GrepFilter < Filter
    Fluent::Plugin.register_filter('grep', self)

    REGEXP_MAX_NUM = 20

    (1..REGEXP_MAX_NUM).each {|i| config_param :"regexp#{i}",  :string, :default => nil }
    (1..REGEXP_MAX_NUM).each {|i| config_param :"exclude#{i}", :string, :default => nil }

    # for test
    attr_reader :regexps
    attr_reader :excludes

    def configure(conf)
      super

      @regexps = {}
      (1..REGEXP_MAX_NUM).each do |i|
        next unless conf["regexp#{i}"]
        key, regexp = conf["regexp#{i}"].split(/ /, 2)
        raise ConfigError, "regexp#{i} does not contain 2 parameters" unless regexp
        raise ConfigError, "regexp#{i} contains a duplicated key, #{key}" if @regexps[key]
        @regexps[key] = Regexp.compile(regexp)
      end

      @excludes = {}
      (1..REGEXP_MAX_NUM).each do |i|
        next unless conf["exclude#{i}"]
        key, exclude = conf["exclude#{i}"].split(/ /, 2)
        raise ConfigError, "exclude#{i} does not contain 2 parameters" unless exclude
        raise ConfigError, "exclude#{i} contains a duplicated key, #{key}" if @excludes[key]
        @excludes[key] = Regexp.compile(exclude)
      end
    end

    def filter_stream(tag, es)
      result_es = MultiEventStream.new
      es.each do |time, record|
        catch(:break_loop) do
          @regexps.each do |key, regexp|
            throw :break_loop unless match(regexp, record[key].to_s)
          end
          @excludes.each do |key, exclude|
            throw :break_loop if match(exclude, record[key].to_s)
          end
          result_es.add(time, record)
        end
      end
      result_es
    rescue => e
      log.warn "failed to grep events", :error_class => e.class, :error => e.message
      log.warn_backtrace
    end

    private

    def match(regexp, string)
      begin
        return regexp.match(string)
      rescue ArgumentError => e
        raise e unless e.message.index("invalid byte sequence in".freeze).zero?
        log.info "invalid byte sequence is replaced in `#{string}`"
        string = string.scrub('?')
        retry
      end
      return true
    end
  end
end

# frozen_string_literal: true

require 'date'

module EveryPivot
  # Semantic time contract 1.0, independent of the bounded Neo4j date helper.
  #
  # Public methods return string-keyed {status, reasons, ...} hashes. Status is
  # match, no_match, unresolved, or unsupported. Malformed supplied values raise
  # InvalidInput. Missing evidence never becomes a zero time or an infinite end.
  #
  # normalize(envelope) preserves the entire input and reports UTC bounds. A
  # time envelope binds {object, occurrence}, field, source_revision, clock
  # {id, reference: UTC, uncertainty_seconds}, timezone and precision. Precision
  # is instant, second, minute, day, month, year or interval. Coarse occurrence
  # values describe possible instants, not an event at midnight. An interval
  # supplies start/end timestamps and explicit inclusive endpoint flags.
  # interval_role is occurrence (uncertainty), validity or service (evidenced
  # continuous state). Explicit zero clock uncertainty is allowed; omission is
  # unknown. reference: UTC is a source-profile assertion, not inferred from Z.
  # Clock calibration and the truth of source assertions require external
  # evidence validation; this module evaluates the stated bounded time model.
  #
  # compare(left, operator, right) supports <, <=, == (lt, lte, eq). It proves a
  # predicate for all possible occurrence instants, disproves it when none can
  # satisfy it, and otherwise returns unresolved. It never chooses a favorable
  # instant. Ordering established validity/service ranges is unsupported.
  #
  # within(envelope, period: {start: YYYY-MM-DD, end: YYYY-MM-DD},
  #        quantifier: 'contained'|'some'|'all'|'at', at: optional time envelope)
  # uses inclusive UTC calendar dates. 'contained' asks whether the whole
  # established interval/possible occurrence lies in the period. For established
  # validity/service only, 'some' asks whether evidenced state intersects the
  # period and 'all' whether it covers the entire requested period. 'at' checks
  # an occurrence against an established state and
  # the selected period. An open/missing state end is never indefinite service.
  # calendar_window(envelope, query_date:, window_days:, quantifier: 'contained')
  # resolves [query_date - window_days, query_date], inclusive, in UTC. It has no
  # implicit current date, knowledge cutoff, default role or source field.
  module SemanticTime
    class InvalidInput < ArgumentError; end

    Interval = Struct.new(:lower, :upper, :lower_inclusive, :upper_inclusive, :role)
    ROLES = %w[occurrence validity service].freeze
    PRECISIONS = %w[instant second minute day month year interval].freeze
    module_function

    def result(status, reasons = [], extra = {})
      { 'status' => status, 'reasons' => Array(reasons) }.merge(extra)
    end

    def normalize(envelope)
      parsed = parse(envelope)
      public_result(parsed)
    end

    def validate_period(period)
      period_interval(period)
      result('match', ['valid inclusive UTC calendar period'], 'period' => period)
    end

    def resolve_calendar_period(query_date:, window_days:)
      unless window_days.is_a?(Numeric) && window_days.finite? && window_days >= 0 && window_days.to_i == window_days
        raise InvalidInput, 'window_days must be a nonnegative mathematical integer'
      end
      anchor = calendar_date(query_date)
      period = { 'start' => (anchor - window_days.to_i).iso8601, 'end' => anchor.iso8601 }
      validate_period(period)
      period
    end

    # Every operand must assert an established state. Independent overlap with
    # the query does not prove that all relationships coexisted with each other.
    def coexists(envelopes, period:)
      requested = period_interval(period)
      raise InvalidInput, 'coexists requires a nonempty array of states' unless envelopes.is_a?(Array) && !envelopes.empty?
      parsed = envelopes.map { |value| parse(value) }
      blocked = combine_inputs(*parsed)
      return blocked if blocked
      intervals = parsed.map { |value| value.fetch('interval') }
      return result('unsupported', ['coexists requires established validity or service, not possible occurrence overlap']) if intervals.any? { |value| value.role == 'occurrence' }
      intervals << requested
      lower = intervals.map(&:lower).max
      upper = intervals.map(&:upper).min
      lower_inclusive = intervals.select { |value| value.lower == lower }.all?(&:lower_inclusive)
      upper_inclusive = intervals.select { |value| value.upper == upper }.all?(&:upper_inclusive)
      exists = lower < upper || (lower == upper && lower_inclusive && upper_inclusive)
      details = {'period' => period, 'operands' => parsed.map { |value| public_result(value) }}
      if exists
        details['common_interval'] = {'lower' => utc_text(lower), 'upper' => utc_text(upper),
                                      'lower_inclusive' => lower_inclusive, 'upper_inclusive' => upper_inclusive}
      end
      result(exists ? 'match' : 'no_match', ['established common applicability within selected period'], details)
    end

    def compare(left, operator, right)
      op = { '<' => 'lt', '<=' => 'lte', '==' => 'eq', '=' => 'eq' }.fetch(operator, operator)
      return result('unsupported', ['unknown comparison operator']) unless %w[lt lte eq].include?(op)

      l = parse(left)
      r = parse(right)
      prerequisite = combine_inputs(l, r)
      return prerequisite if prerequisite

      a, b = l.fetch('interval'), r.fetch('interval')
      return result('unsupported', ['ordering requires occurrence operands; choose state endpoints explicitly']) unless a.role == 'occurrence' && b.role == 'occurrence'

      status = case op
               when 'lte'
                 if a.upper <= b.lower
                   'match'
                 elsif a.lower > b.upper || (a.lower == b.upper && !(a.lower_inclusive && b.upper_inclusive))
                   'no_match'
                 else
                   'unresolved'
                 end
               when 'lt'
                 if a.upper < b.lower || (a.upper == b.lower && !(a.upper_inclusive && b.lower_inclusive))
                   'match'
                 elsif a.lower >= b.upper
                   'no_match'
                 else
                   'unresolved'
                 end
               when 'eq'
                 if point?(a) && point?(b) && a.lower == b.lower
                   'match'
                 elsif disjoint?(a, b)
                   'no_match'
                 else
                   'unresolved'
                 end
               end
      result(status, ["occurrence #{op} #{status}"], 'left' => public_result(l), 'right' => public_result(r))
    end

    def within(envelope, period:, quantifier: 'contained', at: nil)
      requested = period_interval(period)
      return result('unsupported', ['unknown interval quantifier']) unless %w[contained all some at].include?(quantifier)

      parsed = parse(envelope)
      return public_result(parsed) unless parsed['status'] == 'match'

      operand = parsed.fetch('interval')
      if operand.role == 'occurrence' && quantifier != 'contained'
        return result('unsupported', ['uncertain occurrence requires contained; possible overlap is not evidenced state'])
      end
      if quantifier == 'at'
        return result('unsupported', ['at requires an established validity or service interval']) if operand.role == 'occurrence'
        return result('unresolved', ['at occurrence is missing']) if at.nil?

        instant = parse(at)
        return public_result(instant) unless instant['status'] == 'match'
        return result('unsupported', ['at must identify an occurrence']) unless instant['interval'].role == 'occurrence'

        period_status = containment_status(instant['interval'], requested)
        state_status = containment_status(instant['interval'], operand)
        status = if [period_status, state_status].include?('no_match')
                   'no_match'
                 elsif [period_status, state_status].include?('unresolved')
                   'unresolved'
                 else
                   'match'
                 end
      elsif quantifier == 'some'
        status = disjoint?(operand, requested) ? 'no_match' : 'match'
      elsif quantifier == 'all'
        status = subset?(requested, operand) ? 'match' : 'no_match'
      elsif operand.role != 'occurrence'
        status = subset?(operand, requested) ? 'match' : 'no_match'
      else
        status = containment_status(operand, requested)
      end
      result(status, ["#{operand.role} #{quantifier} #{status}"], 'operand' => public_result(parsed), 'period' => period)
    end

    def calendar_window(envelope, query_date:, window_days:, quantifier: 'contained')
      period = resolve_calendar_period(query_date: query_date, window_days: window_days)
      within(envelope, period: period, quantifier: quantifier).merge('resolved_period' => period)
    end

    def parse(envelope)
      return result('unresolved', ['time envelope is missing'], 'original' => nil) if envelope.nil?
      raise InvalidInput, 'time envelope must be an object' unless envelope.is_a?(Hash)

      if envelope.key?('alternatives')
        unknown = envelope.keys - %w[alternatives original_value]
        raise InvalidInput, "alternative time container has unsupported fields: #{unknown.join(', ')}" unless unknown.empty?
        alternatives = envelope['alternatives']
        raise InvalidInput, 'time alternatives must contain at least two envelopes' unless alternatives.is_a?(Array) && alternatives.length >= 2
        parsed = alternatives.map { |entry| parse(entry) }
        return result('unresolved', ['conflicting or alternative time evidence requires an explicit claim; no winner selected'],
                      'original' => envelope, 'alternatives' => parsed.map { |entry| public_result(entry) })
      end

      unknown = envelope.keys - %w[binding field source_revision clock timezone precision interval_role value start end start_inclusive end_inclusive original_value]
      raise InvalidInput, "time envelope has unsupported fields: #{unknown.join(', ')}" unless unknown.empty?

      missing = []
      binding = envelope['binding']
      raise InvalidInput, 'time binding must be an object' unless binding.nil? || binding.is_a?(Hash)
      raise InvalidInput, 'time binding has unsupported fields' if binding && !(binding.keys - %w[object occurrence]).empty?
      %w[object occurrence].each { |key| require_text(binding && binding[key], "binding.#{key}", missing) }
      %w[field source_revision].each { |key| require_text(envelope[key], key, missing) }
      role = require_text(envelope['interval_role'], 'interval_role', missing)
      precision = require_text(envelope['precision'], 'precision', missing)
      if role && !ROLES.include?(role)
        return result('unsupported', ['unknown interval role'], 'original' => envelope)
      end
      if precision && !PRECISIONS.include?(precision)
        return result('unsupported', ['unknown time precision'], 'original' => envelope)
      end

      clock = envelope['clock']
      raise InvalidInput, 'clock must be an object' unless clock.nil? || clock.is_a?(Hash)
      raise InvalidInput, 'clock has unsupported fields' if clock && !(clock.keys - %w[id reference uncertainty_seconds]).empty?
      require_text(clock && clock['id'], 'clock.id', missing)
      reference = require_text(clock && clock['reference'], 'clock.reference', missing)
      return result('unsupported', ['clock reference mapping is unsupported'], 'original' => envelope) if reference && reference != 'UTC'

      uncertainty = clock && clock['uncertainty_seconds']
      if uncertainty.nil?
        missing << 'clock.uncertainty_seconds'
      elsif !uncertainty.is_a?(Numeric) || !uncertainty.finite? || uncertainty < 0
        raise InvalidInput, 'clock uncertainty must be a finite nonnegative number'
      end
      zone = require_text(envelope['timezone'], 'timezone', missing)
      offset = zone && offset_minutes(zone)
      return result('unresolved', ['source timezone offset is explicitly unknown'], 'original' => envelope) if zone == '-00:00'
      return result('unsupported', ['timezone mapping is unsupported'], 'original' => envelope) if zone && offset.nil?

      if precision == 'interval'
        raise InvalidInput, 'interval cannot also supply point value' if envelope.key?('value')
        %w[start end].each { |key| require_text(envelope[key], key, missing) }
        %w[start_inclusive end_inclusive].each do |key|
          value = envelope[key]
          missing << key if value.nil?
          raise InvalidInput, "#{key} must be boolean" unless value.nil? || value == true || value == false
        end
      elsif precision
        raise InvalidInput, 'point/coarse value cannot also supply interval endpoints' unless (envelope.keys & %w[start end start_inclusive end_inclusive]).empty?
        require_text(envelope['value'], 'value', missing)
      end
      return result('unresolved', missing.map { |key| "missing #{key}" }, 'original' => envelope) unless missing.empty?

      if precision == 'interval'
        lower = timestamp(envelope['start'], offset)
        upper = timestamp(envelope['end'], offset)
        lower_inc, upper_inc = envelope.values_at('start_inclusive', 'end_inclusive')
      else
        lower, upper, lower_inc, upper_inc = precision_bounds(envelope['value'], precision, offset)
      end
      if lower > upper || (lower == upper && !(lower_inc && upper_inc))
        raise InvalidInput, 'time interval is reversed or empty'
      end
      if role != 'occurrence' && precision != 'interval' && !point_raw?(lower, upper, lower_inc, upper_inc)
        return result('unsupported', ['coarse state assertion must specify evidenced interval bounds; precision is not duration'], 'original' => envelope)
      end
      # A state with uncertain bounds does not establish all of the enlarged
      # interval. Require a supported state scope instead of expanding it.
      if role != 'occurrence' && uncertainty != 0
        return result('unresolved', ['uncertain state endpoints need separately evidenced applicability'], 'original' => envelope)
      end
      if uncertainty > 0
        delta = Rational(uncertainty.to_s) / 86_400
        lower -= delta
        upper += delta
      end
      interval = Interval.new(lower, upper, lower_inc, upper_inc, role)
      result('match', ['supported UTC temporal envelope'], 'original' => envelope, 'interval' => interval)
    rescue ArgumentError => e
      raise if e.is_a?(InvalidInput)
      raise InvalidInput, "invalid calendar time: #{e.message}"
    end

    def require_text(value, label, missing)
      if value.nil? || value == ''
        missing << label
        return nil
      end
      raise InvalidInput, "#{label} must be a string" unless value.is_a?(String)
      if value.strip.empty?
        missing << label
        return nil
      end
      value
    end

    def offset_minutes(zone)
      return 0 if %w[UTC Z].include?(zone)
      return nil unless zone.match?(/\A[+-][0-9]{2}:[0-9]{2}\z/)
      hours, minutes = zone[1..-1].split(':').map(&:to_i)
      raise InvalidInput, 'timezone offset out of range' if hours > 23 || minutes > 59
      return nil if zone == '-00:00' # RFC-style unknown offset, not known UTC.
      (zone.start_with?('-') ? -1 : 1) * (hours * 60 + minutes)
    end

    def timestamp(value, offset)
      pattern = /\A([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})?\z/
      match = pattern.match(value)
      raise InvalidInput, 'expected full ISO timestamp with seconds' unless match
      raise InvalidInput, 'timestamp hour/minute/second out of range' if match[2].to_i > 23 || match[3].to_i > 59 || match[4].to_i > 59
      zone = match[6]
      actual_offset = zone ? offset_minutes(zone) : offset
      raise InvalidInput, 'timestamp offset contradicts timezone or is unknown' if actual_offset.nil? || actual_offset != offset
      text = zone ? value : value + offset_text(offset)
      DateTime.iso8601(text).new_offset(0)
    end

    def offset_text(minutes)
      sign = minutes.negative? ? '-' : '+'
      format('%s%02d:%02d', sign, minutes.abs / 60, minutes.abs % 60)
    end

    def precision_bounds(value, precision, offset)
      case precision
      when 'instant'
        point = timestamp(value, offset)
        [point, point, true, true]
      when 'second'
        raise InvalidInput, 'second precision must not supply fractional seconds' if value.include?('.')
        point = timestamp(value, offset)
        [point, point + Rational(1, 86_400), true, false]
      when 'minute'
        match = /\A([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2})(Z|[+-][0-9]{2}:[0-9]{2})?\z/.match(value)
        raise InvalidInput, 'minute precision requires YYYY-MM-DDTHH:MM with optional offset' unless match
        point = timestamp(match[1] + ':00' + match[2].to_s, offset)
        [point, point + Rational(1, 1440), true, false]
      when 'day', 'month', 'year'
        pattern = { 'day' => /\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/, 'month' => /\A[0-9]{4}-[0-9]{2}\z/, 'year' => /\A[0-9]{4}\z/ }.fetch(precision)
        raise InvalidInput, 'calendar value does not match stated precision' unless value.match?(pattern)
        date = Date.iso8601(value + { 'day' => '', 'month' => '-01', 'year' => '-01-01' }.fetch(precision))
        next_date = precision == 'day' ? date + 1 : date >> (precision == 'month' ? 1 : 12)
        lower = DateTime.new(date.year, date.month, date.day, 0, 0, 0, Rational(offset, 1440)).new_offset(0)
        upper = DateTime.new(next_date.year, next_date.month, next_date.day, 0, 0, 0, Rational(offset, 1440)).new_offset(0)
        [lower, upper, true, false]
      else
        raise InvalidInput, 'unsupported precision passed to parser'
      end
    end

    def calendar_date(value)
      raise InvalidInput, 'query dates must be YYYY-MM-DD' unless value.is_a?(String) && value.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/)
      Date.iso8601(value)
    rescue ArgumentError => e
      raise if e.is_a?(InvalidInput)
      raise InvalidInput, "invalid query date: #{e.message}"
    end

    def period_interval(period)
      raise InvalidInput, 'period must be an object with start and end dates' unless period.is_a?(Hash)
      raise InvalidInput, 'period has unsupported fields' unless (period.keys - %w[start end]).empty?
      start_date, end_date = calendar_date(period['start']), calendar_date(period['end'])
      raise InvalidInput, 'query period is reversed' if start_date > end_date
      Interval.new(DateTime.iso8601(start_date.iso8601 + 'T00:00:00Z'),
                   DateTime.iso8601((end_date + 1).iso8601 + 'T00:00:00Z'), true, false, 'query')
    end

    def point_raw?(lower, upper, lower_inc, upper_inc)
      lower == upper && lower_inc && upper_inc
    end

    def point?(interval)
      point_raw?(interval.lower, interval.upper, interval.lower_inclusive, interval.upper_inclusive)
    end

    def disjoint?(a, b)
      a.upper < b.lower || b.upper < a.lower ||
        (a.upper == b.lower && !(a.upper_inclusive && b.lower_inclusive)) ||
        (b.upper == a.lower && !(b.upper_inclusive && a.lower_inclusive))
    end

    def subset?(a, b)
      lower_ok = a.lower > b.lower || (a.lower == b.lower && (!a.lower_inclusive || b.lower_inclusive))
      upper_ok = a.upper < b.upper || (a.upper == b.upper && (!a.upper_inclusive || b.upper_inclusive))
      lower_ok && upper_ok
    end

    def containment_status(operand, requested)
      return 'match' if subset?(operand, requested)
      return 'no_match' if disjoint?(operand, requested)
      'unresolved'
    end

    def combine_inputs(*inputs)
      blocked = inputs.reject { |entry| entry['status'] == 'match' }
      return nil if blocked.empty?
      status = blocked.any? { |entry| entry['status'] == 'unsupported' } ? 'unsupported' : 'unresolved'
      result(status, blocked.flat_map { |entry| entry['reasons'] }, 'operands' => inputs.map { |entry| public_result(entry) })
    end

    def public_result(parsed)
      output = parsed.reject { |key, _value| key == 'interval' }
      interval = parsed['interval']
      if interval
        output['normalized'] = {
          'lower' => utc_text(interval.lower), 'upper' => utc_text(interval.upper),
          'lower_inclusive' => interval.lower_inclusive, 'upper_inclusive' => interval.upper_inclusive,
          'interval_role' => interval.role, 'comparison_timezone' => 'UTC'
        }
      end
      output
    end

    def utc_text(value)
      denominator = value.sec_fraction.denominator
      twos = fives = 0
      while (denominator % 2).zero?
        denominator /= 2
        twos += 1
      end
      while (denominator % 5).zero?
        denominator /= 5
        fives += 1
      end
      value.iso8601([twos, fives, 9].max)
    end
    private_class_method :parse, :require_text, :offset_minutes, :timestamp, :offset_text,
                         :precision_bounds, :calendar_date, :period_interval, :point_raw?,
                         :point?, :disjoint?, :subset?, :containment_status, :combine_inputs, :public_result, :utc_text
  end
end

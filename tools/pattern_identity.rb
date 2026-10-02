# frozen_string_literal: true

module EveryPivot
  # One publication unit has one definition per ID, regardless of lane.
  class PatternIdentity
    def initialize
      @paths = {}
    end

    def check(data, path:, basename:, lane:)
      errors = []
      id = data['id']
      if id.is_a?(String)
        if @paths.key?(id)
          errors << "duplicate pattern id #{id.inspect}: #{@paths[id]} and #{path}"
        else
          @paths[id] = path
        end
        errors << "filename must match `id` (`#{basename}` != `#{id}`)" if id != basename
      end
      if data.key?('validation_state') && lane != 'other' && data['validation_state'] != lane
        errors << "`validation_state` should match lane `#{lane}`"
      end
      errors
    end
  end
end

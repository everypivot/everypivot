#!/usr/bin/env ruby
# frozen_string_literal: true
require 'fileutils'
require_relative 'fixture_factory'
expected = {
  'CTI_IMAGE_TEXT_REUSE_CLUSTER' => ['input'],
  'CTI_WEB_CONTENT_EMBEDDED_CONFIG_STRING_CLUSTER' => ['url'],
  'CTI_EMAIL_MESSAGE_TO_EMBEDDED_URLS' => ['url'],
  'ADTECH_WEBAPP_SOURCEMAP_TO_ADMIN_SURFACE' => ['route'],
  'CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_PAYLOADS' => ['output']
}
FileUtils.mkdir_p(File.join(__dir__, 'cases'))
ExtractionFixtures.all.each do |id, data|
  data.delete('contract')
  data['contract_path'] = '../../../contracts/semantics/' + id + '.json'
  data['expected_result_ids'] = expected.fetch(id, ['input'])
  File.write(File.join(__dir__, 'cases', id + '.json'), JSON.pretty_generate(data) + "\n")
end

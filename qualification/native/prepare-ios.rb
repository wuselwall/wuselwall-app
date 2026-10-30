#!/usr/bin/env ruby
# Run only in a disposable checkout. CocoaPods supplies the xcodeproj gem.
require 'xcodeproj'
require 'fileutils'
root = File.expand_path('../..', __dir__)
project_path = File.join(root, 'app/ios/Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)
raise 'Audit target already exists; use a clean disposable checkout' if project.targets.any? { |t| t.name == 'QualificationAudits' }
runner = project.targets.find { |t| t.name == 'Runner' }
target = project.new_target(:ui_test_bundle, 'QualificationAudits', :ios, '17.0')
target.add_dependency(runner)
source = project.main_group.new_file('../../qualification/native/AccessibilityAuditTests.swift')
target.source_build_phase.add_file_reference(source)
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'ch.goomba.wuselwall.QualificationAudits'
  config.build_settings['PRODUCT_NAME'] = 'QualificationAudits'
  config.build_settings['EXECUTABLE_NAME'] = 'QualificationAudits'
  config.build_settings['PRODUCT_MODULE_NAME'] = 'QualificationAudits'
  config.build_settings['TEST_TARGET_NAME'] = 'Runner'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = '../../qualification/native/Audit-Info.plist'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(runner)
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.set_launch_target(runner)
scheme.test_action.build_configuration = 'Debug'
scheme.save_as(project_path, 'QualificationAudits', true)

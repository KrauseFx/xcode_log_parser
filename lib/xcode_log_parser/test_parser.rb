module XcodeLogParser
  class TestParser
    attr_accessor :data

    attr_accessor :file_content

    attr_accessor :raw_json

    def initialize(path)
      path = File.expand_path(path)
      UI.user_error!("File not found at path '#{path}'") unless File.exist?(path)

      self.file_content = File.read(path)
      self.raw_json = Plist.parse_xml(self.file_content)

      ensure_file_valid!
      parse_content
    end

    private

    def ensure_file_valid!
      format_version = self.raw_json["FormatVersion"]
      UI.user_error!("Format version #{format_version} is not supported") unless format_version == "1.2"
    end

    # Convert the Hashes and Arrays in something more useful
    def parse_content
      def unfold_tests(data)
        # `data` looks like this
        # => [{"Subtests"=>
        #  [{"Subtests"=>
        #     [{"Subtests"=>
        #        [{"TestIdentifier"=>"Unit/testExample()",
        #          "TestName"=>"testExample()",
        #          "TestObjectClass"=>"IDESchemeActionTestSummary",
        #          "TestStatus"=>"Success",
        #          "TestSummaryGUID"=>"4A24BFED-03E6-4FBE-BC5E-2D80023C06B4"},
        #         {"FailureSummaries"=>
        #           [{"FileName"=>"/Users/krausefx/Developer/themoji/Unit/Unit.swift",
        #             "LineNumber"=>34,
        #             "Message"=>"XCTAssertTrue failed - ",
        #             "PerformanceFailure"=>false}],
        #          "TestIdentifier"=>"Unit/testExample2()",

        tests = []
        data.each do |current_hash|
          if current_hash["Subtests"]
            tests += unfold_tests(current_hash["Subtests"])
          end
          if current_hash["TestStatus"]
            tests << current_hash
          end
        end
        return tests
      end

      self.data = self.raw_json["TestableSummaries"].collect do |testable_summary|
        {
          project_path: testable_summary["ProjectPath"],
          target_name: testable_summary["TargetName"],
          test_name: testable_summary["TestName"],
          tests: unfold_tests(testable_summary["Tests"]).collect do |current_test|
            current_row = {
              identifier: current_test["TestIdentifier"],
              name: current_test["TestName"],
              object_class: current_test["TestObjectClass"],
              status: current_test["TestStatus"],
              guid: current_test["TestSummaryGUID"]
            }
            if current_test["FailureSummaries"]
              current_row[:failures] = current_test["FailureSummaries"].collect do |current_failure|
                {
                  file_name: current_failure['FileName'],
                  line_number: current_failure['LineNumber'],
                  message: current_failure['Message'],
                  performance_failure: current_failure['PerformanceFailure']
                }
              end
            end
            current_row
          end
        }
      end
    end
  end
end

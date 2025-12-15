note
	description: "Test application for simple_pkg"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run all tests.
		do
			print ("Running simple_pkg tests...%N%N")
			passed := 0
			failed := 0

			run_lib_tests

			print ("%N==================================%N")
			print ("Total: " + (passed + failed).out + " tests%N")
			print ("Passed: " + passed.out + "%N")
			print ("Failed: " + failed.out + "%N")
			if failed > 0 then
				print ("FAILED!%N")
			else
				print ("ALL TESTS PASSED!%N")
			end
		end

feature -- Test Execution

	run_lib_tests
			-- Run main library tests.
		local
			l_tests: LIB_TESTS
		do
			print ("=== LIB_TESTS ===%N")
			create l_tests

			-- ECF Metadata Tests
			run_test (agent l_tests.test_ecf_metadata_parse, "test_ecf_metadata_parse")
			run_test (agent l_tests.test_ecf_metadata_with_package_json, "test_ecf_metadata_with_package_json")
			run_test (agent l_tests.test_ecf_metadata_short_name, "test_ecf_metadata_short_name")

			-- PKG_INFO Tests
			run_test (agent l_tests.test_pkg_info_creation, "test_pkg_info_creation")
			run_test (agent l_tests.test_pkg_info_apply_metadata, "test_pkg_info_apply_metadata")

			-- Search Result Tests
			run_test (agent l_tests.test_search_result_creation, "test_search_result_creation")

			-- PKG_SEARCH Tests
			run_test (agent l_tests.test_pkg_search_make, "test_pkg_search_make")
			run_test (agent l_tests.test_pkg_search_build_index, "test_pkg_search_build_index")
			run_test (agent l_tests.test_pkg_search_fuzzy, "test_pkg_search_fuzzy")
			run_test (agent l_tests.test_pkg_search_browse_category, "test_pkg_search_browse_category")
			run_test (agent l_tests.test_pkg_search_list_categories, "test_pkg_search_list_categories")

			-- PKG_CONFIG Tests
			run_test (agent l_tests.test_pkg_config_defaults, "test_pkg_config_defaults")
			run_test (agent l_tests.test_pkg_config_normalize_name, "test_pkg_config_normalize_name")

			-- ARRAYED_LIST.has Gotcha Tests (CRITICAL!)
			run_test (agent l_tests.test_arrayed_list_has_gotcha, "test_arrayed_list_has_gotcha")
			run_test (agent l_tests.test_install_all_keyword_detection, "test_install_all_keyword_detection")
			run_test (agent l_tests.test_install_dry_run_detection, "test_install_dry_run_detection")

			print ("%N")
		end

feature {NONE} -- Implementation

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test safely.
		local
			l_failed: BOOLEAN
		do
			if not l_failed then
				a_test.call (Void)
				print ("  [PASS] " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			l_failed := True
			print ("  [FAIL] " + a_name + "%N")
			failed := failed + 1
			retry
		end

	passed: INTEGER
			-- Number of passed tests

	failed: INTEGER
			-- Number of failed tests

end

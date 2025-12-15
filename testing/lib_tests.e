note
	description: "Test collection for simple_pkg"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- ECF Metadata Tests

	test_ecf_metadata_parse
			-- Test parsing ECF content for name, description, dependencies.
		local
			l_meta: ECF_METADATA
			l_content: STRING
		do
			l_content := "<?xml version=%"1.0%" encoding=%"ISO-8859-1%"?>"
			l_content.append ("<system name=%"simple_test%" uuid=%"12345678-1234-1234-1234-123456789012%" library_target=%"simple_test%">")
			l_content.append ("<description>Test package</description>")
			l_content.append ("<target name=%"simple_test%">")
			l_content.append ("<library name=%"simple_json%" location=%"$SIMPLE_JSON/simple_json.ecf%"/>")
			l_content.append ("<library name=%"simple_http%" location=%"$SIMPLE_HTTP/simple_http.ecf%"/>")
			l_content.append ("<library name=%"base%" location=%"$ISE_LIBRARY/library/base/base.ecf%"/>")
			l_content.append ("</target>")
			l_content.append ("</system>")

			create l_meta.make_from_content (l_content)

			assert_true ("is_valid", l_meta.is_valid)
			assert_strings_equal ("name", "simple_test", l_meta.name)
			assert_integers_equal ("dependency_count", 2, l_meta.dependencies.count)
			assert_true ("has_simple_json", l_meta.has_dependency ("simple_json"))
			assert_true ("has_simple_http", l_meta.has_dependency ("simple_http"))
			assert_false ("no_base", l_meta.has_dependency ("base"))
		end

	test_ecf_metadata_with_package_json
			-- Test parsing ECF with separate package.json metadata.
		local
			l_meta: ECF_METADATA
			l_ecf_content: STRING
			l_pkg_content: STRING
		do
			-- ECF provides name, description, dependencies
			l_ecf_content := "<?xml version=%"1.0%" encoding=%"ISO-8859-1%"?>"
			l_ecf_content.append ("<system name=%"simple_json%" uuid=%"12345678%">")
			l_ecf_content.append ("<description>JSON parser</description>")
			l_ecf_content.append ("<target name=%"simple_json%"/>")
			l_ecf_content.append ("</system>")

			-- package.json provides version, author, keywords, category, license
			l_pkg_content := "{"
			l_pkg_content.append ("%"name%":%"simple_json%",")
			l_pkg_content.append ("%"version%":%"2.0.1%",")
			l_pkg_content.append ("%"author%":%"Larry Rix%",")
			l_pkg_content.append ("%"license%":%"MIT%",")
			l_pkg_content.append ("%"category%":%"data-formats%",")
			l_pkg_content.append ("%"keywords%":[%"json%",%"parser%",%"schema%",%"rfc8259%"]")
			l_pkg_content.append ("}")

			create l_meta.make_from_content (l_ecf_content)
			l_meta.apply_package_json_content (l_pkg_content)

			assert_true ("is_valid", l_meta.is_valid)
			assert_strings_equal ("version", "2.0.1", l_meta.version)
			assert_strings_equal ("author", "Larry Rix", l_meta.author)
			assert_strings_equal ("category", "data-formats", l_meta.category)
			assert_strings_equal ("license", "MIT", l_meta.license)
			assert_integers_equal ("keyword_count", 4, l_meta.keywords.count)
			assert_true ("has_json", l_meta.has_keyword ("json"))
			assert_true ("has_parser", l_meta.has_keyword ("parser"))
		end

	test_ecf_metadata_short_name
			-- Test short name extraction.
		local
			l_meta: ECF_METADATA
		do
			create l_meta.make ("simple_json")
			assert_strings_equal ("short_name", "json", l_meta.short_name)

			create l_meta.make ("simple_http")
			assert_strings_equal ("short_name_http", "http", l_meta.short_name)
		end

feature -- PKG_INFO Tests

	test_pkg_info_creation
			-- Test PKG_INFO creation.
		local
			l_pkg: PKG_INFO
		do
			create l_pkg.make ("simple_test")
			assert_strings_equal ("name", "simple_test", l_pkg.name)
			assert_strings_equal ("short_name", "test", l_pkg.short_name)
			assert_strings_equal ("env_var", "SIMPLE_TEST", l_pkg.env_var_name)
		end

	test_pkg_info_apply_metadata
			-- Test applying ECF metadata to PKG_INFO.
		local
			l_pkg: PKG_INFO
			l_meta: ECF_METADATA
			l_content: STRING
		do
			l_content := "[
<?xml version="1.0" encoding="ISO-8859-1"?>
<system name="simple_test" uuid="12345678-1234-1234-1234-123456789012">
  <description>Test package</description>
  <version major="1" minor="5" release="0"/>
  <note>
    <package>
      <author>Test Author</author>
      <keywords>test, unit, validation</keywords>
      <category>testing</category>
    </package>
  </note>
  <target name="simple_test">
    <library name="simple_json" location="$SIMPLE_JSON/simple_json.ecf"/>
  </target>
</system>
]"
			create l_meta.make_from_content (l_content)
			create l_pkg.make ("simple_test")
			l_pkg.apply_ecf_metadata (l_meta)

			assert_strings_equal ("version", "1.5.0", l_pkg.version)
			assert_strings_equal ("author", "Test Author", l_pkg.author)
			assert_strings_equal ("category", "testing", l_pkg.category)
			assert_integers_equal ("dep_count", 1, l_pkg.dependencies.count)
		end

feature -- Search Result Tests

	test_search_result_creation
			-- Test SEARCH_RESULT creation.
		local
			l_result: SEARCH_RESULT
		do
			create l_result.make ("simple_json", "JSON parser", "fast <b>json</b> parsing", -15.5)
			assert_strings_equal ("name", "simple_json", l_result.name)
			assert_strings_equal ("short_name", "json", l_result.short_name)
			assert_true ("relevance > 0", l_result.relevance_percent > 0)
		end

feature -- PKG_SEARCH Tests

	test_pkg_search_make
			-- Test PKG_SEARCH creation.
		local
			l_search: PKG_SEARCH
		do
			create l_search.make
			assert_true ("database_open", l_search.database.is_open)
			assert_false ("index_not_built", l_search.is_index_built)
			l_search.close
		end

	test_pkg_search_build_index
			-- Test building FTS5 search index.
		local
			l_search: PKG_SEARCH
			l_packages: ARRAYED_LIST [PKG_INFO]
			l_pkg: PKG_INFO
		do
			create l_search.make
			create l_packages.make (3)

			create l_pkg.make ("simple_json")
			l_pkg.set_description ("High-performance JSON parser")
			l_pkg.set_category ("data-formats")
			l_packages.extend (l_pkg)

			create l_pkg.make ("simple_xml")
			l_pkg.set_description ("XML parser and generator")
			l_pkg.set_category ("data-formats")
			l_packages.extend (l_pkg)

			create l_pkg.make ("simple_http")
			l_pkg.set_description ("HTTP client library")
			l_pkg.set_category ("networking")
			l_packages.extend (l_pkg)

			l_search.build_index (l_packages)

			assert_true ("index_built", l_search.is_index_built)
			assert_integers_equal ("package_count", 3, l_search.package_count)
			l_search.close
		end

	test_pkg_search_fuzzy
			-- Test fuzzy search.
		local
			l_search: PKG_SEARCH
			l_packages: ARRAYED_LIST [PKG_INFO]
			l_results: ARRAYED_LIST [SEARCH_RESULT]
			l_pkg: PKG_INFO
		do
			create l_search.make
			create l_packages.make (3)

			create l_pkg.make ("simple_json")
			l_pkg.set_description ("High-performance JSON parser with Schema support")
			l_pkg.set_category ("data-formats")
			l_packages.extend (l_pkg)

			create l_pkg.make ("simple_yaml")
			l_pkg.set_description ("YAML parser and emitter")
			l_pkg.set_category ("data-formats")
			l_packages.extend (l_pkg)

			create l_pkg.make ("simple_http")
			l_pkg.set_description ("HTTP client library")
			l_pkg.set_category ("networking")
			l_packages.extend (l_pkg)

			l_search.build_index (l_packages)

			-- Search for "parser"
			l_results := l_search.search ("parser")
			assert_true ("found_results", l_results.count >= 2)
			-- JSON and YAML both have "parser" in description
			l_search.close
		end

	test_pkg_search_browse_category
			-- Test category browsing.
		local
			l_search: PKG_SEARCH
			l_packages: ARRAYED_LIST [PKG_INFO]
			l_results: ARRAYED_LIST [PKG_INFO]
			l_pkg: PKG_INFO
		do
			create l_search.make
			create l_packages.make (3)

			create l_pkg.make ("simple_json")
			l_pkg.set_category ("data-formats")
			l_packages.extend (l_pkg)

			create l_pkg.make ("simple_xml")
			l_pkg.set_category ("data-formats")
			l_packages.extend (l_pkg)

			create l_pkg.make ("simple_http")
			l_pkg.set_category ("networking")
			l_packages.extend (l_pkg)

			l_search.build_index (l_packages)

			l_results := l_search.browse_category ("data-formats")
			assert_integers_equal ("data_formats_count", 2, l_results.count)

			l_results := l_search.browse_category ("networking")
			assert_integers_equal ("networking_count", 1, l_results.count)
			l_search.close
		end

	test_pkg_search_list_categories
			-- Test listing categories.
		local
			l_search: PKG_SEARCH
			l_packages: ARRAYED_LIST [PKG_INFO]
			l_categories: ARRAYED_LIST [STRING]
			l_pkg: PKG_INFO
		do
			create l_search.make
			create l_packages.make (3)

			create l_pkg.make ("simple_json")
			l_pkg.set_category ("data-formats")
			l_packages.extend (l_pkg)

			create l_pkg.make ("simple_http")
			l_pkg.set_category ("networking")
			l_packages.extend (l_pkg)

			create l_pkg.make ("simple_testing")
			l_pkg.set_category ("testing")
			l_packages.extend (l_pkg)

			l_search.build_index (l_packages)

			l_categories := l_search.list_categories
			assert_integers_equal ("category_count", 3, l_categories.count)
			assert_true ("has_data_formats", list_has_string (l_categories, "data-formats"))
			assert_true ("has_networking", list_has_string (l_categories, "networking"))
			assert_true ("has_testing", list_has_string (l_categories, "testing"))
			l_search.close
		end

feature -- ARRAYED_LIST.has Gotcha Tests

	test_arrayed_list_has_gotcha
			-- CRITICAL TEST: Demonstrates the ARRAYED_LIST.has gotcha.
			-- ARRAYED_LIST.has uses object IDENTITY, not string EQUALITY!
			-- This test MUST pass to confirm we understand the problem.
		local
			l_list: ARRAYED_LIST [STRING]
		do
			create l_list.make (3)
			l_list.extend ("all")
			l_list.extend ("--test")
			l_list.extend ("json")

			-- THIS IS THE BUG: ARRAYED_LIST.has creates a new string object
			-- and compares by identity, which WILL FAIL!
			-- The following assertion demonstrates the bug - it fails because
			-- "all" (new string) is not identical to the "all" in the list.
			-- assert_true ("has_all_BROKEN", l_list.has ("all"))  -- WOULD FAIL!

			-- CORRECT WAY: Use string content comparison
			assert_true ("has_all_CORRECT", list_has_string (l_list, "all"))
			assert_true ("has_test_CORRECT", list_has_string (l_list, "--test"))
			assert_true ("has_json_CORRECT", list_has_string (l_list, "json"))
			assert_false ("no_xml", list_has_string (l_list, "xml"))
		end

	test_install_all_keyword_detection
			-- Test that "all" keyword is properly detected in command args.
			-- This is the actual bug that caused "simple install all" to fail.
		local
			l_args: ARRAYED_LIST [STRING]
			l_found_all: BOOLEAN
		do
			-- Simulate command line: simple install all
			create l_args.make (1)
			l_args.extend ("all")

			-- Wrong way (object identity) - would fail in real code
			-- l_found_all := l_args.has ("all")

			-- Right way (string content comparison)
			l_found_all := list_has_string (l_args, "all")
			assert_true ("found_all_keyword", l_found_all)
		end

	test_install_dry_run_detection
			-- Test that --dry-run flag is properly detected.
		local
			l_args: ARRAYED_LIST [STRING]
		do
			-- Simulate: simple install json --dry-run
			create l_args.make (2)
			l_args.extend ("json")
			l_args.extend ("--dry-run")

			assert_true ("found_dry_run", list_has_string (l_args, "--dry-run"))
			assert_false ("no_test_flag", list_has_string (l_args, "--test"))
		end

feature -- PKG_CONFIG Tests

	test_pkg_config_defaults
			-- Test PKG_CONFIG default values.
		local
			l_config: PKG_CONFIG
		do
			create l_config.make
			assert_strings_equal ("github_org", "simple-eiffel", l_config.github_org)
			assert_strings_equal ("github_api_base", "https://api.github.com", l_config.github_api_base)
			assert_strings_equal ("github_raw_base", "https://raw.githubusercontent.com", l_config.github_raw_base)
		end

	test_pkg_config_normalize_name
			-- Test package name normalization.
		local
			l_config: PKG_CONFIG
		do
			create l_config.make
			assert_strings_equal ("json_to_simple_json", "simple_json", l_config.normalize_package_name ("json"))
			assert_strings_equal ("simple_json_unchanged", "simple_json", l_config.normalize_package_name ("simple_json"))
			assert_strings_equal ("http_to_simple_http", "simple_http", l_config.normalize_package_name ("http"))
		end

feature {NONE} -- Implementation

	list_has_string (a_list: ARRAYED_LIST [STRING]; a_value: STRING): BOOLEAN
			-- Does `a_list` contain string matching `a_value`?
			-- Uses string content comparison, not object identity.
		do
			across a_list as item loop
				if item.same_string (a_value) then
					Result := True
				end
			end
		end

end

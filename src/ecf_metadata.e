note
	description: "[
		ECF + package.json metadata parser.

		Extracts package information from two sources:

		ECF provides:
		- name, uuid from system element attributes
		- description from <description> element
		- dependencies from <library location="$SIMPLE_*"> elements

		package.json provides:
		- version, author, keywords, category, license

		Usage:
			create metadata.make_from_file ("/d/prod/simple_json/simple_json.ecf")
			metadata.apply_package_json ("/d/prod/simple_json/package.json")
			if metadata.is_valid then
				print (metadata.name)
				print (metadata.category)
				across metadata.dependencies as dep loop
					print (dep)
				end
			end
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	ECF_METADATA

create
	make,
	make_from_content,
	make_from_file

feature {NONE} -- Initialization

	make (a_name: STRING)
			-- Create empty metadata with name.
		require
			name_not_empty: not a_name.is_empty
		do
			name := a_name
			create description.make_empty
			create version.make_empty
			create author.make_empty
			create keywords.make (5)
			create category.make_empty
			create license.make_empty
			create dependencies.make (10)
			create uuid.make_empty
			is_valid := True
			create error_message.make_empty
		ensure
			name_set: name.same_string (a_name)
			is_valid: is_valid
		end

	make_from_content (a_content: STRING)
			-- Parse ECF content and extract metadata.
		require
			content_not_empty: not a_content.is_empty
		do
			create name.make_empty
			create description.make_empty
			create version.make_empty
			create author.make_empty
			create keywords.make (5)
			create category.make_empty
			create license.make_empty
			create dependencies.make (10)
			create uuid.make_empty
			is_valid := False
			create error_message.make_empty

			parse_ecf (a_content)
		end

	make_from_file (a_path: STRING)
			-- Parse ECF file and extract metadata.
		require
			path_not_empty: not a_path.is_empty
		local
			l_file: PLAIN_TEXT_FILE
			l_content: STRING
		do
			create name.make_empty
			create description.make_empty
			create version.make_empty
			create author.make_empty
			create keywords.make (5)
			create category.make_empty
			create license.make_empty
			create dependencies.make (10)
			create uuid.make_empty
			is_valid := False
			create error_message.make_empty

			create l_file.make_with_name (a_path)
			if l_file.exists and then l_file.is_readable then
				l_file.open_read
				l_file.read_stream (l_file.count)
				l_content := l_file.last_string
				l_file.close
				parse_ecf (l_content)
			else
				error_message := "File not found or not readable: " + a_path
			end
		end

feature -- Access

	name: STRING
			-- Package name (e.g., "simple_json")

	uuid: STRING
			-- Package UUID from ECF

	description: STRING
			-- Human-readable description

	version: STRING
			-- Semantic version string (e.g., "1.2.0")

	version_major: INTEGER
			-- Major version number

	version_minor: INTEGER
			-- Minor version number

	version_release: INTEGER
			-- Release (patch) version number

	author: STRING
			-- Package author

	keywords: ARRAYED_LIST [STRING]
			-- Search keywords

	category: STRING
			-- Package category

	license: STRING
			-- License type (e.g., "MIT")

	dependencies: ARRAYED_LIST [STRING]
			-- List of simple_* dependencies (names only, not paths)

feature -- Status

	is_valid: BOOLEAN
			-- Was parsing successful?

	error_message: STRING
			-- Error description if not valid

	has_version: BOOLEAN
			-- Does ECF include version info?
		do
			Result := not version.is_empty
		end

	has_dependencies: BOOLEAN
			-- Does package have simple_* dependencies?
		do
			Result := not dependencies.is_empty
		end

	has_dependency (a_name: STRING): BOOLEAN
			-- Does dependencies list contain `a_name`?
			-- Uses string content comparison, not object identity.
		require
			name_not_void: a_name /= Void
		do
			across dependencies as dep loop
				if dep.same_string (a_name) then
					Result := True
				end
			end
		end

	has_keyword (a_keyword: STRING): BOOLEAN
			-- Does keywords list contain `a_keyword`?
			-- Uses string content comparison, not object identity.
		require
			keyword_not_void: a_keyword /= Void
		do
			across keywords as kw loop
				if kw.same_string (a_keyword) then
					Result := True
				end
			end
		end

feature -- Computed

	short_name: STRING
			-- Name without "simple_" prefix
		do
			if name.starts_with ("simple_") then
				Result := name.substring (8, name.count)
			else
				Result := name
			end
		ensure
			result_attached: Result /= Void
		end

	env_var_name: STRING
			-- Environment variable name (SIMPLE_JSON)
		do
			Result := name.as_upper
		ensure
			result_attached: Result /= Void
			result_upper: Result.same_string (Result.as_upper)
		end

	keywords_string: STRING
			-- Keywords as comma-separated string
		do
			create Result.make (100)
			across keywords as kw loop
				if not Result.is_empty then
					Result.append (", ")
				end
				Result.append (kw)
			end
		ensure
			result_attached: Result /= Void
		end

feature -- Package JSON

	apply_package_json (a_path: STRING)
			-- Load additional metadata from package.json file.
		require
			path_not_empty: not a_path.is_empty
		local
			l_file: PLAIN_TEXT_FILE
			l_content: STRING
			l_json: SIMPLE_JSON
		do
			create l_file.make_with_name (a_path)
			if l_file.exists and then l_file.is_readable then
				l_file.open_read
				l_file.read_stream (l_file.count)
				l_content := l_file.last_string
				l_file.close

				create l_json
				if attached l_json.parse (l_content) as l_value and then l_value.is_object then
					apply_package_object (l_value.as_object)
				end
			end
		end

	apply_package_json_content (a_content: STRING)
			-- Load additional metadata from package.json content string.
		require
			content_not_empty: not a_content.is_empty
		local
			l_json: SIMPLE_JSON
		do
			create l_json
			if attached l_json.parse (a_content) as l_value and then l_value.is_object then
				apply_package_object (l_value.as_object)
			end
		end

feature {NONE} -- Package JSON Implementation

	apply_package_object (a_pkg: SIMPLE_JSON_OBJECT)
			-- Apply metadata from parsed package.json object.
		local
			i: INTEGER
			l_kw: SIMPLE_JSON_VALUE
		do
			-- Version
			if attached a_pkg.string_item ("version") as v then
				version := v.to_string_8
				parse_version_string (version)
			end

			-- Author
			if attached a_pkg.string_item ("author") as a then
				author := a.to_string_8
			end

			-- License
			if attached a_pkg.string_item ("license") as l then
				license := l.to_string_8
			end

			-- Category
			if attached a_pkg.string_item ("category") as c then
				category := c.to_string_8
			end

			-- Keywords (array of strings)
			if attached a_pkg.array_item ("keywords") as kw_array then
				keywords.wipe_out
				from i := 1 until i > kw_array.count loop
					l_kw := kw_array.item (i)
					if l_kw.is_string then
						keywords.extend (l_kw.as_string_32.to_string_8)
					end
					i := i + 1
				end
			end

			-- Description (if not already set from ECF)
			if description.is_empty then
				if attached a_pkg.string_item ("description") as d then
					description := d.to_string_8
				end
			end
		end

	parse_version_string (a_version: STRING)
			-- Parse "1.2.3" into major/minor/release components.
		local
			l_parts: LIST [STRING]
		do
			l_parts := a_version.split ('.')
			if l_parts.count >= 1 then
				version_major := l_parts.i_th (1).to_integer
			end
			if l_parts.count >= 2 then
				version_minor := l_parts.i_th (2).to_integer
			end
			if l_parts.count >= 3 then
				version_release := l_parts.i_th (3).to_integer
			end
		end

feature -- Output

	to_string: STRING
			-- Human-readable representation
		do
			create Result.make (500)
			Result.append ("Package: " + name + "%N")
			if not uuid.is_empty then
				Result.append ("  UUID: " + uuid + "%N")
			end
			if not description.is_empty then
				Result.append ("  Description: " + description + "%N")
			end
			if has_version then
				Result.append ("  Version: " + version + "%N")
			end
			if not author.is_empty then
				Result.append ("  Author: " + author + "%N")
			end
			if not category.is_empty then
				Result.append ("  Category: " + category + "%N")
			end
			if not keywords.is_empty then
				Result.append ("  Keywords: " + keywords_string + "%N")
			end
			if not license.is_empty then
				Result.append ("  License: " + license + "%N")
			end
			if has_dependencies then
				Result.append ("  Dependencies: ")
				across dependencies as dep loop
					if @dep.cursor_index > 1 then
						Result.append (", ")
					end
					Result.append (dep)
				end
				Result.append ("%N")
			end
		ensure
			result_attached: Result /= Void
		end

feature {NONE} -- Implementation

	parse_ecf (a_content: STRING)
			-- Parse ECF XML content.
		local
			l_xml: SIMPLE_XML
			l_doc: SIMPLE_XML_DOCUMENT
			l_root: detachable SIMPLE_XML_ELEMENT
		do
			create l_xml.make
			l_doc := l_xml.parse (a_content)

			if l_doc.is_valid then
				l_root := l_doc.root
				if attached l_root as root then
					parse_system_element (root)
					is_valid := not name.is_empty
				else
					error_message := "No root element found"
				end
			else
				error_message := "XML parse error: " + l_doc.error_message
			end
		end

	parse_system_element (a_root: SIMPLE_XML_ELEMENT)
			-- Parse <system> root element.
		do
			-- Extract name and uuid from attributes
			if attached a_root.attr ("name") as n then
				name := n
			end
			if attached a_root.attr ("uuid") as u then
				uuid := u
			end

			-- Extract description
			if attached a_root.element ("description") as desc_elem then
				description := desc_elem.text.twin
				description.left_adjust
				description.right_adjust
			end

			-- Extract version
			parse_version_element (a_root)

			-- Extract package metadata from note section
			parse_note_element (a_root)

			-- Extract dependencies from targets
			parse_target_dependencies (a_root)
		end

	parse_version_element (a_root: SIMPLE_XML_ELEMENT)
			-- Parse <version> element if present.
		do
			if attached a_root.element ("version") as ver_elem then
				if attached ver_elem.attr ("major") as maj then
					version_major := maj.to_integer
				end
				if attached ver_elem.attr ("minor") as min then
					version_minor := min.to_integer
				end
				if attached ver_elem.attr ("release") as rel then
					version_release := rel.to_integer
				end

				-- Build version string
				version := version_major.out + "." + version_minor.out + "." + version_release.out

				-- Extract author from version element if present
				if attached ver_elem.attr ("company") as comp and then author.is_empty then
					author := comp
				end
			end
		end

	parse_note_element (a_root: SIMPLE_XML_ELEMENT)
			-- Parse <note><package>...</package></note> metadata section.
		do
			if attached a_root.element ("note") as note_elem then
				if attached note_elem.element ("package") as pkg_elem then
					-- Author
					if attached pkg_elem.element ("author") as auth_elem then
						author := auth_elem.text.twin
						author.left_adjust
						author.right_adjust
					end

					-- Keywords
					if attached pkg_elem.element ("keywords") as kw_elem then
						parse_keywords (kw_elem.text)
					end

					-- Category
					if attached pkg_elem.element ("category") as cat_elem then
						category := cat_elem.text.twin
						category.left_adjust
						category.right_adjust
					end

					-- License
					if attached pkg_elem.element ("license") as lic_elem then
						license := lic_elem.text.twin
						license.left_adjust
						license.right_adjust
					end
				end
			end
		end

	parse_keywords (a_keywords_text: STRING)
			-- Parse comma-separated keywords.
		local
			l_parts: LIST [STRING]
			l_kw: STRING
		do
			l_parts := a_keywords_text.split (',')
			across l_parts as part loop
				l_kw := part.twin
				l_kw.left_adjust
				l_kw.right_adjust
				if not l_kw.is_empty then
					keywords.extend (l_kw)
				end
			end
		end

	parse_target_dependencies (a_root: SIMPLE_XML_ELEMENT)
			-- Parse <library> elements from all targets, extract $SIMPLE_* dependencies.
		local
			l_targets: ARRAYED_LIST [SIMPLE_XML_ELEMENT]
			l_libraries: ARRAYED_LIST [SIMPLE_XML_ELEMENT]
			l_location: detachable STRING
			l_dep_name: STRING
		do
			l_targets := a_root.elements ("target")
			across l_targets as target loop
				l_libraries := target.elements ("library")
				across l_libraries as lib loop
					l_location := lib.attr ("location")
					if attached l_location as loc then
						-- Check if it's a simple_* dependency
						if loc.has_substring ("$SIMPLE_") then
							l_dep_name := extract_dependency_name (loc)
							if not l_dep_name.is_empty and then not has_dependency (l_dep_name) then
								dependencies.extend (l_dep_name)
							end
						end
					end
				end
			end
		end

	extract_dependency_name (a_location: STRING): STRING
			-- Extract package name from location like "$SIMPLE_JSON/simple_json.ecf"
		local
			l_start, l_end: INTEGER
		do
			create Result.make_empty

			-- Find $SIMPLE_ prefix
			l_start := a_location.substring_index ("$SIMPLE_", 1)
			if l_start > 0 then
				l_start := l_start + 1  -- Skip the $
				-- Find end (next / or \ or end of string)
				l_end := l_start
				from
				until
					l_end > a_location.count or else
					a_location.item (l_end) = '/' or else
					a_location.item (l_end) = '\'
				loop
					l_end := l_end + 1
				end

				-- Extract the name and convert to lowercase with simple_ prefix
				Result := a_location.substring (l_start, l_end - 1).as_lower
			end
		ensure
			result_attached: Result /= Void
		end

invariant
	name_attached: name /= Void
	description_attached: description /= Void
	version_attached: version /= Void
	author_attached: author /= Void
	keywords_attached: keywords /= Void
	category_attached: category /= Void
	license_attached: license /= Void
	dependencies_attached: dependencies /= Void
	error_message_attached: error_message /= Void

end

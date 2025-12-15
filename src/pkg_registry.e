note
	description: "[
		GitHub-based package registry.

		Fetches package information from the simple-eiffel GitHub organization.
		Uses GitHub API to:
		- List all repositories (packages)
		- Get repository metadata
		- Fetch ECF files for dependency information
		- Get available versions (git tags)

		No authentication required for public repositories.
		Rate limit: 60 requests/hour unauthenticated.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	PKG_REGISTRY

create
	make

feature {NONE} -- Initialization

	make (a_config: PKG_CONFIG)
			-- Initialize registry with configuration.
		require
			config_not_void: a_config /= Void
		do
			config := a_config
			create http.make
			create package_cache.make (50)
			create last_errors.make (10)
		ensure
			config_set: config = a_config
		end

feature -- Access

	config: PKG_CONFIG
			-- Configuration

	http: SIMPLE_HTTP
			-- HTTP client for API calls

	package_cache: HASH_TABLE [PKG_INFO, STRING]
			-- Cache of fetched package info

	last_errors: ARRAYED_LIST [STRING]
			-- Errors from last operation

	has_error: BOOLEAN
			-- Did last operation have errors?
		do
			Result := not last_errors.is_empty
		end

feature -- Package Fetching

	fetch_package (a_name: STRING): detachable PKG_INFO
			-- Fetch package info by name.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_url: STRING
			l_response: detachable STRING
			l_json: SIMPLE_JSON
		do
			last_errors.wipe_out
			l_normalized := config.normalize_package_name (a_name)

			-- Check cache first
			if attached package_cache.item (l_normalized) as cached then
				Result := cached
			else
				-- Fetch from GitHub API
				l_url := config.github_api_base + "/repos/" + config.github_org + "/" + l_normalized

				l_response := http_get (l_url)

				if attached l_response as resp then
					create l_json
					if attached l_json.parse (resp) as l_parsed then
						if l_parsed.is_object and then not l_parsed.as_object.has_key ("message") then
							create Result.make_from_json (l_parsed)
							-- Fetch dependencies from ECF
							fetch_dependencies (Result)
							-- Cache it
							package_cache.force (Result, l_normalized)
						else
							if l_parsed.is_object and then attached l_parsed.as_object.string_item ("message") as msg then
								last_errors.extend ("GitHub API: " + msg.to_string_8)
							end
						end
					end
				end
			end
		end

	fetch_all_packages: ARRAYED_LIST [PKG_INFO]
			-- Fetch all packages from the registry.
		local
			l_url: STRING
			l_response: detachable STRING
			l_json: SIMPLE_JSON
			l_array: detachable SIMPLE_JSON_ARRAY
			i: INTEGER
		do
			create Result.make (70)
			last_errors.wipe_out

			-- Fetch organization repos (paginated, up to 100 per page)
			l_url := config.github_api_base + "/orgs/" + config.github_org + "/repos?per_page=100&type=public"

			l_response := http_get (l_url)

			if attached l_response as resp then
				create l_json
				if attached l_json.parse (resp) as l_parsed and then l_parsed.is_array then
					l_array := l_parsed.as_array
					if attached l_array as arr then
						from i := 1 until i > arr.count loop
							if attached arr.item (i) as item_json and then item_json.is_object then
								if attached item_json.as_object.string_item ("name") as repo_name then
									-- Only include simple_* repositories
									if repo_name.starts_with ("simple_") and then
									   not repo_name.same_string_general ("simple-eiffel.github.io") then
										Result.extend (create {PKG_INFO}.make_from_json (item_json))
									end
								end
							end
							i := i + 1
						end
					end
				else
					last_errors.extend ("Failed to parse repository list as JSON array")
				end
			else
				last_errors.extend ("HTTP request failed - no response from " + l_url)
			end
		ensure
			result_attached: Result /= Void
		end

	search_packages (a_query: STRING): ARRAYED_LIST [PKG_INFO]
			-- Search for packages matching `a_query`.
		require
			query_not_empty: not a_query.is_empty
		local
			l_all: ARRAYED_LIST [PKG_INFO]
			l_query_lower: STRING
		do
			create Result.make (20)
			l_query_lower := a_query.as_lower
			l_all := fetch_all_packages

			across l_all as pkg loop
				if pkg.name.as_lower.has_substring (l_query_lower) or else
				   pkg.description.as_lower.has_substring (l_query_lower) then
					Result.extend (pkg)
				end
			end
		ensure
			result_attached: Result /= Void
		end

feature -- Version Management

	fetch_versions (a_name: STRING): ARRAYED_LIST [STRING]
			-- Fetch available versions (git tags) for package.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_url: STRING
			l_response: detachable STRING
			l_json: SIMPLE_JSON
			l_array: detachable SIMPLE_JSON_ARRAY
			i: INTEGER
		do
			create Result.make (10)
			l_normalized := config.normalize_package_name (a_name)

			l_url := config.github_api_base + "/repos/" + config.github_org + "/" + l_normalized + "/tags"

			l_response := http_get (l_url)

			if attached l_response as resp then
				create l_json
				if attached l_json.parse (resp) as l_parsed and then l_parsed.is_array then
					l_array := l_parsed.as_array
					if attached l_array as arr then
						from i := 1 until i > arr.count loop
							if attached arr.item (i) as tag_json and then tag_json.is_object then
								if attached tag_json.as_object.string_item ("name") as tag_name then
									Result.extend (tag_name.to_string_8)
								end
							end
							i := i + 1
						end
					end
				end
			end
		ensure
			result_attached: Result /= Void
		end

	fetch_latest_version (a_name: STRING): STRING
			-- Fetch latest version for package (latest tag or "main").
		require
			name_not_empty: not a_name.is_empty
		local
			l_versions: ARRAYED_LIST [STRING]
		do
			l_versions := fetch_versions (a_name)
			if l_versions.is_empty then
				Result := "main"
			else
				Result := l_versions.first
			end
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- ECF Fetching

	fetch_ecf_content (a_name: STRING): detachable STRING
			-- Fetch ECF file content for package.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_url: STRING
		do
			l_normalized := config.normalize_package_name (a_name)

			-- Try standard ECF location: simple_name/simple_name.ecf
			l_url := config.github_raw_base + "/" + config.github_org + "/" +
			         l_normalized + "/main/" + l_normalized + ".ecf"

			Result := http_get (l_url)

			-- If not found, try without branch
			if Result = Void or else Result.has_substring ("404") then
				l_url := config.github_raw_base + "/" + config.github_org + "/" +
				         l_normalized + "/master/" + l_normalized + ".ecf"
				Result := http_get (l_url)
			end
		end

	fetch_ecf_metadata (a_name: STRING): detachable ECF_METADATA
			-- Fetch and parse ECF metadata for package.
			-- Also applies package.json metadata if available.
		require
			name_not_empty: not a_name.is_empty
		local
			l_ecf_content: detachable STRING
			l_pkg_content: detachable STRING
		do
			l_ecf_content := fetch_ecf_content (a_name)
			if attached l_ecf_content as ecf_xml and then not ecf_xml.has_substring ("404") then
				create Result.make_from_content (ecf_xml)
				if Result.is_valid then
					-- Also fetch and apply package.json metadata
					l_pkg_content := fetch_package_json_content (a_name)
					if attached l_pkg_content as pkg_json and then not pkg_json.has_substring ("404") then
						Result.apply_package_json_content (pkg_json)
					end
				else
					last_errors.extend ("ECF parse error for " + a_name + ": " + Result.error_message)
					Result := Void
				end
			end
		end

	fetch_package_json_content (a_name: STRING): detachable STRING
			-- Fetch raw package.json content for a package.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_url: STRING
		do
			l_normalized := config.normalize_package_name (a_name)

			-- Try main branch first
			l_url := config.github_raw_base + "/" + config.github_org + "/" +
			         l_normalized + "/main/package.json"
			Result := http_get (l_url)

			-- Fallback to master branch
			if Result = Void or else Result.has_substring ("404") then
				l_url := config.github_raw_base + "/" + config.github_org + "/" +
				         l_normalized + "/master/package.json"
				Result := http_get (l_url)
			end
		end

feature {NONE} -- Implementation

	fetch_dependencies (a_package: PKG_INFO)
			-- Fetch and parse dependencies from ECF file using ECF_METADATA.
		require
			package_not_void: a_package /= Void
		local
			l_metadata: detachable ECF_METADATA
		do
			l_metadata := fetch_ecf_metadata (a_package.name)
			if attached l_metadata as meta then
				-- Apply all ECF metadata to the package
				a_package.apply_ecf_metadata (meta)
			end
		end

	http_get (a_url: STRING): detachable STRING
			-- Perform HTTP GET request using curl (ISE NET lib has chunked encoding bug).
		require
			url_not_empty: not a_url.is_empty
		local
			l_proc: SIMPLE_PROCESS
			l_cmd: STRING
		do
			-- Use curl because ISE's NET library doesn't handle chunked transfer encoding
			create l_proc.make
			l_cmd := "curl -s -H %"User-Agent: simple_pkg/1.0%" -H %"Accept: application/vnd.github.v3+json%" %"" + a_url + "%""
			l_proc.execute (l_cmd)

			if l_proc.exit_code = 0 then
				if attached l_proc.last_output as l_out then
					Result := l_out.to_string_8
				end
				if Result = Void or else Result.is_empty then
					last_errors.extend ("Empty response from " + a_url)
				end
			else
				last_errors.extend ("curl failed with exit code " + l_proc.exit_code.out + " for " + a_url)
				if attached l_proc.last_error as l_err and then not l_err.is_empty then
					last_errors.extend (l_err.to_string_8)
				end
			end
		end

invariant
	config_exists: config /= Void
	http_exists: http /= Void
	cache_exists: package_cache /= Void

end

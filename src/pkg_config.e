note
	description: "[
		Package manager configuration.

		Handles:
		- Installation directory (default: ~/simple_eiffel or D:\simple_eiffel)
		- Cache directory for downloads
		- Environment variable management
		- GitHub organization settings
		- User preferences

		Configuration file: ~/.simple/config.json (or %USERPROFILE%\.simple\config.json on Windows)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	PKG_CONFIG

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize configuration with defaults.
		do
			detect_platform
			set_default_paths
			load_config
		ensure
			install_dir_set: not install_directory.is_empty
			cache_dir_set: not cache_directory.is_empty
		end

feature -- Access

	github_org: STRING = "simple-eiffel"
			-- GitHub organization hosting packages

	github_api_base: STRING = "https://api.github.com"
			-- GitHub API base URL

	github_raw_base: STRING = "https://raw.githubusercontent.com"
			-- GitHub raw content base URL

	install_directory: STRING
			-- Directory where packages are installed
		attribute
			create Result.make_empty
		end

	cache_directory: STRING
			-- Directory for downloaded package cache
		attribute
			create Result.make_empty
		end

	config_directory: STRING
			-- Directory for configuration files
		attribute
			create Result.make_empty
		end

	config_file: STRING
			-- Path to configuration file
		do
			Result := config_directory + path_separator.out + "config.json"
		end

	is_windows: BOOLEAN
			-- Are we running on Windows?

	path_separator: CHARACTER
			-- Platform-specific path separator
		do
			if is_windows then
				Result := '\'
			else
				Result := '/'
			end
		end

	env_var_prefix: STRING = "SIMPLE_"
			-- Prefix for environment variables

feature -- Environment Variables

	get_env (a_name: STRING): detachable STRING
			-- Get environment variable value.
		require
			name_not_empty: not a_name.is_empty
		local
			l_env: SIMPLE_ENV
		do
			create l_env
			if attached l_env.get (a_name) as l_val then
				Result := l_val.to_string_8
			end
		end

	set_env (a_name, a_value: STRING)
			-- Set environment variable (persistent on Windows).
		require
			name_not_empty: not a_name.is_empty
			value_not_empty: not a_value.is_empty
		local
			l_env: SIMPLE_ENV
		do
			create l_env
			l_env.set (a_name, a_value)
			if is_windows then
				set_windows_env_persistent (a_name, a_value)
			end
		end

	unset_env (a_name: STRING)
			-- Remove environment variable (persistent on Windows).
		require
			name_not_empty: not a_name.is_empty
		local
			l_env: SIMPLE_ENV
		do
			create l_env
			l_env.unset (a_name)
			if is_windows then
				unset_windows_env_persistent (a_name)
			end
		ensure
			env_removed: get_env (a_name) = Void
		end

	package_env_var_name (a_package: STRING): STRING
			-- Environment variable name for package.
			-- e.g., "json" -> "SIMPLE_JSON"
		require
			package_not_empty: not a_package.is_empty
		do
			Result := env_var_prefix + a_package.as_upper
			-- Handle "simple_" prefix if present
			if a_package.starts_with ("simple_") then
				Result := a_package.as_upper
			end
		ensure
			result_not_empty: not Result.is_empty
			result_uppercase: Result.same_string (Result.as_upper)
		end

	package_path (a_package: STRING): STRING
			-- Full path where package should be installed.
		require
			package_not_empty: not a_package.is_empty
		local
			l_name: STRING
		do
			l_name := normalize_package_name (a_package)
			Result := install_directory + path_separator.out + l_name
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Package Name Normalization

	normalize_package_name (a_name: STRING): STRING
			-- Normalize package name to standard format.
			-- "json" -> "simple_json"
			-- "simple_json" -> "simple_json"
		require
			name_not_empty: not a_name.is_empty
		do
			if a_name.starts_with ("simple_") then
				Result := a_name.as_lower
			else
				Result := "simple_" + a_name.as_lower
			end
		ensure
			result_starts_with_simple: Result.starts_with ("simple_")
			result_lowercase: Result.same_string (Result.as_lower)
		end

	parse_package_spec (a_spec: STRING): TUPLE [name: STRING; version: STRING]
			-- Parse "package@version" or just "package".
			-- Examples:
			--   "json" -> ["simple_json", ""]
			--   "simple_json@1.2.0" -> ["simple_json", "1.2.0"]
			--   "http@^1.0" -> ["simple_http", "^1.0"]
		require
			spec_not_empty: not a_spec.is_empty
		local
			l_at_pos: INTEGER
			l_name, l_ver: STRING
		do
			l_at_pos := a_spec.index_of ('@', 1)
			if l_at_pos > 0 then
				l_name := a_spec.substring (1, l_at_pos - 1)
				l_ver := a_spec.substring (l_at_pos + 1, a_spec.count)
			else
				l_name := a_spec
				create l_ver.make_empty
			end
			Result := [normalize_package_name (l_name), l_ver]
		ensure
			result_attached: Result /= Void
			name_normalized: Result.name.starts_with ("simple_")
		end

feature -- Lock File Factory

	create_for_directory (a_directory: STRING): PKG_LOCK
			-- Create lock file for directory.
		require
			directory_not_empty: not a_directory.is_empty
		local
			l_path: STRING
		do
			l_path := a_directory + path_separator.out + ".simple-lock.json"
			create Result.make
			Result.set_file_path (l_path)
		ensure
			result_attached: Result /= Void
		end

feature -- Persistence

	save_config
			-- Save configuration to file.
		local
			l_json_obj: SIMPLE_JSON_OBJECT
			l_file: SIMPLE_FILE
		do
			create l_json_obj.make
			l_json_obj := l_json_obj.put_string (install_directory, "install_directory")
			l_json_obj := l_json_obj.put_string (cache_directory, "cache_directory")

			create l_file.make (config_file)
			if not l_file.write_all (l_json_obj.to_json_string) then
				-- Silently fail (best effort)
			end
		end

	load_config
			-- Load configuration from file.
		local
			l_file: SIMPLE_FILE
			l_json: SIMPLE_JSON
			l_content: STRING_32
		do
			create l_file.make (config_file)
			if l_file.exists then
				l_content := l_file.content
				if not l_content.is_empty then
					create l_json
					if attached l_json.parse (l_content) as l_parsed and then l_parsed.is_object then
						if attached l_parsed.as_object.string_item ("install_directory") as l_dir then
							install_directory := l_dir.to_string_8
						end
						if attached l_parsed.as_object.string_item ("cache_directory") as l_cache then
							cache_directory := l_cache.to_string_8
						end
					end
				end
			end
		end

feature {NONE} -- Implementation

	detect_platform
			-- Detect current platform.
		local
			l_env: SIMPLE_ENV
		do
			create l_env
			-- Check for Windows-specific env vars
			is_windows := attached l_env.get ("USERPROFILE") or attached l_env.get ("SystemRoot")
		end

	set_default_paths
			-- Set default installation paths.
			-- Install to current directory (like npm/cargo).
			-- Config/cache goes to user home.
		local
			l_env: SIMPLE_ENV
			l_exec_env: EXECUTION_ENVIRONMENT
		do
			create l_env
			create l_exec_env

			-- Install to current working directory
			-- This makes `simple install json` install to ./simple_json
			if attached l_exec_env.current_working_path as l_cwd then
				install_directory := l_cwd.utf_8_name
			else
				install_directory := "."
			end

			-- Config directory in user home
			if is_windows then
				if attached l_env.get ("USERPROFILE") as l_profile then
					config_directory := l_profile + "\.simple"
				else
					config_directory := "C:\.simple"
				end
			else
				if attached l_env.get ("HOME") as l_home then
					config_directory := l_home + "/.simple"
				else
					config_directory := "/etc/simple"
				end
			end

			cache_directory := config_directory + path_separator.out + "cache"
		end

	set_windows_env_persistent (a_name, a_value: STRING)
			-- Set Windows environment variable persistently (user level).
		require
			is_windows: is_windows
			name_not_empty: not a_name.is_empty
			value_not_empty: not a_value.is_empty
		local
			l_process: SIMPLE_PROCESS
			l_cmd: STRING
		do
			-- Use setx to set persistent user environment variable
			l_cmd := "setx " + a_name + " %"" + a_value + "%""
			create l_process.make
			l_process.run (l_cmd)
		end

	unset_windows_env_persistent (a_name: STRING)
			-- Remove Windows environment variable persistently (user level).
		require
			is_windows: is_windows
			name_not_empty: not a_name.is_empty
		local
			l_process: SIMPLE_PROCESS
			l_cmd: STRING
		do
			-- Use reg delete to remove user environment variable from registry
			l_cmd := "reg delete %"HKCU\Environment%" /v " + a_name + " /f"
			create l_process.make
			l_process.run (l_cmd)
		end

invariant
	install_directory_not_empty: not install_directory.is_empty
	cache_directory_not_empty: not cache_directory.is_empty
	config_directory_not_empty: not config_directory.is_empty

end

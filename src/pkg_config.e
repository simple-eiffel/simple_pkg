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
			-- Prefix for environment variables (legacy, kept for package name normalization)

	root_env_var: STRING = "SIMPLE_EIFFEL"
			-- Single root environment variable for all packages.
			-- Points to directory containing all simple_* libraries.

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
			-- Set environment variable (persistent on Windows, macOS and Linux).
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
			else
				set_linux_env_persistent (a_name, a_value)
			end
		end

	unset_env (a_name: STRING)
			-- Remove environment variable (persistent on Windows, macOS and Linux).
		require
			name_not_empty: not a_name.is_empty
		local
			l_env: SIMPLE_ENV
		do
			create l_env
			l_env.unset (a_name)
			if is_windows then
				unset_windows_env_persistent (a_name)
			else
				unset_linux_env_persistent (a_name)
			end
		ensure
			env_removed: get_env (a_name) = Void
		end

	package_env_var_name (a_package: STRING): STRING
			-- Environment variable name for package (LEGACY - no longer used).
			-- All packages now use SIMPLE_EIFFEL root variable.
			-- e.g., "json" -> "SIMPLE_JSON"
		obsolete "Use root_env_var (SIMPLE_EIFFEL) instead of per-package env vars [2025-12]"
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

	simple_eiffel_root: detachable STRING
			-- Get SIMPLE_EIFFEL root directory from environment.
			-- This is the single source of truth for all package locations.
		local
			l_env: SIMPLE_ENV
		do
			create l_env
			if attached l_env.get (root_env_var) as l_val then
				Result := l_val.to_string_8
			end
		end

	is_simple_eiffel_set: BOOLEAN
			-- Is SIMPLE_EIFFEL environment variable set?
		do
			Result := simple_eiffel_root /= Void
		end

	package_path (a_package: STRING): STRING
			-- Full path where package should be installed.
			-- Uses SIMPLE_EIFFEL root if set, otherwise install_directory.
		require
			package_not_empty: not a_package.is_empty
		local
			l_name: STRING
			l_root: detachable STRING
		do
			l_name := normalize_package_name (a_package)
			l_root := simple_eiffel_root
			if attached l_root as root then
				-- Use SIMPLE_EIFFEL root
				Result := root + "/" + l_name
			else
				-- Fallback to install_directory
				Result := install_directory + path_separator.out + l_name
			end
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
					config_directory := l_profile.to_string_8 + "\.simple"
				else
					config_directory := "C:\.simple"
				end
			else
				if attached l_env.get ("HOME") as l_home then
					config_directory := l_home.to_string_8 + "/.simple"
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

	set_linux_env_persistent (a_name, a_value: STRING)
			-- Keep `a_name' = `a_value' for the user's later shells (macOS and Linux): an export
			-- line in the file their login shell reads at start (`profile_path').
		require
			not_windows: not is_windows
			name_not_empty: not a_name.is_empty
			value_not_empty: not a_value.is_empty
		do
			if attached profile_path as l_path then
				write_export (l_path, a_name, a_value)
			end
		end

	unset_linux_env_persistent (a_name: STRING)
			-- No longer keep `a_name' for later shells: its export line leaves `profile_path'.
		require
			not_windows: not is_windows
			name_not_empty: not a_name.is_empty
		do
			if attached profile_path as l_path then
				remove_export (l_path, a_name)
			end
		end

feature -- Shell start-up files (macOS, Linux)

	profile_path: detachable STRING
			-- The start-up file of the user's login shell ($SHELL), in $HOME; Void without $HOME.
		local
			l_env: SIMPLE_ENV
		do
			create l_env
			if attached l_env.get ("HOME") as l_home then
				if attached l_env.get ("SHELL") as l_shell then
					Result := shell_profile_path (l_shell, l_home, {PLATFORM}.is_mac)
				else
					Result := shell_profile_path ("", l_home, {PLATFORM}.is_mac)
				end
			end
		end

	shell_profile_path (a_shell, a_home: READABLE_STRING_GENERAL; a_mac: BOOLEAN): STRING
			-- The file login shell `a_shell' (a path such as /bin/zsh) reads at start, in `a_home':
			-- zsh's ~/.zshrc; bash's ~/.bashrc, or ~/.bash_profile on macOS (Terminal starts login
			-- shells there, which don't read ~/.bashrc); any other shell's ~/.profile.
		local
			l_name: STRING
			l_slash: INTEGER
		do
			l_name := a_shell.to_string_8
			if not l_name.is_empty then
				l_slash := l_name.last_index_of ('/', l_name.count)
			end
			if l_slash > 0 then
				l_name := l_name.substring (l_slash + 1, l_name.count)
			end
			create Result.make_from_string (a_home.to_string_8)
			if l_name.same_string ("zsh") then
				Result.append ("/.zshrc")
			elseif l_name.same_string ("bash") then
				if a_mac then
					Result.append ("/.bash_profile")
				else
					Result.append ("/.bashrc")
				end
			else
				Result.append ("/.profile")
			end
		ensure
			in_home: Result.starts_with (a_home.to_string_8)
		end

	write_export (a_path, a_name, a_value: STRING)
			-- In shell start-up file `a_path', export `a_name' = `a_value' once: any earlier line for
			-- it goes, and the file is made if it isn't there.
		require
			name_not_empty: not a_name.is_empty
		local
			l_file: SIMPLE_FILE
			l_content: STRING_32
			l_line: STRING
		do
			create l_file.make (a_path)
			l_line := "export " + a_name + "=" + a_value + "  # simple_pkg: " + a_name
			if l_file.exists then
				l_content := remove_bashrc_export (l_file.content, a_name)
				l_content.append ("%N" + l_line)
				l_file.write_all (l_content).do_nothing
			else
				l_file.write_all (l_line).do_nothing
			end
		end

	remove_export (a_path, a_name: STRING)
			-- Take `a_name''s export line out of shell start-up file `a_path'.
		require
			name_not_empty: not a_name.is_empty
		local
			l_file: SIMPLE_FILE
		do
			create l_file.make (a_path)
			if l_file.exists then
				l_file.write_all (remove_bashrc_export (l_file.content, a_name)).do_nothing
			end
		end

feature {NONE} -- Implementation

	remove_bashrc_export (a_content: STRING_32; a_name: STRING): STRING_32
			-- Remove export line for `a_name' from bashrc content.
			-- Looks for lines containing "export NAME=" or "# simple_pkg: NAME".
		require
			content_attached: a_content /= Void
			name_not_empty: not a_name.is_empty
		local
			l_lines: LIST [STRING_32]
			l_line: STRING_32
			l_export_pattern: STRING
			l_marker_pattern: STRING
		do
			create {STRING_32} Result.make (a_content.count)
			l_export_pattern := "export " + a_name + "="
			l_marker_pattern := "# simple_pkg: " + a_name

			l_lines := a_content.split ('%N')
			across l_lines as line loop
				l_line := line
				-- Skip lines that export this variable or have our marker
				if not l_line.has_substring (l_export_pattern) and
				   not l_line.has_substring (l_marker_pattern) then
					if not Result.is_empty then
						Result.append_character ('%N')
					end
					Result.append (l_line)
				end
			end
		ensure
			result_attached: Result /= Void
		end

invariant
	install_directory_not_empty: not install_directory.is_empty
	cache_directory_not_empty: not cache_directory.is_empty
	config_directory_not_empty: not config_directory.is_empty

end

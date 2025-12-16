note
	description: "[
		Package installer.

		Handles:
		- Git clone from GitHub
		- Directory creation
		- Environment variable setup (persistent on Windows)
		- Update via git pull
		- Uninstallation

		Installation directory structure:
			<install_dir>/
				simple_json/
				simple_web/
				simple_sql/
				...
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	PKG_INSTALLER

create
	make

feature {NONE} -- Initialization

	make (a_config: PKG_CONFIG)
			-- Initialize installer with configuration.
		require
			config_not_void: a_config /= Void
		do
			config := a_config
			create last_errors.make (10)
			ensure_directories_exist
		ensure
			config_set: config = a_config
		end

feature -- Access

	config: PKG_CONFIG
			-- Configuration

	last_errors: ARRAYED_LIST [STRING]
			-- Errors from last operation

	has_error: BOOLEAN
			-- Did last operation have errors?
		do
			Result := not last_errors.is_empty
		end

feature -- Status

	is_installed (a_name: STRING): BOOLEAN
			-- Is package `a_name` installed?
		require
			name_not_empty: not a_name.is_empty
		local
			l_path: STRING
			l_dir: DIRECTORY
		do
			l_path := config.package_path (a_name)
			create l_dir.make (l_path)
			Result := l_dir.exists
		end

	installed_packages: ARRAYED_LIST [STRING]
			-- List of installed package names.
		local
			l_dir: DIRECTORY
			l_sub_dir: DIRECTORY
			l_path: STRING
		do
			create Result.make (50)
			create l_dir.make (config.install_directory)

			if l_dir.exists then
				l_dir.open_read
				across l_dir.entries as entry loop
					if attached entry.name as l_name and then l_name.starts_with ("simple_") then
						-- Check if it's actually a directory
						l_path := config.install_directory + config.path_separator.out + l_name.to_string_8
						create l_sub_dir.make (l_path)
						if l_sub_dir.exists then
							Result.extend (l_name.to_string_8)
						end
					end
				end
				l_dir.close
			end
		ensure
			result_attached: Result /= Void
		end

feature -- Installation

	install_package (a_name: STRING)
			-- Install package `a_name` from GitHub.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_clone_url: STRING
			l_target_path: STRING
			l_process: SIMPLE_PROCESS
			l_cmd: STRING
		do
			last_errors.wipe_out
			l_normalized := config.normalize_package_name (a_name)

			if is_installed (l_normalized) then
				-- Already installed, skip
			else
				l_clone_url := "https://github.com/" + config.github_org + "/" + l_normalized + ".git"
				l_target_path := config.package_path (l_normalized)

				-- Git clone
				l_cmd := "git clone --depth 1 " + l_clone_url + " %"" + l_target_path + "%""

				create l_process.make
				l_process.run (l_cmd)

				if l_process.last_exit_code = 0 then
					-- Package installed successfully
					-- Note: Environment variable setup is no longer needed.
					-- All packages use SIMPLE_EIFFEL root variable.
				else
					last_errors.extend ("Failed to clone " + l_normalized + ": exit code " + l_process.last_exit_code.out)
					if attached l_process.last_error as err and then not err.is_empty then
						last_errors.extend ("  " + err)
					end
				end
			end
		end

	install_multiple (a_names: ARRAYED_LIST [STRING])
			-- Install multiple packages.
		require
			names_not_void: a_names /= Void
		do
			across a_names as name loop
				install_package (name)
			end
		end

feature -- Update

	update_package (a_name: STRING)
			-- Update package `a_name` via git pull.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_path: STRING
			l_process: SIMPLE_PROCESS
			l_cmd: STRING
		do
			last_errors.wipe_out
			l_normalized := config.normalize_package_name (a_name)
			l_path := config.package_path (l_normalized)

			if is_installed (l_normalized) then
				-- Git pull
				l_cmd := "git -C %"" + l_path + "%" pull --ff-only"

				create l_process.make
				l_process.run (l_cmd)

				if l_process.last_exit_code /= 0 then
					last_errors.extend ("Failed to update " + l_normalized)
					if attached l_process.last_error as err and then not err.is_empty then
						last_errors.extend ("  " + err)
					end
				end
			else
				last_errors.extend ("Package not installed: " + l_normalized)
			end
		end

	update_all
			-- Update all installed packages.
		local
			l_installed: ARRAYED_LIST [STRING]
		do
			last_errors.wipe_out
			l_installed := installed_packages
			across l_installed as pkg loop
				update_package (pkg)
			end
		end

feature -- Move

	move_package (a_name: STRING)
			-- Move package from its env var location to current install directory.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_env_name: STRING
			l_source_path: detachable STRING
			l_target_path: STRING
			l_process: SIMPLE_PROCESS
			l_cmd: STRING
			l_source_dir, l_target_dir: DIRECTORY
		do
			last_errors.wipe_out
			l_normalized := config.normalize_package_name (a_name)
			l_env_name := config.package_env_var_name (l_normalized)

			-- Get current location from environment variable
			l_source_path := config.get_env (l_env_name)

			if not attached l_source_path then
				last_errors.extend ("Environment variable " + l_env_name + " not set. Package may not be installed.")
			else
				create l_source_dir.make (l_source_path)
				if not l_source_dir.exists then
					last_errors.extend ("Source directory does not exist: " + l_source_path)
				else
					l_target_path := config.package_path (l_normalized)

					-- Check if source and target are the same
					if l_source_path.same_string (l_target_path) then
						last_errors.extend ("Package is already in the target directory: " + l_target_path)
					else
						create l_target_dir.make (l_target_path)
						if l_target_dir.exists then
							last_errors.extend ("Target directory already exists: " + l_target_path)
						else
							-- Move the directory
							if config.is_windows then
								l_cmd := "move %"" + l_source_path + "%" %"" + l_target_path + "%""
							else
								l_cmd := "mv %"" + l_source_path + "%" %"" + l_target_path + "%""
							end

							create l_process.make
							l_process.run (l_cmd)

							if l_process.last_exit_code = 0 then
								-- Package moved successfully
								-- Note: No environment variable update needed.
								-- All packages use SIMPLE_EIFFEL root variable.
							else
								last_errors.extend ("Failed to move " + l_normalized)
								if attached l_process.last_error as err and then not err.is_empty then
									last_errors.extend ("  " + err)
								end
							end
						end
					end
				end
			end
		end

feature -- Uninstallation

	uninstall_package (a_name: STRING)
			-- Remove installed package.
			-- Note: No environment variable removal needed - all packages use SIMPLE_EIFFEL root.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_path: STRING
			l_process: SIMPLE_PROCESS
			l_cmd: STRING
		do
			last_errors.wipe_out
			l_normalized := config.normalize_package_name (a_name)
			l_path := config.package_path (l_normalized)

			if is_installed (l_normalized) then
				-- Remove directory
				if config.is_windows then
					l_cmd := "rmdir /s /q %"" + l_path + "%""
				else
					l_cmd := "rm -rf %"" + l_path + "%""
				end

				create l_process.make
				l_process.run (l_cmd)

				if l_process.last_exit_code /= 0 then
					last_errors.extend ("Failed to remove directory: " + l_normalized)
				end
				-- Note: No environment variable to remove.
				-- All packages use SIMPLE_EIFFEL root variable.
			else
				last_errors.extend ("Package not installed: " + l_normalized)
			end
		ensure
			removed_if_no_error: not has_error implies not is_installed (config.normalize_package_name (a_name))
		end

	uninstall_all
			-- Remove all installed packages and their environment variables.
		local
			l_installed: ARRAYED_LIST [STRING]
		do
			last_errors.wipe_out
			l_installed := installed_packages

			across l_installed as pkg loop
				uninstall_package (pkg)
			end
		end

feature -- Environment Conflict Detection

	check_env_var_conflict (a_name: STRING): detachable STRING
			-- Check if setting env var for `a_name` would overwrite an existing value
			-- pointing to a different location.
			-- Returns: existing path if conflict, Void if no conflict.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_env_name: STRING
			l_target_path: STRING
			l_existing_path: detachable STRING
		do
			l_normalized := config.normalize_package_name (a_name)
			l_env_name := config.package_env_var_name (l_normalized)
			l_target_path := config.package_path (l_normalized)

			-- Check if env var already exists
			l_existing_path := config.get_env (l_env_name)

			if attached l_existing_path as existing then
				-- Normalize paths for comparison (handle / vs \ on Windows)
				if config.is_windows then
					existing.replace_substring_all ("/", "\")
					l_target_path.replace_substring_all ("/", "\")
				end

				-- Check if it points to a different location
				if not existing.same_string (l_target_path) then
					Result := existing
				end
			end
		ensure
			conflict_means_different_path: Result /= Void implies
				not Result.same_string (config.package_path (config.normalize_package_name (a_name)))
		end

feature -- Environment Setup

	ensure_simple_eiffel_set (a_path: STRING)
			-- Ensure SIMPLE_EIFFEL environment variable is set.
			-- This is the single environment variable needed for all packages.
		require
			path_not_empty: not a_path.is_empty
		local
			l_path_win: STRING
		do
			-- Convert path for Windows if needed
			if config.is_windows then
				l_path_win := a_path.twin
				l_path_win.replace_substring_all ("/", "\")
				config.set_env (config.root_env_var, l_path_win)
			else
				config.set_env (config.root_env_var, a_path)
			end
		end

	setup_environment_variable (a_package, a_path: STRING)
			-- Set up environment variable for package (LEGACY - no longer used).
		obsolete "Use ensure_simple_eiffel_set instead of per-package env vars [2025-12]"
		require
			package_not_empty: not a_package.is_empty
			path_not_empty: not a_path.is_empty
		do
			-- No-op: per-package environment variables are no longer used.
			-- All packages use SIMPLE_EIFFEL root variable.
		end

	setup_all_environment_variables
			-- Set up environment variables (LEGACY - replaced by ensure_simple_eiffel_set).
		obsolete "Use ensure_simple_eiffel_set instead [2025-12]"
		do
			-- No-op: per-package environment variables are no longer used.
			-- Just ensure SIMPLE_EIFFEL is set.
			if attached config.simple_eiffel_root as root then
				ensure_simple_eiffel_set (root)
			end
		end

	generate_env_script: STRING
			-- Generate shell script to set SIMPLE_EIFFEL environment variable.
		local
			l_root: detachable STRING
		do
			create Result.make (500)
			l_root := config.simple_eiffel_root

			if config.is_windows then
				Result.append ("@echo off%N")
				Result.append ("REM Simple Eiffel environment setup%N")
				Result.append ("REM Generated by simple_pkg%N")
				Result.append ("REM Only SIMPLE_EIFFEL is needed - all packages use this root.%N%N")
				if attached l_root as root then
					Result.append ("set " + config.root_env_var + "=" + root.twin + "%N")
					Result.append ("setx " + config.root_env_var + " %"" + root.twin + "%"%N")
				else
					Result.append ("REM SIMPLE_EIFFEL not set - please set it to your install directory%N")
					Result.append ("REM Example: setx SIMPLE_EIFFEL D:\simple_eiffel%N")
				end
			else
				Result.append ("#!/bin/bash%N")
				Result.append ("# Simple Eiffel environment setup%N")
				Result.append ("# Generated by simple_pkg%N")
				Result.append ("# Only SIMPLE_EIFFEL is needed - all packages use this root.%N%N")
				if attached l_root as root then
					Result.append ("export " + config.root_env_var + "=%"" + root.twin + "%"%N")
				else
					Result.append ("# SIMPLE_EIFFEL not set - please set it to your install directory%N")
					Result.append ("# Example: export SIMPLE_EIFFEL=/home/user/simple_eiffel%N")
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	save_env_script
			-- Save environment script to config directory.
		local
			l_script: STRING
			l_file: SIMPLE_FILE
			l_path: STRING
		do
			l_script := generate_env_script

			if config.is_windows then
				l_path := config.config_directory + "\env_setup.bat"
			else
				l_path := config.config_directory + "/env_setup.sh"
			end

			create l_file.make (l_path)
			if not l_file.write_all (l_script) then
				-- Silently fail (best effort)
			end
		end

feature {NONE} -- Implementation

	ensure_directories_exist
			-- Create installation and cache directories if needed.
		local
			l_dir: DIRECTORY
		do
			-- Install directory
			create l_dir.make (config.install_directory)
			if not l_dir.exists then
				l_dir.recursive_create_dir
			end

			-- Config directory
			create l_dir.make (config.config_directory)
			if not l_dir.exists then
				l_dir.recursive_create_dir
			end

			-- Cache directory
			create l_dir.make (config.cache_directory)
			if not l_dir.exists then
				l_dir.recursive_create_dir
			end
		end

invariant
	config_exists: config /= Void
	errors_exist: last_errors /= Void

end

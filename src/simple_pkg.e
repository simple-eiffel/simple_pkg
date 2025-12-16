note
	description: "[
		Simple Package Manager - GitHub-based package management for Simple Eiffel.

		Replaces ISE's defunct 'iron' with a modern, GitHub-backed approach.
		All packages live in the simple-eiffel GitHub organization.

		Features:
		- Install packages from GitHub (simple-eiffel org)
		- Automatic dependency resolution from ECF files
		- Environment variable setup ($SIMPLE_*)
		- Version management via git tags
		- Local package cache

		Usage:
			create pkg.make
			pkg.install ("json")
			pkg.install_multiple (<<"json", "web", "sql">>)
			pkg.update_all

		CLI (via simple command):
			simple install json web sql
			simple update
			simple search http
			simple list
			simple info json
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SIMPLE_PKG

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize package manager.
		do
			create config.make
			create registry.make (config)
			create resolver.make
			create installer.make (config)
			create last_errors.make (10)
		ensure
			config_created: config /= Void
			registry_created: registry /= Void
		end

feature -- Access

	config: PKG_CONFIG
			-- Package manager configuration

	registry: PKG_REGISTRY
			-- GitHub registry interface

	resolver: PKG_RESOLVER
			-- Dependency resolver

	installer: PKG_INSTALLER
			-- Package installer

	last_errors: ARRAYED_LIST [STRING]
			-- Errors from last operation

	has_error: BOOLEAN
			-- Did last operation have errors?
		do
			Result := not last_errors.is_empty
		end

feature -- Installation

	install (a_name: STRING)
			-- Install package `a_name` and its dependencies.
		require
			name_not_empty: not a_name.is_empty
		local
			l_package: detachable PKG_INFO
			l_deps: ARRAYED_LIST [STRING]
		do
			last_errors.wipe_out

			-- Fetch package info from registry
			l_package := registry.fetch_package (a_name)

			if attached l_package as pkg then
				-- Resolve dependencies
				l_deps := resolver.resolve_dependencies (pkg, registry)

				-- Install dependencies first
				across l_deps as dep loop
					if not installer.is_installed (dep) then
						install_single (dep)
					end
				end

				-- Install the package itself
				if not installer.is_installed (a_name) then
					install_single (a_name)
				end
			else
				last_errors.extend ("Package not found: " + a_name)
			end
		end

	install_multiple (a_names: ARRAY [STRING])
			-- Install multiple packages.
		require
			names_not_empty: not a_names.is_empty
		do
			across a_names as name loop
				install (name)
			end
		end

	install_all
			-- Install all available packages from the registry.
		local
			l_packages: ARRAYED_LIST [PKG_INFO]
		do
			last_errors.wipe_out
			l_packages := registry.fetch_all_packages
			across l_packages as pkg loop
				if not installer.is_installed (pkg.name) then
					install (pkg.name)
				end
			end
		end

feature -- Update

	update (a_name: STRING)
			-- Update package `a_name` to latest version.
		require
			name_not_empty: not a_name.is_empty
		do
			last_errors.wipe_out
			if installer.is_installed (a_name) then
				installer.update_package (a_name)
				if installer.has_error then
					last_errors.append (installer.last_errors)
				end
			else
				last_errors.extend ("Package not installed: " + a_name)
			end
		end

	update_all
			-- Update all installed packages.
		local
			l_installed: ARRAYED_LIST [STRING]
		do
			last_errors.wipe_out
			l_installed := installer.installed_packages
			across l_installed as pkg loop
				update (pkg)
			end
		end

feature -- Query

	search (a_query: STRING): ARRAYED_LIST [PKG_INFO]
			-- Search for packages matching `a_query`.
		require
			query_not_empty: not a_query.is_empty
		do
			Result := registry.search_packages (a_query)
		ensure
			result_attached: Result /= Void
		end

	list_available: ARRAYED_LIST [PKG_INFO]
			-- List all available packages.
		do
			Result := registry.fetch_all_packages
		ensure
			result_attached: Result /= Void
		end

	list_installed: ARRAYED_LIST [STRING]
			-- List installed packages.
		do
			Result := installer.installed_packages
		ensure
			result_attached: Result /= Void
		end

	info (a_name: STRING): detachable PKG_INFO
			-- Get information about package `a_name`.
			-- First checks locally installed packages, then falls back to GitHub.
		require
			name_not_empty: not a_name.is_empty
		do
			-- Try local first
			Result := local_info (a_name)
			-- Fall back to GitHub
			if Result = Void then
				Result := registry.fetch_package (a_name)
			end
		end

	local_info (a_name: STRING): detachable PKG_INFO
			-- Get info from locally installed package.
			-- Uses SIMPLE_EIFFEL root variable to locate packages.
		require
			name_not_empty: not a_name.is_empty
		local
			l_normalized: STRING
			l_path: detachable STRING
			l_ecf_path: STRING
			l_pkg_path: STRING
			l_meta: ECF_METADATA
			l_dir: DIRECTORY
		do
			l_normalized := config.normalize_package_name (a_name)

			-- Get package path from SIMPLE_EIFFEL root
			if attached config.simple_eiffel_root as l_root then
				l_path := l_root + "/" + l_normalized
			end

			if attached l_path as path then
				-- Check if directory exists
				create l_dir.make (path)
				if l_dir.exists then
					l_ecf_path := path + "/" + l_normalized + ".ecf"
					l_pkg_path := path + "/package.json"
					create l_meta.make_from_file (l_ecf_path)
					if l_meta.is_valid then
						l_meta.apply_package_json (l_pkg_path)
						create Result.make (l_normalized)
						Result.apply_ecf_metadata (l_meta)
						Result.set_installed (True)
						Result.set_local_path (path)
					end
				end
			end
		end

	is_installed (a_name: STRING): BOOLEAN
			-- Is package `a_name` installed?
		require
			name_not_empty: not a_name.is_empty
		do
			Result := installer.is_installed (a_name)
		end

feature {NONE} -- Implementation

	install_single (a_name: STRING)
			-- Install a single package (no dependency resolution).
		require
			name_not_empty: not a_name.is_empty
		do
			installer.install_package (a_name)
			if installer.has_error then
				last_errors.append (installer.last_errors)
			end
		end

invariant
	config_exists: config /= Void
	registry_exists: registry /= Void
	resolver_exists: resolver /= Void
	installer_exists: installer /= Void
	errors_exist: last_errors /= Void

end

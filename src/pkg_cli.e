note
	description: "[
		Simple Package Manager CLI.

		Commands:
			simple install <pkg> [<pkg>...]   Install packages with dependencies
			simple update [<pkg>...]          Update packages (all if none specified)
			simple search <query>             Search for packages
			simple list                       List all available packages
			simple installed                  List installed packages
			simple info <pkg>                 Show package details
			simple uninstall <pkg>            Remove a package
			simple env                        Show/generate environment script
			simple help                       Show help

		Examples:
			simple install json web sql
			simple update
			simple search http
			simple info json
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	PKG_CLI

inherit
	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Run CLI application.
		do
			create console.make
			create pkg.make

			parse_arguments
			execute_command
		end

feature -- Access

	console: SIMPLE_CONSOLE
			-- Console output

	pkg: SIMPLE_PKG
			-- Package manager

	command: STRING
			-- Current command
		attribute
			create Result.make_empty
		end

	command_args: ARRAYED_LIST [STRING]
			-- Command arguments
		attribute
			create Result.make (10)
		end

feature -- Execution

	parse_arguments
			-- Parse command line arguments.
		local
			i: INTEGER
		do
			create command_args.make (10)

			if argument_count >= 1 then
				command := argument (1).to_string_8
			else
				command := "help"
			end

			from i := 2 until i > argument_count loop
				command_args.extend (argument (i).to_string_8)
				i := i + 1
			end
		end

	execute_command
			-- Execute the parsed command.
		do
			if command.same_string ("install") or command.same_string ("i") then
				execute_install
			elseif command.same_string ("update") or command.same_string ("up") then
				execute_update
			elseif command.same_string ("search") or command.same_string ("s") then
				execute_search
			elseif command.same_string ("browse") or command.same_string ("b") then
				execute_browse
			elseif command.same_string ("lock") then
				execute_lock
			elseif command.same_string ("list") then
				execute_list
			elseif command.same_string ("universe") or command.same_string ("-u") or command.same_string ("--univ") then
				execute_universe
			elseif command.same_string ("inventory") or command.same_string ("-i") or command.same_string ("--inventory") or command.same_string ("installed") then
				execute_installed
			elseif command.same_string ("info") then
				execute_info
			elseif command.same_string ("uninstall") or command.same_string ("remove") or command.same_string ("rm") then
				execute_uninstall
			elseif command.same_string ("move") or command.same_string ("mv") then
				execute_move
			elseif command.same_string ("tree") or command.same_string ("deps") then
				execute_tree
			elseif command.same_string ("doctor") or command.same_string ("check") then
				execute_doctor
			elseif command.same_string ("outdated") then
				execute_outdated
			elseif command.same_string ("init") then
				execute_init
			elseif command.same_string ("env") then
				execute_env
			elseif command.same_string ("goto") or command.same_string ("cd") or command.same_string ("g") then
				execute_goto
			elseif command.same_string ("version") or command.same_string ("-v") or command.same_string ("--version") then
				execute_version
			elseif command.same_string ("help") or command.same_string ("-h") or command.same_string ("--help") then
				execute_help
			else
				console.print_error ("Unknown command: " + command)
				console.print_line ("Run 'simple help' for usage information.")
			end
		end

feature -- Commands

	execute_install
			-- Install packages.
		do
			if command_args.is_empty then
				console.print_error ("Usage: simple install <package> [<package>...]")
			else
				across command_args as name loop
					console.print_line ("Installing " + name + "...")
					pkg.install (name)
					if pkg.has_error then
						across pkg.last_errors as err loop
							console.print_error ("  " + err)
						end
					else
						console.print_success ("  Installed " + name)
					end
				end
				console.print_line ("")
				console.print_line ("Environment variables have been set.")
				console.print_line ("You may need to restart your terminal for changes to take effect.")
			end
		end

	execute_update
			-- Update packages.
		do
			if command_args.is_empty then
				console.print_line ("Updating all packages...")
				pkg.update_all
			else
				across command_args as name loop
					console.print_line ("Updating " + name + "...")
					pkg.update (name)
				end
			end

			if pkg.has_error then
				across pkg.last_errors as err loop
					console.print_error (err)
				end
			else
				console.print_success ("Update complete.")
			end
		end

	execute_search
			-- Search for packages using FTS5 fuzzy search.
		local
			l_search: PKG_SEARCH
			l_packages: ARRAYED_LIST [PKG_INFO]
			l_results: ARRAYED_LIST [SEARCH_RESULT]
		do
			if command_args.is_empty then
				console.print_error ("Usage: simple search <query>")
				console.print_line ("")
				console.print_line ("Options:")
				console.print_line ("  simple search <query>           Fuzzy search packages")
				console.print_line ("  simple search --deps <pkg>      Find packages using <pkg>")
			elseif command_args.first.same_string ("--deps") and command_args.count >= 2 then
				-- Search by dependency
				console.print_line ("Fetching package index...")
				l_packages := pkg.list_available
				create l_search.make
				l_search.build_index (l_packages)
				l_packages := l_search.search_by_dependency (command_args.i_th (2))

				if l_packages.is_empty then
					console.print_line ("No packages depend on '" + command_args.i_th (2) + "'")
				else
					console.print_line ("Packages using " + command_args.i_th (2) + ":")
					console.print_line ("")
					across l_packages as p loop
						print_package_brief (p)
					end
				end
			else
				-- FTS5 fuzzy search
				console.print_line ("Searching...")
				l_packages := pkg.list_available
				create l_search.make
				l_search.build_index (l_packages)
				l_results := l_search.search (command_args.first)

				if l_results.is_empty then
					console.print_line ("No packages found matching '" + command_args.first + "'")
				else
					console.print_line ("Found " + l_results.count.out + " package(s):")
					console.print_line ("")
					across l_results as r loop
						print_search_result (r)
					end
				end
			end
		end

	execute_browse
			-- Browse packages by category.
		local
			l_search: PKG_SEARCH
			l_packages: ARRAYED_LIST [PKG_INFO]
			l_categories: ARRAYED_LIST [STRING]
		do
			console.print_line ("Fetching package index...")
			l_packages := pkg.list_available
			create l_search.make
			l_search.build_index (l_packages)

			if command_args.is_empty then
				-- List categories
				l_categories := l_search.list_categories
				console.print_line ("")
				console.print_line ("Available categories:")
				console.print_line ("")
				across l_categories as cat loop
					l_packages := l_search.browse_category (cat)
					console.print_line ("  " + cat + " (" + l_packages.count.out + " packages)")
				end
				console.print_line ("")
				console.print_line ("Use 'simple browse <category>' to see packages in a category.")
			else
				-- Browse specific category
				l_packages := l_search.browse_category (command_args.first)
				if l_packages.is_empty then
					console.print_line ("No packages in category '" + command_args.first + "'")
				else
					console.print_line ("")
					console.print_line ("Category: " + command_args.first + " (" + l_packages.count.out + " packages)")
					console.print_line ("")
					across l_packages as p loop
						print_package_brief (p)
					end
				end
			end
		end

	execute_lock
			-- Generate or show lock file.
		local
			l_lock: PKG_LOCK
			l_installed: ARRAYED_LIST [STRING]
			l_path: STRING
		do
			l_lock := pkg.config.create_for_directory (pkg.config.install_directory)

			if command_args.has ("--show") or command_args.has ("-s") then
				-- Show existing lock file
				l_lock.load
				if l_lock.is_valid then
					console.print_line (l_lock.to_string)
				else
					console.print_line ("No lock file found.")
					console.print_line ("Run 'simple lock' to generate one.")
				end
			else
				-- Generate lock file
				console.print_line ("Generating lock file...")
				l_installed := pkg.list_installed

				across l_installed as name loop
					l_path := pkg.config.package_path (name)
					-- For now, use "main" as version (TODO: read from ECF)
					l_lock.add_package (name, "main", l_path)
				end

				l_lock.save
				console.print_success ("Lock file saved: " + l_lock.default_lock_file_name)
				console.print_line ("")
				console.print_line ("Locked " + l_installed.count.out + " packages.")
			end
		end

	execute_list
			-- List all available packages.
		local
			l_packages: ARRAYED_LIST [PKG_INFO]
		do
			console.print_line ("Fetching package list from GitHub...")
			l_packages := pkg.list_available

			console.print_line ("")
			console.print_line ("Available packages (" + l_packages.count.out + "):")
			console.print_line ("")

			across l_packages as p loop
				print_package_brief (p)
			end
		end

	execute_installed
			-- List installed packages.
		local
			l_installed: ARRAYED_LIST [STRING]
		do
			l_installed := pkg.list_installed

			if l_installed.is_empty then
				console.print_line ("No packages installed.")
				console.print_line ("Run 'simple install <package>' to install packages.")
			else
				console.print_line ("Installed packages (" + l_installed.count.out + "):")
				console.print_line ("")
				across l_installed as name loop
					console.print_line ("  " + name)
				end
			end
		end

	execute_info
			-- Show package information.
		local
			l_info: detachable PKG_INFO
		do
			if command_args.is_empty then
				console.print_error ("Usage: simple info <package>")
			else
				l_info := pkg.info (command_args.first)
				if attached l_info as info then
					print_package_detail (info)
				else
					console.print_error ("Package not found: " + command_args.first)
				end
			end
		end

	execute_uninstall
			-- Uninstall a package.
		do
			if command_args.is_empty then
				console.print_error ("Usage: simple uninstall <package>")
			else
				across command_args as name loop
					console.print_line ("Uninstalling " + name + "...")
					pkg.installer.uninstall_package (name)
					if pkg.installer.has_error then
						across pkg.installer.last_errors as err loop
							console.print_error ("  " + err)
						end
					else
						console.print_success ("  Removed " + name)
					end
				end
			end
		end

	execute_move
			-- Move a package from its current location to current directory.
		local
			l_name: STRING
		do
			if command_args.is_empty then
				console.print_error ("Usage: simple move <package>")
				console.print_line ("Moves a package from its env var location to current directory.")
			else
				l_name := command_args.first
				console.print_line ("Moving " + l_name + " to current directory...")
				pkg.installer.move_package (l_name)
				if pkg.installer.has_error then
					across pkg.installer.last_errors as err loop
						console.print_error ("  " + err)
					end
				else
					console.print_success ("  Moved " + l_name + " to " + pkg.config.install_directory)
					console.print_line ("  Environment variable updated.")
				end
			end
		end

	execute_universe
			-- Show all available packages with installation status.
			-- Inspired by: npm list --all, cargo search --limit 100
		local
			l_packages: ARRAYED_LIST [PKG_INFO]
			l_installed, l_available: INTEGER
		do
			console.print_line ("Fetching Simple Eiffel universe...")
			l_packages := pkg.list_available

			console.print_line ("")
			console.print_line ("Simple Eiffel Universe:")
			console.print_line ("=======================")
			console.print_line ("")

			across l_packages as p loop
				if pkg.is_installed (p.name) then
					console.print_success ("  [*] " + p.name)
					l_installed := l_installed + 1
				else
					console.print_line ("  [ ] " + p.name)
				end
				if not p.description.is_empty then
					console.print_line ("      " + p.description)
				end
				l_available := l_available + 1
			end

			console.print_line ("")
			console.print_line ("Summary: " + l_installed.out + " installed / " + l_available.out + " available")
			console.print_line ("")
			console.print_line ("[*] = installed, [ ] = available")
		end

	execute_tree
			-- Show dependency tree for installed or specified packages.
			-- Inspired by: npm ls --all, cargo tree
		local
			l_info: detachable PKG_INFO
			l_installed: ARRAYED_LIST [STRING]
		do
			console.print_line ("Dependency Tree:")
			console.print_line ("================")
			console.print_line ("")

			if command_args.is_empty then
				-- Show tree for all installed
				l_installed := pkg.list_installed
				across l_installed as name loop
					print_dependency_tree (name, 0)
				end
			else
				-- Show tree for specified package
				l_info := pkg.info (command_args.first)
				if attached l_info then
					print_dependency_tree (l_info.name, 0)
				else
					console.print_error ("Package not found: " + command_args.first)
				end
			end
		end

	execute_doctor
			-- Diagnose environment and report issues.
			-- Inspired by: flutter doctor, brew doctor
		local
			l_installed: ARRAYED_LIST [STRING]
			l_env_val: detachable STRING
			l_env_name: STRING
			l_dir: DIRECTORY
			l_issues: INTEGER
		do
			console.print_line ("Simple Environment Doctor")
			console.print_line ("=========================")
			console.print_line ("")

			-- Check Git
			console.print_line ("Checking prerequisites...")
			if check_command_exists ("git --version") then
				console.print_success ("  [OK] Git is installed")
			else
				console.print_error ("  [X] Git not found - required for package installation")
				l_issues := l_issues + 1
			end

			-- Check EiffelStudio
			l_env_val := pkg.config.get_env ("ISE_EIFFEL")
			if attached l_env_val and then not l_env_val.is_empty then
				console.print_success ("  [OK] ISE_EIFFEL = " + l_env_val)
			else
				console.print_warning ("  [?] ISE_EIFFEL not set")
			end

			console.print_line ("")
			console.print_line ("Checking installed packages...")

			l_installed := pkg.list_installed
			across l_installed as name loop
				l_env_name := pkg.config.package_env_var_name (name)
				l_env_val := pkg.config.get_env (l_env_name)

				if attached l_env_val as ev then
					create l_dir.make (ev)
					if l_dir.exists then
						console.print_success ("  [OK] " + l_env_name + " = " + ev)
					else
						console.print_error ("  [X] " + l_env_name + " points to missing directory: " + ev)
						l_issues := l_issues + 1
					end
				else
					console.print_error ("  [X] " + l_env_name + " not set")
					l_issues := l_issues + 1
				end
			end

			console.print_line ("")
			if l_issues = 0 then
				console.print_success ("No issues found!")
			else
				console.print_error ("Found " + l_issues.out + " issue(s)")
				console.print_line ("Run 'simple env --save' to regenerate environment script.")
			end
		end

	execute_outdated
			-- Show packages that may have updates available.
			-- Inspired by: npm outdated, pip list --outdated
		local
			l_installed: ARRAYED_LIST [STRING]
			l_path: STRING
			l_process: SIMPLE_PROCESS
			l_cmd: STRING
		do
			console.print_line ("Checking for updates...")
			console.print_line ("")

			l_installed := pkg.list_installed

			if l_installed.is_empty then
				console.print_line ("No packages installed.")
			else
				across l_installed as name loop
					l_path := pkg.config.package_path (name)
					l_cmd := "git -C %"" + l_path + "%" fetch --dry-run 2>&1"

					create l_process.make
					l_process.run (l_cmd)

					if attached l_process.last_output as l_out and then not l_out.is_empty then
						console.print_warning ("  " + name + " - updates available")
					else
						console.print_success ("  " + name + " - up to date")
					end
				end
			end

			console.print_line ("")
			console.print_line ("Run 'simple update' to update all packages.")
		end

	execute_init
			-- Initialize a new Eiffel project with selected dependencies.
			-- Inspired by: npm init, cargo init
		local
			l_file: SIMPLE_FILE
			l_ecf_name: STRING
			l_ecf_content: STRING
		do
			if command_args.is_empty then
				console.print_error ("Usage: simple init <project_name> [<pkg>...]")
				console.print_line ("Creates a new .ecf file with dependencies.")
				console.print_line ("")
				console.print_line ("Example:")
				console.print_line ("  simple init my_app json web sql")
			else
				l_ecf_name := command_args.first + ".ecf"
				create l_file.make (l_ecf_name)

				if l_file.exists then
					console.print_error ("File already exists: " + l_ecf_name)
				else
					l_ecf_content := generate_ecf_template (command_args)
					if l_file.write_all (l_ecf_content) then
						console.print_success ("Created " + l_ecf_name)
					else
						console.print_error ("Failed to create " + l_ecf_name)
					end
					console.print_line ("")

					-- Install dependencies if specified
					if command_args.count > 1 then
						console.print_line ("Installing dependencies...")
						from command_args.start; command_args.forth until command_args.after loop
							console.print_line ("  Installing " + command_args.item + "...")
							pkg.install (command_args.item)
						end
					end
				end
			end
		end

	execute_env
			-- Show or generate environment script.
		local
			l_script: STRING
		do
			if command_args.has ("--save") or command_args.has ("-s") then
				pkg.installer.save_env_script
				console.print_success ("Environment script saved to " + pkg.config.config_directory)
			else
				l_script := pkg.installer.generate_env_script
				console.print_line (l_script)
			end
		end

	execute_goto
			-- Output path or cd command to navigate to package directory.
			-- Since child process can't change parent's directory, we output
			-- a path that can be used with: cd (simple goto pdf)
		local
			l_name: STRING
			l_normalized: STRING
			l_env_var: STRING
			l_path: detachable STRING
			l_env: EXECUTION_ENVIRONMENT
		do
			if command_args.is_empty then
				console.print_error ("Usage: simple goto <package>")
				console.print_line ("  Example: simple goto pdf")
				console.print_line ("")
				console.print_line ("PowerShell: cd (simple goto pdf)")
				console.print_line ("CMD:        for /f %%i in ('simple goto pdf') do cd /d %%i")
			else
				l_name := command_args.first
				l_normalized := pkg.config.normalize_package_name (l_name)
				l_env_var := pkg.config.package_env_var_name (l_normalized)

				create l_env
				if attached l_env.item (l_env_var) as l_env_path then
					l_path := l_env_path.to_string_8
				end

				if l_path /= Void and then not l_path.is_empty then
					-- Output just the path - user wraps with cd
					io.put_string (l_path)
					io.put_new_line
				else
					console.print_error ("Package not found: " + l_name)
					console.print_line ("Environment variable " + l_env_var + " is not set.")
				end
			end
		end

	execute_version
			-- Show version.
		do
			console.print_line ("simple (Simple Eiffel Package Manager) " + version)
			console.print_line ("GitHub: https://github.com/simple-eiffel")
		end

	execute_help
			-- Show help.
		do
			console.print_line ("Simple Eiffel Package Manager")
			console.print_line ("")
			console.print_line ("Usage: simple <command> [arguments]")
			console.print_line ("")
			console.print_line ("Package Commands:")
			console.print_line ("  install, i <pkg>...        Install packages with dependencies")
			console.print_line ("  update, up [<pkg>...]      Update packages (all if none specified)")
			console.print_line ("  uninstall, rm <pkg>        Remove a package")
			console.print_line ("  move, mv <pkg>             Move package to current directory")
			console.print_line ("")
			console.print_line ("Discovery Commands:")
			console.print_line ("  search, s <query>          Fuzzy search packages (FTS5)")
			console.print_line ("  search --deps <pkg>        Find packages using <pkg>")
			console.print_line ("  browse, b [<category>]     Browse packages by category")
			console.print_line ("  list                       List all available packages")
			console.print_line ("  universe, -u               Show all packages with install status")
			console.print_line ("  inventory, -i              List installed packages")
			console.print_line ("  info <pkg>                 Show package details")
			console.print_line ("  tree, deps [<pkg>]         Show dependency tree")
			console.print_line ("")
			console.print_line ("Project Commands:")
			console.print_line ("  init <name> [<pkg>...]     Create new project with dependencies")
			console.print_line ("")
			console.print_line ("Navigation:")
			console.print_line ("  goto, g <pkg>              Get path to package (use: cd (simple goto pdf))")
			console.print_line ("")
			console.print_line ("Diagnostics:")
			console.print_line ("  doctor, check              Diagnose environment issues")
			console.print_line ("  outdated                   Check for package updates")
			console.print_line ("  env [--save]               Show/save environment script")
			console.print_line ("  lock [--show]              Generate/show lock file")
			console.print_line ("")
			console.print_line ("Info:")
			console.print_line ("  version, -v                Show version")
			console.print_line ("  help, -h                   Show this help")
			console.print_line ("")
			console.print_line ("Examples:")
			console.print_line ("  simple install json web sql")
			console.print_line ("  simple -u                  # See what's available")
			console.print_line ("  simple init my_app json    # Create project with json")
			console.print_line ("  simple doctor              # Check for issues")
			console.print_line ("  simple tree json           # Show json dependencies")
			console.print_line ("  cd (simple goto pdf)       # Navigate to simple_pdf")
			console.print_line ("")
			console.print_line ("Notes:")
			console.print_line ("  Package names accept short form: 'pdf' = 'simple_pdf'")
			console.print_line ("")
			console.print_line ("Configuration:")
			console.print_line ("  Install directory: " + pkg.config.install_directory)
			console.print_line ("  Config directory:  " + pkg.config.config_directory)
		end

feature {NONE} -- Helper Features

	print_dependency_tree (a_name: STRING; a_depth: INTEGER)
			-- Print dependency tree starting at `a_name` with indentation `a_depth`.
		local
			l_info: detachable PKG_INFO
			l_indent: STRING
			l_status: STRING
			i: INTEGER
		do
			-- Create indentation
			create l_indent.make (a_depth * 2)
			from i := 1 until i > a_depth loop
				l_indent.append ("  ")
				i := i + 1
			end

			-- Get package info
			l_info := pkg.info (a_name)

			if attached l_info then
				if pkg.is_installed (l_info.name) then
					l_status := " [installed]"
				else
					l_status := " [missing]"
				end

				if a_depth = 0 then
					console.print_line (l_indent + l_info.name + l_status)
				else
					console.print_line (l_indent + "+-- " + l_info.name + l_status)
				end

				-- Recurse into dependencies
				across l_info.dependencies as dep loop
					print_dependency_tree (dep, a_depth + 1)
				end
			else
				console.print_line (l_indent + a_name + " [unknown]")
			end
		end

	check_command_exists (a_cmd: STRING): BOOLEAN
			-- Does command `a_cmd` execute successfully?
		local
			l_process: SIMPLE_PROCESS
		do
			create l_process.make
			l_process.run (a_cmd)
			Result := l_process.last_exit_code = 0
		end

	generate_ecf_template (a_args: ARRAYED_LIST [STRING]): STRING
			-- Generate ECF content from arguments (project name + dependencies).
		local
			l_project_name: STRING
			l_lib_name, l_env_var: STRING
		do
			l_project_name := a_args.first

			create Result.make (2000)
			Result.append ("<?xml version=%"1.0%" encoding=%"ISO-8859-1%"?>%N")
			Result.append ("<system xmlns=%"http://www.eiffel.com/developers/xml/configuration-1-23-0%" ")
			Result.append ("xmlns:xsi=%"http://www.w3.org/2001/XMLSchema-instance%" ")
			Result.append ("xsi:schemaLocation=%"http://www.eiffel.com/developers/xml/configuration-1-23-0 ")
			Result.append ("http://www.eiffel.com/developers/xml/configuration-1-23-0.xsd%" ")
			Result.append ("name=%"" + l_project_name + "%" uuid=%"00000000-0000-0000-0000-000000000000%">%N")
			Result.append ("%T<target name=%"" + l_project_name + "%">%N")
			Result.append ("%T%T<root class=%"APPLICATION%" feature=%"make%"/>%N")
			Result.append ("%T%T<option warning=%"warning%" syntax=%"provisional%" manifest_array_type=%"mismatch_warning%">%N")
			Result.append ("%T%T%T<assertions precondition=%"true%" postcondition=%"true%" check=%"true%" invariant=%"true%"/>%N")
			Result.append ("%T%T</option>%N")
			Result.append ("%T%T<setting name=%"console_application%" value=%"true%"/>%N")
			Result.append ("%T%T<setting name=%"concurrency%" value=%"scoop%"/>%N")
			Result.append ("%T%T<capability>%N")
			Result.append ("%T%T%T<concurrency support=%"scoop%"/>%N")
			Result.append ("%T%T%T<void_safety support=%"all%"/>%N")
			Result.append ("%T%T</capability>%N")
			Result.append ("%N")
			Result.append ("%T%T<!-- ISE Libraries -->%N")
			Result.append ("%T%T<library name=%"base%" location=%"$ISE_LIBRARY/library/base/base.ecf%"/>%N")
			Result.append ("%N")

			-- Add simple_* dependencies
			if a_args.count > 1 then
				Result.append ("%T%T<!-- Simple Eiffel Libraries -->%N")
				from a_args.start; a_args.forth until a_args.after loop
					l_lib_name := pkg.config.normalize_package_name (a_args.item)
					l_env_var := pkg.config.package_env_var_name (a_args.item)
					Result.append ("%T%T<library name=%"" + l_lib_name + "%" location=%"$" + l_env_var + "/" + l_lib_name + ".ecf%"/>%N")
				end
				Result.append ("%N")
			end

			Result.append ("%T%T<cluster name=%"src%" location=%".%" recursive=%"true%"/>%N")
			Result.append ("%T</target>%N")
			Result.append ("</system>%N")
		end

feature {NONE} -- Output Helpers

	print_package_brief (a_pkg: PKG_INFO)
			-- Print brief package info.
		require
			pkg_not_void: a_pkg /= Void
		local
			l_status: STRING
		do
			if pkg.is_installed (a_pkg.name) then
				l_status := " [installed]"
			else
				l_status := ""
			end

			console.print_line ("  " + a_pkg.name + l_status)
			if not a_pkg.description.is_empty then
				console.print_line ("    " + a_pkg.description)
			end
		end

	print_search_result (a_result: SEARCH_RESULT)
			-- Print search result with relevance info.
		require
			result_not_void: a_result /= Void
		local
			l_status: STRING
		do
			if attached a_result.package as p and then pkg.is_installed (p.name) then
				l_status := " [installed]"
			else
				l_status := ""
			end

			console.print_line ("  " + a_result.name + l_status + " (" + a_result.relevance_percent.out + "%% match)")
			if not a_result.snippet.is_empty then
				console.print_line ("    " + a_result.snippet)
			elseif not a_result.description.is_empty then
				console.print_line ("    " + a_result.description)
			end
		end

	print_package_detail (a_pkg: PKG_INFO)
			-- Print detailed package info.
		require
			pkg_not_void: a_pkg /= Void
		do
			console.print_line ("Package: " + a_pkg.name)
			console.print_line ("")

			if not a_pkg.description.is_empty then
				console.print_line ("Description:")
				console.print_line ("  " + a_pkg.description)
				console.print_line ("")
			end

			console.print_line ("Version: " + a_pkg.version)
			console.print_line ("GitHub:  " + a_pkg.github_url)

			if a_pkg.stars > 0 then
				console.print_line ("Stars:   " + a_pkg.stars.out)
			end

			console.print_line ("")

			if not a_pkg.dependencies.is_empty then
				console.print_line ("Dependencies:")
				across a_pkg.dependencies as dep loop
					console.print_line ("  - " + dep)
				end
				console.print_line ("")
			end

			if a_pkg.is_installed then
				console.print_line ("Status: INSTALLED")
				if attached a_pkg.local_path as l_path and then not l_path.is_empty then
					console.print_line ("Path:   " + l_path)
				else
					console.print_line ("Path:   " + pkg.config.package_path (a_pkg.name))
				end
				console.print_line ("EnvVar: " + pkg.config.package_env_var_name (a_pkg.name))
			else
				console.print_line ("Status: Not installed")
			end
		end

feature -- Constants

	version: STRING = "1.0.3"
			-- Package manager version

end

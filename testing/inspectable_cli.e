note
	description: "PKG_CLI that runs no command, with its helpers open to the tests."
	author: "Larry Rix"

class
	INSPECTABLE_CLI

inherit
	PKG_CLI
		export
			{ANY} check_command_exists
		end

create
	make_quiet

feature {NONE} -- Initialization

	make_quiet
			-- Set up without parsing arguments or running a command.
		do
			create console.make
			create pkg.make
		end

end

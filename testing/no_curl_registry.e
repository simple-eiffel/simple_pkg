note
	description: "PKG_REGISTRY whose curl cannot be started, for the tests."
	author: "Larry Rix"

class
	NO_CURL_REGISTRY

inherit
	INSPECTABLE_REGISTRY
		redefine
			curl_program
		end

create
	make

feature {NONE} -- Implementation

	curl_program: STRING
			-- A program that does not exist.
		do
			Result := "no_such_curl_program"
		end

end

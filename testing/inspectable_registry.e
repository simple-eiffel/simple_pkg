note
	description: "PKG_REGISTRY with its HTTP call open to the tests."
	author: "Larry Rix"

class
	INSPECTABLE_REGISTRY

inherit
	PKG_REGISTRY
		export
			{ANY} http_get
		end

create
	make

end

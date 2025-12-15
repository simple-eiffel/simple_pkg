note
	description: "[
		FTS5 full-text search engine for package discovery.

		Uses an in-memory SQLite database with FTS5 for fuzzy package search.
		Index is built from package metadata (ECF files).

		Usage:
			create search.make
			search.build_index (packages)  -- Build from PKG_INFO list
			results := search.search ("json parser")  -- Fuzzy search
			results := search.browse_category ("data-formats")  -- Browse by category
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	PKG_SEARCH

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize search engine with in-memory database.
		do
			create database.make_memory
			create indexed_packages.make (70)
			is_index_built := False
		ensure
			database_open: database.is_open
		end

feature -- Access

	database: SIMPLE_SQL_DATABASE
			-- In-memory SQLite database

	indexed_packages: HASH_TABLE [PKG_INFO, STRING]
			-- Cached package info by name

	is_index_built: BOOLEAN
			-- Has the search index been built?

feature -- Index Management

	build_index (a_packages: ARRAYED_LIST [PKG_INFO])
			-- Build FTS5 search index from package list.
		require
			database_open: database.is_open
			packages_not_void: a_packages /= Void
		local
			l_fts: SIMPLE_SQL_FTS5
		do
			-- Drop existing table if any
			database.execute ("DROP TABLE IF EXISTS packages_fts")

			-- Create FTS5 virtual table
			l_fts := database.fts5
			if l_fts.is_fts5_available then
				l_fts.create_table_with_options (
					"packages_fts",
					{ARRAY [READABLE_STRING_8]} <<"name", "description", "keywords", "category">>,
					"tokenize='porter'"  -- Porter stemming for better matching
				)

				-- Index all packages
				across a_packages as pkg loop
					index_package (pkg)
				end

				-- Optimize index
				l_fts.optimize ("packages_fts")
				is_index_built := True
			end
		ensure
			index_built: is_index_built
		end

	index_package (a_package: PKG_INFO)
			-- Add or update a package in the search index.
		require
			database_open: database.is_open
			package_not_void: a_package /= Void
		local
			l_sql: STRING
			l_keywords: STRING
		do
			-- Build keywords string
			l_keywords := a_package.keywords_string
			if l_keywords.is_empty then
				l_keywords := a_package.short_name  -- Use short name as fallback keyword
			end

			-- Insert into FTS5 table
			l_sql := "INSERT INTO packages_fts (name, description, keywords, category) VALUES ('" +
				escape_sql (a_package.name) + "', '" +
				escape_sql (a_package.description) + "', '" +
				escape_sql (l_keywords) + "', '" +
				escape_sql (a_package.category) + "')"

			database.execute (l_sql)

			-- Cache package info
			indexed_packages.force (a_package, a_package.name)
		end

	clear_index
			-- Clear the search index.
		require
			database_open: database.is_open
		do
			database.execute ("DELETE FROM packages_fts")
			indexed_packages.wipe_out
			is_index_built := False
		ensure
			not_built: not is_index_built
		end

feature -- Searching

	search (a_query: STRING): ARRAYED_LIST [SEARCH_RESULT]
			-- Fuzzy search for packages matching query.
			-- Returns results ranked by relevance (BM25).
		require
			query_not_empty: not a_query.is_empty
			index_built: is_index_built
		local
			l_result: SIMPLE_SQL_RESULT
			l_fts: SIMPLE_SQL_FTS5
			l_search_result: SEARCH_RESULT
			l_name: STRING
		do
			create Result.make (20)
			l_fts := database.fts5

			-- Search with BM25 ranking and snippets
			l_result := database.query (
				"SELECT name, description, keywords, category, " +
				"snippet(packages_fts, 1, '<b>', '</b>', '...', 32) as snippet, " +
				"bm25(packages_fts) as rank " +
				"FROM packages_fts " +
				"WHERE packages_fts MATCH '" + escape_fts_query (a_query) + "' " +
				"ORDER BY rank " +
				"LIMIT 50"
			)

			across l_result.rows as row loop
				l_name := row.string_value ("name").to_string_8
				create l_search_result.make (
					l_name,
					row.string_value ("description").to_string_8,
					row.string_value ("snippet").to_string_8,
					row.real_value ("rank")
				)
				l_search_result.set_category (row.string_value ("category").to_string_8)

				-- Link to full package info if available
				if attached indexed_packages.item (l_name) as pkg then
					l_search_result.set_package (pkg)
				end

				Result.extend (l_search_result)
			end
		ensure
			result_attached: Result /= Void
		end

	search_by_name (a_name: STRING): ARRAYED_LIST [SEARCH_RESULT]
			-- Search packages by name (prefix matching).
		require
			name_not_empty: not a_name.is_empty
			index_built: is_index_built
		do
			-- Use FTS5 prefix matching
			Result := search (a_name + "*")
		ensure
			result_attached: Result /= Void
		end

	browse_category (a_category: STRING): ARRAYED_LIST [PKG_INFO]
			-- Get all packages in a category.
		require
			category_not_empty: not a_category.is_empty
			index_built: is_index_built
		local
			l_result: SIMPLE_SQL_RESULT
			l_name: STRING
		do
			create Result.make (20)

			l_result := database.query (
				"SELECT name FROM packages_fts WHERE category = '" +
				escape_sql (a_category) + "' ORDER BY name"
			)

			across l_result.rows as row loop
				l_name := row.string_value ("name").to_string_8
				if attached indexed_packages.item (l_name) as pkg then
					Result.extend (pkg)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	list_categories: ARRAYED_LIST [STRING]
			-- Get list of all categories with package counts.
		require
			index_built: is_index_built
		local
			l_result: SIMPLE_SQL_RESULT
			l_cat: STRING
		do
			create Result.make (15)

			l_result := database.query (
				"SELECT DISTINCT category FROM packages_fts " +
				"WHERE category != '' ORDER BY category"
			)

			across l_result.rows as row loop
				l_cat := row.string_value ("category").to_string_8
				if not l_cat.is_empty then
					Result.extend (l_cat)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	search_by_dependency (a_dep_name: STRING): ARRAYED_LIST [PKG_INFO]
			-- Find packages that depend on a_dep_name.
		require
			dep_not_empty: not a_dep_name.is_empty
		local
			l_normalized: STRING
		do
			create Result.make (20)
			l_normalized := if a_dep_name.starts_with ("simple_") then a_dep_name else "simple_" + a_dep_name end

			across indexed_packages as pkg loop
				if pkg.dependencies.has (l_normalized) then
					Result.extend (pkg)
				end
			end
		ensure
			result_attached: Result /= Void
		end

feature -- Status

	package_count: INTEGER
			-- Number of indexed packages.
		do
			Result := indexed_packages.count
		end

feature {NONE} -- Implementation

	escape_sql (a_string: STRING): STRING
			-- Escape string for SQL.
		local
			i: INTEGER
		do
			create Result.make (a_string.count + 10)
			from i := 1 until i > a_string.count loop
				if a_string.item (i) = '%'' then
					Result.append ("''")
				else
					Result.append_character (a_string.item (i))
				end
				i := i + 1
			end
		end

	escape_fts_query (a_query: STRING): STRING
			-- Escape query for FTS5 MATCH.
		local
			i: INTEGER
			c: CHARACTER
			has_apostrophe: BOOLEAN
		do
			-- Check for apostrophes
			across a_query as ic loop
				if ic.item = '%'' then
					has_apostrophe := True
				end
			end

			create Result.make (a_query.count + 10)

			if has_apostrophe then
				-- Use double-quote phrase matching
				Result.append_character ('"')
				from i := 1 until i > a_query.count loop
					c := a_query.item (i)
					if c = '"' then
						Result.append_character ('"')
						Result.append_character ('"')
					elseif c = '%'' then
						Result.append_character ('%'')
						Result.append_character (c)
					else
						Result.append_character (c)
					end
					i := i + 1
				end
				Result.append_character ('"')
			else
				from i := 1 until i > a_query.count loop
					c := a_query.item (i)
					if c = '%'' or c = '"' then
						Result.append_character ('%'')
						Result.append_character (c)
					else
						Result.append_character (c)
					end
					i := i + 1
				end
			end
		end

feature -- Cleanup

	close
			-- Close database to prevent segfault during garbage collection.
		do
			if database.is_open then
				database.close
			end
		ensure
			database_closed: not database.is_open
		end

invariant
	database_attached: database /= Void
	indexed_packages_attached: indexed_packages /= Void

end

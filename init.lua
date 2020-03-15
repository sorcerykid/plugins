--------------------------------------------------------
-- Minetest :: Pluggable Helpers Mod (plugins)
--
-- See README.txt for licensing and other information.
-- Copyright (c) 2020, Leslie E. Krause
--
-- ./games/minetest_game/mods/plugins/init.lua
--------------------------------------------------------

plugins = { }

local http_req = minetest.request_http_api( )
local mod_path = minetest.get_modpath( "plugins" )
local config = {
	remote_host = "plugins.mytuner.net",
	remote_path = "/source",
}

assert( http_req ~= nil, "Failed to construct HTTP request object" )

local registered_helpers = { }
local downloaded_helpers = { }
local registered_classes = { }
local helper_stats = { registered = 0, downloaded = 0 }

local globals = {
	"next",
	"pairs",
	"ipairs",
	"assert",
	"print",
	"error",
	"dofile",
	"loadfile",
	"loadstring",
	"getmetatable",
	"setmetatable",
	"pcall",
	"rawequal",
	"rawget",
	"rawset",
	"select",
	"tonumber",
	"tostring",
	"type",
	"unpack",
	"dump",
}

local license_defs = {
	["AGPLv2"] = true,
	["AGPLv3"] = true,
	["Apache 2.0"] = true,
	["BSD 2-Clause"] = true,
	["BSD 3-Clause"] = true,
	["CC0"] = true,
	["CC BY 3.0"] = true,
	["CC BY 4.0"] = true,
	["CC BY-NC-SA 3.0"] = true,
	["CC BY-SA 3.0"] = true,
	["CC BY-SA 4.0"] = true,
	["EUPLv1.2"] = true,
	["GPLv2"] = true,
	["GPLv3"] = true,
	["ISC"] = true,
	["LGPLv2.1"] = true,
	["LGPLv3"] = true,
	["MIT"] = true,
}

local _ = { }

local function is_match( text, glob )
	-- use array for captures
	_ = { string.match( text, glob ) }
	return #_ > 0 and _ or nil
end

local function from_version( version )
	return version[ 1 ] .. "." .. version[ 2 ]
end

local function to_version( val )
	if is_match( val, "^([0-9]+).([0-9]+)([ab]?)$" ) then
		return { tonumber( _[ 1 ] ), tonumber( _[ 2 ] ), _[ 3 ] }
	end
	return nil
end

local function to_depends( val )
	local res = { }
	for _, cur_id in ipairs( val ) do
		local data = string.split( cur_id, "/" )

		table.insert( res, { data[ 1 ], to_version( data[ 2 ] or "1.0" ) } )
	end
	return res
end

local function split_id( id )
	if is_match( id, "^([a-z]+)%.([a-z][a-z0-9_]+)$" ) or is_match( id, "^([A-Z][A-Za-z0-9]+)$" ) then
		return _[ 1 ], _[ 2 ]
	end
	return nil
end

local function split_extra_id( extra_id )
	local data = type( extra_id ) == "table" and extra_id or string.split( extra_id, "/" )

	if #data == 1 or #data == 2 then
		return data[ 1 ], to_version( data[ 2 ] or "1.0" )
	end
	return nil
end

local function validate_extra_id( id )
	return string.find( id, "^[a-z]+%.[a-z][a-z0-9_]+/[0-9]+%.[0-9]+$" ) ~= nil or string.find( id, "^[A-Z][A-Za-z0-9]+/[0-9]+%.[0-9]+$" ) ~= nil
end

local function validate_id( id )
	return string.find( id, "^[a-z]+%.[a-z][a-z0-9_]+$" ) ~= nil or string.find( id, "^[A-Z][A-Za-z0-9]+$" ) ~= nil
end

local function check_version( cur_version, min_version )
	if cur_version[ 1 ] < min_version[ 1 ] or cur_version[ 1 ] == min_version[ 1 ] and cur_version[ 2 ] < min_version[ 2 ] then
		return false
	end
	return true
end

local function create_sandbox( func, imports )
	local env = { }

	for _, name in ipairs( globals ) do
		env[ name ] = _G[ name ]
	end

	for _, name in ipairs( imports ) do
		local class, method = split_id( name )

		if not class or not registered_classes[ class ] or method and not registered_classes[ class ][ method ] then
			error( "create_sandbox(): Attempt to import unknown class or method" )
		elseif method then
			env[ method ] = registered_classes[ class ][ method ]
		else
			env[ class ] = registered_classes[ class ]
		end
	end

	setfenv( func, env )
	setmetatable( env, { __index = registered_classes } )
end

local function convert_record( def )
	if not def or def == "" then
		minetest.log( "error", "No helper definition found, aborting" )
		return nil
	end

	local record = { }

	setfenv( def, record )
	local status, func = pcall( def )

	if type( func ) ~= "function" then
		minetest.log( "error", "Missing function in helper definition, aborting" )
		return nil
	elseif record.prototype ~= nil and type( record.prototype ) ~= "table" then
		minetest.log( "error", "Invalid prototype in helper definition, aborting" )
		return nil
	elseif type( record.version ) ~= "string" or not string.find( record.version, "^[0-9]+%.[0-9]+$" ) then
		minetest.log( "error", "Invalid or missing 'version' field in helper definition, aborting" )
		return nil
	elseif type( record.author ) ~= "string" or not string.find( record.author, "^[a-zA-Z0-9_-]+$" ) then
		minetest.log( "error", "Invalid or missing 'author' field in helper definition, aborting" )
		return nil
	elseif type( record.license ) ~= "string" or not license_defs[ record.license ] then
		minetest.log( "error", "Invalid or missing 'license' field in helper definition, aborting" )
		return nil
	elseif type( record.depends ) ~= "table" then
		minetest.log( "error", "Missing 'depends' field in helper definition, aborting" )
		return nil
	elseif type( record.imports ) ~= "table" then
		minetest.log( "error", "Missing 'imports' field in helper definition, aborting" )
		return nil
	end

	for _, cur_id in ipairs( record.depends ) do
		if not validate_id( cur_id ) and not validate_extra_id( cur_id ) then
			minetest.log( "error", "Invalid 'depends' field in helper definition, aborting" )
			return nil
		end
	end

	for _, cur_id in ipairs( record.imports ) do
		if not validate_id( cur_id ) then
			minetest.log( "error", "Invalid 'imports' field in helper definition, aborting" )
			return nil
		end
	end

	return {
		id = record.id,
		author = record.author,
		license = record.license,
		version = to_version( record.version ),
		depends = to_depends( record.depends ),
		imports = record.imports,
		is_required = false,
		func = func,
		this = record.prototype,
	}
end

local function load_repository( )
	minetest.log( "action", "Loading helper definitions from local repository" )

	for _, id in ipairs( minetest.get_dir_list( mod_path .. "/source", false ) ) do
		local record = convert_record( loadfile( mod_path .. "/source/" .. id ) )
		
		if not record then
			error( "load_repository(): Malformed helper definition" ) 
		end

		local class, method = split_id( id )

		if not class then
			error( "load_repository(): Malformed helper ID" )
		elseif method and ( not registered_classes[ class ] or type( registered_classes[ class ] ) ~= "table" ) then
			error( "load_repository(): Unrecognized helper class" )
		end

		registered_helpers[ id ] = record
		helper_stats.registered = helper_stats.registered + 1
	end
end

local function simple_http_request( uri, timeout )
	local status = http_req.fetch_async( { url = uri, timeout = timeout, user_agent = "Pluggable Helpers/1.0" } )
	local result

	-- sleep until request completed
	while true do
		local t = os.clock( )
		while os.clock( ) - t <= 0.1 do end

		local result = http_req.fetch_async_get( status )

		if result.completed then
			return result
		end
	end	
end

local function request( id, version )
	minetest.log( "action", "Requesting helper '" .. id .. "' from remote repository '" .. config.remote_host .. "'" )

	local results = simple_http_request( string.format( "http://%s/%s", config.remote_host .. config.remote_path, id ), 2.0 )

	if results.timeout then
		minetest.log( "error", "Failed to request helper '" .. id .. "', aborting" )
		error( "request(): Connection timed out." ) 

	elseif not results.succeeded then
		minetest.log( "error", "Failed to request helper '" .. id .. "', aborting" )
		if results.code == 404 then
			error( "request(): Resource not found (status 404)" )
		elseif results.code == 403 then
			error( "request(): Permission denied (status 403)" )
		elseif results.code == 418 then
			error( "request(): I'm a teapot, short and stout (status 418)" )
		elseif results.code == 500 then
			error( "request(): Internal server error (status 500)" )
		elseif results.code == 504 then
			error( "request(): Gateway timed out (status 504)" )
		else
			error( "request(): Unhandled exception" )
		end
	end

	local record = convert_record( loadstring( results.data ) )

	if not record then
		minetest.log( "error", "Failed to request helper '" .. id .. "', aborting" )
		error( "request(): Malformed helper definition, '" .. results.data .. "'" )
	elseif not check_version( record.version, version ) then
		minetest.log( "error", "Failed to request helper '" .. id .. "', aborting" )
		error( "request(): Insufficient helper version, '" .. from_version( record.version ) .. "'" )
	end

	if #record.depends > 0 then
		minetest.log( "action", "Resolving dependencies for helper '" .. id .. "'" )
	end

	-- recursively request dependencies
	for idx, elem in ipairs( record.depends ) do
		local cur_id = elem[ 1 ]
		local cur_version = elem[ 2 ]

		-- sanity check for dependency loop
		if cur_id == id or downloaded_helpers[ cur_id ] then
			minetest.log( "error", "Failed to request helper '" .. id .. "', aborting" )
			error( "request(): Unexpected dependency loop" )
		end

		-- if helper is not registered or helper is inadequate version, then download
		if not registered_helpers[ cur_id ] or not check_version( registered_helpers[ cur_id ].version, cur_version ) then
			request( cur_id, cur_version )
		end
	end

	registered_helpers[ id ] = record
	downloaded_helpers[ id ] = results.data
	helper_stats.downloaded = helper_stats.downloaded + 1

	return record
end

local function install_from_queue( )
	for id, source in pairs( downloaded_helpers ) do
		local helper = registered_helpers[ id ]
		local date_spec = os.date( "%c" )
		local host_spec = config.remote_host
		local path_spec = config.remote_path

		minetest.log( "action", "Installing required helper '" .. id .. "' to local repository" )

		local file = io.open( mod_path .. "/source/" .. id, "w" )
		if not file then
			minetest.log( "error", "Failed to install helper '" .. id .. "', aborting" )
			error( "install_from_queue(): Unable to write repository" )
		end

		file:write( "----------------------------------------------------\n" )
		file:write( "-- Installed on " .. date_spec .. "\n" )
		file:write( "-- \n" )
		file:write( "-- http://" .. host_spec .. path_spec .. "/" .. id  .. "\n" )
		file:write( "----------------------------------------------------\n\n" )
		file:write( source )
		file:close( )
	end

	downloaded_helpers = { }
end

local function uninstall_orphans( )
	-- uninstall orphaned helpers automatically
	for id, helper in pairs( registered_helpers ) do
		if not helper.is_required then
			minetest.log( "action", "Uninstalling orphaned helper '" .. id .. "' from local repository" )

			if not os.remove( mod_path .. "/source/" .. id ) then
				minetest.log( "error", "Failed to uninstall helper '" .. id .. "', aborting" )
				error( "uninstall_orphans(): Unable to write repository" )
			end
		end
	end
end

local function require( helper, class, method )
	if helper.is_required then
		return helper.this or helper.func  -- it's already been required, so skip processing
	end

	helper.is_required = true

	-- recursively require dependencies
	for _, elem in ipairs( helper.depends ) do
		local cur_id = elem[ 1 ]
		local cur_helper = registered_helpers[ cur_id ]
		local cur_class, cur_method = split_id( cur_id )

		if not cur_helper or not cur_class then
			minetest.log( "error", "Failed to require helper '" .. cur_id .. "', aborting" )
			error( "require(): Missing dependency" )
		end

		require( cur_helper, cur_class, cur_method )
	end

	-- prepare sandbox with globals and imports
	create_sandbox( helper.func, helper.imports )

	if method then
		_G[ class ][ method ] = helper.func
	elseif not helper.this then
		_G[ class ] = helper.func
		registered_classes[ class ] = helper.func  -- add class to sandbox
	else
		helper.func( helper.this )
	end

	return helper.this or helper.func
end

--------------------
-- Public Methods --
--------------------

plugins.include = function ( extra_id )
	local id, version = split_extra_id( extra_id )

	assert( id, "plugins.include(): Malformed helper ID" )

	local class, method = split_id( id )
	local helper = registered_helpers[ id ]

	assert( class, "plugins.include(): Malformed helper ID" )
	assert( not method, "plugins.include()" )

	if helper then	
		if not check_version( helper.version, version ) then
			minetest.log( "warning", "Required helper '" .. id .. "' found, but insufficient version" )
			helper = request( id, version )
			install_from_queue( )
			return require( helper, class )
		else
			return require( helper, class )
		end
	else
		minetest.log( "warning", "Required helper '" .. id .. "' not found" )
		helper = request( id, version )
		install_from_queue( )
		return require( helper, class )
	end
end

plugins.require = function ( extra_id )
	local id, version = split_extra_id( extra_id )

	assert( id, "plugins.require(): Malformed helper ID" )

	local class, method = split_id( id )
	local helper = registered_helpers[ id ]

	assert( class, "plugins.require(): Malformed helper ID" )
	assert( not method or registered_classes[ class ], "plugins.require(): Unrecognized helper class" )

	if helper then
		if not check_version( helper.version, version ) then
			minetest.log( "warning", "Required helper '" .. id .. "' found, but insufficient version" )
			helper = request( id, version )
			install_from_queue( )
			return require( helper, class, method )
		else
			return require( helper, class, method )
		end
	elseif class and method then
		if not _G[ class ][ method ] then
			minetest.log( "warning", "Required helper '" .. id .. "' not found" )
			helper = request( id, version )
			install_from_queue( )
			return require( helper, class, method )
		end
	elseif class then
		if not _G[ class ] then
			minetest.log( "warning", "Required helper '" .. id .. "' not found" )
			helper = request( id, version )
			install_from_queue( )
			return require( helper, class )
		end
	end
end

plugins.register_class = function ( name, ref )
	if type( ref ) == "function" and not string.find( name, "^[A-Z][A-Za-z0-9]+$" ) or type( ref ) == "table" and not string.find( name, "^[a-z0-9_]+$" ) then
		error( "register_class: Improperly formatted class name, '" .. name .. "'" )
	elseif not type( ref ) == "function" and not type( ref ) == "table" then
		error( "register_class: Unsupported class type, " .. type( ref ) )
	end
	registered_classes[ name ] = ref
end

plugins.register_class( "minetest", minetest )
plugins.register_class( "string", string )
plugins.register_class( "math", math )
plugins.register_class( "table", table )
plugins.register_class( "os", table )
plugins.register_class( "is", table )
plugins.register_class( "debug", debug )
plugins.register_class( "PerlinNoise", PerlinNoise )
plugins.register_class( "PerlinNoiseMap", PerlinNoiseMap )
plugins.register_class( "VoxelManip", VoxelManip )
plugins.register_class( "VoxelArea", VoxelArea.new )

load_repository( )

minetest.after( 0.0, function ( )
	uninstall_orphans( )

	plugins.require = function ( )
		error( "plugins.require(): Delayed invocation not permitted, aborting" )
	end
	plugins.include = function ( )
		error( "plugins.include(): Delayed invocation not permitted, aborting" )
	end
end )

------------------------------
-- Registered Chat Commands --
------------------------------

minetest.register_chatcommand( "plugins", {
	description = "List all plugins installed in local registry",
	privs = { server = true },
	func = function( player_name, param )
		local res = ""

--		for i, v in pairs( registered_helpers )
--			table.insert( res, v.id )
--		end
	end
} )

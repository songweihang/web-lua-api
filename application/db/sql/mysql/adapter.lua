-- perf
local error = error
local ipairs = ipairs
local pairs = pairs
local require = require
local tonumber = tonumber
local function tappend(t, v) t[#t+1] = v end

-- settings
local timeout_subsequent_ops = 1000 -- 1 sec
local max_idle_timeout = 10000 -- 10 sec
local max_packet_size = 1024 * 1024 -- 1MB


local MySql = {}
MySql.default_database = 'mysql'

local function mysql_connect(options)
    -- ini mysql
    local mysql = require "resty.mysql"
    -- create sql object
    local db, err = mysql:new()
    if not db then error("failed to instantiate mysql: " .. err) end
    -- set 1 second timeout for suqsequent operations
    db:set_timeout(timeout_subsequent_ops)
    -- connect to db
    local db_options = {
        host = options.host,
        port = options.port,
        database = options.database,
        user = options.user,
        password = options.password,
        max_packet_size = max_packet_size
    }

    local ok, err, errno, sqlstate = db:connect(db_options)
    if not ok then error("failed to connect to mysql: " .. err .. ": " .. errno .. " " .. sqlstate) end
    -- return
    return db
end

local function mysql_keepalive(db, options)
    -- put it into the connection pool
    local ok, err = db:set_keepalive(max_idle_timeout, options.pool)
    if not ok then error("failed to set mysql keepalive: ", err) end
end

-- quote
function MySql.quote(options, str)
    return ngx.quote_sql_str(str)
end

-- execute query on db
local function db_execute(options, db, sql)
    local res, err, errno, sqlstate = db:query(sql)
    return res, err, errno, sqlstate
end

-- execute a query
function MySql.execute(options, sql)

    -- get db object
    local db = mysql_connect(options)
    -- execute query
    local res, err, errno, sqlstate = db_execute(options, db, sql)
    -- keepalive
    mysql_keepalive(db, options)

    if not res then 
        return 500,"bad mysql result: " .. err .. ": " .. errno .. " " .. sqlstate
    end
    -- return
    return 200,res
end

-- execute a query and return the last ID
function MySql.execute_and_return_last_id(options, sql)
    -- get db object
    local db = mysql_connect(options)

    -- execute query
    local res, err, errno, sqlstate = db_execute(options, db, sql)
    if not res then 
        return 500,"bad mysql result: " .. err .. ": " .. errno .. " " .. sqlstate
    end
    -- get last id
    local res = db_execute(options, db, "SELECT LAST_INSERT_ID() AS id;")
    -- keepalive
    mysql_keepalive(db, options)
    return 200,tonumber(res[1].id)
end

return MySql

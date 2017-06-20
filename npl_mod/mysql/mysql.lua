--[[
	Author: CYF
	Date: 2017年6月19日
	EMail: me@caoyongfeng.com
	Desc: 对mysql操作的封装
]]

NPL.load('common');
local driver = require('luasql.mysql');


local mysql = {};


--[[
	user: 用户名
	pwd: 密码
	db: 要连接的数据库名
	host: 要连接的数据库的ip或域名，默认 '127.0.0.1'
	port: 要连接的数据库的端口，默认 3306
]]
function mysql:new(o)
	o = o or {};
	if(not host) then
		host = '127.0.0.1';
	end
	if(not port) then
		port = 3306;
	end
	setmetatable(o, self);
	self.__index = self;
	return o;
end


function mysql:connect()
	local env = driver.mysql();
	local cn = env:connect(self.db, self.user, self.pwd, self.host, self.port);
	return cn, env;
end


function mysql:exec(sql, sqlParams, cn, env)
	if(not cn or not env) then
		cn, env = self:connect();
	end
	
	if(sqlParams) then
		for k, v in pairs(sqlParams) do
			sql = sql:replace('%?(%w+)', function(w)
				local v = sqlParams[w];
				local ty = type(v);
				if(ty == 'boolean') then
					if(v) then
						v = 1;
					else
						v = 0;
					end
				elseif(ty == 'string') then
					v = '"' .. cn:escape(v) .. '"';
				end
				return v;
			end);
		end
	end
	
	return cn:execute(sql), cn, env;
end


-- cn, env 参数是可选的
-- 执行一条带参数的非查询sql，返回受影响的行数和新插入数据的id（如果有）,
-- 不关闭连接，连接对象和连接环境会作为第一个数据和第二个数据返回
-- return cn, env, cnt, lastId
function mysql:_execNonQuery(sql, sqlParams, cn, env)
	local cur, cn, env = self:exec(sql, sqlParams, cn, env);
	local cur_type = type(cur);
	local lastId = nil;
	if(cur_type == 'number') then
		lastId = cn:getlastautoid();
	end
	return cn, env, cur, lastId;
end


-- cn, env 参数是可选的
-- 执行一条带参数的非查询sql，返回受影响的行数和新插入数据的id
-- 关闭连接，如果在执行时传递了cn、env参数，则不会关闭连接
-- return cnt, lastId
-- 若失败，cnt为nil
function mysql:execNonQuery(sql, sqlParams, cn, env)
	local cn, env, cnt, lastId = self:_execNonQuery(sql, sqlParams, cn, env);
	if(not cn) then
		cn:close();
		env:close();
	end
	return cnt, lastId;
end


-- cn, env 参数是可选的
-- 执行一条带参数的查询sql，
-- 不关闭连接，连接对象和连接环境会作为第一个数据和第二个数据返回
-- return cn, env, rows
function mysql:_execRows(sql, sqlParams, cn, env)
	local cur, cn, env = self:exec(sql, sqlParams, cn, env);
	local results = nil;
	local cur_type = type(cur);
	if(cur_type == 'userdata') then
		results = {};
		local row = cur:fetch({}, 'a');
		while row do
			local tb = {};
			for k, v in pairs(row) do
				tb[k] = v;
			end
			table.insert(results, tb);
			row = cur:fetch(row, 'a')
		end
		cur:close();
	end
	return cn, env, results;
end


-- cn, env 参数是可选的
-- 执行一条带参数的查询sql，
-- 关闭连接，如果在执行execRows()时传递了cn、env参数，则不会关闭连接
-- return rows
function mysql:execRows(sql, sqlParams, cn, env)
	local cn, env, rows = self:_execRows(sql, sqlParams, cn, env);
	if(not cn) then
		cn:close();
		env:close();
	end
	return rows;
end


-- cn, env 参数是可选的
-- 执行一条带参数的查询sql，返回查询到的第一条数据，
-- 不关闭连接，连接对象和连接环境会作为第一个数据和第二个数据返回
-- return cn, env, row
function mysql:_execRow(sql, sqlParams, cn, env)
	local cur, cn, env = self:exec(sql, sqlParams, cn, env);
	local result = nil;
	local cur_type = type(cur);
	if(cur_type == 'userdata') then
		local row = cur:fetch({}, 'a');
		if row then
			result = {};
			for k, v in pairs(row) do
				result[k] = v;
			end
		end
		cur:close();
	end
	return cn, env, result;
end


-- cn, env 参数是可选的
-- 执行一条带参数的查询sql，返回查询到的第一条数据，
-- 关闭连接，如果在执行时传递了cn、env参数，则不会关闭连接
-- return row
function mysql:execRow(sql, sqlParams, cn, env)
	local cn, env, result = self:_execRow(sql, sqlParams, cn, env);
	if(not cn) then
		cn:close();
		env:close();
	end
	return result;
end



-- 在事务中执行。
-- 第一个参数是包含在事务中执行的语句的function，该function会接收三个参数：
--		cn, env, returnTrans
--		第三个参数 returnTrans 是一个function，当数据操作完毕后，需要调此function通知事务程序已经执行完毕事务了，
--			此function可接收两个参数，
--				第一个参数为true或false，当为true时，事务将提交，否则回滚。
--				第二个参数是可选的，如果希望在回调中
function mysql:execInTrans(execFun, callbackFun)
	local cn, env = self:connect();
	cn:setautocommit(false);
	execFun(cn, env, function(issuccess, result)
		if(issuccess) then
			cn:commit();
		else
			cn:rollback();
		end
		cn:close();
		env:close();
		callbackFun(issuccess, result);
	end);
	
	return cn, env;
end


return mysql;
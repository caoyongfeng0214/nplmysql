提供此 package 的目的是为了让NPL开发者能更方便地操作MySQL。

### 如果你正在使用 windows 操作系统，则需要 [点击这里](https://github.com/LiXizhi/luasql/releases) 下载该页面中提供的两个 .dll 文件，并将它们放入到你的NPLRuntime文件夹的 win --> bin 目录下。　　

### 示例：

```
local mysql = NPL.load('mysql'):new({
    user = 'root',
	  pwd = '00000',
	  db = 'test'
});

-- execNonQuery() 用来执行一个“非查询SQL”
-- 返回数据中，第一个为受影响的行数，第二个为新加入的数据（如果是 insert 操作的话）的ID（如果是自增的话）
-- 如果失败，则 num 为 nil
local num, newId = mysql:execNonQuery('insert into users(name, age) values(?name, ?age)', { name='CYF', age=10 });
```

```
-- 返回查找到的所有数据，返回值是一个数组（table）。
-- 如果没有找到任何数据，仍然会返回一个空的数组。
local rows = mysql:execRows('select * from users where age > ?age', { age = 10 });
```

```
-- 与 execRows() 不同的是，execRow() 无论查找到的数据有多少，它只会返回查找到的第一条数据，
-- 如果没有查找到任何数据，则返回 nil
local row = mysql:execRow('select * from users where age > ?age', { age = 10 });
```

```
-- 返回查找到的数据中的第一条数据的第一列的值。
-- 如果没有找到任何数据，则返回 nil
local val = mysql:execScalar('select * from users where age > ?age', { age = 10 });
```

```
-- 若希望使用事务，则可使用 mysql:execInTrans()
-- 第一个参数是一个 function，会有两个参数传进来，
-- 	第一个参数是 cn，在你自己的代码中调用相关方法执行SQL语句时，应将这个数据作为参数传过去（如【1】处的 mysql:execNonQuery() 的最后一个参数），否则执行语句将不受事务控制。
-- 	当事务逻辑处理完毕后，应该主动调用第二个参数 returnTrans 来结束事务。
--      returnTrans 是一个function，能接受两个参数，
--          第一个参数为 boolean 值，若为 true，则会提交事务，若为 false，则会回滚事务，
--          第二个参数是可选的，若希望将数据传递给 execInTrans() 的第二个参数，则使用此参数
-- 第二个参数也是function，是事务处理完毕之后的回调。可选。
--	 将有两个参数传过来，分别为上面传递给 returnTrans 方法的两个参数。
--	     第一个参数表示事务是否成功，
--	     第二个参数是自定义的一些数据
mysql:execInTrans(function(cn, returnTrans)
    local num, newId = mysql:execNonQuery('insert into users(name, age) values(?name, ?age)', { name='CYF', age=10 }, cn);  -- 【1】
    if(num and newId > 100) then
        returnTrans(false);
    else
        local num, newId = mysql:execNonQuery('insert into users(name, age) values(?name, ?age)', { name='Amanda', age=8 }, cn);
        if(num) then
            returnTrans(true, newId); -- 【2】
        else
            returnTrans(false);
        end
    end
end, function(issuccess, result)
	  -- do somthing
    -- 这里的 issuccess 是一个 boolean 值，表示事务中的所有操作是否均已成功执行
    -- result 是传给 returnTrans 的第二个参数，即【2】处的 newId
end);
```

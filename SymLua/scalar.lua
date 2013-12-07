local SymLua = require 'SymLua'
local is = SymLua.is
local is_op = SymLua.is_op

local SCALAR = 'scalar'

add_dtype(SCALAR)

add_op('add', '+', SCALAR,
       function(...)
	 local args = table.pack(...)
	 local dict = { }
	 local vars = { }
	 -- apply merge with add childs, and count variables occurences
	 for i,v in ipairs(args) do
	   if is(v,CONSTANT) then dict.cte = (dict.cte or 0) + v()
	   else
	     local list = { v }
	     if is_op(v,'add') then list = v.args end
	     for j,vj in ipairs(list) do
	       dict[vj.name] = (dict[vj.name] or 0) + 1
	       vars[vj.name] = vj
	     end
	   end
	 end
	 -- simplify replicated variables
	 local result = { }
	 if dict.cte then table.insert(result, dict.cte) end
	 for i,v in ipairs(vars) do
	   if dict[v.name] > 1 then v = dict[v.name] * v end
	   table.insert(resut, v)
	 end
	 return commutative(result)
       end,
       function(...)
	 local args = table.pack(...)
	 local aux = args[1]()
	 for i=2,#args do aux = aux + args[i]() end
	 return aux
       end,
       function(...)
       end)

d = op.add(a,b,c)
d = a + b + c

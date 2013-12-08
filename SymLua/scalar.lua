local SymLua   = require 'SymLua'
local constant = require 'SymLua.constant'

local is                = SymLua.is
local var               = SymLua.var
local compute           = SymLua.compute
local is_op             = SymLua.is_op
local add_op            = SymLua.add_op
local add_dtype         = SymLua.add_dtype
local add_coercion_rule = SymLua.add_coercion_rule
local add_infer_rule    = SymLua.add_infer_rule
local math_n1_list      = SymLua.math_n1_list
local math_n2_list      = SymLua.math_n2_list
local coercion          = SymLua.coercion
local infer             = SymLua.infer
local commutative       = SymLua.commutative

local CONSTANT = constant.dtype
local SCALAR   = 'scalar'

add_dtype(SCALAR, nil, nil,
	  -- basic differentiation function
	  function(tbl,tgt)
	    if tgt[tbl.name] then return var.constant(1)
	    else return var.constant(0)
	    end
	  end)

add_infer_rule(SCALAR, CONSTANT, SCALAR)

------------------------------------------------------------------------------

local commutative_and_distributive_operation = function(args, op1, op2,
							zero,
							reducer1, reducer2)
  local dict,vars = {},{}
  for i,v in ipairs(args) do
    -- add up
    local list = { v }
    if is_op(v,op1) then list = v.args end
    for j,vj in ipairs(list) do
      local vjtype = infer(vj,vj)
      if vjtype == CONSTANT then dict.cte = reducer1((dict.cte or zero), vj())
      else
	if is_op(vj,op2) and #vj.args == 2 and ( is(vj.args[1],CONSTANT) or is(vj.args[2],CONSTANT) ) then
	  -- distribute
	  local a,b = table.unpack(vj.args)
	  if is(b,CONSTANT) then a,b=b,a end
	  dict[b.name] = (dict[b.name] or 0) + a()
	  vars[b.name] = b
	else
	  dict[vj.name] = (dict[vj.name] or 0) + 1
	  vars[vj.name] = vj
	end
      end
    end
  end
  -- simplify replicated variables
  local result = { }
  if dict.cte and dict.cte ~= zero then table.insert(result, var.constant(dict.cte)) end
  for i,v in pairs(vars) do
    if dict[v.name] > 1 then v = reducer2(dict[v.name], v) end
    table.insert(result, v)
  end
  return commutative(result)
end

------------------------------------------------------------------------------

add_op('add', '+', SCALAR,
       function(...)
	 local args   = table.pack(...)
	 local func   = commutative_and_distributive_operation
	 local result = func(args, 'add', 'mul', 0,
			     function(a,b) return a+b end,
			     function(count,a) return a*count end)
	 return result
       end,
       function(...)
	 local args = table.pack(...)
	 local aux = args[1]
	 for i=2,#args do aux = aux + args[i] end
	 return aux
       end)

add_op('mul', '*', SCALAR,
       function(...)
	 local args = table.pack(...)
	 local func = commutative_and_distributive_operation
	 local args = func(args, 'mul', 'pow', 1,
			   function(a,b) return a*b end,
			   function(count,a) return a^count end)
	 -- multiplication of pow with equal base
	 local result,dict,vars = {},{},{}
	 for i,v in ipairs(args) do
	   local a,b
	   if is_op(v,'pow') then a,b = v.args[1],v.args[2]
	   else a,b = v,1
	   end
	   vars[a.name] = a
	   dict[a.name] = (dict[a.name] or 0) + b
	 end
	 for i,v in pairs(dict) do
	   local e = vars[i]
	   if dict[i] ~= 1 then e = e ^ dict[i] end
	   table.insert(result, e)
	 end
	 return commutative(result)
       end,
       function(...)
	 local args = table.pack(...)
	 local aux = args[1]
	 for i=2,#args do aux = aux * args[i] end
	 return aux
       end)

add_op('pow', '^', SCALAR,
       function(...)
	 local args = table.pack(...)
	 assert(#args == 2)
	 return args
       end,
       function(a,b) return a^b end)

return {
  dtype    = SCALAR,
  _NAME    = "SymLua.scalar",
  _VERSION = "0.1",
}

local SymLua = require 'SymLua'
local is = SymLua.is
local is_op = SymLua.is_op
local add_op = SymLua.add_op
local add_type = SymLua.add_type
local math_n1_list = SymLua.math_n1_list
local math_n2_list = SymLua.math_n2_list

local CONSTANT = 'constant'

add_type(CONSTANT, function(s, v) s.value=v end)

local make_composer = function(reducer)
  return function(...)
    local args   = table.pack(...)
    local result = args[1]()
    for i=2,#args do
      local v = args[i]
      assert(is(v,CONSTANT), "Incorrect types")
      result = reducer(result, v())
    end
    return var.constant(result)
  end
end

local diff_func = function(...)
  return function()
    return var.constant(0)
  end
end

add_op('add', '+', CONSTANT,
       -- composition
       make_composer(function(a,b) return a+b end),
       -- operation
       function(a,b) return a+b end,
       -- differentiation
       diff_func)

add_op('sub', '-', CONSTANT,
       -- composition
       make_composer(function(a,b) return a-b end),
       -- operation
       function(a,b) return a-b end,
       -- differentiation
       diff_func)

add_op('mul', '*', CONSTANT,
       -- composition
       make_composer(function(a,b) return a*b end),
       -- operation
       function(a,b) return a*b end,
       -- differentiation
       diff_func)

add_op('div', '/', CONSTANT,
       -- composition
       make_composer(function(a,b) return a/b end),
       -- operation
       function(a,b) return a/b end,
       -- differentiation
       diff_func)

add_op('pow', '^', CONSTANT,
       -- composition
       make_composer(function(a,b) return a^b end),
       -- operation
       function(a,b) return a^b end,
       -- differentiation
       diff_func)

add_op('unm', '-', CONSTANT,
       -- composition
       make_composer(function(a) return -a end),
       -- operation
       function(a) return -a end,
       -- differentiation
       diff_func)

for _,name in ipairs(math_n1_list) do
  add_op(name, name, CONSTANT,
	 make_composer(function(a) return math[name](a) end),
	 function(a) return math[name](a) end,
	 diff_func)
end

for _,name in ipairs(math_n2_list) do
  add_op(name, name, CONSTANT,
	 make_composer(function(a,b) return math[name](a,b) end),
	 function(a) return math[name](a,b) end,
	 diff_func)
end

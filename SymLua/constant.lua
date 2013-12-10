local SymLua = require 'SymLua'

local is                = SymLua.is
local var               = SymLua.var
local is_op             = SymLua.is_op
local add_op            = SymLua.add_op
local add_dtype         = SymLua.add_dtype
local add_coercion_rule = SymLua.add_coercion_rule
local add_infer_rule    = SymLua.add_infer_rule
local math_n1_list      = SymLua.math_n1_list
local math_n2_list      = SymLua.math_n2_list
local coercion          = SymLua.coercion

local CONSTANT = 'constant'

local make_composer_n1 = function(reducer)
  return function(a)
    return var.constant(reducer(a()))
  end
end

local make_composer_n2 = function(reducer)
  return function(...)
    local args = table.pack(...)
    local result = args[1]()
    for i=2,#args do
      local v = args[i]
      assert(is(v,CONSTANT))
      v = v()
      result = reducer(result, v)
    end
    return var.constant(result)
  end
end

local diff_func = function(...)
  return function()
    return var.constant(0)
  end
end

add_dtype(CONSTANT,
	  function(v) return { value=v } end,
	  function(tbl) return tbl.value end,
	  function(tbl,tgt) return var.constant(0) end)

-- Lua type coercion
add_coercion_rule("number", function(v) return var.constant(v) end)

add_op({ name='add', symb='+', dtype=CONSTANT },
       -- composition
       make_composer_n2(function(a,b) return a+b end),
       -- operation
       nil,
       -- differentiation
       diff_func)

add_op({ name='sub', symb='-', dtype=CONSTANT },
       -- composition
       make_composer_n2(function(a,b) return a-b end),
       -- operation
       nil,
       -- differentiation
       diff_func)

add_op({ name='mul', symb='*', dtype=CONSTANT },
       -- composition
       make_composer_n2(function(a,b) return a*b end),
       -- operation
       nil,
       -- differentiation
       diff_func)

add_op({ name='div', symb='/', dtype=CONSTANT },
       -- composition
       make_composer_n2(function(a,b) return a/b end),
       -- operation
       nil,
       -- differentiation
       diff_func)

add_op({ name='pow', symb='^', dtype=CONSTANT },
       -- composition
       make_composer_n2(function(a,b) return a^b end),
       -- operation
       nil,
       -- differentiation
       diff_func)

add_op({ name='unm', symb='-', dtype=CONSTANT },
       -- composition
       make_composer_n1(function(a) return -a end),
       -- operation
       nil,
       -- differentiation
       diff_func)

for _,name in ipairs(math_n1_list) do
  add_op({ name=name, dtype=CONSTANT },
	 make_composer_n1(function(a) return math[name](a) end),
	 nil,
	 diff_func)
end

for _,name in ipairs(math_n2_list) do
  add_op({ name=name, dtype=CONSTANT },
	 make_composer_n2(function(a,b) return math[name](a,b) end),
	 nil,
	 diff_func)
end

return {
  dtype    = CONSTANT,
  _NAME    = "SymLua.constant",
  _VERSION = "0.1",
}

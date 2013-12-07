-- This file is part of the SymLua library
--
-- Copyright 2013, Francisco Zamora-Martinez
--
-- The SymLua library is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License version 3 as
-- published by the Free Software Foundation
--
-- This library is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this library; if not, write to the Free Software Foundation,
-- Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA


-- 
-- MODULE SymLua :: A concept draft for symbolic calculus in Lua
-- SymLua = require('SymLua') if you want to use it
--
-- The module deploys a table with three fields:
--
-- var: a table with functions for variable declaration (var.scalar, var.constant, ...)
--
-- compute: a function for computation of symbolic variable, compute(f, { x=1, y=2 })
--
-- diff: a function for differentiation, dfdx = diff(f, x)


-- var is a table with useful functions for variable type declarations
local var = {}

local math_n1_list = {
  "sqrt",
  "frexp",
  "exp", "log", "log10",
  "abs", "floor", "ceil",
  "deg", "rad",
  "cos", "sin", "tan",
  "cosh", "sinh", "tanh",
  "acos", "asin", "atan",
}

local math_n2_list = {
  "atan2",
  "min", "max",
  "ldexp",
}

-- current basic types
local NUMBER='number'
local SCALAR='scalar'
local CONSTANT='constant'

-- cache functions
local cache_add = function(cache, name, value)
  cache[name] = value
end
local cache_get = function(cache, name)
  -- if cache[name] then print ("HIT", name) end
  return cache[name]
end

-- computation function, is the primary function, receives a symbolic variable,
-- a table with initial values, and optionally a table where operations will be
-- cached
local compute = function(symb_var, t, prev_cache)
  local cache = prev_cache or { }
  for name,value in pairs(t) do
    if type(value) ~= "table" then
      cache_add(cache, name, value)
    end
  end
  for name,value in pairs(t) do
    if type(value) == "table" then value(cache) end
  end
  return symb_var(cache)
end

-- gradient
local diff = function(symb_var, partial)
  local tgt
  if type(partial) == "string" then tgt = partial
  else tgt = partial.name
  end
  return symb_var.grad(tgt)
end

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------

local commutative = function(args)
  table.sort(args, function(a,b) return a.name < b.name end)
  return args
end

local is = function(v,dtype) return v.dtype == dtype end
local is_op = function(v,op) return v.op == op end

local coercion   = {}
local op = {}

function expr(name, dtype, args)
  local sv = svar(string.format("(%s %s)",
				name, table.concat(args, " ")),
		  dtype)
  sv.op   = name
  sv.args = args
  return sv
end

local add_op = function(name, pretty_name, dtype,
			compose_func, compute_func, diff_func)
  if not op[name] then
    op[name] = {}
    setmetatable(op[name],
		 {
		   __call = function(t,...)
		     local dtype = coercion(...)
		     local data  = assert(op[name][dtype])
		     local vars = data.compose_func(...)
		     return expr( name, dtype, vars )
		   end,
		 })
  end
  op[name][dtype] = {
    pretty_name  = pretty_name,
    compose_func = compose_func or function() error("Composition not implemented") end,
    compute_func = compute_func or function() error("Computation not implemented") end,
    diff_func    = diff_func or function() error("Differation not implemented") end,
  }
end

local add_dtype = function(dtype,constructor)
  var[dtype] = function(...)
    local args = table.pack(...)
    local list = {}
    for i,arg in ipairs(args) do
      local str = tostring(arg)
      for v in str:match("[^%s]+") do
	local sv = svar(tostring(v), dtype)
	constructor(sv,v)
	table.insert(list, sv)
      end
    end
    return table.unpack(list)
  end
end

-- Function for symbolic variable declaration. Receives a name and a type. The
-- symbolic variable has this fields:
--
--  name = the name of the variable, or the expression canonical representation
--
--  func = a function which computes the value of the variable. In case of
--         operations, this function computes it.
--
--  args = arguments needed by previous function, by default an empty table
--
--  op = a string indicating the name of the operation, when needed

local mt = { }
local svar = function(name, dtype)
  -- valores por defecto de una variable
  local v = {
    name=name,
    dtype=dtype,
    args = { },
  }
  v.func = function(cache)
    -- su funcion se devuelve a si misma
    return v
  end
  v.grad = function(tgt)
    if tgt == v.name then return var.constant(1)
    else return var.constant(0)
    end
  end
  setmetatable(v, mt)
  return v
end

-- auxiliary function which
local auto = function(v)
  if type(v) == "string" then return svar(v)
  elseif type(v) ~= "table" then return var.constant(v)
  else return v
  end
end

local copy = function(v)
  local sv = svar(v.name,v.dtype)
  for key,value in pairs(v) do sv[key] = value end
  return sv
end

local coercion = function(dtype1, dtype2)
  if dtype1 == dtype2 then return dtype1 end
  if dtype1 == CONSTANT then return dtype2
  else return dtype1
  end
end

-- auxiliary function to produce binary operator functions
local make_op2 = function(op_symbol,
			  commutative,
			  left_zero,  left_ident,
			  right_zero, right_ident,
			  ident,
			  func,
			  grad_maker,
			  dtype)
  return function(a,b)
    local a,b    = auto(a),auto(b)
    local v_type = dtype or coercion(a.dtype, b.dtype)
    local v
    if a == left_zero or b == right_zero then v = copy(ident)
    elseif a == left_ident then v = copy(b)
    elseif b == right_ident then v = copy(a)
    elseif a.dtype == CONSTANT and b.dtype == CONSTANT then
      v = var.constant( func( a(),b() ) )
    else
      local args = { a, b }
      if commutative then
	table.sort(args, function(a,b) return a.name < b.name end)
      end
      -- variable simbolica resultante, con el nombre canonico de la operacion
      v = svar(string.format("(%s %s %s)",
			     args[1].name, op_symbol, args[2].name),
	       v_type)
      v.func = func
      v.op   = op_symbol
      v.args = args
    end
    -- print(a,op_symbol,b,"=",v, v.dtype, a.dtype, b.dtype)
    v.grad = grad_maker(a,b)
    return v
  end
end

-- auxiliary function to produce unary operator functions
local make_op1 = function(op_symbol, zero, func, grad_maker)
  return function(a)
    local a = auto(a)
    if a == zero then return zero end
    -- variable simbolica resultante, con el nombre canonico de la operacion
    local v = svar(string.format("(%s %s)", op_symbol, a.name), a.dtype)
    v.op = op_symbol
    v.args = { a }
    v.func = func
    v.grad = grad_maker(a)
    return v
  end
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

-- scalar variable creation
var.scalar = function(...)
  local t = table.pack(...)
  local list = {}
  for i=1,#t do
    for name in t[i]:gmatch("[^%s]+") do
      table.insert(list, svar(name, SCALAR))
    end
  end
  return table.unpack(list)
end

-- constant variable creation
var.constant = function(...)
  local t = table.pack(...)
  local list = {}
  for i=1,#t do
    local value = t[i]
    local v = svar(tostring(value), CONSTANT)
    v.value = value
    v.func  = function() return value end
    table.insert(list, v)
  end
  return table.unpack(list)
end

-- METATABLE for symbolic variables

-- the () operator returns the result in cache, or executes the operation
mt.__call = function(v, cache)
  local cache  = cache or {}
  local result = cache_get(cache, v.name)
  if not result then
    local args = {}
    for i,sv in ipairs(v.args) do args[i] = sv(cache) end
    result = v.func(table.unpack(args))
  elseif type(result) == "table" then result = result(cache)
  end
  cache_add(cache, v.name, result)
  return result
end

-- mathematical operations
mt.__add    = make_op2('+',  true,
		       nil, var.constant(0),
		       nil, var.constant(0),
		       var.constant(0),
		       function(a,b) return a+b  end,
		       function(a,b)
			 return function(tgt)
			   return a.grad(tgt) + b.grad(tgt)
			 end
		       end)
mt.__sub    = make_op2('-',  false,
		       nil, nil,
		       nil, var.constant(0),
		       var.constant(0),
		       function(a,b) return a-b  end,
		       function(a,b)
			 return function(tgt)
			   return a.grad(tgt) - b.grad(tgt)
			 end
		       end)
mt.__mul    = make_op2('*',  true,
		       var.constant(0), var.constant(1),
		       var.constant(0), var.constant(1),
		       var.constant(0),
		       function(a,b) return a*b  end,
		       function(a,b)
			 return function(tgt)
			   return a.grad(tgt)*b + a*b.grad(tgt)
			 end
		       end)
mt.__div    = make_op2('/',  false,
		       var.constant(0), var.constant(1),
		       nil, var.constant(1),
		       var.constant(1),
		       function(a,b) return a/b  end,
		       function(a,b)
			 return function(tgt)
			   return (a.grad(tgt)*b - a*b.grad(tgt)) / (b^2)
			 end
		       end)
mt.__pow    = make_op2('^',  false,
		       nil, var.constant(1),
		       var.constant(0), var.constant(1),
		       var.constant(1),
		       function(a,b) return a^b  end,
		       function(a,b)
			 return function(tgt)
			   return b * (a^(b-1)) * a.grad(tgt)
			 end
		       end)
mt.__mod    = make_op2('%',  false,
		       nil, nil,
		       nil, nil,
		       nil,
		       function(a,b) return a%b  end,
		       function()
			 return function() error("Non differentiable function") end
		       end)
mt.__concat = make_op2('..', false,
		       nil, nil,
		       nil, nil,
		       nil,
		       function(a,b) return a..b end,
		       function()
			 return function() error("Non differentiable function") end
		       end)
mt.__unm    = make_op1('-',
		       var.constant(0),
		       function(a) return -a end,
		       function(a)
			 return function(tgt)
			   return -a.grad(tgt)
			 end
		       end)
mt.__eq     = function(a,b) return a.dtype==b.dtype and a.name == b.name end
-- for printing purposes
mt.__tostring = function(v) return v.name end

-- mathematical functions

local infer = function(a)
  if type(a) == "table" then return assert(a.dtype, "Incorrect type") end
  return type(a)
end

local math_gradients = {
  [SCALAR] = {
    exp = function(a)
      return function(tgt)
	return var.exp(a) * a.grad(tgt)
      end
    end,
    floor = function()
      return function() error("Not differentiable function") end
    end,
    ceil = function()
      return function() error("Not differentiable function") end
    end,
    abs = function()
      return function() error("Non continuous function") end
    end,
    deg = function()
      return function() error("Not implemented gradient") end
    end,
    rad = function()
      return function() error("Not implemented gradient") end
    end,
    frexp = function()
      return function() error("Not implemented gradient") end
    end,
    ldexp = function()
      return function() error("Not implemented gradient") end
    end,
    min = function()
      return function() error("Not implemented gradient") end
    end,
    max = function()
      return function() error("Not implemented gradient") end
    end,
    sinh = function(a)
      return function(tgt)
	return var.cosh(a) * a.grad(tgt)
      end
    end,
    cosh = function(a)
      return function(tgt)
	return var.sinh(a) * a.grad(tgt)
      end
    end,
    tanh = function()
      return function() error("Not implemented gradient") end
    end,
    sin = function(a)
      return function(tgt)
	return var.cos(a) * a.grad(tgt)
      end
    end,
    cos = function(a)
      return function(tgt)
	return var.sin(a) * a.grad(tgt)
      end
    end,
    tan = function()
      return function() error("Not implemented gradient") end
    end,
    asin = function(a)
      return function(tgt)
	return 1 / var.sqrt(1 - a^2) * a.grad(tgt)
      end
    end,
    acos = function(a)
      return function(tgt)
	return -1 / var.sqrt(1 - a^2) * a.grad(tgt)
      end
    end,
    atan = function(a)
      return function(tgt)
	return 1 / (1 + a^2) * a.grad(tgt)
      end
    end,
    atan2 = function(a,b)
      return function(tgt)
	return 1 / (1 + (a/b)^2) * (a/b).grad(tgt)
      end
    end,
    log10 = function(a)
      return function(tgt)
	return 1 / (a + var.log(10)) * a.grad(tgt)
      end
    end,
    log = function(a)
      return function(tgt)
	return 1/a * a.grad(tgt)
      end
    end,
    sqrt = function(a)
      return function(tgt)
	return 1/(2*a) * a.grad(tgt)
      end
    end,
  }
}

local var_math = { }

-- unary math operations
for _,name in ipairs{ "exp", "floor", "sinh", "log10", "log", "deg", "tanh",
		      "abs", "acos", "cos", "sqrt", "sin", "rad", "tan",
		      "frexp", "cosh", "ceil", "atan", "asin" } do
  var_math[name] = {
    [NUMBER] = math[name],
    [SCALAR] = make_op1(name, nil,
			function(a) return var_math[name][infer(a)](a) end,
			math_gradients[SCALAR][name]),
  }
end

-- binary math operations
for _,name in ipairs{ "atan2", "min", "max", "ldexp" } do
  var_math[name] = {
    [NUMBER] = math[name],
    [SCALAR] = make_op2(name, false,
			nil, nil,
			nil, nil,
			nil,
			function(a,b)
			  local dtype = infer(a)
			  assert(dtype == infer(b),
				 string.format("Incorrect types %s != %s",
					       dtype, infer(b)))
			  return var_math[name][dtype](a,b)
			end,
			math_gradients[SCALAR][name]),
  }
end

-- Inserta las funciones matematicas en var.BLAH
for i,v in pairs(var_math) do
  var[i] = function(sv)
    return assert(v[sv.dtype], "Math functions need dtype")(sv)
  end
end

------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------

return {
  var     = var,
  compute = compute,
  diff    = diff,
}

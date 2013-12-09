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

local NULL = "@NULL@"

local infer_rules    = {}
local coercion_rules = {}
local op             = {}
local var            = {}
local svar_mt        = {}
local svar

local coercion = function(a)
  local dtype = (type(a)=="table" and a.dtype) or type(a)
  local func = coercion_rules[dtype]
  return (func and func(a)) or a
end

local infer = function(a_dtype,b_dtype)
  if a_dtype > b_dtype then a_dtype,b_dtype = b_dtype,a_dtype end
  local aux = assert(infer_rules[a_dtype],
		     "Type inference fail: " .. a_dtype .. " " .. b_dtype)
  return assert(aux[b_dtype],
		"Type inference fail: " .. a_dtype .. " " .. b_dtype)
end

--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------

-- cache functions
local cache_add = function(cache, name, value)
  cache[name] = value
end
local cache_get = function(cache, name)
  -- if cache[name] then print ("HIT", name) end
  return cache[name]
end

--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------

-- computation function, is the primary function, receives a symbolic variable,
-- a table with initial values, and optionally a table where operations will be
-- cached
local compute = function(symb_var, t, prev_cache)
  if type(symb_var) ~= "table" or not symb_var.issvar then return symb_var end
  local t     = t or { }
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

local expr = function(name, dtype, args)
  assert(op[name], "Undefined math operation " .. name)
  assert(op[name][dtype],
         "Undefined math operation " .. name .. " for type " .. dtype)
  local o = op[name][dtype]
  if o.compose_func then args = o.compose_func(table.unpack(args)) end
  if args.issvar then return args
  else
    local str_tbl = {} for i=1,#args do str_tbl[i] = tostring(args[i]) end
    local pretty = string.format("(%s %s)",
				 o.pretty_name,
				 table.concat(str_tbl, " "))
    --    local pretty = string.format("( %s )",
    --				 table.concat(str_tbl, o.pretty_name))
    local sv = svar(pretty, dtype)
    sv.op   = name
    sv.args = args
    sv.func = function(_,...) return o.compute_func(...) end
    sv.diff = o.diff_func
    return sv
  end
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

local add_coercion_rule = function(dtype, func)
  assert(not coercion_rules[dtype],
	 "Redifinition of coercion for type: " .. dtype)
  -- SymLua dtype or Lua type coercion
  coercion_rules[dtype] = func
end

local add_infer_rule = function(a_dtype, b_dtype, result)
  if a_dtype > b_dtype then a_dtype,b_dtype = b_dtype,a_dtype end
  infer_rules[a_dtype]          = infer_rules[a_dtype] or {}
  infer_rules[a_dtype][b_dtype] = result
end

local add_op = function(name, pretty_name, dtype,
			compose_func, compute_func, diff_func)
  assert(compose_func or compute_func)
  if not op[name] then
    op[name] = {}
    setmetatable(op[name],
		 {
		   __call = function(t, ...)
		     local args  = table.pack(...)
		     args[1]     = coercion(args[1])
		     local dtype = args[1].dtype
		     for i=2,#args do
		       args[i] = coercion(args[i])
		       dtype = infer(dtype,args[i].dtype)
		     end
		     return expr( name, dtype, args )
		   end,
		 })
  end
  op[name][dtype] = {
    pretty_name  = pretty_name,
    compose_func = compose_func,
    compute_func = compute_func,
    diff_func    = diff_func or function() error("Differation not implemented") end,
  }
end

local add_dtype = function(dtype,constructor,func,diff_func)
  if dtype == "number" or dtype == "string" or dtype == "table" then
    error("Lua types 'number', 'string' and 'table' are reserved")
  end
  var[dtype] = function(...)
    local args = table.pack(...)
    local list = {}
    for i,arg in ipairs(args) do
      if type(arg) == "string" then
	for v in arg:gmatch("[^%s]+") do
	  local sv = svar(tostring(v), dtype)
	  local aux = (constructor and constructor(v)) or { }
	  for j,vj in pairs(aux) do assert(not sv[j]) sv[j]=vj end
	  sv.func = func or sv.func
	  sv.diff_func = diff_func
	  table.insert(list, sv)
	end
      else
	local sv = svar(tostring(arg), dtype)
	local aux = (constructor and constructor(arg)) or { }
	for j,vj in pairs(aux) do assert(not sv[j]) sv[j]=vj end
	sv.func = func or sv.func
	sv.diff_func = diff_func
	table.insert(list, sv)
      end
    end
    return table.unpack(list)
  end
  add_infer_rule(dtype,dtype,dtype)
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

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

svar = function(name, dtype)
  -- default values of symbolic variable
  local v = {
    name  = name,
    dtype = dtype,
    args  = { },
    issvar = true,
  }
  v.func = function() return v end -- identity function
  -- v.grad = function(tgt)
  --   if tgt == v.name then return var.constant(1)
  --   else return var.constant(0)
  --   end
  -- end
  setmetatable(v, svar_mt)
  return v
end

-- -- the () operator returns the result in cache, or executes the operation
svar_mt.__call = function(v, cache)
  local cache  = cache or {}
  local result = cache_get(cache, v.name)
  if not result then
    local args = { }
    for i,sv in ipairs(v.args) do args[i] = sv(cache) end
    result = v:func(table.unpack(args))
  elseif type(result) == "table" then result = result(cache)
  end
  cache_add(cache, v.name, result)
  return result
end

svar_mt.__tostring = function(v)
  return v.name
end

svar_mt.__eq = function(a,b) return a.name == b.name end

local make_op2 = function(name)
  return function(a,b)
    a,b = coercion(a),coercion(b)
    local dtype = infer(a.dtype,b.dtype)
    local e = expr( name, dtype, {a,b} )
    return e
  end
end

local make_op1 = function(name)
  return function(a)
    a = coercion(a)
    local e = expr( name, a.dtype, {a} )
    return e
  end
end

svar_mt.__add = make_op2('add')
svar_mt.__sub = make_op2('sub')
svar_mt.__mul = make_op2('mul')
svar_mt.__div = make_op2('div')
svar_mt.__pow = make_op2('pow')
svar_mt.__unm = make_op1('unm')

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

return {
  var               = var,
  op                = op,
  svar              = svar,
  expr              = expr,
  compute           = compute,
  diff              = diff,
  is                = is,
  is_op             = is_op,
  add_op            = add_op,
  add_dtype         = add_dtype,
  add_coercion_rule = add_coercion_rule,
  add_infer_rule    = add_infer_rule,
  coercion          = coercion,
  infer             = infer,
  commutative       = commutative,
  math_n1_list      = math_n1_list,
  math_n2_list      = math_n2_list,
  expr              = expr,
  _NAME             = "SymLua",
  _VERSION          = "0.1",
}

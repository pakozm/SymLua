local SymLua   = require 'SymLua'
local constant = require 'SymLua.constant'
local scalar   = require 'SymLua.scalar'

local var      = SymLua.var
local op       = SymLua.op
local compute  = SymLua.compute
local CONSTANT = constant.dtype
local SCALAR   = scalar.dtype

local a,b = var.constant(4,7)

local c = op.atan2(op.log( a + b*10 ), 3) * op.exp(2)

print( compute(c) )


local a,b,c = var.scalar('a b c')

d = c - c + c

print(d)

print( compute(d, { a=2, b=3, c=4 }) )

-- local SymLua = require 'SymLua'

-- -- 
-- local var     = SymLua.var
-- local compute = SymLua.compute
-- local diff    = SymLua.diff

-- local x,y,w,b = var.scalar('x','y','w','b')
-- local values = { x=0.1, y=0.4, w=1, b=-1 }

-- local f = w * x + b     -- una funcion lineal (w*x + b)
-- local z = 0.5*(f - y)^2 -- el MSE de dicha funcion respecto a un objetivo y
-- print(z)

-- local cache = {}
-- print( "f   = ", compute(f, values, cache) ) -- aqui tenemos el valor de la funcion
-- print( "MSE = ", compute(z, values, cache) ) -- aqui tenemos el MSE del resultado

-- local gw = diff(z, w)

-- local res = compute(gw , values, cache)

-- print( "grad f / grad w = ", gw )
-- print( "grad f / grad w = ", res )

-- ----------------------------------------------------------------------------

-- local a,b,c,x = var.scalar('a b c x')
-- local f = a * var.exp(-b*b*x) + c

-- print(f)
-- print( diff(f,a) )
-- print( diff(f,b) )
-- print( diff(f,c) )

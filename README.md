SymLua
======

A draft concept for Symbolic Calculus in Lua.

Test it doing:

```
$ lua test.lua
(((((w * x) + b) - y) ^ 2) * 0.5)
f   = 	-0.9
MSE = 	0.845
grad f / grad w = 	((((((w * x) + b) - y) * 2) * x) * 0.5)
grad f / grad w = 	-0.13
(((exp (((- b) * b) * x)) * a) + c)
(exp (((- b) * b) * x))
((((((- 1) * b) + (- b)) * x) * (exp (((- b) * b) * x))) * a)
1
```

If you want to use it, you need to install `SymLua.lua` in your system Lua
modules library path. Your Lua program needs to `require` the module `SymLua`,
and thats it, you can produce symbolic operations, and differentiate it.

```Lua
> SymLua = require 'SymLua'
> -- this declares two scalars with names x,y
> x,y = SymLua.var.scalar('x', 'y')
> -- this declares two scalars with names a,b
> a,b = SymLua.var.scalar('a b')
> -- this decalres an operation with previous scalars
> f = x*y * a^b
> print(f)
((a ^ b) * (x * y))
> -- automatic differentation
> dfdx = SymLua.diff(f, x)
> print(dfdx)
((a ^ b) * y)
> -- compute the value of the gradient
> print( SymLua.compute(dfdx, { x=4, a=1, b=2, y=-1 }) )
-1
```

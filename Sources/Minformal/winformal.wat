(module
   (type $Point (struct (field $x i32) (field $y i32)))
   (func (export "addXY") (param (ref $Point)) (result i32)
       (i32.add
           (struct.get $Point $x (local.get 0))
           (struct.get $Point $y (local.get 0)))
   )
)
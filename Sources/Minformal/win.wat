(module
   (type $Point (struct (field $x i32) (field $y i32)))
   (func (export "addXY") (param (ref $Point)) (result i32)
       (i32.add
           (struct.get $Point $x (local.get 0))
           (struct.get $Point $y (local.get 0)))
   )
   (type $Point2 (struct (field $x2 i32) (field $y2 i32)))

    (func (export "add") (param i32 i32) (result i32)
        (i32.add (local.get 0) (local.get 1))
    )

)
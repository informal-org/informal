  (func $__av_run (type 16) (result i32)
    (local i32 i32 i32 i32 i32 i32 i32)
    global.get 0
    i32.const 80
    i32.sub
    local.tee 0
    global.set 0
    local.get 0
    call $__av_inject
    local.get 0
    i32.const 1024
    call $_ZN11flatbuffers7builder17FlatBufferBuilder17new_with_capacity17h44002bf5761bf963E
    local.get 0
    i32.const 1049532
    i32.const 12
    call $_ZN11flatbuffers7builder17FlatBufferBuilder13create_string17ha9feb9fb9873ab3eE
    local.set 1
    local.get 0
    local.get 0
    i32.load offset=40
    local.tee 2
    i32.const 8
    local.get 2
    i32.const 8
    i32.gt_u
    select
    i32.store offset=40
    local.get 0
    local.get 0
    i32.load offset=12
    local.get 0
    i32.load offset=8
    i32.sub
    i32.const 7
    i32.and
    call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
    drop
    local.get 0
    local.get 0
    i32.load offset=40
    local.tee 2
    i32.const 4
    local.get 2
    i32.const 4
    i32.gt_u
    select
    i32.store offset=40
    local.get 0
    local.get 0
    i32.load offset=12
    local.get 0
    i32.load offset=8
    i32.sub
    i32.const 3
    i32.and
    call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
    drop
    local.get 0
    i32.const 4
    call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
    drop
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            local.get 0
            i32.load offset=8
            local.tee 3
            local.get 0
            i32.load offset=12
            local.tee 2
            i32.lt_u
            br_if 0 (;@4;)
            block  ;; label = @5
              local.get 3
              local.get 2
              i32.sub
              i32.const 3
              i32.gt_u
              br_if 0 (;@5;)
              i32.const 1049508
              call $_ZN4core9panicking5panic17h1fb303f1c113605dE
              unreachable
            end
            local.get 0
            i32.load
            local.get 2
            i32.add
            i32.const 0
            i32.store
            local.get 0
            i32.load offset=12
            local.set 4
            local.get 0
            i32.load offset=8
            local.set 5
            local.get 0
            i32.const 76
            i32.add
            local.get 0
            i32.const 1049544
            i32.const 6
            call $_ZN11flatbuffers7builder17FlatBufferBuilder13create_string17ha9feb9fb9873ab3eE
            i32.store
            local.get 0
            i32.const 1
            i32.store offset=72
            local.get 0
            i32.const 0
            i32.store offset=64
            local.get 0
            i32.const 0
            i32.store offset=56
            local.get 0
            i64.const 0
            i64.store offset=48
            local.get 0
            local.get 0
            i32.const 48
            i32.add
            call $_ZN3avs14avfb_generated4avfb7AvFbObj6create17h38290e305cf5d624E
            local.set 3
            local.get 0
            local.get 0
            i32.load offset=40
            local.tee 2
            i32.const 4
            local.get 2
            i32.const 4
            i32.gt_u
            select
            i32.store offset=40
            local.get 0
            local.get 0
            i32.load offset=12
            local.get 0
            i32.load offset=8
            i32.sub
            i32.const 3
            i32.and
            call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
            drop
            local.get 0
            local.get 0
            i32.load offset=40
            local.tee 2
            i32.const 4
            local.get 2
            i32.const 4
            i32.gt_u
            select
            i32.store offset=40
            local.get 0
            local.get 0
            i32.load offset=12
            local.get 0
            i32.load offset=8
            i32.sub
            i32.const 3
            i32.and
            call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
            drop
            local.get 0
            i32.const 4
            call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
            drop
            local.get 0
            i32.load offset=8
            local.tee 6
            local.get 0
            i32.load offset=12
            local.tee 2
            i32.lt_u
            br_if 1 (;@3;)
            local.get 6
            local.get 2
            i32.sub
            local.tee 6
            i32.const 3
            i32.le_u
            br_if 2 (;@2;)
            local.get 0
            i32.load
            local.get 2
            i32.add
            local.get 6
            local.get 3
            i32.sub
            i32.store
            local.get 0
            local.get 0
            i32.load offset=40
            local.tee 2
            i32.const 4
            local.get 2
            i32.const 4
            i32.gt_u
            select
            i32.store offset=40
            local.get 0
            local.get 0
            i32.load offset=12
            local.get 0
            i32.load offset=8
            i32.sub
            i32.const 3
            i32.and
            call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
            drop
            local.get 0
            i32.const 4
            call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
            drop
            local.get 0
            i32.load offset=8
            local.tee 3
            local.get 0
            i32.load offset=12
            local.tee 2
            i32.ge_u
            br_if 3 (;@1;)
            local.get 2
            local.get 3
            call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
            unreachable
          end
          local.get 2
          local.get 3
          call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
          unreachable
        end
        local.get 2
        local.get 6
        call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
        unreachable
      end
      i32.const 1049508
      call $_ZN4core9panicking5panic17h1fb303f1c113605dE
      unreachable
    end
    block  ;; label = @1
      local.get 3
      local.get 2
      i32.sub
      i32.const 3
      i32.gt_u
      br_if 0 (;@1;)
      i32.const 1049508
      call $_ZN4core9panicking5panic17h1fb303f1c113605dE
      unreachable
    end
    local.get 0
    i32.load
    local.get 2
    i32.add
    i32.const 1
    i32.store
    local.get 0
    i32.load offset=12
    local.set 2
    local.get 0
    i32.load offset=8
    local.set 3
    local.get 0
    i32.const 76
    i32.add
    local.get 1
    i32.store
    local.get 0
    i32.const 68
    i32.add
    local.get 3
    local.get 2
    i32.sub
    i32.store
    local.get 0
    i32.const 60
    i32.add
    local.get 5
    local.get 4
    i32.sub
    i32.store
    local.get 0
    i32.const 1
    i32.store offset=72
    local.get 0
    i32.const 1
    i32.store offset=64
    local.get 0
    i32.const 1
    i32.store offset=56
    local.get 0
    i64.const 0
    i64.store offset=48
    local.get 0
    local.get 0
    local.get 0
    i32.const 48
    i32.add
    call $_ZN3avs14avfb_generated4avfb7AvFbObj6create17h38290e305cf5d624E
    i32.const 0
    local.get 0
    i32.const 0
    call $_ZN11flatbuffers7builder17FlatBufferBuilder16finish_with_opts17h4bad56fa8cb0fd81E
    block  ;; label = @1
      local.get 0
      i32.load offset=8
      local.tee 1
      local.get 0
      i32.load offset=12
      local.tee 2
      i32.lt_u
      br_if 0 (;@1;)
      block  ;; label = @2
        local.get 1
        local.get 2
        i32.sub
        local.tee 1
        i32.eqz
        br_if 0 (;@2;)
        local.get 0
        i32.load
        local.get 2
        i32.add
        local.get 1
        call $__av_sized_ptr
        local.set 2
        block  ;; label = @3
          local.get 0
          i32.load offset=4
          local.tee 1
          i32.eqz
          br_if 0 (;@3;)
          local.get 0
          i32.load
          local.get 1
          i32.const 1
          call $__rust_dealloc
        end
        block  ;; label = @3
          local.get 0
          i32.const 20
          i32.add
          i32.load
          local.tee 1
          i32.eqz
          br_if 0 (;@3;)
          local.get 0
          i32.load offset=16
          local.get 1
          i32.const 3
          i32.shl
          i32.const 4
          call $__rust_dealloc
        end
        block  ;; label = @3
          local.get 0
          i32.const 32
          i32.add
          i32.load
          local.tee 1
          i32.eqz
          br_if 0 (;@3;)
          local.get 0
          i32.load offset=28
          local.get 1
          i32.const 2
          i32.shl
          i32.const 4
          call $__rust_dealloc
        end
        local.get 0
        i32.const 80
        i32.add
        global.set 0
        local.get 2
        return
      end
      i32.const 1049564
      i32.const 0
      i32.const 0
      call $_ZN4core9panicking18panic_bounds_check17hdaf7aa012e2661faE
      unreachable
    end
    local.get 2
    local.get 1
    call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
    unreachable)
  (func $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.2 (type 2) (param i32 i32) (result i32)
    (local i32 i32 i32 i32 i32 i32 i32 i32)
    global.get 0
    i32.const 96
    i32.sub
    local.tee 2
    global.set 0
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              local.get 0
              i32.const 12
              i32.add
              local.tee 3
              i32.load
              local.tee 4
              local.get 1
              i32.ge_u
              br_if 0 (;@5;)
              local.get 1
              i32.const -2147483648
              i32.gt_u
              br_if 1 (;@4;)
              local.get 0
              i32.const 8
              i32.add
              local.set 5
              local.get 0
              i32.const 12
              i32.add
              local.set 6
              loop  ;; label = @6
                local.get 0
                local.get 5
                i32.load
                local.tee 4
                i32.const 1
                i32.shl
                local.tee 7
                i32.const 1
                local.get 7
                select
                local.tee 8
                i32.const 0
                call $_ZN5alloc3vec12Vec$LT$T$GT$6resize17ha7e1fd22820a0cf7E
                local.get 6
                local.get 6
                i32.load
                local.get 4
                i32.sub
                local.get 8
                i32.add
                local.tee 4
                i32.store
                block  ;; label = @7
                  local.get 7
                  i32.eqz
                  br_if 0 (;@7;)
                  local.get 5
                  i32.load
                  local.tee 9
                  local.get 8
                  i32.const 1
                  i32.shr_u
                  local.tee 7
                  i32.lt_u
                  br_if 4 (;@3;)
                  local.get 0
                  i32.load
                  local.set 4
                  local.get 2
                  local.get 9
                  local.get 7
                  i32.sub
                  local.tee 8
                  i32.store offset=8
                  local.get 2
                  local.get 7
                  i32.store offset=12
                  local.get 8
                  local.get 7
                  i32.ne
                  br_if 5 (;@2;)
                  local.get 4
                  local.get 7
                  i32.add
                  local.get 4
                  local.get 7
                  call $memcpy
                  drop
                  local.get 5
                  i32.load
                  local.tee 4
                  local.get 7
                  i32.lt_u
                  br_if 6 (;@1;)
                  local.get 0
                  i32.load
                  i32.const 0
                  local.get 7
                  call $memset
                  drop
                  local.get 6
                  i32.load
                  local.set 4
                end
                local.get 4
                local.get 1
                i32.lt_u
                br_if 0 (;@6;)
              end
            end
            local.get 3
            local.get 4
            local.get 1
            i32.sub
            local.tee 7
            i32.store
            local.get 2
            i32.const 96
            i32.add
            global.set 0
            local.get 7
            return
          end
          i32.const 1049692
          i32.const 37
          i32.const 1049676
          call $_ZN3std9panicking11begin_panic17h6f5191b790a90319E
          unreachable
        end
        i32.const 1049784
        call $_ZN4core9panicking5panic17h1fb303f1c113605dE
        unreachable
      end
      local.get 2
      i32.const 40
      i32.add
      i32.const 20
      i32.add
      i32.const 7
      i32.store
      local.get 2
      i32.const 52
      i32.add
      i32.const 8
      i32.store
      local.get 2
      i32.const 16
      i32.add
      i32.const 20
      i32.add
      i32.const 3
      i32.store
      local.get 2
      local.get 2
      i32.const 8
      i32.add
      i32.store offset=64
      local.get 2
      local.get 2
      i32.const 12
      i32.add
      i32.store offset=68
      local.get 2
      i32.const 72
      i32.add
      i32.const 20
      i32.add
      i32.const 0
      i32.store
      local.get 2
      i64.const 3
      i64.store offset=20 align=4
      local.get 2
      i32.const 1049204
      i32.store offset=16
      local.get 2
      i32.const 8
      i32.store offset=44
      local.get 2
      i32.const 1049288
      i32.store offset=88
      local.get 2
      i64.const 1
      i64.store offset=76 align=4
      local.get 2
      i32.const 1049280
      i32.store offset=72
      local.get 2
      local.get 2
      i32.const 40
      i32.add
      i32.store offset=32
      local.get 2
      local.get 2
      i32.const 72
      i32.add
      i32.store offset=56
      local.get 2
      local.get 2
      i32.const 68
      i32.add
      i32.store offset=48
      local.get 2
      local.get 2
      i32.const 64
      i32.add
      i32.store offset=40
      local.get 2
      i32.const 16
      i32.add
      i32.const 1049288
      call $_ZN4core9panicking9panic_fmt17h52bd9c4c06b66d8dE
      unreachable
    end
    local.get 7
    local.get 4
    call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
    unreachable)
  (func $_ZN11flatbuffers7builder17FlatBufferBuilder16finish_with_opts17h4bad56fa8cb0fd81E (type 17) (param i32 i32 i32 i32 i32)
    (local i32 i32 i32 i32)
    local.get 0
    i32.const 36
    i32.add
    i32.const 0
    i32.store
    local.get 0
    local.get 0
    i32.load offset=40
    i32.const -1
    i32.add
    i32.const 0
    local.get 2
    i32.const 0
    i32.ne
    i32.const 2
    i32.shl
    i32.const 8
    i32.const 4
    local.get 4
    select
    i32.add
    local.get 0
    i32.const 8
    i32.add
    local.tee 5
    i32.load
    local.get 0
    i32.load offset=12
    i32.sub
    i32.add
    i32.sub
    i32.and
    call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.2
    drop
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                block  ;; label = @7
                  local.get 2
                  i32.eqz
                  br_if 0 (;@7;)
                  local.get 0
                  local.get 3
                  call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.2
                  local.tee 6
                  local.get 3
                  i32.add
                  local.tee 7
                  local.get 6
                  i32.lt_u
                  br_if 1 (;@6;)
                  local.get 5
                  i32.load
                  local.tee 8
                  local.get 7
                  i32.lt_u
                  br_if 2 (;@5;)
                  local.get 0
                  i32.load
                  local.get 6
                  i32.add
                  local.get 2
                  local.get 3
                  call $memcpy
                  drop
                end
                local.get 0
                local.get 0
                i32.load offset=40
                local.tee 2
                i32.const 4
                local.get 2
                i32.const 4
                i32.gt_u
                select
                i32.store offset=40
                local.get 0
                local.get 0
                i32.load offset=12
                local.get 5
                i32.load
                i32.sub
                i32.const 3
                i32.and
                call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.2
                drop
                local.get 0
                i32.const 4
                call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.2
                drop
                local.get 5
                i32.load
                local.tee 5
                local.get 0
                i32.load offset=12
                local.tee 2
                i32.lt_u
                br_if 2 (;@4;)
                local.get 5
                local.get 2
                i32.sub
                local.tee 5
                i32.const 3
                i32.le_u
                br_if 3 (;@3;)
                local.get 0
                i32.load
                local.get 2
                i32.add
                local.get 5
                local.get 1
                i32.sub
                i32.store
                block  ;; label = @7
                  local.get 4
                  i32.eqz
                  br_if 0 (;@7;)
                  local.get 0
                  local.get 0
                  i32.load offset=40
                  local.tee 2
                  i32.const 4
                  local.get 2
                  i32.const 4
                  i32.gt_u
                  select
                  i32.store offset=40
                  local.get 0
                  local.get 0
                  i32.load offset=12
                  local.tee 5
                  local.get 0
                  i32.const 8
                  i32.add
                  local.tee 2
                  i32.load
                  local.tee 4
                  i32.sub
                  i32.const 3
                  i32.and
                  call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.2
                  drop
                  local.get 0
                  i32.const 4
                  call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.2
                  drop
                  local.get 2
                  i32.load
                  local.tee 3
                  local.get 0
                  i32.load offset=12
                  local.tee 2
                  i32.lt_u
                  br_if 5 (;@2;)
                  local.get 3
                  local.get 2
                  i32.sub
                  i32.const 3
                  i32.le_u
                  br_if 6 (;@1;)
                  local.get 0
                  i32.load
                  local.get 2
                  i32.add
                  local.get 4
                  local.get 5
                  i32.sub
                  i32.store
                end
                local.get 0
                i32.const 1
                i32.store8 offset=45
                return
              end
              local.get 6
              local.get 7
              call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
              unreachable
            end
            local.get 7
            local.get 8
            call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
            unreachable
          end
          local.get 2
          local.get 5
          call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
          unreachable
        end
        i32.const 1049784
        call $_ZN4core9panicking5panic17h1fb303f1c113605dE
        unreachable
      end
      local.get 2
      local.get 3
      call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
      unreachable
    end
    i32.const 1049784
    call $_ZN4core9panicking5panic17h1fb303f1c113605dE
    unreachable)
  (func $__rust_alloc (type 2) (param i32 i32) (result i32)
    (local i32)
    local.get 0
    local.get 1
    call $__rdl_alloc
    local.set 2
    local.get 2
    return)
  (func $__rust_dealloc (type 4) (param i32 i32 i32)
    local.get 0
    local.get 1
    local.get 2
    call $__rdl_dealloc
    return)
  (func $__rust_realloc (type 9) (param i32 i32 i32 i32) (result i32)
    (local i32)
    local.get 0
    local.get 1
    local.get 2
    local.get 3
    call $__rdl_realloc
    local.set 4
    local.get 4
    return)
  (func $__rust_alloc_zeroed (type 2) (param i32 i32) (result i32)
    (local i32)
    local.get 0
    local.get 1
    call $__rdl_alloc_zeroed
    local.set 2
    local.get 2
    return)
  (func $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17hf963d3f015ba5d6cE.llvm.4110220102860285710 (type 3)
    call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
    unreachable)
  (func $_ZN11flatbuffers7builder17FlatBufferBuilder17new_with_capacity17h44002bf5761bf963E (type 0) (param i32 i32)
    (local i32)
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          local.get 1
          i32.const -2147483648
          i32.gt_u
          br_if 0 (;@3;)
          local.get 1
          i32.const -1
          i32.le_s
          br_if 1 (;@2;)
          block  ;; label = @4
            block  ;; label = @5
              local.get 1
              br_if 0 (;@5;)
              i32.const 1
              local.set 2
              br 1 (;@4;)
            end
            local.get 1
            i32.const 1
            call $__rust_alloc_zeroed
            local.tee 2
            i32.eqz
            br_if 3 (;@1;)
          end
          local.get 0
          i64.const 4
          i64.store offset=16 align=4
          local.get 0
          local.get 1
          i32.store offset=12
          local.get 0
          local.get 1
          i32.store offset=8
          local.get 0
          local.get 1
          i32.store offset=4
          local.get 0
          local.get 2
          i32.store
          local.get 0
          i32.const 32
          i32.add
          i64.const 0
          i64.store align=4
          local.get 0
          i32.const 24
          i32.add
          i64.const 17179869184
          i64.store align=4
          local.get 0
          i32.const 38
          i32.add
          i64.const 0
          i64.store align=2
          return
        end
        i32.const 1049996
        i32.const 48
        i32.const 1049980
        call $_ZN3std9panicking11begin_panic17h90e4280fdc05adacE
        unreachable
      end
      call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17hf963d3f015ba5d6cE.llvm.4110220102860285710
      unreachable
    end
    local.get 1
    i32.const 1
    call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
    unreachable)
  (func $_ZN11flatbuffers7builder17FlatBufferBuilder12write_vtable17hcd1f528e78ed5e7eE (type 2) (param i32 i32) (result i32)
    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    global.get 0
    i32.const 32
    i32.sub
    local.tee 2
    global.set 0
    local.get 0
    local.get 0
    i32.load offset=40
    local.tee 3
    i32.const 4
    local.get 3
    i32.const 4
    i32.gt_u
    select
    i32.store offset=40
    local.get 0
    local.get 0
    i32.load offset=12
    local.get 0
    i32.const 8
    i32.add
    local.tee 3
    i32.load
    i32.sub
    i32.const 3
    i32.and
    call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.3
    local.get 0
    i32.const 4
    call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.3
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                block  ;; label = @7
                  block  ;; label = @8
                    block  ;; label = @9
                      block  ;; label = @10
                        block  ;; label = @11
                          block  ;; label = @12
                            block  ;; label = @13
                              local.get 3
                              i32.load
                              local.tee 4
                              local.get 0
                              i32.load offset=12
                              local.tee 3
                              i32.lt_u
                              br_if 0 (;@13;)
                              local.get 4
                              local.get 3
                              i32.sub
                              i32.const 3
                              i32.le_u
                              br_if 1 (;@12;)
                              local.get 0
                              i32.load
                              local.get 3
                              i32.add
                              i32.const -252645136
                              i32.store
                              local.get 0
                              i32.const 8
                              i32.add
                              local.tee 5
                              i32.load
                              local.set 6
                              local.get 0
                              i32.load offset=12
                              local.set 7
                              block  ;; label = @14
                                block  ;; label = @15
                                  local.get 0
                                  i32.const 24
                                  i32.add
                                  i32.load
                                  local.tee 8
                                  br_if 0 (;@15;)
                                  i32.const 4
                                  local.set 9
                                  br 1 (;@14;)
                                end
                                local.get 0
                                i32.load offset=16
                                local.tee 4
                                i32.const 4
                                i32.add
                                i32.load16_u
                                local.set 3
                                block  ;; label = @15
                                  local.get 8
                                  i32.const 1
                                  i32.eq
                                  br_if 0 (;@15;)
                                  local.get 4
                                  i32.const 12
                                  i32.add
                                  local.set 4
                                  local.get 8
                                  i32.const 3
                                  i32.shl
                                  i32.const -8
                                  i32.add
                                  local.set 8
                                  loop  ;; label = @16
                                    local.get 3
                                    local.get 4
                                    i32.load16_s
                                    local.tee 9
                                    local.get 3
                                    i32.const 16
                                    i32.shl
                                    i32.const 16
                                    i32.shr_s
                                    local.get 9
                                    i32.gt_s
                                    select
                                    local.set 3
                                    local.get 4
                                    i32.const 8
                                    i32.add
                                    local.set 4
                                    local.get 8
                                    i32.const -8
                                    i32.add
                                    local.tee 8
                                    br_if 0 (;@16;)
                                  end
                                end
                                local.get 3
                                i32.const 16
                                i32.shl
                                i32.const 16
                                i32.shr_s
                                i32.const 2
                                i32.add
                                local.set 9
                              end
                              local.get 0
                              local.get 9
                              call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.3
                              local.get 0
                              i32.load offset=12
                              local.tee 10
                              local.get 9
                              i32.add
                              local.tee 11
                              local.get 10
                              i32.lt_u
                              br_if 2 (;@11;)
                              local.get 5
                              i32.load
                              local.tee 3
                              local.get 11
                              i32.lt_u
                              br_if 3 (;@10;)
                              local.get 9
                              i32.const 1
                              i32.le_u
                              br_if 4 (;@9;)
                              local.get 0
                              i32.load
                              local.get 10
                              i32.add
                              local.tee 12
                              local.get 9
                              i32.store16
                              local.get 9
                              i32.const 3
                              i32.le_u
                              br_if 5 (;@8;)
                              local.get 12
                              local.get 6
                              local.get 7
                              i32.sub
                              local.tee 5
                              local.get 1
                              i32.sub
                              i32.store16 offset=2
                              block  ;; label = @14
                                local.get 0
                                i32.load offset=24
                                local.tee 4
                                i32.eqz
                                br_if 0 (;@14;)
                                local.get 0
                                i32.load offset=16
                                local.tee 3
                                local.get 4
                                i32.const 3
                                i32.shl
                                i32.add
                                local.set 1
                                loop  ;; label = @15
                                  local.get 3
                                  i32.const 4
                                  i32.add
                                  i32.load16_s
                                  local.tee 4
                                  i32.const 2
                                  i32.add
                                  local.set 8
                                  local.get 4
                                  i32.const -3
                                  i32.gt_u
                                  br_if 8 (;@7;)
                                  local.get 9
                                  local.get 8
                                  i32.lt_u
                                  br_if 9 (;@6;)
                                  local.get 12
                                  local.get 4
                                  i32.add
                                  local.get 5
                                  local.get 3
                                  i32.load
                                  i32.sub
                                  i32.store16
                                  local.get 3
                                  i32.const 8
                                  i32.add
                                  local.tee 3
                                  local.get 1
                                  i32.ne
                                  br_if 0 (;@15;)
                                end
                              end
                              local.get 0
                              i32.const 12
                              i32.add
                              local.set 7
                              local.get 0
                              i32.const 8
                              i32.add
                              local.tee 12
                              i32.load
                              local.set 3
                              local.get 0
                              i32.load
                              local.set 4
                              local.get 2
                              local.get 0
                              i32.load offset=12
                              i32.store offset=8
                              local.get 2
                              local.get 3
                              i32.store offset=4
                              local.get 2
                              local.get 4
                              i32.store
                              local.get 0
                              i32.const 36
                              i32.add
                              local.tee 6
                              i32.load
                              i32.const 2
                              i32.shl
                              local.set 3
                              local.get 0
                              i32.load offset=28
                              i32.const -4
                              i32.add
                              local.set 1
                              block  ;; label = @14
                                block  ;; label = @15
                                  loop  ;; label = @16
                                    local.get 3
                                    i32.eqz
                                    br_if 1 (;@15;)
                                    local.get 1
                                    local.get 3
                                    i32.add
                                    i32.load
                                    local.set 4
                                    local.get 2
                                    local.get 12
                                    i32.load
                                    local.tee 8
                                    i32.store offset=20
                                    local.get 2
                                    local.get 0
                                    i32.load
                                    i32.store offset=16
                                    local.get 2
                                    local.get 8
                                    local.get 4
                                    i32.sub
                                    i32.store offset=24
                                    local.get 3
                                    i32.const -4
                                    i32.add
                                    local.set 3
                                    local.get 2
                                    local.get 2
                                    i32.const 16
                                    i32.add
                                    call $_ZN68_$LT$flatbuffers..vtable..VTable$u20$as$u20$core..cmp..PartialEq$GT$2eq17h4079535067fc9a31E
                                    i32.eqz
                                    br_if 0 (;@16;)
                                  end
                                  local.get 0
                                  i32.const 8
                                  i32.add
                                  i32.load
                                  local.tee 3
                                  local.get 11
                                  i32.lt_u
                                  br_if 12 (;@3;)
                                  local.get 0
                                  i32.load
                                  local.get 10
                                  i32.add
                                  i32.const 0
                                  local.get 9
                                  call $memset
                                  drop
                                  local.get 7
                                  local.set 6
                                  br 1 (;@14;)
                                end
                                local.get 0
                                i32.const 8
                                i32.add
                                i32.load
                                local.set 4
                                local.get 0
                                i32.load offset=12
                                local.set 8
                                block  ;; label = @15
                                  local.get 0
                                  i32.load offset=36
                                  local.tee 3
                                  local.get 0
                                  i32.const 32
                                  i32.add
                                  i32.load
                                  i32.ne
                                  br_if 0 (;@15;)
                                  local.get 3
                                  i32.const 1
                                  i32.add
                                  local.tee 9
                                  local.get 3
                                  i32.lt_u
                                  br_if 11 (;@4;)
                                  local.get 3
                                  i32.const 1
                                  i32.shl
                                  local.tee 12
                                  local.get 9
                                  local.get 9
                                  local.get 12
                                  i32.lt_u
                                  select
                                  local.tee 9
                                  i32.const 1073741823
                                  i32.and
                                  local.get 9
                                  i32.ne
                                  br_if 11 (;@4;)
                                  local.get 9
                                  i32.const 2
                                  i32.shl
                                  local.tee 12
                                  i32.const 0
                                  i32.lt_s
                                  br_if 11 (;@4;)
                                  block  ;; label = @16
                                    block  ;; label = @17
                                      local.get 3
                                      br_if 0 (;@17;)
                                      local.get 12
                                      i32.const 4
                                      call $__rust_alloc
                                      local.set 3
                                      br 1 (;@16;)
                                    end
                                    local.get 0
                                    i32.load offset=28
                                    local.get 3
                                    i32.const 2
                                    i32.shl
                                    i32.const 4
                                    local.get 12
                                    call $__rust_realloc
                                    local.set 3
                                  end
                                  local.get 3
                                  i32.eqz
                                  br_if 10 (;@5;)
                                  local.get 0
                                  local.get 3
                                  i32.store offset=28
                                  local.get 0
                                  i32.const 32
                                  i32.add
                                  local.get 9
                                  i32.store
                                  local.get 0
                                  i32.load offset=36
                                  local.set 3
                                end
                                local.get 0
                                i32.load offset=28
                                local.get 3
                                i32.const 2
                                i32.shl
                                i32.add
                                local.get 4
                                local.get 8
                                i32.sub
                                local.tee 4
                                i32.store
                                i32.const 1
                                local.set 9
                              end
                              local.get 6
                              local.get 6
                              i32.load
                              local.get 9
                              i32.add
                              i32.store
                              local.get 0
                              i32.const 8
                              i32.add
                              i32.load
                              local.tee 8
                              local.get 5
                              i32.sub
                              local.tee 3
                              i32.const 4
                              i32.add
                              local.set 9
                              local.get 3
                              i32.const -5
                              i32.gt_u
                              br_if 11 (;@2;)
                              local.get 8
                              local.get 9
                              i32.lt_u
                              br_if 12 (;@1;)
                              local.get 0
                              i32.load
                              local.get 3
                              i32.add
                              local.get 4
                              local.get 5
                              i32.sub
                              i32.store
                              local.get 0
                              i32.const 0
                              i32.store offset=24
                              local.get 2
                              i32.const 32
                              i32.add
                              global.set 0
                              local.get 5
                              return
                            end
                            local.get 3
                            local.get 4
                            call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
                            unreachable
                          end
                          i32.const 1049860
                          call $_ZN4core9panicking5panic17h1fb303f1c113605dE
                          unreachable
                        end
                        local.get 10
                        local.get 11
                        call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
                        unreachable
                      end
                      local.get 11
                      local.get 3
                      call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
                      unreachable
                    end
                    i32.const 2
                    local.get 9
                    call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
                    unreachable
                  end
                  i32.const 4
                  local.get 9
                  call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
                  unreachable
                end
                local.get 4
                local.get 8
                call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
                unreachable
              end
              local.get 8
              local.get 9
              call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
              unreachable
            end
            local.get 12
            i32.const 4
            call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
            unreachable
          end
          call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
          unreachable
        end
        local.get 11
        local.get 3
        call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
        unreachable
      end
      local.get 3
      local.get 9
      call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
      unreachable
    end
    local.get 9
    local.get 8
    call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
    unreachable)
  (func $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.3 (type 0) (param i32 i32)
    (local i32 i32 i32 i32 i32 i32 i32 i32)
    global.get 0
    i32.const 96
    i32.sub
    local.tee 2
    global.set 0
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              local.get 0
              i32.const 12
              i32.add
              local.tee 3
              i32.load
              local.tee 4
              local.get 1
              i32.ge_u
              br_if 0 (;@5;)
              local.get 1
              i32.const -2147483648
              i32.gt_u
              br_if 1 (;@4;)
              local.get 0
              i32.const 8
              i32.add
              local.set 5
              local.get 0
              i32.const 12
              i32.add
              local.set 6
              loop  ;; label = @6
                local.get 0
                local.get 5
                i32.load
                local.tee 4
                i32.const 1
                i32.shl
                local.tee 7
                i32.const 1
                local.get 7
                select
                local.tee 8
                i32.const 0
                call $_ZN5alloc3vec12Vec$LT$T$GT$6resize17hb0da3021419efc71E
                local.get 6
                local.get 6
                i32.load
                local.get 4
                i32.sub
                local.get 8
                i32.add
                local.tee 4
                i32.store
                block  ;; label = @7
                  local.get 7
                  i32.eqz
                  br_if 0 (;@7;)
                  local.get 5
                  i32.load
                  local.tee 9
                  local.get 8
                  i32.const 1
                  i32.shr_u
                  local.tee 7
                  i32.lt_u
                  br_if 4 (;@3;)
                  local.get 0
                  i32.load
                  local.set 4
                  local.get 2
                  local.get 9
                  local.get 7
                  i32.sub
                  local.tee 8
                  i32.store offset=8
                  local.get 2
                  local.get 7
                  i32.store offset=12
                  local.get 8
                  local.get 7
                  i32.ne
                  br_if 5 (;@2;)
                  local.get 4
                  local.get 7
                  i32.add
                  local.get 4
                  local.get 7
                  call $memcpy
                  drop
                  local.get 5
                  i32.load
                  local.tee 4
                  local.get 7
                  i32.lt_u
                  br_if 6 (;@1;)
                  local.get 0
                  i32.load
                  i32.const 0
                  local.get 7
                  call $memset
                  drop
                  local.get 6
                  i32.load
                  local.set 4
                end
                local.get 4
                local.get 1
                i32.lt_u
                br_if 0 (;@6;)
              end
            end
            local.get 3
            local.get 4
            local.get 1
            i32.sub
            i32.store
            local.get 2
            i32.const 96
            i32.add
            global.set 0
            return
          end
          i32.const 1050060
          i32.const 37
          i32.const 1050044
          call $_ZN3std9panicking11begin_panic17h90e4280fdc05adacE
          unreachable
        end
        i32.const 1049860
        call $_ZN4core9panicking5panic17h1fb303f1c113605dE
        unreachable
      end
      local.get 2
      i32.const 40
      i32.add
      i32.const 20
      i32.add
      i32.const 7
      i32.store
      local.get 2
      i32.const 52
      i32.add
      i32.const 9
      i32.store
      local.get 2
      i32.const 16
      i32.add
      i32.const 20
      i32.add
      i32.const 3
      i32.store
      local.get 2
      local.get 2
      i32.const 8
      i32.add
      i32.store offset=64
      local.get 2
      local.get 2
      i32.const 12
      i32.add
      i32.store offset=68
      local.get 2
      i32.const 72
      i32.add
      i32.const 20
      i32.add
      i32.const 0
      i32.store
      local.get 2
      i64.const 3
      i64.store offset=20 align=4
      local.get 2
      i32.const 1050160
      i32.store offset=16
      local.get 2
      i32.const 9
      i32.store offset=44
      local.get 2
      i32.const 1050244
      i32.store offset=88
      local.get 2
      i64.const 1
      i64.store offset=76 align=4
      local.get 2
      i32.const 1050236
      i32.store offset=72
      local.get 2
      local.get 2
      i32.const 40
      i32.add
      i32.store offset=32
      local.get 2
      local.get 2
      i32.const 72
      i32.add
      i32.store offset=56
      local.get 2
      local.get 2
      i32.const 68
      i32.add
      i32.store offset=48
      local.get 2
      local.get 2
      i32.const 64
      i32.add
      i32.store offset=40
      local.get 2
      i32.const 16
      i32.add
      i32.const 1050268
      call $_ZN4core9panicking9panic_fmt17h52bd9c4c06b66d8dE
      unreachable
    end
    local.get 7
    local.get 4
    call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
    unreachable)
  (func $_ZN5alloc3vec12Vec$LT$T$GT$6resize17hb0da3021419efc71E (type 4) (param i32 i32 i32)
    (local i32 i32 i32 i32 i32)
    block  ;; label = @1
      block  ;; label = @2
        local.get 0
        i32.const 8
        i32.add
        i32.load
        local.tee 3
        local.get 1
        i32.lt_u
        br_if 0 (;@2;)
        local.get 1
        local.get 3
        local.get 3
        local.get 1
        i32.gt_u
        select
        local.set 4
        br 1 (;@1;)
      end
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                block  ;; label = @7
                  local.get 0
                  i32.const 4
                  i32.add
                  i32.load
                  local.tee 5
                  local.get 3
                  i32.sub
                  local.get 1
                  local.get 3
                  i32.sub
                  local.tee 6
                  i32.lt_u
                  br_if 0 (;@7;)
                  local.get 0
                  i32.load
                  local.set 5
                  local.get 3
                  local.set 4
                  br 1 (;@6;)
                end
                local.get 3
                local.get 6
                i32.add
                local.tee 4
                local.get 3
                i32.lt_u
                br_if 2 (;@4;)
                local.get 5
                i32.const 1
                i32.shl
                local.tee 7
                local.get 4
                local.get 4
                local.get 7
                i32.lt_u
                select
                local.tee 4
                i32.const 0
                i32.lt_s
                br_if 2 (;@4;)
                block  ;; label = @7
                  block  ;; label = @8
                    local.get 5
                    br_if 0 (;@8;)
                    local.get 4
                    i32.const 1
                    call $__rust_alloc
                    local.set 5
                    br 1 (;@7;)
                  end
                  local.get 0
                  i32.load
                  local.get 5
                  i32.const 1
                  local.get 4
                  call $__rust_realloc
                  local.set 5
                end
                local.get 5
                i32.eqz
                br_if 1 (;@5;)
                local.get 0
                local.get 5
                i32.store
                local.get 0
                i32.const 4
                i32.add
                local.get 4
                i32.store
                local.get 0
                i32.const 8
                i32.add
                i32.load
                local.set 4
              end
              local.get 5
              local.get 4
              i32.add
              local.set 5
              local.get 6
              i32.const 2
              i32.lt_u
              br_if 2 (;@3;)
              local.get 5
              local.get 2
              local.get 3
              i32.const -1
              i32.xor
              local.get 1
              i32.add
              local.tee 6
              call $memset
              drop
              local.get 4
              local.get 1
              i32.add
              local.set 1
              loop  ;; label = @6
                local.get 5
                i32.const 1
                i32.add
                local.set 5
                local.get 6
                i32.const -1
                i32.add
                local.tee 6
                br_if 0 (;@6;)
              end
              local.get 1
              local.get 3
              i32.const -1
              i32.xor
              i32.add
              local.set 4
              br 3 (;@2;)
            end
            local.get 4
            i32.const 1
            call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
            unreachable
          end
          call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
          unreachable
        end
        local.get 6
        i32.eqz
        br_if 1 (;@1;)
      end
      local.get 5
      local.get 2
      i32.store8
      local.get 4
      i32.const 1
      i32.add
      local.set 4
    end
    local.get 0
    i32.const 8
    i32.add
    local.get 4
    i32.store)
  (func $_ZN68_$LT$flatbuffers..vtable..VTable$u20$as$u20$core..cmp..PartialEq$GT$2eq17h4079535067fc9a31E (type 2) (param i32 i32) (result i32)
    (local i32 i32 i32 i32 i32)
    local.get 0
    i32.load offset=8
    local.tee 2
    i32.const 2
    i32.add
    local.set 3
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                block  ;; label = @7
                  block  ;; label = @8
                    local.get 2
                    i32.const -3
                    i32.gt_u
                    br_if 0 (;@8;)
                    local.get 3
                    local.get 0
                    i32.load offset=4
                    local.tee 4
                    i32.gt_u
                    br_if 1 (;@7;)
                    local.get 2
                    local.get 0
                    i32.load
                    local.get 2
                    i32.add
                    local.tee 5
                    i32.load16_s
                    local.tee 0
                    i32.add
                    local.tee 3
                    local.get 2
                    i32.lt_u
                    br_if 2 (;@6;)
                    local.get 4
                    local.get 3
                    i32.lt_u
                    br_if 3 (;@5;)
                    local.get 1
                    i32.load offset=8
                    local.tee 2
                    i32.const 2
                    i32.add
                    local.set 3
                    local.get 2
                    i32.const -3
                    i32.gt_u
                    br_if 4 (;@4;)
                    local.get 3
                    local.get 1
                    i32.load offset=4
                    local.tee 4
                    i32.gt_u
                    br_if 5 (;@3;)
                    local.get 2
                    local.get 1
                    i32.load
                    local.get 2
                    i32.add
                    local.tee 6
                    i32.load16_s
                    local.tee 1
                    i32.add
                    local.tee 3
                    local.get 2
                    i32.lt_u
                    br_if 6 (;@2;)
                    local.get 4
                    local.get 3
                    i32.lt_u
                    br_if 7 (;@1;)
                    i32.const 0
                    local.set 2
                    block  ;; label = @9
                      local.get 0
                      local.get 1
                      i32.ne
                      br_if 0 (;@9;)
                      block  ;; label = @10
                        local.get 5
                        local.get 6
                        i32.ne
                        br_if 0 (;@10;)
                        i32.const 1
                        return
                      end
                      local.get 5
                      local.get 6
                      local.get 0
                      call $memcmp
                      i32.eqz
                      local.set 2
                    end
                    local.get 2
                    return
                  end
                  local.get 2
                  local.get 3
                  call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
                  unreachable
                end
                local.get 3
                local.get 4
                call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
                unreachable
              end
              local.get 2
              local.get 3
              call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
              unreachable
            end
            local.get 3
            local.get 4
            call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
            unreachable
          end
          local.get 2
          local.get 3
          call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
          unreachable
        end
        local.get 3
        local.get 4
        call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
        unreachable
      end
      local.get 2
      local.get 3
      call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
      unreachable
    end
    local.get 3
    local.get 4
    call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
    unreachable)
  (func $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17h62254d034ac8f094E (type 7) (param i32) (result i64)
    i64.const 1229646359891580772)
  (func $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17hee077d8ebd6c8808E (type 7) (param i32) (result i64)
    i64.const 7549865886324542212)
  (func $_ZN3std9panicking11begin_panic17h90e4280fdc05adacE (type 4) (param i32 i32 i32)
    (local i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 3
    global.set 0
    local.get 3
    local.get 1
    i32.store offset=12
    local.get 3
    local.get 0
    i32.store offset=8
    local.get 3
    i32.const 8
    i32.add
    i32.const 1050284
    i32.const 0
    local.get 2
    call $_ZN3std9panicking20rust_panic_with_hook17h868a29d5aa6e3f6fE
    unreachable)
  (func $_ZN4core3ptr18real_drop_in_place17h01dc3ff363e02a2aE (type 5) (param i32))
  (func $_ZN4core3ptr18real_drop_in_place17h18af938be9857b46E (type 5) (param i32))
  (func $_ZN91_$LT$std..panicking..begin_panic..PanicPayload$LT$A$GT$$u20$as$u20$core..panic..BoxMeUp$GT$3get17hce68feec1b34af62E (type 0) (param i32 i32)
    (local i32)
    local.get 0
    i32.const 1050320
    i32.const 1050304
    local.get 1
    i32.load
    local.tee 2
    select
    i32.store offset=4
    local.get 0
    local.get 1
    i32.const 1050304
    local.get 2
    select
    i32.store)
  (func $_ZN91_$LT$std..panicking..begin_panic..PanicPayload$LT$A$GT$$u20$as$u20$core..panic..BoxMeUp$GT$9box_me_up17h27e7c64f2151a277E (type 0) (param i32 i32)
    (local i32 i32)
    local.get 1
    i32.load
    local.set 2
    local.get 1
    i32.const 0
    i32.store
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          local.get 2
          br_if 0 (;@3;)
          i32.const 1
          local.set 1
          i32.const 1050304
          local.set 2
          br 1 (;@2;)
        end
        local.get 1
        i32.load offset=4
        local.set 3
        i32.const 8
        i32.const 4
        call $__rust_alloc
        local.tee 1
        i32.eqz
        br_if 1 (;@1;)
        local.get 1
        local.get 3
        i32.store offset=4
        local.get 1
        local.get 2
        i32.store
        i32.const 1050320
        local.set 2
      end
      local.get 0
      local.get 2
      i32.store offset=4
      local.get 0
      local.get 1
      i32.store
      return
    end
    i32.const 8
    i32.const 4
    call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
    unreachable)
  (func $_ZN42_$LT$$RF$T$u20$as$u20$core..fmt..Debug$GT$3fmt17ha7817e91bf95d0d2E (type 2) (param i32 i32) (result i32)
    local.get 0
    i32.load
    local.set 0
    block  ;; label = @1
      local.get 1
      call $_ZN4core3fmt9Formatter15debug_lower_hex17h793eb06599a6f4afE
      br_if 0 (;@1;)
      block  ;; label = @2
        local.get 1
        call $_ZN4core3fmt9Formatter15debug_upper_hex17h04e91d8eabf032bdE
        br_if 0 (;@2;)
        local.get 0
        local.get 1
        call $_ZN4core3fmt3num3imp52_$LT$impl$u20$core..fmt..Display$u20$for$u20$u32$GT$3fmt17h1c0bcbdea3856b66E
        return
      end
      local.get 0
      local.get 1
      call $_ZN4core3fmt3num53_$LT$impl$u20$core..fmt..UpperHex$u20$for$u20$i32$GT$3fmt17hfd1f5de01f0dfb51E
      return
    end
    local.get 0
    local.get 1
    call $_ZN4core3fmt3num53_$LT$impl$u20$core..fmt..LowerHex$u20$for$u20$i32$GT$3fmt17h8ac32090674e93f6E)
  (func $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17h1ffa740b2640435fE (type 7) (param i32) (result i64)
    i64.const 1145285805598152968)
  (func $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17hba0a1a7ef3521e31E (type 7) (param i32) (result i64)
    i64.const 6849931393926300958)
  (func $_ZN4core3ptr18real_drop_in_place17h194e86810a2d41bcE (type 5) (param i32))
  (func $_ZN4core3ptr18real_drop_in_place17h1e18bed522b4a4cdE (type 5) (param i32)
    (local i32)
    block  ;; label = @1
      local.get 0
      i32.load offset=4
      local.tee 1
      i32.eqz
      br_if 0 (;@1;)
      local.get 0
      i32.load
      local.get 1
      i32.const 1
      call $__rust_dealloc
    end)
  (func $_ZN4core3ptr18real_drop_in_place17ha9e5ebb6b6afa0f2E (type 5) (param i32)
    (local i32)
    block  ;; label = @1
      local.get 0
      i32.load offset=4
      local.tee 1
      i32.eqz
      br_if 0 (;@1;)
      local.get 0
      i32.const 8
      i32.add
      i32.load
      local.tee 0
      i32.eqz
      br_if 0 (;@1;)
      local.get 1
      local.get 0
      i32.const 1
      call $__rust_dealloc
    end)
  (func $_ZN4core6option15Option$LT$T$GT$6unwrap17h99fb07dbd9c42ce1E (type 6) (param i32) (result i32)
    block  ;; label = @1
      local.get 0
      br_if 0 (;@1;)
      i32.const 1050440
      call $_ZN4core9panicking5panic17h1fb303f1c113605dE
      unreachable
    end
    local.get 0)
  (func $_ZN4core6option15Option$LT$T$GT$6unwrap17hb71a7ffe6558a5a2E (type 6) (param i32) (result i32)
    block  ;; label = @1
      local.get 0
      br_if 0 (;@1;)
      i32.const 1050440
      call $_ZN4core9panicking5panic17h1fb303f1c113605dE
      unreachable
    end
    local.get 0)
  (func $_ZN50_$LT$$RF$mut$u20$W$u20$as$u20$core..fmt..Write$GT$10write_char17h01c83a182d3c68a2E (type 2) (param i32 i32) (result i32)
    (local i32 i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 2
    global.set 0
    local.get 0
    i32.load
    local.set 0
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            local.get 1
            i32.const 128
            i32.lt_u
            br_if 0 (;@4;)
            local.get 2
            i32.const 0
            i32.store offset=12
            local.get 1
            i32.const 2048
            i32.lt_u
            br_if 1 (;@3;)
            block  ;; label = @5
              local.get 1
              i32.const 65536
              i32.ge_u
              br_if 0 (;@5;)
              local.get 2
              local.get 1
              i32.const 63
              i32.and
              i32.const 128
              i32.or
              i32.store8 offset=14
              local.get 2
              local.get 1
              i32.const 6
              i32.shr_u
              i32.const 63
              i32.and
              i32.const 128
              i32.or
              i32.store8 offset=13
              local.get 2
              local.get 1
              i32.const 12
              i32.shr_u
              i32.const 15
              i32.and
              i32.const 224
              i32.or
              i32.store8 offset=12
              i32.const 3
              local.set 1
              br 3 (;@2;)
            end
            local.get 2
            local.get 1
            i32.const 63
            i32.and
            i32.const 128
            i32.or
            i32.store8 offset=15
            local.get 2
            local.get 1
            i32.const 18
            i32.shr_u
            i32.const 240
            i32.or
            i32.store8 offset=12
            local.get 2
            local.get 1
            i32.const 6
            i32.shr_u
            i32.const 63
            i32.and
            i32.const 128
            i32.or
            i32.store8 offset=14
            local.get 2
            local.get 1
            i32.const 12
            i32.shr_u
            i32.const 63
            i32.and
            i32.const 128
            i32.or
            i32.store8 offset=13
            i32.const 4
            local.set 1
            br 2 (;@2;)
          end
          block  ;; label = @4
            local.get 0
            i32.load offset=8
            local.tee 3
            local.get 0
            i32.load offset=4
            i32.ne
            br_if 0 (;@4;)
            local.get 0
            i32.const 1
            call $_ZN5alloc3vec12Vec$LT$T$GT$7reserve17h32e26e1292808e78E
            local.get 0
            i32.load offset=8
            local.set 3
          end
          local.get 0
          i32.load
          local.get 3
          i32.add
          local.get 1
          i32.store8
          local.get 0
          local.get 0
          i32.load offset=8
          i32.const 1
          i32.add
          i32.store offset=8
          br 2 (;@1;)
        end
        local.get 2
        local.get 1
        i32.const 63
        i32.and
        i32.const 128
        i32.or
        i32.store8 offset=13
        local.get 2
        local.get 1
        i32.const 6
        i32.shr_u
        i32.const 31
        i32.and
        i32.const 192
        i32.or
        i32.store8 offset=12
        i32.const 2
        local.set 1
      end
      local.get 0
      local.get 1
      call $_ZN5alloc3vec12Vec$LT$T$GT$7reserve17h32e26e1292808e78E
      local.get 0
      local.get 0
      i32.load offset=8
      local.tee 3
      local.get 1
      i32.add
      i32.store offset=8
      local.get 3
      local.get 0
      i32.load
      i32.add
      local.get 2
      i32.const 12
      i32.add
      local.get 1
      call $memcpy
      drop
    end
    local.get 2
    i32.const 16
    i32.add
    global.set 0
    i32.const 0)
  (func $_ZN5alloc3vec12Vec$LT$T$GT$7reserve17h32e26e1292808e78E (type 0) (param i32 i32)
    (local i32 i32)
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          local.get 0
          i32.load offset=4
          local.tee 2
          local.get 0
          i32.load offset=8
          local.tee 3
          i32.sub
          local.get 1
          i32.ge_u
          br_if 0 (;@3;)
          local.get 3
          local.get 1
          i32.add
          local.tee 1
          local.get 3
          i32.lt_u
          br_if 2 (;@1;)
          local.get 2
          i32.const 1
          i32.shl
          local.tee 3
          local.get 1
          local.get 1
          local.get 3
          i32.lt_u
          select
          local.tee 1
          i32.const 0
          i32.lt_s
          br_if 2 (;@1;)
          block  ;; label = @4
            block  ;; label = @5
              local.get 2
              br_if 0 (;@5;)
              local.get 1
              i32.const 1
              call $__rust_alloc
              local.set 2
              br 1 (;@4;)
            end
            local.get 0
            i32.load
            local.get 2
            i32.const 1
            local.get 1
            call $__rust_realloc
            local.set 2
          end
          local.get 2
          i32.eqz
          br_if 1 (;@2;)
          local.get 0
          local.get 1
          i32.store offset=4
          local.get 0
          local.get 2
          i32.store
        end
        return
      end
      local.get 1
      i32.const 1
      call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
      unreachable
    end
    call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
    unreachable)
  (func $_ZN50_$LT$$RF$mut$u20$W$u20$as$u20$core..fmt..Write$GT$9write_fmt17ha18d073f4bdaf9caE (type 2) (param i32 i32) (result i32)
    (local i32)
    global.get 0
    i32.const 32
    i32.sub
    local.tee 2
    global.set 0
    local.get 2
    local.get 0
    i32.load
    i32.store offset=4
    local.get 2
    i32.const 8
    i32.add
    i32.const 16
    i32.add
    local.get 1
    i32.const 16
    i32.add
    i64.load align=4
    i64.store
    local.get 2
    i32.const 8
    i32.add
    i32.const 8
    i32.add
    local.get 1
    i32.const 8
    i32.add
    i64.load align=4
    i64.store
    local.get 2
    local.get 1
    i64.load align=4
    i64.store offset=8
    local.get 2
    i32.const 4
    i32.add
    i32.const 1050336
    local.get 2
    i32.const 8
    i32.add
    call $_ZN4core3fmt5write17hd3aab830518de99fE
    local.set 1
    local.get 2
    i32.const 32
    i32.add
    global.set 0
    local.get 1)
  (func $_ZN50_$LT$$RF$mut$u20$W$u20$as$u20$core..fmt..Write$GT$9write_str17h72d3f0de1e233110E (type 1) (param i32 i32 i32) (result i32)
    (local i32)
    local.get 0
    i32.load
    local.tee 0
    local.get 2
    call $_ZN5alloc3vec12Vec$LT$T$GT$7reserve17h32e26e1292808e78E
    local.get 0
    local.get 0
    i32.load offset=8
    local.tee 3
    local.get 2
    i32.add
    i32.store offset=8
    local.get 3
    local.get 0
    i32.load
    i32.add
    local.get 1
    local.get 2
    call $memcpy
    drop
    i32.const 0)
  (func $_ZN76_$LT$std..sys_common..thread_local..Key$u20$as$u20$core..ops..drop..Drop$GT$4drop17ha98b17b5e613edf7E (type 5) (param i32))
  (func $_ZN3std5alloc24default_alloc_error_hook17h7e3753373bf77437E (type 0) (param i32 i32))
  (func $rust_oom (type 0) (param i32 i32)
    (local i32)
    local.get 0
    local.get 1
    i32.const 0
    i32.load offset=1051160
    local.tee 2
    i32.const 16
    local.get 2
    select
    call_indirect (type 0)
    unreachable
    unreachable)
  (func $__rdl_alloc (type 2) (param i32 i32) (result i32)
    block  ;; label = @1
      i32.const 1051176
      call $_ZN8dlmalloc8dlmalloc8Dlmalloc16malloc_alignment17h9bc92124581be9ecE
      local.get 1
      i32.ge_u
      br_if 0 (;@1;)
      i32.const 1051176
      local.get 1
      local.get 0
      call $_ZN8dlmalloc8dlmalloc8Dlmalloc8memalign17h5b13792549d920d9E
      return
    end
    i32.const 1051176
    local.get 0
    call $_ZN8dlmalloc8dlmalloc8Dlmalloc6malloc17h4ea5e05e71d3c045E)
  (func $__rdl_dealloc (type 4) (param i32 i32 i32)
    i32.const 1051176
    local.get 0
    call $_ZN8dlmalloc8dlmalloc8Dlmalloc4free17hffa4364fa24b2098E)
  (func $__rdl_realloc (type 9) (param i32 i32 i32 i32) (result i32)
    block  ;; label = @1
      block  ;; label = @2
        i32.const 1051176
        call $_ZN8dlmalloc8dlmalloc8Dlmalloc16malloc_alignment17h9bc92124581be9ecE
        local.get 2
        i32.ge_u
        br_if 0 (;@2;)
        block  ;; label = @3
          block  ;; label = @4
            i32.const 1051176
            call $_ZN8dlmalloc8dlmalloc8Dlmalloc16malloc_alignment17h9bc92124581be9ecE
            local.get 2
            i32.ge_u
            br_if 0 (;@4;)
            i32.const 1051176
            local.get 2
            local.get 3
            call $_ZN8dlmalloc8dlmalloc8Dlmalloc8memalign17h5b13792549d920d9E
            local.set 2
            br 1 (;@3;)
          end
          i32.const 1051176
          local.get 3
          call $_ZN8dlmalloc8dlmalloc8Dlmalloc6malloc17h4ea5e05e71d3c045E
          local.set 2
        end
        local.get 2
        br_if 1 (;@1;)
        i32.const 0
        return
      end
      i32.const 1051176
      local.get 0
      local.get 3
      call $_ZN8dlmalloc8dlmalloc8Dlmalloc7realloc17h342015522c41c924E
      return
    end
    local.get 2
    local.get 0
    local.get 3
    local.get 1
    local.get 1
    local.get 3
    i32.gt_u
    select
    call $memcpy
    local.set 2
    i32.const 1051176
    local.get 0
    call $_ZN8dlmalloc8dlmalloc8Dlmalloc4free17hffa4364fa24b2098E
    local.get 2)
  (func $__rdl_alloc_zeroed (type 2) (param i32 i32) (result i32)
    block  ;; label = @1
      block  ;; label = @2
        i32.const 1051176
        call $_ZN8dlmalloc8dlmalloc8Dlmalloc16malloc_alignment17h9bc92124581be9ecE
        local.get 1
        i32.ge_u
        br_if 0 (;@2;)
        i32.const 1051176
        local.get 1
        local.get 0
        call $_ZN8dlmalloc8dlmalloc8Dlmalloc8memalign17h5b13792549d920d9E
        local.set 1
        br 1 (;@1;)
      end
      i32.const 1051176
      local.get 0
      call $_ZN8dlmalloc8dlmalloc8Dlmalloc6malloc17h4ea5e05e71d3c045E
      local.set 1
    end
    block  ;; label = @1
      local.get 1
      i32.eqz
      br_if 0 (;@1;)
      i32.const 1051176
      local.get 1
      call $_ZN8dlmalloc8dlmalloc8Dlmalloc17calloc_must_clear17h12013583272156edE
      i32.eqz
      br_if 0 (;@1;)
      local.get 1
      i32.const 0
      local.get 0
      call $memset
      drop
    end
    local.get 1)
  (func $rust_begin_unwind (type 5) (param i32)
    local.get 0
    call $_ZN3std9panicking18continue_panic_fmt17h5bc0f5dc42367f4bE
    unreachable)
  (func $_ZN3std9panicking18continue_panic_fmt17h5bc0f5dc42367f4bE (type 5) (param i32)
    (local i32 i32 i32 i64 i32)
    global.get 0
    i32.const 48
    i32.sub
    local.tee 1
    global.set 0
    local.get 0
    call $_ZN4core5panic9PanicInfo8location17ha2676bb4cd3a13d5E
    call $_ZN4core6option15Option$LT$T$GT$6unwrap17h99fb07dbd9c42ce1E
    local.set 2
    local.get 0
    call $_ZN4core5panic9PanicInfo7message17hdcd25a611da38ea7E
    call $_ZN4core6option15Option$LT$T$GT$6unwrap17hb71a7ffe6558a5a2E
    local.set 3
    local.get 1
    i32.const 8
    i32.add
    local.get 2
    call $_ZN4core5panic8Location4file17hf1af7974a4d66f1aE
    local.get 1
    i64.load offset=8
    local.set 4
    local.get 2
    call $_ZN4core5panic8Location4line17hb259bed5c38d555eE
    local.set 5
    local.get 1
    local.get 2
    call $_ZN4core5panic8Location6column17ha177fe4aa32d620dE
    i32.store offset=28
    local.get 1
    local.get 5
    i32.store offset=24
    local.get 1
    local.get 4
    i64.store offset=16
    local.get 1
    i32.const 0
    i32.store offset=36
    local.get 1
    local.get 3
    i32.store offset=32
    local.get 1
    i32.const 32
    i32.add
    i32.const 1050464
    local.get 0
    call $_ZN4core5panic9PanicInfo7message17hdcd25a611da38ea7E
    local.get 1
    i32.const 16
    i32.add
    call $_ZN3std9panicking20rust_panic_with_hook17h868a29d5aa6e3f6fE
    unreachable)
  (func $_ZN3std9panicking20rust_panic_with_hook17h868a29d5aa6e3f6fE (type 13) (param i32 i32 i32 i32)
    (local i32 i32 i32 i32 i32)
    global.get 0
    i32.const 64
    i32.sub
    local.tee 4
    global.set 0
    i32.const 1
    local.set 5
    local.get 3
    i32.load offset=12
    local.set 6
    local.get 3
    i32.load offset=8
    local.set 7
    local.get 3
    i32.load offset=4
    local.set 8
    local.get 3
    i32.load
    local.set 3
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            i32.const 0
            i32.load offset=1051632
            i32.const 1
            i32.eq
            br_if 0 (;@4;)
            i32.const 0
            i64.const 4294967297
            i64.store offset=1051632
            br 1 (;@3;)
          end
          i32.const 0
          i32.const 0
          i32.load offset=1051636
          i32.const 1
          i32.add
          local.tee 5
          i32.store offset=1051636
          local.get 5
          i32.const 2
          i32.gt_u
          br_if 1 (;@2;)
        end
        local.get 4
        i32.const 48
        i32.add
        local.get 3
        local.get 8
        local.get 7
        local.get 6
        call $_ZN4core5panic8Location20internal_constructor17ha5194c997adfccb1E
        local.get 4
        i32.const 36
        i32.add
        local.get 4
        i32.const 56
        i32.add
        i64.load
        i64.store align=4
        local.get 4
        local.get 2
        i32.store offset=24
        local.get 4
        i32.const 1050360
        i32.store offset=20
        local.get 4
        i32.const 1050360
        i32.store offset=16
        local.get 4
        local.get 4
        i64.load offset=48
        i64.store offset=28 align=4
        i32.const 0
        i32.load offset=1051164
        local.tee 3
        i32.const -1
        i32.le_s
        br_if 0 (;@2;)
        i32.const 0
        local.get 3
        i32.const 1
        i32.add
        local.tee 3
        i32.store offset=1051164
        block  ;; label = @3
          i32.const 0
          i32.load offset=1051172
          local.tee 2
          i32.eqz
          br_if 0 (;@3;)
          i32.const 0
          i32.load offset=1051168
          local.set 3
          local.get 4
          i32.const 8
          i32.add
          local.get 0
          local.get 1
          i32.load offset=16
          call_indirect (type 0)
          local.get 4
          local.get 4
          i64.load offset=8
          i64.store offset=16
          local.get 3
          local.get 4
          i32.const 16
          i32.add
          local.get 2
          i32.load offset=12
          call_indirect (type 0)
          i32.const 0
          i32.load offset=1051164
          local.set 3
        end
        i32.const 0
        local.get 3
        i32.const -1
        i32.add
        i32.store offset=1051164
        local.get 5
        i32.const 1
        i32.le_u
        br_if 1 (;@1;)
      end
      unreachable
      unreachable
    end
    local.get 0
    local.get 1
    call $rust_panic
    unreachable)
  (func $_ZN89_$LT$std..panicking..continue_panic_fmt..PanicPayload$u20$as$u20$core..panic..BoxMeUp$GT$9box_me_up17hb40334927d95d13bE (type 0) (param i32 i32)
    (local i32 i32 i32 i32 i32)
    global.get 0
    i32.const 64
    i32.sub
    local.tee 2
    global.set 0
    block  ;; label = @1
      local.get 1
      i32.load offset=4
      local.tee 3
      br_if 0 (;@1;)
      local.get 1
      i32.const 4
      i32.add
      local.set 3
      local.get 1
      i32.load
      local.set 4
      local.get 2
      i32.const 0
      i32.store offset=32
      local.get 2
      i64.const 1
      i64.store offset=24
      local.get 2
      local.get 2
      i32.const 24
      i32.add
      i32.store offset=36
      local.get 2
      i32.const 40
      i32.add
      i32.const 16
      i32.add
      local.get 4
      i32.const 16
      i32.add
      i64.load align=4
      i64.store
      local.get 2
      i32.const 40
      i32.add
      i32.const 8
      i32.add
      local.get 4
      i32.const 8
      i32.add
      i64.load align=4
      i64.store
      local.get 2
      local.get 4
      i64.load align=4
      i64.store offset=40
      local.get 2
      i32.const 36
      i32.add
      i32.const 1050336
      local.get 2
      i32.const 40
      i32.add
      call $_ZN4core3fmt5write17hd3aab830518de99fE
      drop
      local.get 2
      i32.const 8
      i32.add
      i32.const 8
      i32.add
      local.tee 4
      local.get 2
      i32.load offset=32
      i32.store
      local.get 2
      local.get 2
      i64.load offset=24
      i64.store offset=8
      block  ;; label = @2
        local.get 1
        i32.load offset=4
        local.tee 5
        i32.eqz
        br_if 0 (;@2;)
        local.get 1
        i32.const 8
        i32.add
        i32.load
        local.tee 6
        i32.eqz
        br_if 0 (;@2;)
        local.get 5
        local.get 6
        i32.const 1
        call $__rust_dealloc
      end
      local.get 3
      local.get 2
      i64.load offset=8
      i64.store align=4
      local.get 3
      i32.const 8
      i32.add
      local.get 4
      i32.load
      i32.store
      local.get 3
      i32.load
      local.set 3
    end
    local.get 1
    i32.const 1
    i32.store offset=4
    local.get 1
    i32.const 12
    i32.add
    i32.load
    local.set 4
    local.get 1
    i32.const 8
    i32.add
    local.tee 1
    i32.load
    local.set 5
    local.get 1
    i64.const 0
    i64.store align=4
    block  ;; label = @1
      i32.const 12
      i32.const 4
      call $__rust_alloc
      local.tee 1
      br_if 0 (;@1;)
      i32.const 12
      i32.const 4
      call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
      unreachable
    end
    local.get 1
    local.get 4
    i32.store offset=8
    local.get 1
    local.get 5
    i32.store offset=4
    local.get 1
    local.get 3
    i32.store
    local.get 0
    i32.const 1050484
    i32.store offset=4
    local.get 0
    local.get 1
    i32.store
    local.get 2
    i32.const 64
    i32.add
    global.set 0)
  (func $_ZN89_$LT$std..panicking..continue_panic_fmt..PanicPayload$u20$as$u20$core..panic..BoxMeUp$GT$3get17h4b595ece533c7d31E (type 0) (param i32 i32)
    (local i32 i32 i32 i32)
    global.get 0
    i32.const 64
    i32.sub
    local.tee 2
    global.set 0
    local.get 1
    i32.const 4
    i32.add
    local.set 3
    block  ;; label = @1
      local.get 1
      i32.load offset=4
      br_if 0 (;@1;)
      local.get 1
      i32.load
      local.set 4
      local.get 2
      i32.const 0
      i32.store offset=32
      local.get 2
      i64.const 1
      i64.store offset=24
      local.get 2
      local.get 2
      i32.const 24
      i32.add
      i32.store offset=36
      local.get 2
      i32.const 40
      i32.add
      i32.const 16
      i32.add
      local.get 4
      i32.const 16
      i32.add
      i64.load align=4
      i64.store
      local.get 2
      i32.const 40
      i32.add
      i32.const 8
      i32.add
      local.get 4
      i32.const 8
      i32.add
      i64.load align=4
      i64.store
      local.get 2
      local.get 4
      i64.load align=4
      i64.store offset=40
      local.get 2
      i32.const 36
      i32.add
      i32.const 1050336
      local.get 2
      i32.const 40
      i32.add
      call $_ZN4core3fmt5write17hd3aab830518de99fE
      drop
      local.get 2
      i32.const 8
      i32.add
      i32.const 8
      i32.add
      local.tee 4
      local.get 2
      i32.load offset=32
      i32.store
      local.get 2
      local.get 2
      i64.load offset=24
      i64.store offset=8
      block  ;; label = @2
        local.get 1
        i32.load offset=4
        local.tee 5
        i32.eqz
        br_if 0 (;@2;)
        local.get 1
        i32.const 8
        i32.add
        i32.load
        local.tee 1
        i32.eqz
        br_if 0 (;@2;)
        local.get 5
        local.get 1
        i32.const 1
        call $__rust_dealloc
      end
      local.get 3
      local.get 2
      i64.load offset=8
      i64.store align=4
      local.get 3
      i32.const 8
      i32.add
      local.get 4
      i32.load
      i32.store
    end
    local.get 0
    i32.const 1050484
    i32.store offset=4
    local.get 0
    local.get 3
    i32.store
    local.get 2
    i32.const 64
    i32.add
    global.set 0)
  (func $rust_panic (type 0) (param i32 i32)
    (local i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 2
    global.set 0
    local.get 2
    local.get 1
    i32.store offset=12
    local.get 2
    local.get 0
    i32.store offset=8
    local.get 2
    i32.const 8
    i32.add
    call $__rust_start_panic
    drop
    unreachable
    unreachable)
  (func $__rust_start_panic (type 6) (param i32) (result i32)
    (local i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 1
    global.set 0
    local.get 1
    i32.const 8
    i32.add
    local.get 0
    i32.load
    local.get 0
    i32.load offset=4
    i32.load offset=12
    call_indirect (type 0)
    unreachable
    unreachable)
  (func $_ZN8dlmalloc8dlmalloc8Dlmalloc16malloc_alignment17h9bc92124581be9ecE (type 6) (param i32) (result i32)
    i32.const 8)
  (func $_ZN8dlmalloc8dlmalloc8Dlmalloc17calloc_must_clear17h12013583272156edE (type 2) (param i32 i32) (result i32)
    local.get 1
    i32.const -4
    i32.add
    i32.load8_u
    i32.const 3
    i32.and
    i32.const 0
    i32.ne)
  (func $_ZN8dlmalloc8dlmalloc8Dlmalloc6malloc17h4ea5e05e71d3c045E (type 2) (param i32 i32) (result i32)
    (local i32 i32 i32 i32 i32 i32 i32 i32 i64)
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          local.get 1
          i32.const 245
          i32.lt_u
          br_if 0 (;@3;)
          i32.const 0
          local.set 2
          local.get 1
          i32.const -65587
          i32.ge_u
          br_if 2 (;@1;)
          local.get 1
          i32.const 11
          i32.add
          local.tee 1
          i32.const -8
          i32.and
          local.set 3
          local.get 0
          i32.load offset=4
          local.tee 4
          i32.eqz
          br_if 1 (;@2;)
          i32.const 0
          local.set 5
          block  ;; label = @4
            local.get 1
            i32.const 8
            i32.shr_u
            local.tee 1
            i32.eqz
            br_if 0 (;@4;)
            i32.const 31
            local.set 5
            local.get 3
            i32.const 16777215
            i32.gt_u
            br_if 0 (;@4;)
            local.get 3
            i32.const 6
            local.get 1
            i32.clz
            local.tee 1
            i32.sub
            i32.const 31
            i32.and
            i32.shr_u
            i32.const 1
            i32.and
            local.get 1
            i32.const 1
            i32.shl
            i32.sub
            i32.const 62
            i32.add
            local.set 5
          end
          i32.const 0
          local.get 3
          i32.sub
          local.set 2
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                local.get 0
                local.get 5
                i32.const 2
                i32.shl
                i32.add
                i32.const 272
                i32.add
                i32.load
                local.tee 1
                i32.eqz
                br_if 0 (;@6;)
                i32.const 0
                local.set 6
                local.get 3
                i32.const 0
                i32.const 25
                local.get 5
                i32.const 1
                i32.shr_u
                i32.sub
                i32.const 31
                i32.and
                local.get 5
                i32.const 31
                i32.eq
                select
                i32.shl
                local.set 7
                i32.const 0
                local.set 8
                loop  ;; label = @7
                  block  ;; label = @8
                    local.get 1
                    i32.load offset=4
                    i32.const -8
                    i32.and
                    local.tee 9
                    local.get 3
                    i32.lt_u
                    br_if 0 (;@8;)
                    local.get 9
                    local.get 3
                    i32.sub
                    local.tee 9
                    local.get 2
                    i32.ge_u
                    br_if 0 (;@8;)
                    local.get 9
                    local.set 2
                    local.get 1
                    local.set 8
                    local.get 9
                    br_if 0 (;@8;)
                    i32.const 0
                    local.set 2
                    local.get 1
                    local.set 8
                    br 3 (;@5;)
                  end
                  local.get 1
                  i32.const 20
                  i32.add
                  i32.load
                  local.tee 9
                  local.get 6
                  local.get 9
                  local.get 1
                  local.get 7
                  i32.const 29
                  i32.shr_u
                  i32.const 4
                  i32.and
                  i32.add
                  i32.const 16
                  i32.add
                  i32.load
                  local.tee 1
                  i32.ne
                  select
                  local.get 6
                  local.get 9
                  select
                  local.set 6
                  local.get 7
                  i32.const 1
                  i32.shl
                  local.set 7
                  local.get 1
                  br_if 0 (;@7;)
                end
                block  ;; label = @7
                  local.get 6
                  i32.eqz
                  br_if 0 (;@7;)
                  local.get 6
                  local.set 1
                  br 2 (;@5;)
                end
                local.get 8
                br_if 2 (;@4;)
              end
              i32.const 0
              local.set 8
              i32.const 2
              local.get 5
              i32.const 31
              i32.and
              i32.shl
              local.tee 1
              i32.const 0
              local.get 1
              i32.sub
              i32.or
              local.get 4
              i32.and
              local.tee 1
              i32.eqz
              br_if 3 (;@2;)
              local.get 0
              local.get 1
              i32.const 0
              local.get 1
              i32.sub
              i32.and
              i32.ctz
              i32.const 2
              i32.shl
              i32.add
              i32.const 272
              i32.add
              i32.load
              local.tee 1
              i32.eqz
              br_if 3 (;@2;)
            end
            loop  ;; label = @5
              local.get 1
              i32.load offset=4
              i32.const -8
              i32.and
              local.tee 6
              local.get 3
              i32.ge_u
              local.get 6
              local.get 3
              i32.sub
              local.tee 9
              local.get 2
              i32.lt_u
              i32.and
              local.set 7
              block  ;; label = @6
                local.get 1
                i32.load offset=16
                local.tee 6
                br_if 0 (;@6;)
                local.get 1
                i32.const 20
                i32.add
                i32.load
                local.set 6
              end
              local.get 1
              local.get 8
              local.get 7
              select
              local.set 8
              local.get 9
              local.get 2
              local.get 7
              select
              local.set 2
              local.get 6
              local.set 1
              local.get 6
              br_if 0 (;@5;)
            end
            local.get 8
            i32.eqz
            br_if 2 (;@2;)
          end
          block  ;; label = @4
            local.get 0
            i32.load offset=400
            local.tee 1
            local.get 3
            i32.lt_u
            br_if 0 (;@4;)
            local.get 2
            local.get 1
            local.get 3
            i32.sub
            i32.ge_u
            br_if 2 (;@2;)
          end
          local.get 0
          local.get 8
          call $_ZN8dlmalloc8dlmalloc8Dlmalloc18unlink_large_chunk17h979ff7c31798a32bE
          block  ;; label = @4
            block  ;; label = @5
              local.get 2
              i32.const 16
              i32.lt_u
              br_if 0 (;@5;)
              local.get 8
              local.get 3
              i32.const 3
              i32.or
              i32.store offset=4
              local.get 8
              local.get 3
              i32.add
              local.tee 1
              local.get 2
              i32.const 1
              i32.or
              i32.store offset=4
              local.get 1
              local.get 2
              i32.add
              local.get 2
              i32.store
              block  ;; label = @6
                local.get 2
                i32.const 256
                i32.lt_u
                br_if 0 (;@6;)
                local.get 0
                local.get 1
                local.get 2
                call $_ZN8dlmalloc8dlmalloc8Dlmalloc18insert_large_chunk17h2eefc93f2226b039E
                br 2 (;@4;)
              end
              local.get 0
              local.get 2
              i32.const 3
              i32.shr_u
              local.tee 2
              i32.const 3
              i32.shl
              i32.add
              i32.const 8
              i32.add
              local.set 3
              block  ;; label = @6
                block  ;; label = @7
                  local.get 0
                  i32.load
                  local.tee 6
                  i32.const 1
                  local.get 2
                  i32.const 31
                  i32.and
                  i32.shl
                  local.tee 2
                  i32.and
                  i32.eqz
                  br_if 0 (;@7;)
                  local.get 3
                  i32.load offset=8
                  local.set 2
                  br 1 (;@6;)
                end
                local.get 0
                local.get 6
                local.get 2
                i32.or
                i32.store
                local.get 3
                local.set 2
              end
              local.get 3
              local.get 1
              i32.store offset=8
              local.get 2
              local.get 1
              i32.store offset=12
              local.get 1
              local.get 3
              i32.store offset=12
              local.get 1
              local.get 2
              i32.store offset=8
              br 1 (;@4;)
            end
            local.get 8
            local.get 2
            local.get 3
            i32.add
            local.tee 1
            i32.const 3
            i32.or
            i32.store offset=4
            local.get 8
            local.get 1
            i32.add
            local.tee 1
            local.get 1
            i32.load offset=4
            i32.const 1
            i32.or
            i32.store offset=4
          end
          local.get 8
          i32.const 8
          i32.add
          return
        end
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              local.get 0
              i32.load
              local.tee 8
              i32.const 16
              local.get 1
              i32.const 11
              i32.add
              i32.const -8
              i32.and
              local.get 1
              i32.const 11
              i32.lt_u
              select
              local.tee 3
              i32.const 3
              i32.shr_u
              local.tee 2
              i32.const 31
              i32.and
              local.tee 6
              i32.shr_u
              local.tee 1
              i32.const 3
              i32.and
              br_if 0 (;@5;)
              local.get 3
              local.get 0
              i32.load offset=400
              i32.le_u
              br_if 3 (;@2;)
              local.get 1
              br_if 1 (;@4;)
              local.get 0
              i32.load offset=4
              local.tee 1
              i32.eqz
              br_if 3 (;@2;)
              local.get 0
              local.get 1
              i32.const 0
              local.get 1
              i32.sub
              i32.and
              i32.ctz
              i32.const 2
              i32.shl
              i32.add
              i32.const 272
              i32.add
              i32.load
              local.tee 6
              i32.load offset=4
              i32.const -8
              i32.and
              local.get 3
              i32.sub
              local.set 2
              local.get 6
              local.set 7
              loop  ;; label = @6
                block  ;; label = @7
                  local.get 6
                  i32.load offset=16
                  local.tee 1
                  br_if 0 (;@7;)
                  local.get 6
                  i32.const 20
                  i32.add
                  i32.load
                  local.tee 1
                  i32.eqz
                  br_if 4 (;@3;)
                end
                local.get 1
                i32.load offset=4
                i32.const -8
                i32.and
                local.get 3
                i32.sub
                local.tee 6
                local.get 2
                local.get 6
                local.get 2
                i32.lt_u
                local.tee 6
                select
                local.set 2
                local.get 1
                local.get 7
                local.get 6
                select
                local.set 7
                local.get 1
                local.set 6
                br 0 (;@6;)
              end
            end
            local.get 0
            local.get 1
            i32.const -1
            i32.xor
            i32.const 1
            i32.and
            local.get 2
            i32.add
            local.tee 3
            i32.const 3
            i32.shl
            i32.add
            local.tee 7
            i32.const 16
            i32.add
            i32.load
            local.tee 1
            i32.const 8
            i32.add
            local.set 2
            block  ;; label = @5
              block  ;; label = @6
                local.get 1
                i32.load offset=8
                local.tee 6
                local.get 7
                i32.const 8
                i32.add
                local.tee 7
                i32.eq
                br_if 0 (;@6;)
                local.get 6
                local.get 7
                i32.store offset=12
                local.get 7
                local.get 6
                i32.store offset=8
                br 1 (;@5;)
              end
              local.get 0
              local.get 8
              i32.const -2
              local.get 3
              i32.rotl
              i32.and
              i32.store
            end
            local.get 1
            local.get 3
            i32.const 3
            i32.shl
            local.tee 3
            i32.const 3
            i32.or
            i32.store offset=4
            local.get 1
            local.get 3
            i32.add
            local.tee 1
            local.get 1
            i32.load offset=4
            i32.const 1
            i32.or
            i32.store offset=4
            br 3 (;@1;)
          end
          block  ;; label = @4
            block  ;; label = @5
              local.get 0
              local.get 1
              local.get 6
              i32.shl
              i32.const 2
              local.get 6
              i32.shl
              local.tee 1
              i32.const 0
              local.get 1
              i32.sub
              i32.or
              i32.and
              local.tee 1
              i32.const 0
              local.get 1
              i32.sub
              i32.and
              i32.ctz
              local.tee 2
              i32.const 3
              i32.shl
              i32.add
              local.tee 7
              i32.const 16
              i32.add
              i32.load
              local.tee 1
              i32.load offset=8
              local.tee 6
              local.get 7
              i32.const 8
              i32.add
              local.tee 7
              i32.eq
              br_if 0 (;@5;)
              local.get 6
              local.get 7
              i32.store offset=12
              local.get 7
              local.get 6
              i32.store offset=8
              br 1 (;@4;)
            end
            local.get 0
            local.get 8
            i32.const -2
            local.get 2
            i32.rotl
            i32.and
            i32.store
          end
          local.get 1
          i32.const 8
          i32.add
          local.set 6
          local.get 1
          local.get 3
          i32.const 3
          i32.or
          i32.store offset=4
          local.get 1
          local.get 3
          i32.add
          local.tee 7
          local.get 2
          i32.const 3
          i32.shl
          local.tee 2
          local.get 3
          i32.sub
          local.tee 3
          i32.const 1
          i32.or
          i32.store offset=4
          local.get 1
          local.get 2
          i32.add
          local.get 3
          i32.store
          block  ;; label = @4
            local.get 0
            i32.load offset=400
            local.tee 1
            i32.eqz
            br_if 0 (;@4;)
            local.get 0
            local.get 1
            i32.const 3
            i32.shr_u
            local.tee 8
            i32.const 3
            i32.shl
            i32.add
            i32.const 8
            i32.add
            local.set 2
            local.get 0
            i32.load offset=408
            local.set 1
            block  ;; label = @5
              block  ;; label = @6
                local.get 0
                i32.load
                local.tee 9
                i32.const 1
                local.get 8
                i32.const 31
                i32.and
                i32.shl
                local.tee 8
                i32.and
                i32.eqz
                br_if 0 (;@6;)
                local.get 2
                i32.load offset=8
                local.set 8
                br 1 (;@5;)
              end
              local.get 0
              local.get 9
              local.get 8
              i32.or
              i32.store
              local.get 2
              local.set 8
            end
            local.get 2
            local.get 1
            i32.store offset=8
            local.get 8
            local.get 1
            i32.store offset=12
            local.get 1
            local.get 2
            i32.store offset=12
            local.get 1
            local.get 8
            i32.store offset=8
          end
          local.get 0
          local.get 7
          i32.store offset=408
          local.get 0
          local.get 3
          i32.store offset=400
          local.get 6
          return
        end
        local.get 0
        local.get 7
        call $_ZN8dlmalloc8dlmalloc8Dlmalloc18unlink_large_chunk17h979ff7c31798a32bE
        block  ;; label = @3
          block  ;; label = @4
            local.get 2
            i32.const 16
            i32.lt_u
            br_if 0 (;@4;)
            local.get 7
            local.get 3
            i32.const 3
            i32.or
            i32.store offset=4
            local.get 7
            local.get 3
            i32.add
            local.tee 3
            local.get 2
            i32.const 1
            i32.or
            i32.store offset=4
            local.get 3
            local.get 2
            i32.add
            local.get 2
            i32.store
            block  ;; label = @5
              local.get 0
              i32.load offset=400
              local.tee 1
              i32.eqz
              br_if 0 (;@5;)
              local.get 0
              local.get 1
              i32.const 3
              i32.shr_u
              local.tee 8
              i32.const 3
              i32.shl
              i32.add
              i32.const 8
              i32.add
              local.set 6
              local.get 0
              i32.load offset=408
              local.set 1
              block  ;; label = @6
                block  ;; label = @7
                  local.get 0
                  i32.load
                  local.tee 9
                  i32.const 1
                  local.get 8
                  i32.const 31
                  i32.and
                  i32.shl
                  local.tee 8
                  i32.and
                  i32.eqz
                  br_if 0 (;@7;)
                  local.get 6
                  i32.load offset=8
                  local.set 8
                  br 1 (;@6;)
                end
                local.get 0
                local.get 9
                local.get 8
                i32.or
                i32.store
                local.get 6
                local.set 8
              end
              local.get 6
              local.get 1
              i32.store offset=8
              local.get 8
              local.get 1
              i32.store offset=12
              local.get 1
              local.get 6
              i32.store offset=12
              local.get 1
              local.get 8
              i32.store offset=8
            end
            local.get 0
            local.get 3
            i32.store offset=408
            local.get 0
            local.get 2
            i32.store offset=400
            br 1 (;@3;)
          end
          local.get 7
          local.get 2
          local.get 3
          i32.add
          local.tee 1
          i32.const 3
          i32.or
          i32.store offset=4
          local.get 7
          local.get 1
          i32.add
          local.tee 1
          local.get 1
          i32.load offset=4
          i32.const 1
          i32.or
          i32.store offset=4
        end
        local.get 7
        i32.const 8
        i32.add
        return
      end
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                block  ;; label = @7
                  block  ;; label = @8
                    local.get 0
                    i32.load offset=400
                    local.tee 2
                    local.get 3
                    i32.ge_u
                    br_if 0 (;@8;)
                    local.get 0
                    i32.load offset=404
                    local.tee 1
                    local.get 3
                    i32.gt_u
                    br_if 3 (;@5;)
                    i32.const 0
                    local.set 2
                    local.get 3
                    i32.const 65583
                    i32.add
                    local.tee 6
                    i32.const 16
                    i32.shr_u
                    memory.grow
                    local.tee 1
                    i32.const -1
                    i32.eq
                    br_if 7 (;@1;)
                    local.get 1
                    i32.const 16
                    i32.shl
                    local.tee 8
                    i32.eqz
                    br_if 7 (;@1;)
                    local.get 0
                    local.get 0
                    i32.load offset=416
                    local.get 6
                    i32.const -65536
                    i32.and
                    local.tee 5
                    i32.add
                    local.tee 1
                    i32.store offset=416
                    local.get 0
                    local.get 0
                    i32.load offset=420
                    local.tee 6
                    local.get 1
                    local.get 1
                    local.get 6
                    i32.lt_u
                    select
                    i32.store offset=420
                    local.get 0
                    i32.load offset=412
                    local.tee 6
                    i32.eqz
                    br_if 1 (;@7;)
                    local.get 0
                    i32.const 424
                    i32.add
                    local.tee 4
                    local.set 1
                    loop  ;; label = @9
                      local.get 1
                      i32.load
                      local.tee 7
                      local.get 1
                      i32.load offset=4
                      local.tee 9
                      i32.add
                      local.get 8
                      i32.eq
                      br_if 3 (;@6;)
                      local.get 1
                      i32.load offset=8
                      local.tee 1
                      br_if 0 (;@9;)
                      br 6 (;@3;)
                    end
                  end
                  local.get 0
                  i32.load offset=408
                  local.set 1
                  block  ;; label = @8
                    block  ;; label = @9
                      local.get 2
                      local.get 3
                      i32.sub
                      local.tee 6
                      i32.const 15
                      i32.gt_u
                      br_if 0 (;@9;)
                      local.get 0
                      i32.const 0
                      i32.store offset=408
                      local.get 0
                      i32.const 0
                      i32.store offset=400
                      local.get 1
                      local.get 2
                      i32.const 3
                      i32.or
                      i32.store offset=4
                      local.get 1
                      local.get 2
                      i32.add
                      local.tee 2
                      i32.const 4
                      i32.add
                      local.set 3
                      local.get 2
                      i32.load offset=4
                      i32.const 1
                      i32.or
                      local.set 2
                      br 1 (;@8;)
                    end
                    local.get 0
                    local.get 6
                    i32.store offset=400
                    local.get 0
                    local.get 1
                    local.get 3
                    i32.add
                    local.tee 7
                    i32.store offset=408
                    local.get 7
                    local.get 6
                    i32.const 1
                    i32.or
                    i32.store offset=4
                    local.get 1
                    local.get 2
                    i32.add
                    local.get 6
                    i32.store
                    local.get 3
                    i32.const 3
                    i32.or
                    local.set 2
                    local.get 1
                    i32.const 4
                    i32.add
                    local.set 3
                  end
                  local.get 3
                  local.get 2
                  i32.store
                  local.get 1
                  i32.const 8
                  i32.add
                  return
                end
                block  ;; label = @7
                  block  ;; label = @8
                    local.get 0
                    i32.load offset=444
                    local.tee 1
                    i32.eqz
                    br_if 0 (;@8;)
                    local.get 1
                    local.get 8
                    i32.le_u
                    br_if 1 (;@7;)
                  end
                  local.get 0
                  local.get 8
                  i32.store offset=444
                end
                local.get 0
                i32.const 4095
                i32.store offset=448
                local.get 0
                local.get 8
                i32.store offset=424
                i32.const 0
                local.set 1
                local.get 0
                i32.const 436
                i32.add
                i32.const 0
                i32.store
                local.get 0
                i32.const 428
                i32.add
                local.get 5
                i32.store
                loop  ;; label = @7
                  local.get 0
                  local.get 1
                  i32.add
                  local.tee 6
                  i32.const 16
                  i32.add
                  local.get 6
                  i32.const 8
                  i32.add
                  local.tee 7
                  i32.store
                  local.get 6
                  i32.const 20
                  i32.add
                  local.get 7
                  i32.store
                  local.get 1
                  i32.const 8
                  i32.add
                  local.tee 1
                  i32.const 256
                  i32.ne
                  br_if 0 (;@7;)
                end
                local.get 0
                local.get 8
                i32.store offset=412
                local.get 0
                local.get 5
                i32.const -40
                i32.add
                local.tee 1
                i32.store offset=404
                local.get 8
                local.get 1
                i32.const 1
                i32.or
                i32.store offset=4
                local.get 8
                local.get 1
                i32.add
                i32.const 40
                i32.store offset=4
                local.get 0
                i32.const 2097152
                i32.store offset=440
                br 4 (;@2;)
              end
              local.get 1
              i32.load offset=12
              i32.eqz
              br_if 1 (;@4;)
              br 2 (;@3;)
            end
            local.get 0
            local.get 1
            local.get 3
            i32.sub
            local.tee 2
            i32.store offset=404
            local.get 0
            local.get 0
            i32.load offset=412
            local.tee 1
            local.get 3
            i32.add
            local.tee 6
            i32.store offset=412
            local.get 6
            local.get 2
            i32.const 1
            i32.or
            i32.store offset=4
            local.get 1
            local.get 3
            i32.const 3
            i32.or
            i32.store offset=4
            local.get 1
            i32.const 8
            i32.add
            return
          end
          local.get 8
          local.get 6
          i32.le_u
          br_if 0 (;@3;)
          local.get 7
          local.get 6
          i32.gt_u
          br_if 0 (;@3;)
          local.get 1
          local.get 9
          local.get 5
          i32.add
          i32.store offset=4
          local.get 0
          local.get 0
          i32.load offset=412
          local.tee 1
          i32.const 15
          i32.add
          i32.const -8
          i32.and
          local.tee 6
          i32.const -8
          i32.add
          i32.store offset=412
          local.get 0
          local.get 1
          local.get 6
          i32.sub
          local.get 0
          i32.load offset=404
          local.get 5
          i32.add
          local.tee 7
          i32.add
          i32.const 8
          i32.add
          local.tee 8
          i32.store offset=404
          local.get 6
          i32.const -4
          i32.add
          local.get 8
          i32.const 1
          i32.or
          i32.store
          local.get 1
          local.get 7
          i32.add
          i32.const 40
          i32.store offset=4
          local.get 0
          i32.const 2097152
          i32.store offset=440
          br 1 (;@2;)
        end
        local.get 0
        local.get 0
        i32.load offset=444
        local.tee 1
        local.get 8
        local.get 1
        local.get 8
        i32.lt_u
        select
        i32.store offset=444
        local.get 8
        local.get 5
        i32.add
        local.set 7
        local.get 4
        local.set 1
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              loop  ;; label = @6
                local.get 1
                i32.load
                local.get 7
                i32.eq
                br_if 1 (;@5;)
                local.get 1
                i32.load offset=8
                local.tee 1
                br_if 0 (;@6;)
                br 2 (;@4;)
              end
            end
            local.get 1
            i32.load offset=12
            i32.eqz
            br_if 1 (;@3;)
          end
          local.get 4
          local.set 1
          block  ;; label = @4
            loop  ;; label = @5
              block  ;; label = @6
                local.get 1
                i32.load
                local.tee 7
                local.get 6
                i32.gt_u
                br_if 0 (;@6;)
                local.get 7
                local.get 1
                i32.load offset=4
                i32.add
                local.tee 7
                local.get 6
                i32.gt_u
                br_if 2 (;@4;)
              end
              local.get 1
              i32.load offset=8
              local.set 1
              br 0 (;@5;)
            end
          end
          local.get 0
          local.get 8
          i32.store offset=412
          local.get 0
          local.get 5
          i32.const -40
          i32.add
          local.tee 1
          i32.store offset=404
          local.get 8
          local.get 1
          i32.const 1
          i32.or
          i32.store offset=4
          local.get 8
          local.get 1
          i32.add
          i32.const 40
          i32.store offset=4
          local.get 0
          i32.const 2097152
          i32.store offset=440
          local.get 6
          local.get 7
          i32.const -32
          i32.add
          i32.const -8
          i32.and
          i32.const -8
          i32.add
          local.tee 1
          local.get 1
          local.get 6
          i32.const 16
          i32.add
          i32.lt_u
          select
          local.tee 9
          i32.const 27
          i32.store offset=4
          local.get 4
          i64.load align=4
          local.set 10
          local.get 9
          i32.const 16
          i32.add
          local.get 4
          i32.const 8
          i32.add
          i64.load align=4
          i64.store align=4
          local.get 9
          local.get 10
          i64.store offset=8 align=4
          local.get 0
          i32.const 436
          i32.add
          i32.const 0
          i32.store
          local.get 0
          i32.const 428
          i32.add
          local.get 5
          i32.store
          local.get 0
          local.get 8
          i32.store offset=424
          local.get 0
          i32.const 432
          i32.add
          local.get 9
          i32.const 8
          i32.add
          i32.store
          local.get 9
          i32.const 28
          i32.add
          local.set 1
          loop  ;; label = @4
            local.get 1
            i32.const 7
            i32.store
            local.get 7
            local.get 1
            i32.const 4
            i32.add
            local.tee 1
            i32.gt_u
            br_if 0 (;@4;)
          end
          local.get 9
          local.get 6
          i32.eq
          br_if 1 (;@2;)
          local.get 9
          local.get 9
          i32.load offset=4
          i32.const -2
          i32.and
          i32.store offset=4
          local.get 6
          local.get 9
          local.get 6
          i32.sub
          local.tee 1
          i32.const 1
          i32.or
          i32.store offset=4
          local.get 9
          local.get 1
          i32.store
          block  ;; label = @4
            local.get 1
            i32.const 256
            i32.lt_u
            br_if 0 (;@4;)
            local.get 0
            local.get 6
            local.get 1
            call $_ZN8dlmalloc8dlmalloc8Dlmalloc18insert_large_chunk17h2eefc93f2226b039E
            br 2 (;@2;)
          end
          local.get 0
          local.get 1
          i32.const 3
          i32.shr_u
          local.tee 7
          i32.const 3
          i32.shl
          i32.add
          i32.const 8
          i32.add
          local.set 1
          block  ;; label = @4
            block  ;; label = @5
              local.get 0
              i32.load
              local.tee 8
              i32.const 1
              local.get 7
              i32.const 31
              i32.and
              i32.shl
              local.tee 7
              i32.and
              i32.eqz
              br_if 0 (;@5;)
              local.get 1
              i32.load offset=8
              local.set 7
              br 1 (;@4;)
            end
            local.get 0
            local.get 8
            local.get 7
            i32.or
            i32.store
            local.get 1
            local.set 7
          end
          local.get 1
          local.get 6
          i32.store offset=8
          local.get 7
          local.get 6
          i32.store offset=12
          local.get 6
          local.get 1
          i32.store offset=12
          local.get 6
          local.get 7
          i32.store offset=8
          br 1 (;@2;)
        end
        local.get 1
        local.get 8
        i32.store
        local.get 1
        local.get 1
        i32.load offset=4
        local.get 5
        i32.add
        i32.store offset=4
        local.get 8
        local.get 3
        i32.const 3
        i32.or
        i32.store offset=4
        local.get 8
        local.get 3
        i32.add
        local.set 1
        local.get 7
        local.get 8
        i32.sub
        local.get 3
        i32.sub
        local.set 3
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              local.get 0
              i32.load offset=412
              local.get 7
              i32.eq
              br_if 0 (;@5;)
              local.get 0
              i32.load offset=408
              local.get 7
              i32.eq
              br_if 1 (;@4;)
              block  ;; label = @6
                local.get 7
                i32.load offset=4
                local.tee 2
                i32.const 3
                i32.and
                i32.const 1
                i32.ne
                br_if 0 (;@6;)
                block  ;; label = @7
                  block  ;; label = @8
                    local.get 2
                    i32.const -8
                    i32.and
                    local.tee 6
                    i32.const 256
                    i32.lt_u
                    br_if 0 (;@8;)
                    local.get 0
                    local.get 7
                    call $_ZN8dlmalloc8dlmalloc8Dlmalloc18unlink_large_chunk17h979ff7c31798a32bE
                    br 1 (;@7;)
                  end
                  block  ;; label = @8
                    local.get 7
                    i32.load offset=12
                    local.tee 9
                    local.get 7
                    i32.load offset=8
                    local.tee 5
                    i32.eq
                    br_if 0 (;@8;)
                    local.get 5
                    local.get 9
                    i32.store offset=12
                    local.get 9
                    local.get 5
                    i32.store offset=8
                    br 1 (;@7;)
                  end
                  local.get 0
                  local.get 0
                  i32.load
                  i32.const -2
                  local.get 2
                  i32.const 3
                  i32.shr_u
                  i32.rotl
                  i32.and
                  i32.store
                end
                local.get 6
                local.get 3
                i32.add
                local.set 3
                local.get 7
                local.get 6
                i32.add
                local.set 7
              end
              local.get 7
              local.get 7
              i32.load offset=4
              i32.const -2
              i32.and
              i32.store offset=4
              local.get 1
              local.get 3
              i32.const 1
              i32.or
              i32.store offset=4
              local.get 1
              local.get 3
              i32.add
              local.get 3
              i32.store
              block  ;; label = @6
                local.get 3
                i32.const 256
                i32.lt_u
                br_if 0 (;@6;)
                local.get 0
                local.get 1
                local.get 3
                call $_ZN8dlmalloc8dlmalloc8Dlmalloc18insert_large_chunk17h2eefc93f2226b039E
                br 3 (;@3;)
              end
              local.get 0
              local.get 3
              i32.const 3
              i32.shr_u
              local.tee 2
              i32.const 3
              i32.shl
              i32.add
              i32.const 8
              i32.add
              local.set 3
              block  ;; label = @6
                block  ;; label = @7
                  local.get 0
                  i32.load
                  local.tee 6
                  i32.const 1
                  local.get 2
                  i32.const 31
                  i32.and
                  i32.shl
                  local.tee 2
                  i32.and
                  i32.eqz
                  br_if 0 (;@7;)
                  local.get 3
                  i32.load offset=8
                  local.set 2
                  br 1 (;@6;)
                end
                local.get 0
                local.get 6
                local.get 2
                i32.or
                i32.store
                local.get 3
                local.set 2
              end
              local.get 3
              local.get 1
              i32.store offset=8
              local.get 2
              local.get 1
              i32.store offset=12
              local.get 1
              local.get 3
              i32.store offset=12
              local.get 1
              local.get 2
              i32.store offset=8
              br 2 (;@3;)
            end
            local.get 0
            local.get 1
            i32.store offset=412
            local.get 0
            local.get 0
            i32.load offset=404
            local.get 3
            i32.add
            local.tee 3
            i32.store offset=404
            local.get 1
            local.get 3
            i32.const 1
            i32.or
            i32.store offset=4
            br 1 (;@3;)
          end
          local.get 0
          local.get 1
          i32.store offset=408
          local.get 0
          local.get 0
          i32.load offset=400
          local.get 3
          i32.add
          local.tee 3
          i32.store offset=400
          local.get 1
          local.get 3
          i32.const 1
          i32.or
          i32.store offset=4
          local.get 1
          local.get 3
          i32.add
          local.get 3
          i32.store
        end
        local.get 8
        i32.const 8
        i32.add
        return
      end
      local.get 0
      i32.load offset=404
      local.tee 1
      local.get 3
      i32.le_u
      br_if 0 (;@1;)
      local.get 0
      local.get 1
      local.get 3
      i32.sub
      local.tee 2
      i32.store offset=404
      local.get 0
      local.get 0
      i32.load offset=412
      local.tee 1
      local.get 3
      i32.add
      local.tee 6
      i32.store offset=412
      local.get 6
      local.get 2
      i32.const 1
      i32.or
      i32.store offset=4
      local.get 1
      local.get 3
      i32.const 3
      i32.or
      i32.store offset=4
      local.get 1
      i32.const 8
      i32.add
      return
    end
    local.get 2)
  (func $_ZN8dlmalloc8dlmalloc8Dlmalloc18unlink_large_chunk17h979ff7c31798a32bE (type 0) (param i32 i32)
    (local i32 i32 i32 i32 i32)
    local.get 1
    i32.load offset=24
    local.set 2
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          local.get 1
          i32.load offset=12
          local.tee 3
          local.get 1
          i32.ne
          br_if 0 (;@3;)
          local.get 1
          i32.const 20
          i32.const 16
          local.get 1
          i32.const 20
          i32.add
          local.tee 3
          i32.load
          local.tee 4
          select
          i32.add
          i32.load
          local.tee 5
          br_if 1 (;@2;)
          i32.const 0
          local.set 3
          br 2 (;@1;)
        end
        local.get 1
        i32.load offset=8
        local.tee 5
        local.get 3
        i32.store offset=12
        local.get 3
        local.get 5
        i32.store offset=8
        br 1 (;@1;)
      end
      local.get 3
      local.get 1
      i32.const 16
      i32.add
      local.get 4
      select
      local.set 4
      loop  ;; label = @2
        local.get 4
        local.set 6
        block  ;; label = @3
          local.get 5
          local.tee 3
          i32.const 20
          i32.add
          local.tee 4
          i32.load
          local.tee 5
          br_if 0 (;@3;)
          local.get 3
          i32.const 16
          i32.add
          local.set 4
          local.get 3
          i32.load offset=16
          local.set 5
        end
        local.get 5
        br_if 0 (;@2;)
      end
      local.get 6
      i32.const 0
      i32.store
    end
    block  ;; label = @1
      local.get 2
      i32.eqz
      br_if 0 (;@1;)
      block  ;; label = @2
        block  ;; label = @3
          local.get 0
          local.get 1
          i32.load offset=28
          i32.const 2
          i32.shl
          i32.add
          i32.const 272
          i32.add
          local.tee 5
          i32.load
          local.get 1
          i32.ne
          br_if 0 (;@3;)
          local.get 5
          local.get 3
          i32.store
          local.get 3
          br_if 1 (;@2;)
          local.get 0
          local.get 0
          i32.load offset=4
          i32.const -2
          local.get 1
          i32.load offset=28
          i32.rotl
          i32.and
          i32.store offset=4
          return
        end
        local.get 2
        i32.const 16
        i32.const 20
        local.get 2
        i32.load offset=16
        local.get 1
        i32.eq
        select
        i32.add
        local.get 3
        i32.store
        local.get 3
        i32.eqz
        br_if 1 (;@1;)
      end
      local.get 3
      local.get 2
      i32.store offset=24
      block  ;; label = @2
        local.get 1
        i32.load offset=16
        local.tee 5
        i32.eqz
        br_if 0 (;@2;)
        local.get 3
        local.get 5
        i32.store offset=16
        local.get 5
        local.get 3
        i32.store offset=24
      end
      local.get 1
      i32.const 20
      i32.add
      i32.load
      local.tee 5
      i32.eqz
      br_if 0 (;@1;)
      local.get 3
      i32.const 20
      i32.add
      local.get 5
      i32.store
      local.get 5
      local.get 3
      i32.store offset=24
    end)
  (func $_ZN8dlmalloc8dlmalloc8Dlmalloc18insert_large_chunk17h2eefc93f2226b039E (type 4) (param i32 i32 i32)
    (local i32 i32 i32 i32)
    block  ;; label = @1
      block  ;; label = @2
        local.get 2
        i32.const 8
        i32.shr_u
        local.tee 3
        br_if 0 (;@2;)
        i32.const 0
        local.set 4
        br 1 (;@1;)
      end
      i32.const 31
      local.set 4
      local.get 2
      i32.const 16777215
      i32.gt_u
      br_if 0 (;@1;)
      local.get 2
      i32.const 6
      local.get 3
      i32.clz
      local.tee 4
      i32.sub
      i32.const 31
      i32.and
      i32.shr_u
      i32.const 1
      i32.and
      local.get 4
      i32.const 1
      i32.shl
      i32.sub
      i32.const 62
      i32.add
      local.set 4
    end
    local.get 1
    i64.const 0
    i64.store offset=16 align=4
    local.get 1
    local.get 4
    i32.store offset=28
    local.get 0
    local.get 4
    i32.const 2
    i32.shl
    i32.add
    i32.const 272
    i32.add
    local.set 3
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              local.get 0
              i32.load offset=4
              local.tee 5
              i32.const 1
              local.get 4
              i32.const 31
              i32.and
              i32.shl
              local.tee 6
              i32.and
              i32.eqz
              br_if 0 (;@5;)
              local.get 3
              i32.load
              local.tee 3
              i32.load offset=4
              i32.const -8
              i32.and
              local.get 2
              i32.ne
              br_if 1 (;@4;)
              local.get 3
              local.set 4
              br 2 (;@3;)
            end
            local.get 0
            local.get 5
            local.get 6
            i32.or
            i32.store offset=4
            local.get 3
            local.get 1
            i32.store
            local.get 1
            local.get 3
            i32.store offset=24
            br 3 (;@1;)
          end
          local.get 2
          i32.const 0
          i32.const 25
          local.get 4
          i32.const 1
          i32.shr_u
          i32.sub
          i32.const 31
          i32.and
          local.get 4
          i32.const 31
          i32.eq
          select
          i32.shl
          local.set 0
          loop  ;; label = @4
            local.get 3
            local.get 0
            i32.const 29
            i32.shr_u
            i32.const 4
            i32.and
            i32.add
            i32.const 16
            i32.add
            local.tee 5
            i32.load
            local.tee 4
            i32.eqz
            br_if 2 (;@2;)
            local.get 0
            i32.const 1
            i32.shl
            local.set 0
            local.get 4
            local.set 3
            local.get 4
            i32.load offset=4
            i32.const -8
            i32.and
            local.get 2
            i32.ne
            br_if 0 (;@4;)
          end
        end
        local.get 4
        i32.load offset=8
        local.tee 0
        local.get 1
        i32.store offset=12
        local.get 4
        local.get 1
        i32.store offset=8
        local.get 1
        i32.const 0
        i32.store offset=24
        local.get 1
        local.get 4
        i32.store offset=12
        local.get 1
        local.get 0
        i32.store offset=8
        return
      end
      local.get 5
      local.get 1
      i32.store
      local.get 1
      local.get 3
      i32.store offset=24
    end
    local.get 1
    local.get 1
    i32.store offset=12
    local.get 1
    local.get 1
    i32.store offset=8)
  (func $_ZN8dlmalloc8dlmalloc8Dlmalloc7realloc17h342015522c41c924E (type 1) (param i32 i32 i32) (result i32)
    (local i32 i32 i32 i32 i32 i32 i32 i32)
    i32.const 0
    local.set 3
    block  ;; label = @1
      local.get 2
      i32.const -65588
      i32.gt_u
      br_if 0 (;@1;)
      i32.const 16
      local.get 2
      i32.const 11
      i32.add
      i32.const -8
      i32.and
      local.get 2
      i32.const 11
      i32.lt_u
      select
      local.set 4
      local.get 1
      i32.const -4
      i32.add
      local.tee 5
      i32.load
      local.tee 6
      i32.const -8
      i32.and
      local.set 7
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                block  ;; label = @7
                  block  ;; label = @8
                    local.get 6
                    i32.const 3
                    i32.and
                    i32.eqz
                    br_if 0 (;@8;)
                    local.get 1
                    i32.const -8
                    i32.add
                    local.tee 8
                    local.get 7
                    i32.add
                    local.set 9
                    local.get 7
                    local.get 4
                    i32.ge_u
                    br_if 1 (;@7;)
                    local.get 0
                    i32.load offset=412
                    local.get 9
                    i32.eq
                    br_if 2 (;@6;)
                    local.get 0
                    i32.load offset=408
                    local.get 9
                    i32.eq
                    br_if 3 (;@5;)
                    local.get 9
                    i32.load offset=4
                    local.tee 6
                    i32.const 2
                    i32.and
                    br_if 6 (;@2;)
                    local.get 6
                    i32.const -8
                    i32.and
                    local.tee 10
                    local.get 7
                    i32.add
                    local.tee 7
                    local.get 4
                    i32.ge_u
                    br_if 4 (;@4;)
                    br 6 (;@2;)
                  end
                  local.get 4
                  i32.const 256
                  i32.lt_u
                  br_if 5 (;@2;)
                  local.get 7
                  local.get 4
                  i32.const 4
                  i32.or
                  i32.lt_u
                  br_if 5 (;@2;)
                  local.get 7
                  local.get 4
                  i32.sub
                  i32.const 131073
                  i32.ge_u
                  br_if 5 (;@2;)
                  br 4 (;@3;)
                end
                local.get 7
                local.get 4
                i32.sub
                local.tee 2
                i32.const 16
                i32.lt_u
                br_if 3 (;@3;)
                local.get 5
                local.get 4
                local.get 6
                i32.const 1
                i32.and
                i32.or
                i32.const 2
                i32.or
                i32.store
                local.get 8
                local.get 4
                i32.add
                local.tee 3
                local.get 2
                i32.const 3
                i32.or
                i32.store offset=4
                local.get 9
                local.get 9
                i32.load offset=4
                i32.const 1
                i32.or
                i32.store offset=4
                local.get 0
                local.get 3
                local.get 2
                call $_ZN8dlmalloc8dlmalloc8Dlmalloc13dispose_chunk17hcacaa87797ad60a1E
                br 3 (;@3;)
              end
              local.get 0
              i32.load offset=404
              local.get 7
              i32.add
              local.tee 7
              local.get 4
              i32.le_u
              br_if 3 (;@2;)
              local.get 5
              local.get 4
              local.get 6
              i32.const 1
              i32.and
              i32.or
              i32.const 2
              i32.or
              i32.store
              local.get 8
              local.get 4
              i32.add
              local.tee 2
              local.get 7
              local.get 4
              i32.sub
              local.tee 3
              i32.const 1
              i32.or
              i32.store offset=4
              local.get 0
              local.get 3
              i32.store offset=404
              local.get 0
              local.get 2
              i32.store offset=412
              br 2 (;@3;)
            end
            local.get 0
            i32.load offset=400
            local.get 7
            i32.add
            local.tee 7
            local.get 4
            i32.lt_u
            br_if 2 (;@2;)
            block  ;; label = @5
              block  ;; label = @6
                local.get 7
                local.get 4
                i32.sub
                local.tee 2
                i32.const 15
                i32.gt_u
                br_if 0 (;@6;)
                local.get 5
                local.get 6
                i32.const 1
                i32.and
                local.get 7
                i32.or
                i32.const 2
                i32.or
                i32.store
                local.get 8
                local.get 7
                i32.add
                local.tee 2
                local.get 2
                i32.load offset=4
                i32.const 1
                i32.or
                i32.store offset=4
                i32.const 0
                local.set 2
                i32.const 0
                local.set 3
                br 1 (;@5;)
              end
              local.get 5
              local.get 4
              local.get 6
              i32.const 1
              i32.and
              i32.or
              i32.const 2
              i32.or
              i32.store
              local.get 8
              local.get 4
              i32.add
              local.tee 3
              local.get 2
              i32.const 1
              i32.or
              i32.store offset=4
              local.get 8
              local.get 7
              i32.add
              local.tee 4
              local.get 2
              i32.store
              local.get 4
              local.get 4
              i32.load offset=4
              i32.const -2
              i32.and
              i32.store offset=4
            end
            local.get 0
            local.get 3
            i32.store offset=408
            local.get 0
            local.get 2
            i32.store offset=400
            br 1 (;@3;)
          end
          local.get 7
          local.get 4
          i32.sub
          local.set 2
          block  ;; label = @4
            block  ;; label = @5
              local.get 10
              i32.const 256
              i32.lt_u
              br_if 0 (;@5;)
              local.get 0
              local.get 9
              call $_ZN8dlmalloc8dlmalloc8Dlmalloc18unlink_large_chunk17h979ff7c31798a32bE
              br 1 (;@4;)
            end
            block  ;; label = @5
              local.get 9
              i32.load offset=12
              local.tee 3
              local.get 9
              i32.load offset=8
              local.tee 9
              i32.eq
              br_if 0 (;@5;)
              local.get 9
              local.get 3
              i32.store offset=12
              local.get 3
              local.get 9
              i32.store offset=8
              br 1 (;@4;)
            end
            local.get 0
            local.get 0
            i32.load
            i32.const -2
            local.get 6
            i32.const 3
            i32.shr_u
            i32.rotl
            i32.and
            i32.store
          end
          block  ;; label = @4
            local.get 2
            i32.const 16
            i32.lt_u
            br_if 0 (;@4;)
            local.get 5
            local.get 4
            local.get 5
            i32.load
            i32.const 1
            i32.and
            i32.or
            i32.const 2
            i32.or
            i32.store
            local.get 8
            local.get 4
            i32.add
            local.tee 3
            local.get 2
            i32.const 3
            i32.or
            i32.store offset=4
            local.get 8
            local.get 7
            i32.add
            local.tee 4
            local.get 4
            i32.load offset=4
            i32.const 1
            i32.or
            i32.store offset=4
            local.get 0
            local.get 3
            local.get 2
            call $_ZN8dlmalloc8dlmalloc8Dlmalloc13dispose_chunk17hcacaa87797ad60a1E
            br 1 (;@3;)
          end
          local.get 5
          local.get 7
          local.get 5
          i32.load
          i32.const 1
          i32.and
          i32.or
          i32.const 2
          i32.or
          i32.store
          local.get 8
          local.get 7
          i32.add
          local.tee 2
          local.get 2
          i32.load offset=4
          i32.const 1
          i32.or
          i32.store offset=4
        end
        local.get 1
        local.set 3
        br 1 (;@1;)
      end
      local.get 0
      local.get 2
      call $_ZN8dlmalloc8dlmalloc8Dlmalloc6malloc17h4ea5e05e71d3c045E
      local.tee 4
      i32.eqz
      br_if 0 (;@1;)
      local.get 4
      local.get 1
      local.get 2
      local.get 5
      i32.load
      local.tee 3
      i32.const -8
      i32.and
      i32.const 4
      i32.const 8
      local.get 3
      i32.const 3
      i32.and
      select
      i32.sub
      local.tee 3
      local.get 3
      local.get 2
      i32.gt_u
      select
      call $memcpy
      local.set 2
      local.get 0
      local.get 1
      call $_ZN8dlmalloc8dlmalloc8Dlmalloc4free17hffa4364fa24b2098E
      local.get 2
      return
    end
    local.get 3)
  (func $_ZN8dlmalloc8dlmalloc8Dlmalloc13dispose_chunk17hcacaa87797ad60a1E (type 4) (param i32 i32 i32)
    (local i32 i32 i32 i32)
    local.get 1
    local.get 2
    i32.add
    local.set 3
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          local.get 1
          i32.load offset=4
          local.tee 4
          i32.const 1
          i32.and
          br_if 0 (;@3;)
          local.get 4
          i32.const 3
          i32.and
          i32.eqz
          br_if 1 (;@2;)
          local.get 1
          i32.load
          local.tee 4
          local.get 2
          i32.add
          local.set 2
          block  ;; label = @4
            local.get 0
            i32.load offset=408
            local.get 1
            local.get 4
            i32.sub
            local.tee 1
            i32.ne
            br_if 0 (;@4;)
            local.get 3
            i32.load offset=4
            i32.const 3
            i32.and
            i32.const 3
            i32.ne
            br_if 1 (;@3;)
            local.get 0
            local.get 2
            i32.store offset=400
            local.get 3
            local.get 3
            i32.load offset=4
            i32.const -2
            i32.and
            i32.store offset=4
            local.get 1
            local.get 2
            i32.const 1
            i32.or
            i32.store offset=4
            local.get 3
            local.get 2
            i32.store
            return
          end
          block  ;; label = @4
            local.get 4
            i32.const 256
            i32.lt_u
            br_if 0 (;@4;)
            local.get 0
            local.get 1
            call $_ZN8dlmalloc8dlmalloc8Dlmalloc18unlink_large_chunk17h979ff7c31798a32bE
            br 1 (;@3;)
          end
          block  ;; label = @4
            local.get 1
            i32.load offset=12
            local.tee 5
            local.get 1
            i32.load offset=8
            local.tee 6
            i32.eq
            br_if 0 (;@4;)
            local.get 6
            local.get 5
            i32.store offset=12
            local.get 5
            local.get 6
            i32.store offset=8
            br 1 (;@3;)
          end
          local.get 0
          local.get 0
          i32.load
          i32.const -2
          local.get 4
          i32.const 3
          i32.shr_u
          i32.rotl
          i32.and
          i32.store
        end
        block  ;; label = @3
          local.get 3
          i32.load offset=4
          local.tee 4
          i32.const 2
          i32.and
          i32.eqz
          br_if 0 (;@3;)
          local.get 3
          local.get 4
          i32.const -2
          i32.and
          i32.store offset=4
          local.get 1
          local.get 2
          i32.const 1
          i32.or
          i32.store offset=4
          local.get 1
          local.get 2
          i32.add
          local.get 2
          i32.store
          br 2 (;@1;)
        end
        block  ;; label = @3
          block  ;; label = @4
            local.get 0
            i32.load offset=412
            local.get 3
            i32.eq
            br_if 0 (;@4;)
            local.get 0
            i32.load offset=408
            local.get 3
            i32.ne
            br_if 1 (;@3;)
            local.get 0
            local.get 1
            i32.store offset=408
            local.get 0
            local.get 0
            i32.load offset=400
            local.get 2
            i32.add
            local.tee 2
            i32.store offset=400
            local.get 1
            local.get 2
            i32.const 1
            i32.or
            i32.store offset=4
            local.get 1
            local.get 2
            i32.add
            local.get 2
            i32.store
            return
          end
          local.get 0
          local.get 1
          i32.store offset=412
          local.get 0
          local.get 0
          i32.load offset=404
          local.get 2
          i32.add
          local.tee 2
          i32.store offset=404
          local.get 1
          local.get 2
          i32.const 1
          i32.or
          i32.store offset=4
          local.get 1
          local.get 0
          i32.load offset=408
          i32.ne
          br_if 1 (;@2;)
          local.get 0
          i32.const 0
          i32.store offset=400
          local.get 0
          i32.const 0
          i32.store offset=408
          return
        end
        local.get 4
        i32.const -8
        i32.and
        local.tee 5
        local.get 2
        i32.add
        local.set 2
        block  ;; label = @3
          block  ;; label = @4
            local.get 5
            i32.const 256
            i32.lt_u
            br_if 0 (;@4;)
            local.get 0
            local.get 3
            call $_ZN8dlmalloc8dlmalloc8Dlmalloc18unlink_large_chunk17h979ff7c31798a32bE
            br 1 (;@3;)
          end
          block  ;; label = @4
            local.get 3
            i32.load offset=12
            local.tee 5
            local.get 3
            i32.load offset=8
            local.tee 3
            i32.eq
            br_if 0 (;@4;)
            local.get 3
            local.get 5
            i32.store offset=12
            local.get 5
            local.get 3
            i32.store offset=8
            br 1 (;@3;)
          end
          local.get 0
          local.get 0
          i32.load
          i32.const -2
          local.get 4
          i32.const 3
          i32.shr_u
          i32.rotl
          i32.and
          i32.store
        end
        local.get 1
        local.get 2
        i32.const 1
        i32.or
        i32.store offset=4
        local.get 1
        local.get 2
        i32.add
        local.get 2
        i32.store
        local.get 1
        local.get 0
        i32.load offset=408
        i32.ne
        br_if 1 (;@1;)
        local.get 0
        local.get 2
        i32.store offset=400
      end
      return
    end
    block  ;; label = @1
      local.get 2
      i32.const 256
      i32.lt_u
      br_if 0 (;@1;)
      local.get 0
      local.get 1
      local.get 2
      call $_ZN8dlmalloc8dlmalloc8Dlmalloc18insert_large_chunk17h2eefc93f2226b039E
      return
    end
    local.get 0
    local.get 2
    i32.const 3
    i32.shr_u
    local.tee 3
    i32.const 3
    i32.shl
    i32.add
    i32.const 8
    i32.add
    local.set 2
    block  ;; label = @1
      block  ;; label = @2
        local.get 0
        i32.load
        local.tee 4
        i32.const 1
        local.get 3
        i32.const 31
        i32.and
        i32.shl
        local.tee 3
        i32.and
        i32.eqz
        br_if 0 (;@2;)
        local.get 2
        i32.load offset=8
        local.set 0
        br 1 (;@1;)
      end
      local.get 0
      local.get 4
      local.get 3
      i32.or
      i32.store
      local.get 2
      local.set 0
    end
    local.get 2
    local.get 1
    i32.store offset=8
    local.get 0
    local.get 1
    i32.store offset=12
    local.get 1
    local.get 2
    i32.store offset=12
    local.get 1
    local.get 0
    i32.store offset=8)
  (func $_ZN8dlmalloc8dlmalloc8Dlmalloc4free17hffa4364fa24b2098E (type 0) (param i32 i32)
    (local i32 i32 i32 i32 i32)
    local.get 1
    i32.const -8
    i32.add
    local.tee 2
    local.get 1
    i32.const -4
    i32.add
    i32.load
    local.tee 3
    i32.const -8
    i32.and
    local.tee 1
    i32.add
    local.set 4
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            local.get 3
            i32.const 1
            i32.and
            br_if 0 (;@4;)
            local.get 3
            i32.const 3
            i32.and
            i32.eqz
            br_if 1 (;@3;)
            local.get 2
            i32.load
            local.tee 3
            local.get 1
            i32.add
            local.set 1
            block  ;; label = @5
              local.get 0
              i32.load offset=408
              local.get 2
              local.get 3
              i32.sub
              local.tee 2
              i32.ne
              br_if 0 (;@5;)
              local.get 4
              i32.load offset=4
              i32.const 3
              i32.and
              i32.const 3
              i32.ne
              br_if 1 (;@4;)
              local.get 0
              local.get 1
              i32.store offset=400
              local.get 4
              local.get 4
              i32.load offset=4
              i32.const -2
              i32.and
              i32.store offset=4
              local.get 2
              local.get 1
              i32.const 1
              i32.or
              i32.store offset=4
              local.get 2
              local.get 1
              i32.add
              local.get 1
              i32.store
              return
            end
            block  ;; label = @5
              local.get 3
              i32.const 256
              i32.lt_u
              br_if 0 (;@5;)
              local.get 0
              local.get 2
              call $_ZN8dlmalloc8dlmalloc8Dlmalloc18unlink_large_chunk17h979ff7c31798a32bE
              br 1 (;@4;)
            end
            block  ;; label = @5
              local.get 2
              i32.load offset=12
              local.tee 5
              local.get 2
              i32.load offset=8
              local.tee 6
              i32.eq
              br_if 0 (;@5;)
              local.get 6
              local.get 5
              i32.store offset=12
              local.get 5
              local.get 6
              i32.store offset=8
              br 1 (;@4;)
            end
            local.get 0
            local.get 0
            i32.load
            i32.const -2
            local.get 3
            i32.const 3
            i32.shr_u
            i32.rotl
            i32.and
            i32.store
          end
          block  ;; label = @4
            block  ;; label = @5
              local.get 4
              i32.load offset=4
              local.tee 3
              i32.const 2
              i32.and
              i32.eqz
              br_if 0 (;@5;)
              local.get 4
              local.get 3
              i32.const -2
              i32.and
              i32.store offset=4
              local.get 2
              local.get 1
              i32.const 1
              i32.or
              i32.store offset=4
              local.get 2
              local.get 1
              i32.add
              local.get 1
              i32.store
              br 1 (;@4;)
            end
            block  ;; label = @5
              block  ;; label = @6
                local.get 0
                i32.load offset=412
                local.get 4
                i32.eq
                br_if 0 (;@6;)
                local.get 0
                i32.load offset=408
                local.get 4
                i32.ne
                br_if 1 (;@5;)
                local.get 0
                local.get 2
                i32.store offset=408
                local.get 0
                local.get 0
                i32.load offset=400
                local.get 1
                i32.add
                local.tee 1
                i32.store offset=400
                local.get 2
                local.get 1
                i32.const 1
                i32.or
                i32.store offset=4
                local.get 2
                local.get 1
                i32.add
                local.get 1
                i32.store
                return
              end
              local.get 0
              local.get 2
              i32.store offset=412
              local.get 0
              local.get 0
              i32.load offset=404
              local.get 1
              i32.add
              local.tee 1
              i32.store offset=404
              local.get 2
              local.get 1
              i32.const 1
              i32.or
              i32.store offset=4
              block  ;; label = @6
                local.get 2
                local.get 0
                i32.load offset=408
                i32.ne
                br_if 0 (;@6;)
                local.get 0
                i32.const 0
                i32.store offset=400
                local.get 0
                i32.const 0
                i32.store offset=408
              end
              local.get 0
              i32.load offset=440
              local.tee 3
              local.get 1
              i32.ge_u
              br_if 2 (;@3;)
              local.get 0
              i32.load offset=412
              local.tee 1
              i32.eqz
              br_if 2 (;@3;)
              block  ;; label = @6
                local.get 0
                i32.load offset=404
                local.tee 5
                i32.const 41
                i32.lt_u
                br_if 0 (;@6;)
                local.get 0
                i32.const 424
                i32.add
                local.set 2
                loop  ;; label = @7
                  block  ;; label = @8
                    local.get 2
                    i32.load
                    local.tee 4
                    local.get 1
                    i32.gt_u
                    br_if 0 (;@8;)
                    local.get 4
                    local.get 2
                    i32.load offset=4
                    i32.add
                    local.get 1
                    i32.gt_u
                    br_if 2 (;@6;)
                  end
                  local.get 2
                  i32.load offset=8
                  local.tee 2
                  br_if 0 (;@7;)
                end
              end
              block  ;; label = @6
                block  ;; label = @7
                  local.get 0
                  i32.const 432
                  i32.add
                  i32.load
                  local.tee 1
                  br_if 0 (;@7;)
                  i32.const 4095
                  local.set 2
                  br 1 (;@6;)
                end
                i32.const 0
                local.set 2
                loop  ;; label = @7
                  local.get 2
                  i32.const 1
                  i32.add
                  local.set 2
                  local.get 1
                  i32.load offset=8
                  local.tee 1
                  br_if 0 (;@7;)
                end
                local.get 2
                i32.const 4095
                local.get 2
                i32.const 4095
                i32.gt_u
                select
                local.set 2
              end
              local.get 0
              local.get 2
              i32.store offset=448
              local.get 5
              local.get 3
              i32.le_u
              br_if 2 (;@3;)
              local.get 0
              i32.const -1
              i32.store offset=440
              return
            end
            local.get 3
            i32.const -8
            i32.and
            local.tee 5
            local.get 1
            i32.add
            local.set 1
            block  ;; label = @5
              block  ;; label = @6
                local.get 5
                i32.const 256
                i32.lt_u
                br_if 0 (;@6;)
                local.get 0
                local.get 4
                call $_ZN8dlmalloc8dlmalloc8Dlmalloc18unlink_large_chunk17h979ff7c31798a32bE
                br 1 (;@5;)
              end
              block  ;; label = @6
                local.get 4
                i32.load offset=12
                local.tee 5
                local.get 4
                i32.load offset=8
                local.tee 4
                i32.eq
                br_if 0 (;@6;)
                local.get 4
                local.get 5
                i32.store offset=12
                local.get 5
                local.get 4
                i32.store offset=8
                br 1 (;@5;)
              end
              local.get 0
              local.get 0
              i32.load
              i32.const -2
              local.get 3
              i32.const 3
              i32.shr_u
              i32.rotl
              i32.and
              i32.store
            end
            local.get 2
            local.get 1
            i32.const 1
            i32.or
            i32.store offset=4
            local.get 2
            local.get 1
            i32.add
            local.get 1
            i32.store
            local.get 2
            local.get 0
            i32.load offset=408
            i32.ne
            br_if 0 (;@4;)
            local.get 0
            local.get 1
            i32.store offset=400
            br 1 (;@3;)
          end
          local.get 1
          i32.const 256
          i32.lt_u
          br_if 1 (;@2;)
          local.get 0
          local.get 2
          local.get 1
          call $_ZN8dlmalloc8dlmalloc8Dlmalloc18insert_large_chunk17h2eefc93f2226b039E
          local.get 0
          local.get 0
          i32.load offset=448
          i32.const -1
          i32.add
          local.tee 2
          i32.store offset=448
          local.get 2
          br_if 0 (;@3;)
          local.get 0
          i32.const 432
          i32.add
          i32.load
          local.tee 1
          br_if 2 (;@1;)
          local.get 0
          i32.const 4095
          i32.store offset=448
          return
        end
        return
      end
      local.get 0
      local.get 1
      i32.const 3
      i32.shr_u
      local.tee 4
      i32.const 3
      i32.shl
      i32.add
      i32.const 8
      i32.add
      local.set 1
      block  ;; label = @2
        block  ;; label = @3
          local.get 0
          i32.load
          local.tee 3
          i32.const 1
          local.get 4
          i32.const 31
          i32.and
          i32.shl
          local.tee 4
          i32.and
          i32.eqz
          br_if 0 (;@3;)
          local.get 1
          i32.load offset=8
          local.set 0
          br 1 (;@2;)
        end
        local.get 0
        local.get 3
        local.get 4
        i32.or
        i32.store
        local.get 1
        local.set 0
      end
      local.get 1
      local.get 2
      i32.store offset=8
      local.get 0
      local.get 2
      i32.store offset=12
      local.get 2
      local.get 1
      i32.store offset=12
      local.get 2
      local.get 0
      i32.store offset=8
      return
    end
    i32.const 0
    local.set 2
    loop  ;; label = @1
      local.get 2
      i32.const 1
      i32.add
      local.set 2
      local.get 1
      i32.load offset=8
      local.tee 1
      br_if 0 (;@1;)
    end
    local.get 0
    local.get 2
    i32.const 4095
    local.get 2
    i32.const 4095
    i32.gt_u
    select
    i32.store offset=448)
  (func $_ZN8dlmalloc8dlmalloc8Dlmalloc8memalign17h5b13792549d920d9E (type 1) (param i32 i32 i32) (result i32)
    (local i32 i32 i32 i32 i32)
    i32.const 0
    local.set 3
    block  ;; label = @1
      i32.const -65587
      local.get 1
      i32.const 16
      local.get 1
      i32.const 16
      i32.gt_u
      select
      local.tee 1
      i32.sub
      local.get 2
      i32.le_u
      br_if 0 (;@1;)
      local.get 0
      local.get 1
      i32.const 16
      local.get 2
      i32.const 11
      i32.add
      i32.const -8
      i32.and
      local.get 2
      i32.const 11
      i32.lt_u
      select
      local.tee 4
      i32.add
      i32.const 12
      i32.add
      call $_ZN8dlmalloc8dlmalloc8Dlmalloc6malloc17h4ea5e05e71d3c045E
      local.tee 2
      i32.eqz
      br_if 0 (;@1;)
      local.get 2
      i32.const -8
      i32.add
      local.set 3
      block  ;; label = @2
        block  ;; label = @3
          local.get 1
          i32.const -1
          i32.add
          local.tee 5
          local.get 2
          i32.and
          br_if 0 (;@3;)
          local.get 3
          local.set 1
          br 1 (;@2;)
        end
        local.get 2
        i32.const -4
        i32.add
        local.tee 6
        i32.load
        local.tee 7
        i32.const -8
        i32.and
        local.get 5
        local.get 2
        i32.add
        i32.const 0
        local.get 1
        i32.sub
        i32.and
        i32.const -8
        i32.add
        local.tee 2
        local.get 2
        local.get 1
        i32.add
        local.get 2
        local.get 3
        i32.sub
        i32.const 16
        i32.gt_u
        select
        local.tee 1
        local.get 3
        i32.sub
        local.tee 2
        i32.sub
        local.set 5
        block  ;; label = @3
          local.get 7
          i32.const 3
          i32.and
          i32.eqz
          br_if 0 (;@3;)
          local.get 1
          local.get 5
          local.get 1
          i32.load offset=4
          i32.const 1
          i32.and
          i32.or
          i32.const 2
          i32.or
          i32.store offset=4
          local.get 1
          local.get 5
          i32.add
          local.tee 5
          local.get 5
          i32.load offset=4
          i32.const 1
          i32.or
          i32.store offset=4
          local.get 6
          local.get 2
          local.get 6
          i32.load
          i32.const 1
          i32.and
          i32.or
          i32.const 2
          i32.or
          i32.store
          local.get 1
          local.get 1
          i32.load offset=4
          i32.const 1
          i32.or
          i32.store offset=4
          local.get 0
          local.get 3
          local.get 2
          call $_ZN8dlmalloc8dlmalloc8Dlmalloc13dispose_chunk17hcacaa87797ad60a1E
          br 1 (;@2;)
        end
        local.get 3
        i32.load
        local.set 3
        local.get 1
        local.get 5
        i32.store offset=4
        local.get 1
        local.get 3
        local.get 2
        i32.add
        i32.store
      end
      block  ;; label = @2
        local.get 1
        i32.load offset=4
        local.tee 2
        i32.const 3
        i32.and
        i32.eqz
        br_if 0 (;@2;)
        local.get 2
        i32.const -8
        i32.and
        local.tee 3
        local.get 4
        i32.const 16
        i32.add
        i32.le_u
        br_if 0 (;@2;)
        local.get 1
        local.get 4
        local.get 2
        i32.const 1
        i32.and
        i32.or
        i32.const 2
        i32.or
        i32.store offset=4
        local.get 1
        local.get 4
        i32.add
        local.tee 2
        local.get 3
        local.get 4
        i32.sub
        local.tee 4
        i32.const 3
        i32.or
        i32.store offset=4
        local.get 1
        local.get 3
        i32.add
        local.tee 3
        local.get 3
        i32.load offset=4
        i32.const 1
        i32.or
        i32.store offset=4
        local.get 0
        local.get 2
        local.get 4
        call $_ZN8dlmalloc8dlmalloc8Dlmalloc13dispose_chunk17hcacaa87797ad60a1E
      end
      local.get 1
      i32.const 8
      i32.add
      local.set 3
    end
    local.get 3)
  (func $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E (type 0) (param i32 i32)
    local.get 0
    local.get 1
    call $rust_oom
    unreachable)
  (func $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17hd8466700409e2f20E (type 3)
    call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
    unreachable)
  (func $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E (type 3)
    i32.const 1050540
    call $_ZN4core9panicking5panic17h1fb303f1c113605dE
    unreachable)
  (func $_ZN60_$LT$alloc..string..String$u20$as$u20$core..clone..Clone$GT$5clone17hcaceec0319ee7974E (type 0) (param i32 i32)
    (local i32 i32)
    block  ;; label = @1
      block  ;; label = @2
        local.get 1
        i32.load offset=8
        local.tee 2
        i32.const -1
        i32.le_s
        br_if 0 (;@2;)
        local.get 1
        i32.load
        local.set 1
        block  ;; label = @3
          block  ;; label = @4
            local.get 2
            br_if 0 (;@4;)
            i32.const 1
            local.set 3
            br 1 (;@3;)
          end
          local.get 2
          i32.const 1
          call $__rust_alloc
          local.tee 3
          i32.eqz
          br_if 2 (;@1;)
        end
        local.get 3
        local.get 1
        local.get 2
        call $memcpy
        local.set 1
        local.get 0
        local.get 2
        i32.store offset=8
        local.get 0
        local.get 2
        i32.store offset=4
        local.get 0
        local.get 1
        i32.store
        return
      end
      call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17hd8466700409e2f20E
      unreachable
    end
    local.get 2
    i32.const 1
    call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
    unreachable)
  (func $_ZN4core3ptr18real_drop_in_place17he09fc700ab5b0ef3E (type 5) (param i32))
  (func $_ZN4core9panicking18panic_bounds_check17hdaf7aa012e2661faE (type 4) (param i32 i32 i32)
    (local i32)
    global.get 0
    i32.const 48
    i32.sub
    local.tee 3
    global.set 0
    local.get 3
    local.get 2
    i32.store offset=4
    local.get 3
    local.get 1
    i32.store
    local.get 3
    i32.const 28
    i32.add
    i32.const 2
    i32.store
    local.get 3
    i32.const 44
    i32.add
    i32.const 28
    i32.store
    local.get 3
    i64.const 2
    i64.store offset=12 align=4
    local.get 3
    i32.const 1050632
    i32.store offset=8
    local.get 3
    i32.const 28
    i32.store offset=36
    local.get 3
    local.get 3
    i32.const 32
    i32.add
    i32.store offset=24
    local.get 3
    local.get 3
    i32.store offset=40
    local.get 3
    local.get 3
    i32.const 4
    i32.add
    i32.store offset=32
    local.get 3
    i32.const 8
    i32.add
    local.get 0
    call $_ZN4core9panicking9panic_fmt17h52bd9c4c06b66d8dE
    unreachable)
  (func $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE (type 0) (param i32 i32)
    (local i32)
    global.get 0
    i32.const 48
    i32.sub
    local.tee 2
    global.set 0
    local.get 2
    local.get 1
    i32.store offset=4
    local.get 2
    local.get 0
    i32.store
    local.get 2
    i32.const 28
    i32.add
    i32.const 2
    i32.store
    local.get 2
    i32.const 44
    i32.add
    i32.const 28
    i32.store
    local.get 2
    i64.const 2
    i64.store offset=12 align=4
    local.get 2
    i32.const 1050800
    i32.store offset=8
    local.get 2
    i32.const 28
    i32.store offset=36
    local.get 2
    local.get 2
    i32.const 32
    i32.add
    i32.store offset=24
    local.get 2
    local.get 2
    i32.const 4
    i32.add
    i32.store offset=40
    local.get 2
    local.get 2
    i32.store offset=32
    local.get 2
    i32.const 8
    i32.add
    i32.const 1050816
    call $_ZN4core9panicking9panic_fmt17h52bd9c4c06b66d8dE
    unreachable)
  (func $_ZN4core9panicking5panic17h1fb303f1c113605dE (type 5) (param i32)
    (local i32 i64 i64 i64)
    global.get 0
    i32.const 48
    i32.sub
    local.tee 1
    global.set 0
    local.get 0
    i64.load offset=8 align=4
    local.set 2
    local.get 0
    i64.load offset=16 align=4
    local.set 3
    local.get 0
    i64.load align=4
    local.set 4
    local.get 1
    i32.const 20
    i32.add
    i32.const 0
    i32.store
    local.get 1
    i32.const 1050564
    i32.store offset=16
    local.get 1
    i64.const 1
    i64.store offset=4 align=4
    local.get 1
    local.get 4
    i64.store offset=24
    local.get 1
    local.get 1
    i32.const 24
    i32.add
    i32.store
    local.get 1
    local.get 3
    i64.store offset=40
    local.get 1
    local.get 2
    i64.store offset=32
    local.get 1
    local.get 1
    i32.const 32
    i32.add
    call $_ZN4core9panicking9panic_fmt17h52bd9c4c06b66d8dE
    unreachable)
  (func $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE (type 0) (param i32 i32)
    (local i32)
    global.get 0
    i32.const 48
    i32.sub
    local.tee 2
    global.set 0
    local.get 2
    local.get 1
    i32.store offset=4
    local.get 2
    local.get 0
    i32.store
    local.get 2
    i32.const 28
    i32.add
    i32.const 2
    i32.store
    local.get 2
    i32.const 44
    i32.add
    i32.const 28
    i32.store
    local.get 2
    i64.const 2
    i64.store offset=12 align=4
    local.get 2
    i32.const 1050868
    i32.store offset=8
    local.get 2
    i32.const 28
    i32.store offset=36
    local.get 2
    local.get 2
    i32.const 32
    i32.add
    i32.store offset=24
    local.get 2
    local.get 2
    i32.const 4
    i32.add
    i32.store offset=40
    local.get 2
    local.get 2
    i32.store offset=32
    local.get 2
    i32.const 8
    i32.add
    i32.const 1050884
    call $_ZN4core9panicking9panic_fmt17h52bd9c4c06b66d8dE
    unreachable)
  (func $_ZN4core9panicking9panic_fmt17h52bd9c4c06b66d8dE (type 0) (param i32 i32)
    (local i32 i64)
    global.get 0
    i32.const 32
    i32.sub
    local.tee 2
    global.set 0
    local.get 1
    i64.load align=4
    local.set 3
    local.get 2
    i32.const 20
    i32.add
    local.get 1
    i64.load offset=8 align=4
    i64.store align=4
    local.get 2
    local.get 3
    i64.store offset=12 align=4
    local.get 2
    local.get 0
    i32.store offset=8
    local.get 2
    i32.const 1050564
    i32.store offset=4
    local.get 2
    i32.const 1050564
    i32.store
    local.get 2
    call $rust_begin_unwind
    unreachable)
  (func $_ZN4core3fmt3num3imp52_$LT$impl$u20$core..fmt..Display$u20$for$u20$u32$GT$3fmt17h1c0bcbdea3856b66E (type 2) (param i32 i32) (result i32)
    local.get 0
    i64.load32_u
    i32.const 1
    local.get 1
    call $_ZN4core3fmt3num3imp7fmt_u6417h803709c51b6e7b35E)
  (func $_ZN4core3fmt5write17hd3aab830518de99fE (type 1) (param i32 i32 i32) (result i32)
    (local i32 i32 i32 i32 i32 i32 i32 i32)
    global.get 0
    i32.const 64
    i32.sub
    local.tee 3
    global.set 0
    local.get 3
    i32.const 36
    i32.add
    local.get 1
    i32.store
    local.get 3
    i32.const 52
    i32.add
    local.get 2
    i32.const 20
    i32.add
    i32.load
    local.tee 4
    i32.store
    local.get 3
    i32.const 3
    i32.store8 offset=56
    local.get 3
    i32.const 44
    i32.add
    local.get 2
    i32.load offset=16
    local.tee 5
    local.get 4
    i32.const 3
    i32.shl
    i32.add
    i32.store
    local.get 3
    i64.const 137438953472
    i64.store offset=8
    local.get 3
    local.get 0
    i32.store offset=32
    i32.const 0
    local.set 6
    local.get 3
    i32.const 0
    i32.store offset=24
    local.get 3
    i32.const 0
    i32.store offset=16
    local.get 3
    local.get 5
    i32.store offset=48
    local.get 3
    local.get 5
    i32.store offset=40
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              local.get 2
              i32.load offset=8
              local.tee 7
              br_if 0 (;@5;)
              local.get 2
              i32.load
              local.set 8
              local.get 2
              i32.load offset=4
              local.tee 9
              local.get 4
              local.get 4
              local.get 9
              i32.gt_u
              select
              local.tee 10
              i32.eqz
              br_if 1 (;@4;)
              i32.const 1
              local.set 4
              local.get 0
              local.get 8
              i32.load
              local.get 8
              i32.load offset=4
              local.get 1
              i32.load offset=12
              call_indirect (type 1)
              br_if 4 (;@1;)
              local.get 8
              i32.const 12
              i32.add
              local.set 2
              i32.const 1
              local.set 6
              loop  ;; label = @6
                block  ;; label = @7
                  local.get 5
                  i32.load
                  local.get 3
                  i32.const 8
                  i32.add
                  local.get 5
                  i32.const 4
                  i32.add
                  i32.load
                  call_indirect (type 2)
                  i32.eqz
                  br_if 0 (;@7;)
                  i32.const 1
                  local.set 4
                  br 6 (;@1;)
                end
                local.get 6
                local.get 10
                i32.ge_u
                br_if 2 (;@4;)
                local.get 2
                i32.const -4
                i32.add
                local.set 0
                local.get 2
                i32.load
                local.set 1
                local.get 2
                i32.const 8
                i32.add
                local.set 2
                local.get 5
                i32.const 8
                i32.add
                local.set 5
                i32.const 1
                local.set 4
                local.get 6
                i32.const 1
                i32.add
                local.set 6
                local.get 3
                i32.load offset=32
                local.get 0
                i32.load
                local.get 1
                local.get 3
                i32.load offset=36
                i32.load offset=12
                call_indirect (type 1)
                i32.eqz
                br_if 0 (;@6;)
                br 5 (;@1;)
              end
            end
            local.get 2
            i32.load
            local.set 8
            local.get 2
            i32.load offset=4
            local.tee 9
            local.get 2
            i32.const 12
            i32.add
            i32.load
            local.tee 5
            local.get 5
            local.get 9
            i32.gt_u
            select
            local.tee 10
            i32.eqz
            br_if 0 (;@4;)
            i32.const 1
            local.set 4
            local.get 0
            local.get 8
            i32.load
            local.get 8
            i32.load offset=4
            local.get 1
            i32.load offset=12
            call_indirect (type 1)
            br_if 3 (;@1;)
            local.get 8
            i32.const 12
            i32.add
            local.set 2
            local.get 7
            i32.const 16
            i32.add
            local.set 5
            i32.const 1
            local.set 6
            loop  ;; label = @5
              local.get 3
              local.get 5
              i32.const -8
              i32.add
              i32.load
              i32.store offset=12
              local.get 3
              local.get 5
              i32.const 16
              i32.add
              i32.load8_u
              i32.store8 offset=56
              local.get 3
              local.get 5
              i32.const -4
              i32.add
              i32.load
              i32.store offset=8
              i32.const 0
              local.set 1
              i32.const 0
              local.set 4
              block  ;; label = @6
                block  ;; label = @7
                  block  ;; label = @8
                    block  ;; label = @9
                      local.get 5
                      i32.const 8
                      i32.add
                      i32.load
                      br_table 0 (;@9;) 1 (;@8;) 2 (;@7;) 3 (;@6;) 0 (;@9;)
                    end
                    local.get 5
                    i32.const 12
                    i32.add
                    i32.load
                    local.set 0
                    i32.const 1
                    local.set 4
                    br 2 (;@6;)
                  end
                  block  ;; label = @8
                    local.get 5
                    i32.const 12
                    i32.add
                    i32.load
                    local.tee 7
                    local.get 3
                    i32.load offset=52
                    local.tee 4
                    i32.ge_u
                    br_if 0 (;@8;)
                    i32.const 0
                    local.set 4
                    local.get 3
                    i32.load offset=48
                    local.get 7
                    i32.const 3
                    i32.shl
                    i32.add
                    local.tee 7
                    i32.load offset=4
                    i32.const 29
                    i32.ne
                    br_if 2 (;@6;)
                    local.get 7
                    i32.load
                    i32.load
                    local.set 0
                    i32.const 1
                    local.set 4
                    br 2 (;@6;)
                  end
                  i32.const 1051144
                  local.get 7
                  local.get 4
                  call $_ZN4core9panicking18panic_bounds_check17hdaf7aa012e2661faE
                  unreachable
                end
                i32.const 0
                local.set 4
                local.get 3
                i32.load offset=40
                local.tee 7
                local.get 3
                i32.load offset=44
                i32.eq
                br_if 0 (;@6;)
                local.get 3
                local.get 7
                i32.const 8
                i32.add
                i32.store offset=40
                i32.const 0
                local.set 4
                local.get 7
                i32.load offset=4
                i32.const 29
                i32.ne
                br_if 0 (;@6;)
                local.get 7
                i32.load
                i32.load
                local.set 0
                i32.const 1
                local.set 4
              end
              local.get 3
              local.get 0
              i32.store offset=20
              local.get 3
              local.get 4
              i32.store offset=16
              block  ;; label = @6
                block  ;; label = @7
                  block  ;; label = @8
                    block  ;; label = @9
                      block  ;; label = @10
                        block  ;; label = @11
                          block  ;; label = @12
                            local.get 5
                            i32.load
                            br_table 4 (;@8;) 1 (;@11;) 0 (;@12;) 6 (;@6;) 4 (;@8;)
                          end
                          local.get 3
                          i32.load offset=40
                          local.tee 0
                          local.get 3
                          i32.load offset=44
                          i32.ne
                          br_if 1 (;@10;)
                          br 5 (;@6;)
                        end
                        local.get 5
                        i32.const 4
                        i32.add
                        i32.load
                        local.tee 0
                        local.get 3
                        i32.load offset=52
                        local.tee 4
                        i32.ge_u
                        br_if 1 (;@9;)
                        local.get 3
                        i32.load offset=48
                        local.get 0
                        i32.const 3
                        i32.shl
                        i32.add
                        local.tee 0
                        i32.load offset=4
                        i32.const 29
                        i32.ne
                        br_if 4 (;@6;)
                        local.get 0
                        i32.load
                        i32.load
                        local.set 4
                        br 3 (;@7;)
                      end
                      local.get 3
                      local.get 0
                      i32.const 8
                      i32.add
                      i32.store offset=40
                      local.get 0
                      i32.load offset=4
                      i32.const 29
                      i32.ne
                      br_if 3 (;@6;)
                      local.get 0
                      i32.load
                      i32.load
                      local.set 4
                      br 2 (;@7;)
                    end
                    i32.const 1051144
                    local.get 0
                    local.get 4
                    call $_ZN4core9panicking18panic_bounds_check17hdaf7aa012e2661faE
                    unreachable
                  end
                  local.get 5
                  i32.const 4
                  i32.add
                  i32.load
                  local.set 4
                end
                i32.const 1
                local.set 1
              end
              local.get 3
              local.get 4
              i32.store offset=28
              local.get 3
              local.get 1
              i32.store offset=24
              block  ;; label = @6
                block  ;; label = @7
                  local.get 5
                  i32.const -16
                  i32.add
                  i32.load
                  i32.const 1
                  i32.eq
                  br_if 0 (;@7;)
                  local.get 3
                  i32.load offset=40
                  local.tee 4
                  local.get 3
                  i32.load offset=44
                  i32.eq
                  br_if 4 (;@3;)
                  local.get 3
                  local.get 4
                  i32.const 8
                  i32.add
                  i32.store offset=40
                  br 1 (;@6;)
                end
                local.get 5
                i32.const -12
                i32.add
                i32.load
                local.tee 4
                local.get 3
                i32.load offset=52
                local.tee 0
                i32.ge_u
                br_if 4 (;@2;)
                local.get 3
                i32.load offset=48
                local.get 4
                i32.const 3
                i32.shl
                i32.add
                local.set 4
              end
              block  ;; label = @6
                local.get 4
                i32.load
                local.get 3
                i32.const 8
                i32.add
                local.get 4
                i32.const 4
                i32.add
                i32.load
                call_indirect (type 2)
                i32.eqz
                br_if 0 (;@6;)
                i32.const 1
                local.set 4
                br 5 (;@1;)
              end
              local.get 6
              local.get 10
              i32.ge_u
              br_if 1 (;@4;)
              local.get 2
              i32.const -4
              i32.add
              local.set 0
              local.get 2
              i32.load
              local.set 1
              local.get 2
              i32.const 8
              i32.add
              local.set 2
              local.get 5
              i32.const 36
              i32.add
              local.set 5
              i32.const 1
              local.set 4
              local.get 6
              i32.const 1
              i32.add
              local.set 6
              local.get 3
              i32.load offset=32
              local.get 0
              i32.load
              local.get 1
              local.get 3
              i32.load offset=36
              i32.load offset=12
              call_indirect (type 1)
              i32.eqz
              br_if 0 (;@5;)
              br 4 (;@1;)
            end
          end
          block  ;; label = @4
            local.get 9
            local.get 6
            i32.le_u
            br_if 0 (;@4;)
            i32.const 1
            local.set 4
            local.get 3
            i32.load offset=32
            local.get 8
            local.get 6
            i32.const 3
            i32.shl
            i32.add
            local.tee 5
            i32.load
            local.get 5
            i32.load offset=4
            local.get 3
            i32.load offset=36
            i32.load offset=12
            call_indirect (type 1)
            br_if 3 (;@1;)
          end
          i32.const 0
          local.set 4
          br 2 (;@1;)
        end
        i32.const 1050712
        call $_ZN4core9panicking5panic17h1fb303f1c113605dE
        unreachable
      end
      i32.const 1051128
      local.get 4
      local.get 0
      call $_ZN4core9panicking18panic_bounds_check17hdaf7aa012e2661faE
      unreachable
    end
    local.get 3
    i32.const 64
    i32.add
    global.set 0
    local.get 4)
  (func $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17h453c6ffd565494afE (type 7) (param i32) (result i64)
    i64.const 6849931393926300958)
  (func $_ZN4core5panic9PanicInfo7message17hdcd25a611da38ea7E (type 6) (param i32) (result i32)
    local.get 0
    i32.load offset=8)
  (func $_ZN4core5panic9PanicInfo8location17ha2676bb4cd3a13d5E (type 6) (param i32) (result i32)
    local.get 0
    i32.const 12
    i32.add)
  (func $_ZN4core5panic8Location20internal_constructor17ha5194c997adfccb1E (type 17) (param i32 i32 i32 i32 i32)
    local.get 0
    local.get 4
    i32.store offset=12
    local.get 0
    local.get 3
    i32.store offset=8
    local.get 0
    local.get 2
    i32.store offset=4
    local.get 0
    local.get 1
    i32.store)
  (func $_ZN4core5panic8Location4file17hf1af7974a4d66f1aE (type 0) (param i32 i32)
    local.get 0
    local.get 1
    i64.load align=4
    i64.store align=4)
  (func $_ZN4core5panic8Location4line17hb259bed5c38d555eE (type 6) (param i32) (result i32)
    local.get 0
    i32.load offset=8)
  (func $_ZN4core5panic8Location6column17ha177fe4aa32d620dE (type 6) (param i32) (result i32)
    local.get 0
    i32.load offset=12)
  (func $_ZN4core3fmt10ArgumentV110show_usize17h854a277e0a6571caE (type 2) (param i32 i32) (result i32)
    local.get 0
    i64.load32_u
    i32.const 1
    local.get 1
    call $_ZN4core3fmt3num3imp7fmt_u6417h803709c51b6e7b35E)
  (func $_ZN4core3fmt3num3imp7fmt_u6417h803709c51b6e7b35E (type 18) (param i64 i32 i32) (result i32)
    (local i32 i32 i64 i32 i32 i32)
    global.get 0
    i32.const 48
    i32.sub
    local.tee 3
    global.set 0
    i32.const 39
    local.set 4
    block  ;; label = @1
      block  ;; label = @2
        local.get 0
        i64.const 10000
        i64.ge_u
        br_if 0 (;@2;)
        local.get 0
        local.set 5
        br 1 (;@1;)
      end
      i32.const 39
      local.set 4
      loop  ;; label = @2
        local.get 3
        i32.const 9
        i32.add
        local.get 4
        i32.add
        local.tee 6
        i32.const -4
        i32.add
        local.get 0
        local.get 0
        i64.const 10000
        i64.div_u
        local.tee 5
        i64.const 10000
        i64.mul
        i64.sub
        i32.wrap_i64
        local.tee 7
        i32.const 65535
        i32.and
        i32.const 100
        i32.div_u
        local.tee 8
        i32.const 1
        i32.shl
        i32.const 1050902
        i32.add
        i32.load16_u align=1
        i32.store16 align=1
        local.get 6
        i32.const -2
        i32.add
        local.get 7
        local.get 8
        i32.const 100
        i32.mul
        i32.sub
        i32.const 65535
        i32.and
        i32.const 1
        i32.shl
        i32.const 1050902
        i32.add
        i32.load16_u align=1
        i32.store16 align=1
        local.get 4
        i32.const -4
        i32.add
        local.set 4
        local.get 0
        i64.const 99999999
        i64.gt_u
        local.set 6
        local.get 5
        local.set 0
        local.get 6
        br_if 0 (;@2;)
      end
    end
    block  ;; label = @1
      local.get 5
      i32.wrap_i64
      local.tee 6
      i32.const 99
      i32.le_s
      br_if 0 (;@1;)
      local.get 3
      i32.const 9
      i32.add
      local.get 4
      i32.const -2
      i32.add
      local.tee 4
      i32.add
      local.get 5
      i32.wrap_i64
      local.tee 6
      local.get 6
      i32.const 65535
      i32.and
      i32.const 100
      i32.div_u
      local.tee 6
      i32.const 100
      i32.mul
      i32.sub
      i32.const 65535
      i32.and
      i32.const 1
      i32.shl
      i32.const 1050902
      i32.add
      i32.load16_u align=1
      i32.store16 align=1
    end
    block  ;; label = @1
      block  ;; label = @2
        local.get 6
        i32.const 10
        i32.lt_s
        br_if 0 (;@2;)
        local.get 3
        i32.const 9
        i32.add
        local.get 4
        i32.const -2
        i32.add
        local.tee 4
        i32.add
        local.get 6
        i32.const 1
        i32.shl
        i32.const 1050902
        i32.add
        i32.load16_u align=1
        i32.store16 align=1
        br 1 (;@1;)
      end
      local.get 3
      i32.const 9
      i32.add
      local.get 4
      i32.const -1
      i32.add
      local.tee 4
      i32.add
      local.get 6
      i32.const 48
      i32.add
      i32.store8
    end
    local.get 2
    local.get 1
    i32.const 1050564
    i32.const 0
    local.get 3
    i32.const 9
    i32.add
    local.get 4
    i32.add
    i32.const 39
    local.get 4
    i32.sub
    call $_ZN4core3fmt9Formatter12pad_integral17h445473f2203112d4E
    local.set 4
    local.get 3
    i32.const 48
    i32.add
    global.set 0
    local.get 4)
  (func $_ZN59_$LT$core..fmt..Arguments$u20$as$u20$core..fmt..Display$GT$3fmt17h3ae122dc78887ce1E (type 2) (param i32 i32) (result i32)
    (local i32 i32)
    global.get 0
    i32.const 32
    i32.sub
    local.tee 2
    global.set 0
    local.get 1
    i32.const 28
    i32.add
    i32.load
    local.set 3
    local.get 1
    i32.load offset=24
    local.set 1
    local.get 2
    i32.const 8
    i32.add
    i32.const 16
    i32.add
    local.get 0
    i32.const 16
    i32.add
    i64.load align=4
    i64.store
    local.get 2
    i32.const 8
    i32.add
    i32.const 8
    i32.add
    local.get 0
    i32.const 8
    i32.add
    i64.load align=4
    i64.store
    local.get 2
    local.get 0
    i64.load align=4
    i64.store offset=8
    local.get 1
    local.get 3
    local.get 2
    i32.const 8
    i32.add
    call $_ZN4core3fmt5write17hd3aab830518de99fE
    local.set 0
    local.get 2
    i32.const 32
    i32.add
    global.set 0
    local.get 0)
  (func $_ZN4core3fmt9Formatter12pad_integral17h445473f2203112d4E (type 19) (param i32 i32 i32 i32 i32 i32) (result i32)
    (local i32 i32 i32 i32 i32)
    block  ;; label = @1
      block  ;; label = @2
        local.get 1
        i32.eqz
        br_if 0 (;@2;)
        i32.const 43
        i32.const 1114112
        local.get 0
        i32.load
        local.tee 6
        i32.const 1
        i32.and
        local.tee 1
        select
        local.set 7
        local.get 1
        local.get 5
        i32.add
        local.set 8
        br 1 (;@1;)
      end
      local.get 5
      i32.const 1
      i32.add
      local.set 8
      local.get 0
      i32.load
      local.set 6
      i32.const 45
      local.set 7
    end
    block  ;; label = @1
      block  ;; label = @2
        local.get 6
        i32.const 4
        i32.and
        br_if 0 (;@2;)
        i32.const 0
        local.set 2
        br 1 (;@1;)
      end
      i32.const 0
      local.set 9
      block  ;; label = @2
        local.get 3
        i32.eqz
        br_if 0 (;@2;)
        local.get 3
        local.set 10
        local.get 2
        local.set 1
        loop  ;; label = @3
          local.get 9
          local.get 1
          i32.load8_u
          i32.const 192
          i32.and
          i32.const 128
          i32.eq
          i32.add
          local.set 9
          local.get 1
          i32.const 1
          i32.add
          local.set 1
          local.get 10
          i32.const -1
          i32.add
          local.tee 10
          br_if 0 (;@3;)
        end
      end
      local.get 8
      local.get 3
      i32.add
      local.get 9
      i32.sub
      local.set 8
    end
    i32.const 1
    local.set 1
    block  ;; label = @1
      block  ;; label = @2
        local.get 0
        i32.load offset=8
        i32.const 1
        i32.eq
        br_if 0 (;@2;)
        local.get 0
        local.get 7
        local.get 2
        local.get 3
        call $_ZN4core3fmt9Formatter12pad_integral12write_prefix17hcc05e8c16b96dca0E
        br_if 1 (;@1;)
        local.get 0
        i32.load offset=24
        local.get 4
        local.get 5
        local.get 0
        i32.const 28
        i32.add
        i32.load
        i32.load offset=12
        call_indirect (type 1)
        return
      end
      block  ;; label = @2
        local.get 0
        i32.const 12
        i32.add
        i32.load
        local.tee 9
        local.get 8
        i32.gt_u
        br_if 0 (;@2;)
        local.get 0
        local.get 7
        local.get 2
        local.get 3
        call $_ZN4core3fmt9Formatter12pad_integral12write_prefix17hcc05e8c16b96dca0E
        br_if 1 (;@1;)
        local.get 0
        i32.load offset=24
        local.get 4
        local.get 5
        local.get 0
        i32.const 28
        i32.add
        i32.load
        i32.load offset=12
        call_indirect (type 1)
        return
      end
      block  ;; label = @2
        block  ;; label = @3
          local.get 6
          i32.const 8
          i32.and
          br_if 0 (;@3;)
          local.get 9
          local.get 8
          i32.sub
          local.set 9
          i32.const 0
          local.set 1
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                i32.const 1
                local.get 0
                i32.load8_u offset=48
                local.tee 10
                local.get 10
                i32.const 3
                i32.eq
                select
                br_table 2 (;@4;) 0 (;@6;) 1 (;@5;) 0 (;@6;) 2 (;@4;)
              end
              local.get 9
              local.set 1
              i32.const 0
              local.set 9
              br 1 (;@4;)
            end
            local.get 9
            i32.const 1
            i32.shr_u
            local.set 1
            local.get 9
            i32.const 1
            i32.add
            i32.const 1
            i32.shr_u
            local.set 9
          end
          local.get 1
          i32.const 1
          i32.add
          local.set 1
          loop  ;; label = @4
            local.get 1
            i32.const -1
            i32.add
            local.tee 1
            i32.eqz
            br_if 2 (;@2;)
            local.get 0
            i32.load offset=24
            local.get 0
            i32.load offset=4
            local.get 0
            i32.load offset=28
            i32.load offset=16
            call_indirect (type 2)
            i32.eqz
            br_if 0 (;@4;)
          end
          i32.const 1
          return
        end
        i32.const 1
        local.set 1
        local.get 0
        i32.const 1
        i32.store8 offset=48
        local.get 0
        i32.const 48
        i32.store offset=4
        local.get 0
        local.get 7
        local.get 2
        local.get 3
        call $_ZN4core3fmt9Formatter12pad_integral12write_prefix17hcc05e8c16b96dca0E
        br_if 1 (;@1;)
        local.get 9
        local.get 8
        i32.sub
        local.set 9
        i32.const 0
        local.set 1
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              i32.const 1
              local.get 0
              i32.load8_u offset=48
              local.tee 10
              local.get 10
              i32.const 3
              i32.eq
              select
              br_table 2 (;@3;) 0 (;@5;) 1 (;@4;) 0 (;@5;) 2 (;@3;)
            end
            local.get 9
            local.set 1
            i32.const 0
            local.set 9
            br 1 (;@3;)
          end
          local.get 9
          i32.const 1
          i32.shr_u
          local.set 1
          local.get 9
          i32.const 1
          i32.add
          i32.const 1
          i32.shr_u
          local.set 9
        end
        local.get 1
        i32.const 1
        i32.add
        local.set 1
        block  ;; label = @3
          loop  ;; label = @4
            local.get 1
            i32.const -1
            i32.add
            local.tee 1
            i32.eqz
            br_if 1 (;@3;)
            local.get 0
            i32.load offset=24
            local.get 0
            i32.load offset=4
            local.get 0
            i32.load offset=28
            i32.load offset=16
            call_indirect (type 2)
            i32.eqz
            br_if 0 (;@4;)
          end
          i32.const 1
          return
        end
        local.get 0
        i32.load offset=4
        local.set 10
        i32.const 1
        local.set 1
        local.get 0
        i32.load offset=24
        local.get 4
        local.get 5
        local.get 0
        i32.load offset=28
        i32.load offset=12
        call_indirect (type 1)
        br_if 1 (;@1;)
        local.get 9
        i32.const 1
        i32.add
        local.set 9
        local.get 0
        i32.load offset=28
        local.set 3
        local.get 0
        i32.load offset=24
        local.set 0
        loop  ;; label = @3
          block  ;; label = @4
            local.get 9
            i32.const -1
            i32.add
            local.tee 9
            br_if 0 (;@4;)
            i32.const 0
            return
          end
          i32.const 1
          local.set 1
          local.get 0
          local.get 10
          local.get 3
          i32.load offset=16
          call_indirect (type 2)
          i32.eqz
          br_if 0 (;@3;)
          br 2 (;@1;)
        end
      end
      local.get 0
      i32.load offset=4
      local.set 10
      i32.const 1
      local.set 1
      local.get 0
      local.get 7
      local.get 2
      local.get 3
      call $_ZN4core3fmt9Formatter12pad_integral12write_prefix17hcc05e8c16b96dca0E
      br_if 0 (;@1;)
      local.get 0
      i32.load offset=24
      local.get 4
      local.get 5
      local.get 0
      i32.load offset=28
      i32.load offset=12
      call_indirect (type 1)
      br_if 0 (;@1;)
      local.get 9
      i32.const 1
      i32.add
      local.set 9
      local.get 0
      i32.load offset=28
      local.set 3
      local.get 0
      i32.load offset=24
      local.set 0
      loop  ;; label = @2
        block  ;; label = @3
          local.get 9
          i32.const -1
          i32.add
          local.tee 9
          br_if 0 (;@3;)
          i32.const 0
          return
        end
        i32.const 1
        local.set 1
        local.get 0
        local.get 10
        local.get 3
        i32.load offset=16
        call_indirect (type 2)
        i32.eqz
        br_if 0 (;@2;)
      end
    end
    local.get 1)
  (func $_ZN4core3fmt9Formatter12pad_integral12write_prefix17hcc05e8c16b96dca0E (type 9) (param i32 i32 i32 i32) (result i32)
    (local i32)
    block  ;; label = @1
      block  ;; label = @2
        local.get 1
        i32.const 1114112
        i32.eq
        br_if 0 (;@2;)
        i32.const 1
        local.set 4
        local.get 0
        i32.load offset=24
        local.get 1
        local.get 0
        i32.const 28
        i32.add
        i32.load
        i32.load offset=16
        call_indirect (type 2)
        br_if 1 (;@1;)
      end
      block  ;; label = @2
        local.get 2
        br_if 0 (;@2;)
        i32.const 0
        return
      end
      local.get 0
      i32.load offset=24
      local.get 2
      local.get 3
      local.get 0
      i32.const 28
      i32.add
      i32.load
      i32.load offset=12
      call_indirect (type 1)
      local.set 4
    end
    local.get 4)
  (func $_ZN4core3fmt9Formatter15debug_lower_hex17h793eb06599a6f4afE (type 6) (param i32) (result i32)
    local.get 0
    i32.load8_u
    i32.const 16
    i32.and
    i32.const 4
    i32.shr_u)
  (func $_ZN4core3fmt9Formatter15debug_upper_hex17h04e91d8eabf032bdE (type 6) (param i32) (result i32)
    local.get 0
    i32.load8_u
    i32.const 32
    i32.and
    i32.const 5
    i32.shr_u)
  (func $_ZN4core3fmt3num53_$LT$impl$u20$core..fmt..LowerHex$u20$for$u20$i32$GT$3fmt17h8ac32090674e93f6E (type 2) (param i32 i32) (result i32)
    (local i32 i32 i32)
    global.get 0
    i32.const 128
    i32.sub
    local.tee 2
    global.set 0
    local.get 0
    i32.load
    local.set 3
    i32.const 0
    local.set 0
    loop  ;; label = @1
      local.get 2
      local.get 0
      i32.add
      i32.const 127
      i32.add
      local.get 3
      i32.const 15
      i32.and
      local.tee 4
      i32.const 48
      i32.or
      local.get 4
      i32.const 87
      i32.add
      local.get 4
      i32.const 10
      i32.lt_u
      select
      i32.store8
      local.get 0
      i32.const -1
      i32.add
      local.set 0
      local.get 3
      i32.const 4
      i32.shr_u
      local.tee 3
      br_if 0 (;@1;)
    end
    block  ;; label = @1
      local.get 0
      i32.const 128
      i32.add
      local.tee 3
      i32.const 129
      i32.lt_u
      br_if 0 (;@1;)
      local.get 3
      i32.const 128
      call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
      unreachable
    end
    local.get 1
    i32.const 1
    i32.const 1050900
    i32.const 2
    local.get 2
    local.get 0
    i32.add
    i32.const 128
    i32.add
    i32.const 0
    local.get 0
    i32.sub
    call $_ZN4core3fmt9Formatter12pad_integral17h445473f2203112d4E
    local.set 0
    local.get 2
    i32.const 128
    i32.add
    global.set 0
    local.get 0)
  (func $_ZN4core3fmt3num53_$LT$impl$u20$core..fmt..UpperHex$u20$for$u20$i32$GT$3fmt17hfd1f5de01f0dfb51E (type 2) (param i32 i32) (result i32)
    (local i32 i32 i32)
    global.get 0
    i32.const 128
    i32.sub
    local.tee 2
    global.set 0
    local.get 0
    i32.load
    local.set 3
    i32.const 0
    local.set 0
    loop  ;; label = @1
      local.get 2
      local.get 0
      i32.add
      i32.const 127
      i32.add
      local.get 3
      i32.const 15
      i32.and
      local.tee 4
      i32.const 48
      i32.or
      local.get 4
      i32.const 55
      i32.add
      local.get 4
      i32.const 10
      i32.lt_u
      select
      i32.store8
      local.get 0
      i32.const -1
      i32.add
      local.set 0
      local.get 3
      i32.const 4
      i32.shr_u
      local.tee 3
      br_if 0 (;@1;)
    end
    block  ;; label = @1
      local.get 0
      i32.const 128
      i32.add
      local.tee 3
      i32.const 129
      i32.lt_u
      br_if 0 (;@1;)
      local.get 3
      i32.const 128
      call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
      unreachable
    end
    local.get 1
    i32.const 1
    i32.const 1050900
    i32.const 2
    local.get 2
    local.get 0
    i32.add
    i32.const 128
    i32.add
    i32.const 0
    local.get 0
    i32.sub
    call $_ZN4core3fmt9Formatter12pad_integral17h445473f2203112d4E
    local.set 0
    local.get 2
    i32.const 128
    i32.add
    global.set 0
    local.get 0)
  (func $memset (type 1) (param i32 i32 i32) (result i32)
    (local i32)
    block  ;; label = @1
      local.get 2
      i32.eqz
      br_if 0 (;@1;)
      local.get 0
      local.set 3
      loop  ;; label = @2
        local.get 3
        local.get 1
        i32.store8
        local.get 3
        i32.const 1
        i32.add
        local.set 3
        local.get 2
        i32.const -1
        i32.add
        local.tee 2
        br_if 0 (;@2;)
      end
    end
    local.get 0)
  (func $memcpy (type 1) (param i32 i32 i32) (result i32)
    (local i32)
    block  ;; label = @1
      local.get 2
      i32.eqz
      br_if 0 (;@1;)
      local.get 0
      local.set 3
      loop  ;; label = @2
        local.get 3
        local.get 1
        i32.load8_u
        i32.store8
        local.get 3
        i32.const 1
        i32.add
        local.set 3
        local.get 1
        i32.const 1
        i32.add
        local.set 1
        local.get 2
        i32.const -1
        i32.add
        local.tee 2
        br_if 0 (;@2;)
      end
    end
    local.get 0)
  (func $memmove (type 1) (param i32 i32 i32) (result i32)
    (local i32)
    block  ;; label = @1
      block  ;; label = @2
        local.get 1
        local.get 0
        i32.lt_u
        br_if 0 (;@2;)
        local.get 2
        i32.eqz
        br_if 1 (;@1;)
        local.get 0
        local.set 3
        loop  ;; label = @3
          local.get 3
          local.get 1
          i32.load8_u
          i32.store8
          local.get 1
          i32.const 1
          i32.add
          local.set 1
          local.get 3
          i32.const 1
          i32.add
          local.set 3
          local.get 2
          i32.const -1
          i32.add
          local.tee 2
          br_if 0 (;@3;)
          br 2 (;@1;)
        end
      end
      local.get 2
      i32.eqz
      br_if 0 (;@1;)
      local.get 1
      i32.const -1
      i32.add
      local.set 1
      local.get 0
      i32.const -1
      i32.add
      local.set 3
      loop  ;; label = @2
        local.get 3
        local.get 2
        i32.add
        local.get 1
        local.get 2
        i32.add
        i32.load8_u
        i32.store8
        local.get 2
        i32.const -1
        i32.add
        local.tee 2
        br_if 0 (;@2;)
      end
    end
    local.get 0)
  (func $memcmp (type 1) (param i32 i32 i32) (result i32)
    (local i32 i32 i32)
    i32.const 0
    local.set 3
    block  ;; label = @1
      local.get 2
      i32.eqz
      br_if 0 (;@1;)
      block  ;; label = @2
        loop  ;; label = @3
          local.get 0
          i32.load8_u
          local.tee 4
          local.get 1
          i32.load8_u
          local.tee 5
          i32.ne
          br_if 1 (;@2;)
          local.get 1
          i32.const 1
          i32.add
          local.set 1
          local.get 0
          i32.const 1
          i32.add
          local.set 0
          local.get 2
          i32.const -1
          i32.add
          local.tee 2
          i32.eqz
          br_if 2 (;@1;)
          br 0 (;@3;)
        end
      end
      local.get 4
      local.get 5
      i32.sub
      local.set 3
    end
    local.get 3)
  (table (;0;) 32 32 funcref)
  (memory (;0;) 17)
  (global (;0;) (mut i32) (i32.const 1048576))
  (export "memory" (memory 0))
  (export "__av_read_obj" (func $__av_read_obj))
  (export "__av_malloc" (func $__av_malloc))
  (export "__av_sized_ptr" (func $__av_sized_ptr))
  (export "__av_free" (func $__av_free))
  (export "__av_typeof" (func $__av_typeof))
  (export "__av_as_bool" (func $__av_as_bool))
  (export "__av_add" (func $__av_add))
  (export "__av_sub" (func $__av_sub))
  (export "__av_mul" (func $__av_mul))
  (export "__av_div" (func $__av_div))
  (export "__av_and" (func $__av_and))
  (export "__av_or" (func $__av_or))
  (export "__av_not" (func $__av_not))
  (export "__av_gt" (func $__av_gt))
  (export "__av_gte" (func $__av_gte))
  (export "__av_lt" (func $__av_lt))
  (export "__av_lte" (func $__av_lte))
  (export "__av_save" (func $__av_save))
  (export "__av_get" (func $__av_get))
  (export "__av_inject" (func $__av_inject))
  (export "__av_run" (func $__av_run))
  (elem (;0;) (i32.const 1) $_ZN4core3ptr18real_drop_in_place17h690b672ae349c00bE $_ZN91_$LT$std..panicking..begin_panic..PanicPayload$LT$A$GT$$u20$as$u20$core..panic..BoxMeUp$GT$9box_me_up17hf4417af5be5a3cf6E $_ZN91_$LT$std..panicking..begin_panic..PanicPayload$LT$A$GT$$u20$as$u20$core..panic..BoxMeUp$GT$3get17h4f9c9343a6dec52cE $_ZN4core3ptr18real_drop_in_place17hbcf1f7ed4038b54aE $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17h44bc4801beac1581E $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17hd27c2a1ed228407aE $_ZN59_$LT$core..fmt..Arguments$u20$as$u20$core..fmt..Display$GT$3fmt17h3ae122dc78887ce1E $_ZN42_$LT$$RF$T$u20$as$u20$core..fmt..Debug$GT$3fmt17h85084fb3be4df7b2E $_ZN42_$LT$$RF$T$u20$as$u20$core..fmt..Debug$GT$3fmt17ha7817e91bf95d0d2E $_ZN4core3ptr18real_drop_in_place17h01dc3ff363e02a2aE $_ZN91_$LT$std..panicking..begin_panic..PanicPayload$LT$A$GT$$u20$as$u20$core..panic..BoxMeUp$GT$9box_me_up17h27e7c64f2151a277E $_ZN91_$LT$std..panicking..begin_panic..PanicPayload$LT$A$GT$$u20$as$u20$core..panic..BoxMeUp$GT$3get17hce68feec1b34af62E $_ZN4core3ptr18real_drop_in_place17h18af938be9857b46E $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17hee077d8ebd6c8808E $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17h62254d034ac8f094E $_ZN3std5alloc24default_alloc_error_hook17h7e3753373bf77437E $_ZN76_$LT$std..sys_common..thread_local..Key$u20$as$u20$core..ops..drop..Drop$GT$4drop17ha98b17b5e613edf7E $_ZN50_$LT$$RF$mut$u20$W$u20$as$u20$core..fmt..Write$GT$9write_str17h72d3f0de1e233110E $_ZN50_$LT$$RF$mut$u20$W$u20$as$u20$core..fmt..Write$GT$10write_char17h01c83a182d3c68a2E $_ZN50_$LT$$RF$mut$u20$W$u20$as$u20$core..fmt..Write$GT$9write_fmt17ha18d073f4bdaf9caE $_ZN4core3ptr18real_drop_in_place17h194e86810a2d41bcE $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17hba0a1a7ef3521e31E $_ZN4core3ptr18real_drop_in_place17ha9e5ebb6b6afa0f2E $_ZN89_$LT$std..panicking..continue_panic_fmt..PanicPayload$u20$as$u20$core..panic..BoxMeUp$GT$9box_me_up17hb40334927d95d13bE $_ZN89_$LT$std..panicking..continue_panic_fmt..PanicPayload$u20$as$u20$core..panic..BoxMeUp$GT$3get17h4b595ece533c7d31E $_ZN4core3ptr18real_drop_in_place17h1e18bed522b4a4cdE $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17h1ffa740b2640435fE $_ZN4core3fmt3num3imp52_$LT$impl$u20$core..fmt..Display$u20$for$u20$u32$GT$3fmt17h1c0bcbdea3856b66E $_ZN4core3fmt10ArgumentV110show_usize17h854a277e0a6571caE $_ZN4core3ptr18real_drop_in_place17he09fc700ab5b0ef3E $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17h453c6ffd565494afE)
  (data (;0;) (i32.const 1048576) "Tried to shrink to a larger capacitysrc/liballoc/raw_vec.rs\00\00\00\10\00$\00\00\00$\00\10\00\17\00\00\00@\02\00\00\09\00\00\00\01\00\00\00\08\00\00\00\04\00\00\00\02\00\00\00\03\00\00\00\04\00\00\00\00\00\00\00\01\00\00\00\05\00\00\00\01\00\00\00\08\00\00\00\04\00\00\00\06\00\00\00hello\00\00\00avs/src/memory.rs\00\00\00\90\00\10\00\11\00\00\00 \00\00\00\0a\00\00\00/home/cobalt/.cargo/registry/src/github.com-1ecc6299db9ec823/flatbuffers-0.6.0/src/builder.rs\00\00\00\b4\00\10\00]\00\00\00O\02\00\00\09\00\00\00cannot grow buffer beyond 2 gigabytessrc/libcore/slice/mod.rsassertion failed: mid <= len\00\00\00a\01\10\00\1c\00\00\00I\01\10\00\18\00\00\00\df\03\00\00\0d\00\00\00/cargo/registry/src/github.com-1ecc6299db9ec823/hashbrown-0.4.0/src/raw/mod.rsHash table capacity overflow\00\00\e6\01\10\00\1c\00\00\00\98\01\10\00N\00\00\00N\00\00\00(\00\00\00\ff\ff\ff\ffsrc/libcore/slice/mod.rsassertion failed: `(left == right)`\0a  left: ``,\0a right: ``: 8\02\10\00-\00\00\00e\02\10\00\0c\00\00\00q\02\10\00\03\00\00\00destination and source slices have different lengths\8c\02\10\004\00\00\00 \02\10\00\18\00\00\00>\08\00\00\09\00\00\00/home/cobalt/.cargo/registry/src/github.com-1ecc6299db9ec823/flatbuffers-0.6.0/src/builder.rs\00\00\00\d8\02\10\00]\00\00\00O\02\00\00\09\00\00\00cannot grow buffer beyond 2 gigabytessrc/libcore/slice/mod.rsassertion failed: mid <= len\00\00\00\85\03\10\00\1c\00\00\00m\03\10\00\18\00\00\00\df\03\00\00\0d\00\00\00Hello ArevelSpringavs/src/lib.rs\ce\03\10\00\0e\00\00\00}\00\00\00\0e\00\00\00/home/cobalt/.cargo/registry/src/github.com-1ecc6299db9ec823/flatbuffers-0.6.0/src/builder.rs\00\00\00\ec\03\10\00]\00\00\00O\02\00\00\09\00\00\00cannot grow buffer beyond 2 gigabytessrc/libcore/slice/mod.rsassertion failed: mid <= len\00\00\00\99\04\10\00\1c\00\00\00\81\04\10\00\18\00\00\00\df\03\00\00\0d\00\00\00src/libcore/slice/mod.rsassertion failed: mid <= len\e8\04\10\00\1c\00\00\00\d0\04\10\00\18\00\00\00\df\03\00\00\0d\00\00\00/home/cobalt/.cargo/registry/src/github.com-1ecc6299db9ec823/flatbuffers-0.6.0/src/builder.rs\00\00\00\1c\05\10\00]\00\00\00G\00\00\00\09\00\00\00cannot initialize buffer bigger than 2 gigabytes\1c\05\10\00]\00\00\00O\02\00\00\09\00\00\00cannot grow buffer beyond 2 gigabytesassertion failed: `(left == right)`\0a  left: ``,\0a right: ``: \00\00\00\f1\05\10\00-\00\00\00\1e\06\10\00\0c\00\00\00*\06\10\00\03\00\00\00destination and source slices have different lengthsH\06\10\004\00\00\00src/libcore/slice/mod.rs\84\06\10\00\18\00\00\00>\08\00\00\09\00\00\00\0a\00\00\00\08\00\00\00\04\00\00\00\0b\00\00\00\0c\00\00\00\0d\00\00\00\00\00\00\00\01\00\00\00\0e\00\00\00\0a\00\00\00\08\00\00\00\04\00\00\00\0f\00\00\00\11\00\00\00\04\00\00\00\04\00\00\00\12\00\00\00\13\00\00\00\14\00\00\00\15\00\00\00\00\00\00\00\01\00\00\00\16\00\00\00called `Option::unwrap()` on a `None` valuesrc/libcore/option.rs\08\07\10\00+\00\00\003\07\10\00\15\00\00\00z\01\00\00\15\00\00\00\17\00\00\00\10\00\00\00\04\00\00\00\18\00\00\00\19\00\00\00\1a\00\00\00\0c\00\00\00\04\00\00\00\1b\00\00\00src/liballoc/raw_vec.rscapacity overflow\9b\07\10\00\11\00\00\00\84\07\10\00\17\00\00\00\ec\02\00\00\05\00\00\00\1e\00\00\00\00\00\00\00\01\00\00\00\1f\00\00\00index out of bounds: the len is  but the index is \00\00\d4\07\10\00 \00\00\00\f4\07\10\00\12\00\00\00called `Option::unwrap()` on a `None` valuesrc/libcore/option.rs\18\08\10\00+\00\00\00C\08\10\00\15\00\00\00z\01\00\00\15\00\00\00src/libcore/slice/mod.rsindex  out of range for slice of length \88\08\10\00\06\00\00\00\8e\08\10\00\22\00\00\00p\08\10\00\18\00\00\00\fb\09\00\00\05\00\00\00slice index starts at  but ends at \00\d0\08\10\00\16\00\00\00\e6\08\10\00\0d\00\00\00p\08\10\00\18\00\00\00\01\0a\00\00\05\00\00\000x00010203040506070809101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899\00\00src/libcore/fmt/mod.rs\00\00\e0\09\10\00\16\00\00\00H\04\00\00(\00\00\00\e0\09\10\00\16\00\00\00T\04\00\00\11\00\00\00")
  (data (;1;) (i32.const 1051160) "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00"))

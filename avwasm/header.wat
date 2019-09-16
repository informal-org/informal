(module
  (type (;0;) (func (param i32 i32)))
  (type (;1;) (func (param i32 i32 i32) (result i32)))
  (type (;2;) (func (param i32 i32) (result i32)))
  (type (;3;) (func))
  (type (;4;) (func (param i32 i32 i32)))
  (type (;5;) (func (param i32)))
  (type (;6;) (func (param i32) (result i32)))
  (type (;7;) (func (param i32) (result i64)))
  (type (;8;) (func (param i64) (result i32)))
  (type (;9;) (func (param i32 i32 i32 i32) (result i32)))
  (type (;10;) (func (param i32 i32 i64 i32)))
  (type (;11;) (func (param i32 i64 i64) (result i64)))
  (type (;12;) (func (param i32 i64) (result i64)))
  (type (;13;) (func (param i32 i32 i32 i32)))
  (type (;14;) (func (param i32 i64 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)))
  (type (;15;) (func (param i32 i64) (result i32)))
  (type (;16;) (func (result i32)))
  (type (;17;) (func (param i32 i32 i32 i32 i32)))
  (type (;18;) (func (param i64 i32 i32) (result i32)))
  (type (;19;) (func (param i32 i32 i32 i32 i32 i32) (result i32)))
  (func $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17h356d4b685803bd7bE.llvm.118960385785549565 (type 3)
    call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
    unreachable)
  (func $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$7reserve17h6f10024db8f70c62E (type 4) (param i32 i32 i32)
    (local i32)
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          local.get 0
          i32.const 4
          i32.add
          i32.load
          local.tee 3
          local.get 1
          i32.sub
          local.get 2
          i32.ge_u
          br_if 0 (;@3;)
          local.get 1
          local.get 2
          i32.add
          local.tee 2
          local.get 1
          i32.lt_u
          br_if 2 (;@1;)
          local.get 3
          i32.const 1
          i32.shl
          local.tee 1
          local.get 2
          local.get 2
          local.get 1
          i32.lt_u
          select
          local.tee 1
          i32.const 0
          i32.lt_s
          br_if 2 (;@1;)
          block  ;; label = @4
            block  ;; label = @5
              local.get 3
              br_if 0 (;@5;)
              local.get 1
              i32.const 1
              call $__rust_alloc
              local.set 2
              br 1 (;@4;)
            end
            local.get 0
            i32.load
            local.get 3
            i32.const 1
            local.get 1
            call $__rust_realloc
            local.set 2
          end
          local.get 2
          i32.eqz
          br_if 1 (;@2;)
          local.get 0
          local.get 2
          i32.store
          local.get 0
          i32.const 4
          i32.add
          local.get 1
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
  (func $_ZN5alloc3vec12Vec$LT$T$GT$6resize17ha7e1fd22820a0cf7E (type 4) (param i32 i32 i32)
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
  (func $_ZN3std9panicking11begin_panic17h6f5191b790a90319E (type 4) (param i32 i32 i32)
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
    i32.const 1048660
    i32.const 0
    local.get 2
    call $_ZN3std9panicking20rust_panic_with_hook17h868a29d5aa6e3f6fE
    unreachable)
  (func $_ZN4core3ptr18real_drop_in_place17h690b672ae349c00bE (type 5) (param i32))
  (func $_ZN4core3ptr18real_drop_in_place17hbcf1f7ed4038b54aE (type 5) (param i32))
  (func $_ZN91_$LT$std..panicking..begin_panic..PanicPayload$LT$A$GT$$u20$as$u20$core..panic..BoxMeUp$GT$3get17h4f9c9343a6dec52cE (type 0) (param i32 i32)
    (local i32)
    local.get 0
    i32.const 1048696
    i32.const 1048680
    local.get 1
    i32.load
    local.tee 2
    select
    i32.store offset=4
    local.get 0
    local.get 1
    i32.const 1048680
    local.get 2
    select
    i32.store)
  (func $_ZN91_$LT$std..panicking..begin_panic..PanicPayload$LT$A$GT$$u20$as$u20$core..panic..BoxMeUp$GT$9box_me_up17hf4417af5be5a3cf6E (type 0) (param i32 i32)
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
          i32.const 1048680
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
        i32.const 1048696
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
  (func $__av_read_obj (type 4) (param i32 i32 i32)
    (local i32 i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 3
    global.set 0
    block  ;; label = @1
      i32.const 5
      i32.const 1
      call $__rust_alloc
      local.tee 4
      br_if 0 (;@1;)
      i32.const 5
      i32.const 1
      call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
      unreachable
    end
    local.get 3
    i64.const 5
    i64.store offset=4 align=4
    local.get 3
    local.get 4
    i32.store
    local.get 3
    i32.const 0
    i32.const 5
    call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$7reserve17h6f10024db8f70c62E
    local.get 3
    local.get 3
    i32.load offset=8
    local.tee 4
    i32.const 5
    i32.add
    i32.store offset=8
    local.get 4
    local.get 3
    i32.load
    i32.add
    i32.const 5
    i32.const 1048712
    i32.const 5
    call $_ZN4core5slice29_$LT$impl$u20$$u5b$T$u5d$$GT$15copy_from_slice17h2ac8d46f96f9c8eaE
    local.get 3
    i32.load
    local.set 4
    local.get 0
    local.get 3
    i64.load offset=4 align=4
    i64.store offset=4 align=4
    local.get 0
    local.get 4
    i32.store
    local.get 3
    i32.const 16
    i32.add
    global.set 0)
  (func $__av_malloc (type 6) (param i32) (result i32)
    (local i32 i32 i32 i32 i32 i32 i32)
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                block  ;; label = @7
                  block  ;; label = @8
                    block  ;; label = @9
                      local.get 0
                      i32.const 536870911
                      i32.and
                      local.get 0
                      i32.ne
                      br_if 0 (;@9;)
                      local.get 0
                      i32.const 3
                      i32.shl
                      local.tee 1
                      i32.const -1
                      i32.le_s
                      br_if 1 (;@8;)
                      block  ;; label = @10
                        block  ;; label = @11
                          local.get 1
                          br_if 0 (;@11;)
                          i32.const 8
                          local.set 2
                          br 1 (;@10;)
                        end
                        local.get 1
                        i32.const 8
                        call $__rust_alloc
                        local.tee 2
                        i32.eqz
                        br_if 3 (;@7;)
                      end
                      local.get 0
                      i32.eqz
                      br_if 5 (;@4;)
                      i32.const 0
                      local.set 3
                      i32.const 0
                      local.set 4
                      i32.const 0
                      local.set 5
                      local.get 0
                      local.set 6
                      loop  ;; label = @10
                        local.get 5
                        i32.const 1
                        i32.add
                        local.set 1
                        block  ;; label = @11
                          local.get 5
                          local.get 6
                          i32.ne
                          br_if 0 (;@11;)
                          block  ;; label = @12
                            block  ;; label = @13
                              local.get 4
                              local.get 1
                              local.get 1
                              local.get 4
                              i32.lt_u
                              select
                              local.tee 6
                              i32.const 536870911
                              i32.and
                              local.get 6
                              i32.ne
                              br_if 0 (;@13;)
                              local.get 6
                              i32.const 3
                              i32.shl
                              local.tee 7
                              i32.const 0
                              i32.ge_s
                              br_if 1 (;@12;)
                            end
                            call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
                            unreachable
                          end
                          block  ;; label = @12
                            block  ;; label = @13
                              local.get 5
                              br_if 0 (;@13;)
                              local.get 7
                              i32.const 8
                              call $__rust_alloc
                              local.set 2
                              br 1 (;@12;)
                            end
                            local.get 2
                            local.get 3
                            i32.const 8
                            local.get 7
                            call $__rust_realloc
                            local.set 2
                          end
                          local.get 2
                          i32.eqz
                          br_if 5 (;@6;)
                        end
                        local.get 2
                        local.get 3
                        i32.add
                        i64.const 0
                        i64.store
                        local.get 3
                        i32.const 8
                        i32.add
                        local.set 3
                        local.get 4
                        i32.const 2
                        i32.add
                        local.set 4
                        local.get 1
                        local.set 5
                        local.get 0
                        local.get 1
                        i32.eq
                        br_if 5 (;@5;)
                        br 0 (;@10;)
                      end
                    end
                    call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17h356d4b685803bd7bE.llvm.118960385785549565
                    unreachable
                  end
                  call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17h356d4b685803bd7bE.llvm.118960385785549565
                  unreachable
                end
                local.get 1
                i32.const 8
                call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
                unreachable
              end
              local.get 7
              i32.const 8
              call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
              unreachable
            end
            block  ;; label = @5
              local.get 6
              local.get 0
              i32.eq
              br_if 0 (;@5;)
              local.get 6
              local.get 0
              i32.lt_u
              br_if 2 (;@3;)
              block  ;; label = @6
                local.get 0
                br_if 0 (;@6;)
                local.get 6
                i32.eqz
                br_if 2 (;@4;)
                local.get 2
                local.get 6
                i32.const 3
                i32.shl
                i32.const 8
                call $__rust_dealloc
                br 2 (;@4;)
              end
              local.get 2
              local.get 6
              i32.const 3
              i32.shl
              i32.const 8
              local.get 0
              i32.const 3
              i32.shl
              local.tee 1
              call $__rust_realloc
              local.tee 2
              i32.eqz
              br_if 3 (;@2;)
              br 4 (;@1;)
            end
            local.get 0
            br_if 3 (;@1;)
          end
          i32.const 1048740
          i32.const 0
          i32.const 0
          call $_ZN4core9panicking18panic_bounds_check17hdaf7aa012e2661faE
          unreachable
        end
        i32.const 1048636
        call $_ZN4core9panicking5panic17h1fb303f1c113605dE
        unreachable
      end
      local.get 1
      i32.const 8
      call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
      unreachable
    end
    local.get 2)
  (func $__av_sized_ptr (type 2) (param i32 i32) (result i32)
    (local i32)
    block  ;; label = @1
      block  ;; label = @2
        i32.const 16
        i32.const 4
        call $__rust_alloc
        local.tee 2
        i32.eqz
        br_if 0 (;@2;)
        local.get 2
        local.get 1
        i32.store offset=4
        local.get 2
        local.get 0
        i32.store
        local.get 2
        i32.const 16
        i32.const 4
        i32.const 8
        call $__rust_realloc
        local.tee 2
        i32.eqz
        br_if 1 (;@1;)
        local.get 2
        local.get 1
        i32.store offset=4
        local.get 2
        local.get 0
        i32.store
        local.get 2
        return
      end
      i32.const 16
      i32.const 4
      call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
      unreachable
    end
    i32.const 8
    i32.const 4
    call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
    unreachable)
  (func $__av_free (type 0) (param i32 i32)
    block  ;; label = @1
      local.get 1
      i32.const 3
      i32.shl
      local.tee 1
      i32.eqz
      br_if 0 (;@1;)
      local.get 0
      local.get 1
      i32.const 8
      call $__rust_dealloc
    end)
  (func $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17h44bc4801beac1581E (type 7) (param i32) (result i64)
    i64.const 7549865886324542212)
  (func $_ZN36_$LT$T$u20$as$u20$core..any..Any$GT$7type_id17hd27c2a1ed228407aE (type 7) (param i32) (result i64)
    i64.const 1229646359891580772)
  (func $__av_typeof (type 8) (param i64) (result i32)
    (local i32)
    i32.const 0
    local.set 1
    block  ;; label = @1
      local.get 0
      i64.const -2251799813685248
      i64.lt_u
      br_if 0 (;@1;)
      i32.const 1
      local.set 1
      local.get 0
      i64.const -4222124650659840
      i64.and
      i64.const -4222124650659840
      i64.ne
      br_if 0 (;@1;)
      i32.const 0
      local.set 1
      local.get 0
      i64.const 1970324836974592
      i64.add
      local.tee 0
      i64.const 15
      i64.rotl
      i64.const -9223372036854743041
      i64.and
      i64.const 3
      i64.gt_u
      br_if 0 (;@1;)
      i32.const 50463490
      local.get 0
      i64.const 49
      i64.shr_u
      i32.wrap_i64
      i32.const 3
      i32.shl
      i32.shr_u
      i32.const 255
      i32.and
      return
    end
    local.get 1)
  (func $__av_as_bool (type 8) (param i64) (result i32)
    (local f64)
    local.get 0
    i64.const -3377699720527872
    i64.and
    i64.const -3377699720527872
    i64.eq
    local.get 0
    f64.reinterpret_i64
    local.tee 1
    f64.const 0x0p+0 (;=0;)
    f64.ne
    local.get 1
    local.get 1
    f64.eq
    i32.and
    i32.or)
  (func $_ZN42_$LT$$RF$T$u20$as$u20$core..fmt..Debug$GT$3fmt17h85084fb3be4df7b2E (type 2) (param i32 i32) (result i32)
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
  (func $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E (type 0) (param i32 i32)
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
            i32.store
            local.get 2
            i32.const 96
            i32.add
            global.set 0
            return
          end
          i32.const 1048868
          i32.const 37
          i32.const 1048852
          call $_ZN3std9panicking11begin_panic17h6f5191b790a90319E
          unreachable
        end
        i32.const 1048960
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
  (func $_ZN11flatbuffers7builder17FlatBufferBuilder9push_slot17h27e8cafe53f32fecE (type 4) (param i32 i32 i32)
    (local i32 i32 i32 i32)
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              local.get 2
              i32.eqz
              br_if 0 (;@5;)
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
              call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E
              local.get 0
              i32.const 4
              call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E
              local.get 3
              i32.load
              local.tee 4
              local.get 0
              i32.load offset=12
              local.tee 3
              i32.lt_u
              br_if 1 (;@4;)
              local.get 4
              local.get 3
              i32.sub
              i32.const 3
              i32.le_u
              br_if 2 (;@3;)
              local.get 0
              i32.load
              local.get 3
              i32.add
              local.get 2
              i32.store
              local.get 0
              i32.const 8
              i32.add
              i32.load
              local.set 3
              local.get 0
              i32.load offset=12
              local.set 4
              block  ;; label = @6
                local.get 0
                i32.const 24
                i32.add
                i32.load
                local.tee 2
                local.get 0
                i32.const 20
                i32.add
                i32.load
                i32.ne
                br_if 0 (;@6;)
                local.get 2
                i32.const 1
                i32.add
                local.tee 5
                local.get 2
                i32.lt_u
                br_if 5 (;@1;)
                local.get 2
                i32.const 1
                i32.shl
                local.tee 6
                local.get 5
                local.get 5
                local.get 6
                i32.lt_u
                select
                local.tee 5
                i32.const 536870911
                i32.and
                local.get 5
                i32.ne
                br_if 5 (;@1;)
                local.get 5
                i32.const 3
                i32.shl
                local.tee 6
                i32.const 0
                i32.lt_s
                br_if 5 (;@1;)
                block  ;; label = @7
                  block  ;; label = @8
                    local.get 2
                    br_if 0 (;@8;)
                    local.get 6
                    i32.const 4
                    call $__rust_alloc
                    local.set 2
                    br 1 (;@7;)
                  end
                  local.get 0
                  i32.load offset=16
                  local.get 2
                  i32.const 3
                  i32.shl
                  i32.const 4
                  local.get 6
                  call $__rust_realloc
                  local.set 2
                end
                local.get 2
                i32.eqz
                br_if 4 (;@2;)
                local.get 0
                local.get 2
                i32.store offset=16
                local.get 0
                i32.const 20
                i32.add
                local.get 5
                i32.store
                local.get 0
                i32.load offset=24
                local.set 2
              end
              local.get 0
              i32.load offset=16
              local.get 2
              i32.const 3
              i32.shl
              i32.add
              local.tee 2
              local.get 1
              i32.store16 offset=4
              local.get 2
              local.get 3
              local.get 4
              i32.sub
              i32.store
              local.get 0
              local.get 0
              i32.load offset=24
              i32.const 1
              i32.add
              i32.store offset=24
            end
            return
          end
          local.get 3
          local.get 4
          call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
          unreachable
        end
        i32.const 1048960
        call $_ZN4core9panicking5panic17h1fb303f1c113605dE
        unreachable
      end
      local.get 6
      i32.const 4
      call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
      unreachable
    end
    call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
    unreachable)
  (func $_ZN3avs14avfb_generated4avfb7AvFbObj6create17h38290e305cf5d624E (type 2) (param i32 i32) (result i32)
    (local i32 i32 i32 i32 i32 i32 i32)
    local.get 0
    i32.const 1
    i32.store8 offset=44
    local.get 0
    i32.const 8
    i32.add
    local.tee 2
    i32.load
    local.set 3
    local.get 0
    i32.load offset=12
    local.set 4
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
                          local.get 1
                          i32.load offset=24
                          i32.const 1
                          i32.ne
                          br_if 0 (;@11;)
                          local.get 0
                          local.get 0
                          i32.load offset=40
                          local.tee 5
                          i32.const 4
                          local.get 5
                          i32.const 4
                          i32.gt_u
                          select
                          i32.store offset=40
                          local.get 1
                          i32.const 28
                          i32.add
                          i32.load
                          local.set 5
                          local.get 0
                          local.get 4
                          local.get 3
                          i32.sub
                          i32.const 3
                          i32.and
                          call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E
                          local.get 0
                          i32.const 4
                          call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E
                          local.get 2
                          i32.load
                          local.tee 6
                          local.get 0
                          i32.load offset=12
                          local.tee 2
                          i32.lt_u
                          br_if 1 (;@10;)
                          local.get 6
                          local.get 2
                          i32.sub
                          local.tee 6
                          i32.const 3
                          i32.le_u
                          br_if 2 (;@9;)
                          local.get 0
                          i32.load
                          local.get 2
                          i32.add
                          local.get 6
                          local.get 5
                          i32.sub
                          i32.store
                          local.get 0
                          i32.const 8
                          i32.add
                          i32.load
                          local.set 5
                          local.get 0
                          i32.load offset=12
                          local.set 6
                          block  ;; label = @12
                            local.get 0
                            i32.const 24
                            i32.add
                            i32.load
                            local.tee 2
                            local.get 0
                            i32.const 20
                            i32.add
                            i32.load
                            i32.ne
                            br_if 0 (;@12;)
                            local.get 2
                            i32.const 1
                            i32.add
                            local.tee 7
                            local.get 2
                            i32.lt_u
                            br_if 11 (;@1;)
                            local.get 2
                            i32.const 1
                            i32.shl
                            local.tee 8
                            local.get 7
                            local.get 7
                            local.get 8
                            i32.lt_u
                            select
                            local.tee 7
                            i32.const 536870911
                            i32.and
                            local.get 7
                            i32.ne
                            br_if 11 (;@1;)
                            local.get 7
                            i32.const 3
                            i32.shl
                            local.tee 8
                            i32.const 0
                            i32.lt_s
                            br_if 11 (;@1;)
                            block  ;; label = @13
                              block  ;; label = @14
                                local.get 2
                                br_if 0 (;@14;)
                                local.get 8
                                i32.const 4
                                call $__rust_alloc
                                local.set 2
                                br 1 (;@13;)
                              end
                              local.get 0
                              i32.load offset=16
                              local.get 2
                              i32.const 3
                              i32.shl
                              i32.const 4
                              local.get 8
                              call $__rust_realloc
                              local.set 2
                            end
                            local.get 2
                            i32.eqz
                            br_if 4 (;@8;)
                            local.get 0
                            local.get 2
                            i32.store offset=16
                            local.get 0
                            i32.const 20
                            i32.add
                            local.get 7
                            i32.store
                            local.get 0
                            i32.load offset=24
                            local.set 2
                          end
                          local.get 0
                          i32.load offset=16
                          local.get 2
                          i32.const 3
                          i32.shl
                          i32.add
                          local.tee 2
                          i32.const 12
                          i32.store16 offset=4
                          local.get 2
                          local.get 5
                          local.get 6
                          i32.sub
                          i32.store
                          local.get 0
                          local.get 0
                          i32.load offset=24
                          i32.const 1
                          i32.add
                          i32.store offset=24
                        end
                        block  ;; label = @11
                          local.get 1
                          i32.load offset=16
                          i32.const 1
                          i32.ne
                          br_if 0 (;@11;)
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
                          local.get 1
                          i32.const 20
                          i32.add
                          i32.load
                          local.set 5
                          local.get 0
                          local.get 0
                          i32.load offset=12
                          local.get 0
                          i32.const 8
                          i32.add
                          local.tee 2
                          i32.load
                          i32.sub
                          i32.const 3
                          i32.and
                          call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E
                          local.get 0
                          i32.const 4
                          call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E
                          local.get 2
                          i32.load
                          local.tee 6
                          local.get 0
                          i32.load offset=12
                          local.tee 2
                          i32.lt_u
                          br_if 4 (;@7;)
                          local.get 6
                          local.get 2
                          i32.sub
                          local.tee 6
                          i32.const 3
                          i32.le_u
                          br_if 5 (;@6;)
                          local.get 0
                          i32.load
                          local.get 2
                          i32.add
                          local.get 6
                          local.get 5
                          i32.sub
                          i32.store
                          local.get 0
                          i32.const 8
                          i32.add
                          i32.load
                          local.set 5
                          local.get 0
                          i32.load offset=12
                          local.set 6
                          block  ;; label = @12
                            local.get 0
                            i32.const 24
                            i32.add
                            i32.load
                            local.tee 2
                            local.get 0
                            i32.const 20
                            i32.add
                            i32.load
                            i32.ne
                            br_if 0 (;@12;)
                            local.get 2
                            i32.const 1
                            i32.add
                            local.tee 7
                            local.get 2
                            i32.lt_u
                            br_if 11 (;@1;)
                            local.get 2
                            i32.const 1
                            i32.shl
                            local.tee 8
                            local.get 7
                            local.get 7
                            local.get 8
                            i32.lt_u
                            select
                            local.tee 7
                            i32.const 536870911
                            i32.and
                            local.get 7
                            i32.ne
                            br_if 11 (;@1;)
                            local.get 7
                            i32.const 3
                            i32.shl
                            local.tee 8
                            i32.const 0
                            i32.lt_s
                            br_if 11 (;@1;)
                            block  ;; label = @13
                              block  ;; label = @14
                                local.get 2
                                br_if 0 (;@14;)
                                local.get 8
                                i32.const 4
                                call $__rust_alloc
                                local.set 2
                                br 1 (;@13;)
                              end
                              local.get 0
                              i32.load offset=16
                              local.get 2
                              i32.const 3
                              i32.shl
                              i32.const 4
                              local.get 8
                              call $__rust_realloc
                              local.set 2
                            end
                            local.get 2
                            i32.eqz
                            br_if 7 (;@5;)
                            local.get 0
                            local.get 2
                            i32.store offset=16
                            local.get 0
                            i32.const 20
                            i32.add
                            local.get 7
                            i32.store
                            local.get 0
                            i32.load offset=24
                            local.set 2
                          end
                          local.get 0
                          i32.load offset=16
                          local.get 2
                          i32.const 3
                          i32.shl
                          i32.add
                          local.tee 2
                          i32.const 10
                          i32.store16 offset=4
                          local.get 2
                          local.get 5
                          local.get 6
                          i32.sub
                          i32.store
                          local.get 0
                          local.get 0
                          i32.load offset=24
                          i32.const 1
                          i32.add
                          i32.store offset=24
                        end
                        block  ;; label = @11
                          local.get 1
                          i32.load offset=8
                          i32.const 1
                          i32.ne
                          br_if 0 (;@11;)
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
                          local.get 1
                          i32.const 12
                          i32.add
                          i32.load
                          local.set 5
                          local.get 0
                          local.get 0
                          i32.load offset=12
                          local.get 0
                          i32.const 8
                          i32.add
                          local.tee 2
                          i32.load
                          i32.sub
                          i32.const 3
                          i32.and
                          call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E
                          local.get 0
                          i32.const 4
                          call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E
                          local.get 2
                          i32.load
                          local.tee 6
                          local.get 0
                          i32.load offset=12
                          local.tee 2
                          i32.lt_u
                          br_if 7 (;@4;)
                          local.get 6
                          local.get 2
                          i32.sub
                          local.tee 6
                          i32.const 3
                          i32.le_u
                          br_if 8 (;@3;)
                          local.get 0
                          i32.load
                          local.get 2
                          i32.add
                          local.get 6
                          local.get 5
                          i32.sub
                          i32.store
                          local.get 0
                          i32.const 8
                          i32.add
                          i32.load
                          local.set 5
                          local.get 0
                          i32.load offset=12
                          local.set 6
                          block  ;; label = @12
                            local.get 0
                            i32.const 24
                            i32.add
                            i32.load
                            local.tee 2
                            local.get 0
                            i32.const 20
                            i32.add
                            i32.load
                            i32.ne
                            br_if 0 (;@12;)
                            local.get 2
                            i32.const 1
                            i32.add
                            local.tee 7
                            local.get 2
                            i32.lt_u
                            br_if 11 (;@1;)
                            local.get 2
                            i32.const 1
                            i32.shl
                            local.tee 8
                            local.get 7
                            local.get 7
                            local.get 8
                            i32.lt_u
                            select
                            local.tee 7
                            i32.const 536870911
                            i32.and
                            local.get 7
                            i32.ne
                            br_if 11 (;@1;)
                            local.get 7
                            i32.const 3
                            i32.shl
                            local.tee 8
                            i32.const 0
                            i32.lt_s
                            br_if 11 (;@1;)
                            block  ;; label = @13
                              block  ;; label = @14
                                local.get 2
                                br_if 0 (;@14;)
                                local.get 8
                                i32.const 4
                                call $__rust_alloc
                                local.set 2
                                br 1 (;@13;)
                              end
                              local.get 0
                              i32.load offset=16
                              local.get 2
                              i32.const 3
                              i32.shl
                              i32.const 4
                              local.get 8
                              call $__rust_realloc
                              local.set 2
                            end
                            local.get 2
                            i32.eqz
                            br_if 10 (;@2;)
                            local.get 0
                            local.get 2
                            i32.store offset=16
                            local.get 0
                            i32.const 20
                            i32.add
                            local.get 7
                            i32.store
                            local.get 0
                            i32.load offset=24
                            local.set 2
                          end
                          local.get 0
                          i32.load offset=16
                          local.get 2
                          i32.const 3
                          i32.shl
                          i32.add
                          local.tee 2
                          i32.const 8
                          i32.store16 offset=4
                          local.get 2
                          local.get 5
                          local.get 6
                          i32.sub
                          i32.store
                          local.get 0
                          local.get 0
                          i32.load offset=24
                          i32.const 1
                          i32.add
                          i32.store offset=24
                        end
                        local.get 0
                        i32.const 6
                        local.get 1
                        i32.load offset=4
                        call $_ZN11flatbuffers7builder17FlatBufferBuilder9push_slot17h27e8cafe53f32fecE
                        local.get 0
                        i32.const 4
                        local.get 1
                        i32.load
                        call $_ZN11flatbuffers7builder17FlatBufferBuilder9push_slot17h27e8cafe53f32fecE
                        local.get 0
                        local.get 3
                        local.get 4
                        i32.sub
                        call $_ZN11flatbuffers7builder17FlatBufferBuilder12write_vtable17hcd1f528e78ed5e7eE
                        local.set 1
                        local.get 0
                        i32.const 24
                        i32.add
                        i32.const 0
                        i32.store
                        local.get 0
                        i32.const 0
                        i32.store8 offset=44
                        local.get 1
                        return
                      end
                      local.get 2
                      local.get 6
                      call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
                      unreachable
                    end
                    i32.const 1048960
                    call $_ZN4core9panicking5panic17h1fb303f1c113605dE
                    unreachable
                  end
                  local.get 8
                  i32.const 4
                  call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
                  unreachable
                end
                local.get 2
                local.get 6
                call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
                unreachable
              end
              i32.const 1048960
              call $_ZN4core9panicking5panic17h1fb303f1c113605dE
              unreachable
            end
            local.get 8
            i32.const 4
            call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
            unreachable
          end
          local.get 2
          local.get 6
          call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
          unreachable
        end
        i32.const 1048960
        call $_ZN4core9panicking5panic17h1fb303f1c113605dE
        unreachable
      end
      local.get 8
      i32.const 4
      call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
      unreachable
    end
    call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
    unreachable)
  (func $_ZN72_$LT$hashbrown..raw..RawTable$LT$T$GT$$u20$as$u20$core..clone..Clone$GT$5clone17habb655206efa7990E (type 0) (param i32 i32)
    (local i32 i32 i32 i64 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i64 i32 i32 i32 i32 i64 i32 i32)
    global.get 0
    i32.const 32
    i32.sub
    local.tee 2
    global.set 0
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                block  ;; label = @7
                  block  ;; label = @8
                    local.get 1
                    i32.load
                    local.tee 3
                    i32.eqz
                    br_if 0 (;@8;)
                    local.get 3
                    i32.const 1
                    i32.add
                    local.tee 4
                    i64.extend_i32_u
                    i64.const 48
                    i64.mul
                    local.tee 5
                    i64.const 32
                    i64.shr_u
                    i32.wrap_i64
                    br_if 1 (;@7;)
                    local.get 3
                    i32.const 12
                    i32.add
                    i32.const -8
                    i32.and
                    local.tee 6
                    local.get 3
                    i32.const 5
                    i32.add
                    local.tee 7
                    i32.lt_u
                    br_if 1 (;@7;)
                    local.get 6
                    local.get 5
                    i32.wrap_i64
                    i32.add
                    local.tee 8
                    local.get 6
                    i32.lt_u
                    br_if 1 (;@7;)
                    local.get 8
                    i32.const -7
                    i32.ge_u
                    br_if 1 (;@7;)
                    local.get 8
                    i32.const 8
                    call $__rust_alloc
                    local.tee 9
                    i32.eqz
                    br_if 2 (;@6;)
                    local.get 9
                    local.get 1
                    i32.const 4
                    i32.add
                    i32.load
                    local.tee 8
                    local.get 7
                    call $memcpy
                    local.tee 10
                    local.get 6
                    i32.add
                    local.set 11
                    local.get 8
                    i32.const 4
                    i32.add
                    local.set 6
                    local.get 8
                    local.get 4
                    i32.add
                    local.set 7
                    local.get 8
                    i32.load
                    i32.const -1
                    i32.xor
                    i32.const -2139062144
                    i32.and
                    local.set 12
                    local.get 1
                    i32.load offset=16
                    local.set 13
                    local.get 1
                    i32.const 8
                    i32.add
                    i32.load
                    local.tee 14
                    local.set 8
                    loop  ;; label = @9
                      block  ;; label = @10
                        local.get 12
                        br_if 0 (;@10;)
                        loop  ;; label = @11
                          local.get 6
                          local.get 7
                          i32.ge_u
                          br_if 6 (;@5;)
                          local.get 8
                          i32.const 192
                          i32.add
                          local.set 8
                          local.get 6
                          i32.load
                          local.set 4
                          local.get 6
                          i32.const 4
                          i32.add
                          local.tee 9
                          local.set 6
                          local.get 4
                          i32.const -2139062144
                          i32.and
                          local.tee 4
                          i32.const -2139062144
                          i32.eq
                          br_if 0 (;@11;)
                        end
                        local.get 4
                        i32.const -2139062144
                        i32.xor
                        local.set 12
                        local.get 9
                        local.set 6
                      end
                      local.get 8
                      local.get 12
                      i32.ctz
                      i32.const 3
                      i32.shr_u
                      i32.const 48
                      i32.mul
                      i32.add
                      local.tee 4
                      i32.const 8
                      i32.add
                      local.set 15
                      local.get 4
                      local.get 14
                      i32.sub
                      i32.const 48
                      i32.div_s
                      local.set 9
                      local.get 4
                      i64.load
                      local.set 5
                      block  ;; label = @10
                        block  ;; label = @11
                          block  ;; label = @12
                            block  ;; label = @13
                              block  ;; label = @14
                                block  ;; label = @15
                                  block  ;; label = @16
                                    local.get 4
                                    i32.load offset=8
                                    br_table 0 (;@16;) 1 (;@15;) 2 (;@14;) 3 (;@13;) 4 (;@12;) 5 (;@11;) 0 (;@16;)
                                  end
                                  local.get 4
                                  i64.load offset=16
                                  local.tee 16
                                  i32.wrap_i64
                                  local.set 17
                                  local.get 16
                                  i64.const 32
                                  i64.shr_u
                                  i32.wrap_i64
                                  local.set 18
                                  i32.const 0
                                  local.set 19
                                  br 5 (;@10;)
                                end
                                local.get 2
                                i32.const 8
                                i32.add
                                local.get 15
                                i32.const 4
                                i32.add
                                call $_ZN60_$LT$alloc..string..String$u20$as$u20$core..clone..Clone$GT$5clone17hcaceec0319ee7974E
                                local.get 2
                                i32.load offset=16
                                local.set 18
                                local.get 2
                                i32.load offset=12
                                local.set 17
                                local.get 2
                                i32.load offset=8
                                local.set 20
                                i32.const 1
                                local.set 19
                                br 4 (;@10;)
                              end
                              local.get 4
                              i32.const 20
                              i32.add
                              i32.load
                              local.set 18
                              local.get 4
                              i32.load offset=16
                              local.set 17
                              i32.const 2
                              local.set 19
                              br 3 (;@10;)
                            end
                            local.get 4
                            i64.load offset=24
                            local.set 21
                            local.get 4
                            i64.load offset=16
                            local.set 16
                            block  ;; label = @13
                              block  ;; label = @14
                                local.get 4
                                i32.load offset=32
                                local.tee 18
                                br_if 0 (;@14;)
                                i32.const 0
                                local.set 22
                                br 1 (;@13;)
                              end
                              local.get 4
                              i32.load offset=40
                              local.tee 23
                              i32.const 536870911
                              i32.and
                              local.get 23
                              i32.ne
                              br_if 9 (;@4;)
                              local.get 23
                              i32.const 3
                              i32.shl
                              local.tee 4
                              i32.const -1
                              i32.le_s
                              br_if 10 (;@3;)
                              block  ;; label = @14
                                block  ;; label = @15
                                  local.get 4
                                  br_if 0 (;@15;)
                                  i32.const 8
                                  local.set 22
                                  br 1 (;@14;)
                                end
                                local.get 4
                                i32.const 8
                                call $__rust_alloc
                                local.tee 22
                                i32.eqz
                                br_if 12 (;@2;)
                              end
                              local.get 22
                              local.get 23
                              local.get 18
                              local.get 23
                              call $_ZN4core5slice29_$LT$impl$u20$$u5b$T$u5d$$GT$15copy_from_slice17h66a985877caaf92eE
                            end
                            local.get 16
                            i64.const 32
                            i64.shr_u
                            i32.wrap_i64
                            local.set 18
                            local.get 16
                            i32.wrap_i64
                            local.set 17
                            i32.const 3
                            local.set 19
                            br 2 (;@10;)
                          end
                          i32.const 4
                          local.set 19
                          local.get 2
                          i32.const 8
                          i32.add
                          local.get 15
                          i32.const 4
                          i32.add
                          call $_ZN72_$LT$hashbrown..raw..RawTable$LT$T$GT$$u20$as$u20$core..clone..Clone$GT$5clone17habb655206efa7990E
                          local.get 2
                          i64.load offset=20 align=4
                          local.set 21
                          local.get 2
                          i32.load offset=16
                          local.set 18
                          local.get 2
                          i32.load offset=12
                          local.set 17
                          local.get 2
                          i32.load offset=8
                          local.set 20
                          br 1 (;@10;)
                        end
                        local.get 4
                        i32.const 16
                        i32.add
                        i32.load
                        local.set 17
                        local.get 15
                        i32.load offset=4
                        local.set 20
                        i32.const 5
                        local.set 19
                      end
                      local.get 12
                      i32.const -1
                      i32.add
                      local.get 12
                      i32.and
                      local.set 12
                      local.get 11
                      local.get 9
                      i32.const 48
                      i32.mul
                      i32.add
                      local.tee 4
                      local.get 5
                      i64.store
                      local.get 4
                      local.get 20
                      i32.store offset=12
                      local.get 4
                      local.get 18
                      i32.store offset=20
                      local.get 4
                      local.get 19
                      i32.store offset=8
                      local.get 4
                      local.get 17
                      i32.store offset=16
                      local.get 4
                      local.get 23
                      i32.store offset=40
                      local.get 4
                      local.get 22
                      i32.store offset=32
                      local.get 4
                      local.get 21
                      i64.store offset=24
                      local.get 4
                      i32.const 36
                      i32.add
                      local.get 23
                      i32.store
                      br 0 (;@9;)
                    end
                  end
                  local.get 0
                  i32.const 8
                  i32.store offset=8
                  local.get 0
                  i32.const 1049116
                  i32.store offset=4
                  i32.const 0
                  local.set 6
                  local.get 0
                  i32.const 0
                  i32.store
                  i32.const 0
                  local.set 13
                  br 6 (;@1;)
                end
                i32.const 1049092
                call $_ZN4core9panicking5panic17h1fb303f1c113605dE
                unreachable
              end
              local.get 8
              i32.const 8
              call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
              unreachable
            end
            local.get 0
            local.get 11
            i32.store offset=8
            local.get 0
            local.get 10
            i32.store offset=4
            local.get 0
            local.get 3
            i32.store
            local.get 1
            i32.load offset=12
            local.set 6
            br 3 (;@1;)
          end
          call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17h356d4b685803bd7bE.llvm.118960385785549565
          unreachable
        end
        call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17h356d4b685803bd7bE.llvm.118960385785549565
        unreachable
      end
      local.get 4
      i32.const 8
      call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
      unreachable
    end
    local.get 0
    local.get 13
    i32.store offset=16
    local.get 0
    local.get 6
    i32.store offset=12
    local.get 2
    i32.const 32
    i32.add
    global.set 0)
  (func $_ZN9hashbrown3raw17RawTable$LT$T$GT$17try_with_capacity17h3bd2fba12b9433f7E.llvm.10704638106819740323 (type 4) (param i32 i32 i32)
    (local i32 i64 i32 i32 i32 i32)
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              local.get 1
              i32.eqz
              br_if 0 (;@5;)
              local.get 1
              i32.const 8
              i32.lt_u
              br_if 2 (;@3;)
              block  ;; label = @6
                local.get 1
                i32.const 536870911
                i32.and
                local.get 1
                i32.ne
                br_if 0 (;@6;)
                local.get 1
                i32.const 3
                i32.shl
                i32.const 7
                i32.div_u
                local.set 1
                br 4 (;@2;)
              end
              local.get 2
              i32.eqz
              br_if 1 (;@4;)
              i32.const 1049092
              call $_ZN4core9panicking5panic17h1fb303f1c113605dE
              unreachable
            end
            local.get 0
            i32.const 20
            i32.add
            i32.const 0
            i32.store
            local.get 0
            i32.const 12
            i32.add
            i64.const 8
            i64.store align=4
            local.get 0
            i32.const 8
            i32.add
            i32.const 1049116
            i32.store
            local.get 0
            i32.const 4
            i32.add
            i32.const 0
            i32.store
            local.get 0
            i32.const 0
            i32.store8
            return
          end
          local.get 0
          i32.const 0
          i32.store8 offset=1
          br 2 (;@1;)
        end
        local.get 1
        i32.const 1
        i32.add
        local.set 1
      end
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            i32.const -1
            local.get 1
            i32.const -1
            i32.add
            i32.clz
            i32.shr_u
            local.tee 1
            i32.const 1
            i32.add
            local.tee 3
            i64.extend_i32_u
            i64.const 48
            i64.mul
            local.tee 4
            i64.const 32
            i64.shr_u
            i32.wrap_i64
            br_if 0 (;@4;)
            local.get 1
            i32.const 12
            i32.add
            i32.const -8
            i32.and
            local.tee 5
            local.get 1
            i32.const 5
            i32.add
            local.tee 6
            i32.lt_u
            br_if 0 (;@4;)
            local.get 5
            local.get 4
            i32.wrap_i64
            i32.add
            local.tee 7
            local.get 5
            i32.lt_u
            br_if 0 (;@4;)
            local.get 7
            i32.const -7
            i32.lt_u
            br_if 1 (;@3;)
          end
          i32.const 0
          local.set 1
          local.get 2
          i32.eqz
          br_if 1 (;@2;)
          i32.const 1049092
          call $_ZN4core9panicking5panic17h1fb303f1c113605dE
          unreachable
        end
        block  ;; label = @3
          local.get 7
          i32.const 8
          call $__rust_alloc
          local.tee 8
          br_if 0 (;@3;)
          i32.const 1
          local.set 1
          local.get 2
          i32.eqz
          br_if 1 (;@2;)
          local.get 7
          i32.const 8
          call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
          unreachable
        end
        local.get 8
        i32.const 255
        local.get 6
        call $memset
        local.set 2
        local.get 0
        i32.const 20
        i32.add
        i32.const 0
        i32.store
        local.get 0
        i32.const 12
        i32.add
        local.get 2
        local.get 5
        i32.add
        i32.store
        local.get 0
        i32.const 8
        i32.add
        local.get 2
        i32.store
        local.get 0
        i32.const 4
        i32.add
        local.get 1
        i32.store
        local.get 0
        i32.const 16
        i32.add
        local.get 1
        local.get 3
        i32.const 3
        i32.shr_u
        i32.const 7
        i32.mul
        local.get 1
        i32.const 8
        i32.lt_u
        select
        i32.store
        local.get 0
        i32.const 0
        i32.store8
        return
      end
      local.get 0
      local.get 1
      i32.store8 offset=1
    end
    local.get 0
    i32.const 1
    i32.store8)
  (func $_ZN9hashbrown3raw17RawTable$LT$T$GT$14reserve_rehash17ha147baa928635926E (type 9) (param i32 i32 i32 i32) (result i32)
    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i64 i32 i64 i64 i64)
    global.get 0
    i32.const 64
    i32.sub
    local.tee 4
    global.set 0
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                local.get 0
                i32.load offset=16
                local.tee 5
                local.get 1
                i32.add
                local.tee 1
                local.get 5
                i32.ge_u
                br_if 0 (;@6;)
                local.get 3
                br_if 1 (;@5;)
              end
              i32.const 0
              local.set 6
              local.get 1
              local.get 5
              i32.lt_u
              br_if 4 (;@1;)
              local.get 0
              i32.load
              local.tee 5
              local.set 6
              block  ;; label = @6
                local.get 5
                i32.const 8
                i32.lt_u
                br_if 0 (;@6;)
                local.get 5
                i32.const 1
                i32.add
                i32.const 3
                i32.shr_u
                i32.const 7
                i32.mul
                local.set 6
              end
              block  ;; label = @6
                local.get 1
                local.get 6
                i32.const 1
                i32.shr_u
                i32.lt_u
                br_if 0 (;@6;)
                local.get 4
                i32.const 40
                i32.add
                local.get 1
                local.get 3
                call $_ZN9hashbrown3raw17RawTable$LT$T$GT$17try_with_capacity17h3bd2fba12b9433f7E.llvm.10704638106819740323
                local.get 4
                i32.load8_u offset=40
                i32.const 1
                i32.eq
                br_if 2 (;@4;)
                local.get 4
                i32.const 40
                i32.add
                i32.const 16
                i32.add
                i32.load
                local.set 7
                local.get 4
                i32.const 52
                i32.add
                i32.load
                local.set 8
                local.get 4
                i32.const 40
                i32.add
                i32.const 8
                i32.add
                i32.load
                local.set 3
                local.get 4
                i32.load offset=44
                local.set 9
                local.get 0
                i32.load offset=4
                local.tee 5
                i32.const 4
                i32.add
                local.set 10
                local.get 0
                i32.load
                local.get 5
                i32.add
                i32.const 1
                i32.add
                local.set 11
                local.get 5
                i32.load
                i32.const -1
                i32.xor
                i32.const -2139062144
                i32.and
                local.set 12
                local.get 0
                i32.load offset=8
                local.set 13
                local.get 0
                i32.load offset=16
                local.set 14
                block  ;; label = @7
                  loop  ;; label = @8
                    block  ;; label = @9
                      local.get 12
                      br_if 0 (;@9;)
                      loop  ;; label = @10
                        local.get 10
                        local.get 11
                        i32.ge_u
                        br_if 3 (;@7;)
                        local.get 13
                        i32.const 192
                        i32.add
                        local.set 13
                        local.get 10
                        i32.load
                        local.set 5
                        local.get 10
                        i32.const 4
                        i32.add
                        local.tee 1
                        local.set 10
                        local.get 5
                        i32.const -2139062144
                        i32.and
                        local.tee 5
                        i32.const -2139062144
                        i32.eq
                        br_if 0 (;@10;)
                      end
                      local.get 5
                      i32.const -2139062144
                      i32.xor
                      local.set 12
                      local.get 1
                      local.set 10
                    end
                    local.get 13
                    local.get 12
                    i32.ctz
                    i32.const 3
                    i32.shr_u
                    i32.const 48
                    i32.mul
                    i32.add
                    local.tee 15
                    i64.load
                    local.tee 16
                    i64.const 255
                    i64.and
                    i64.const -3750763034362895579
                    i64.xor
                    i64.const 1099511628211
                    i64.mul
                    local.get 16
                    i64.const 8
                    i64.shr_u
                    i64.const 255
                    i64.and
                    i64.xor
                    i64.const 1099511628211
                    i64.mul
                    local.get 16
                    i64.const 16
                    i64.shr_u
                    i64.const 255
                    i64.and
                    i64.xor
                    i64.const 1099511628211
                    i64.mul
                    local.get 16
                    i64.const 24
                    i64.shr_u
                    i64.const 255
                    i64.and
                    i64.xor
                    i64.const 1099511628211
                    i64.mul
                    local.get 16
                    i64.const 32
                    i64.shr_u
                    i64.const 255
                    i64.and
                    i64.xor
                    i64.const 1099511628211
                    i64.mul
                    local.get 16
                    i64.const 40
                    i64.shr_u
                    i64.const 255
                    i64.and
                    i64.xor
                    i64.const 1099511628211
                    i64.mul
                    local.get 16
                    i64.const 48
                    i64.shr_u
                    i64.const 255
                    i64.and
                    i64.xor
                    i64.const 1099511628211
                    i64.mul
                    local.get 16
                    i64.const 56
                    i64.shr_u
                    i64.xor
                    i64.const 1099511628211
                    i64.mul
                    local.tee 16
                    i32.wrap_i64
                    local.set 5
                    i32.const 0
                    local.set 1
                    loop  ;; label = @9
                      local.get 1
                      i32.const 4
                      i32.add
                      local.tee 1
                      local.get 5
                      local.get 9
                      i32.and
                      local.tee 6
                      i32.add
                      local.set 5
                      local.get 3
                      local.get 6
                      i32.add
                      i32.load align=1
                      i32.const -2139062144
                      i32.and
                      local.tee 17
                      i32.eqz
                      br_if 0 (;@9;)
                    end
                    local.get 12
                    i32.const -1
                    i32.add
                    local.set 1
                    block  ;; label = @9
                      local.get 3
                      local.get 17
                      i32.ctz
                      i32.const 3
                      i32.shr_u
                      local.get 6
                      i32.add
                      local.get 9
                      i32.and
                      local.tee 5
                      i32.add
                      i32.load8_s
                      i32.const 0
                      i32.lt_s
                      br_if 0 (;@9;)
                      local.get 3
                      i32.load
                      i32.const -2139062144
                      i32.and
                      i32.ctz
                      i32.const 3
                      i32.shr_u
                      local.set 5
                    end
                    local.get 1
                    local.get 12
                    i32.and
                    local.set 12
                    local.get 3
                    local.get 5
                    i32.add
                    local.get 16
                    i32.wrap_i64
                    i32.const 25
                    i32.shr_u
                    local.tee 1
                    i32.store8
                    local.get 5
                    i32.const -4
                    i32.add
                    local.get 9
                    i32.and
                    local.get 3
                    i32.add
                    i32.const 4
                    i32.add
                    local.get 1
                    i32.store8
                    local.get 8
                    local.get 5
                    i32.const 48
                    i32.mul
                    i32.add
                    local.tee 5
                    i32.const 40
                    i32.add
                    local.get 15
                    i32.const 40
                    i32.add
                    i64.load
                    i64.store
                    local.get 5
                    i32.const 32
                    i32.add
                    local.get 15
                    i32.const 32
                    i32.add
                    i64.load
                    i64.store
                    local.get 5
                    i32.const 24
                    i32.add
                    local.get 15
                    i32.const 24
                    i32.add
                    i64.load
                    i64.store
                    local.get 5
                    i32.const 16
                    i32.add
                    local.get 15
                    i32.const 16
                    i32.add
                    i64.load
                    i64.store
                    local.get 5
                    i32.const 8
                    i32.add
                    local.get 15
                    i32.const 8
                    i32.add
                    i64.load
                    i64.store
                    local.get 5
                    local.get 15
                    i64.load
                    i64.store
                    br 0 (;@8;)
                  end
                end
                local.get 0
                local.get 14
                i32.store offset=16
                local.get 0
                local.get 8
                i32.store offset=8
                local.get 0
                local.get 7
                local.get 14
                i32.sub
                i32.store offset=12
                local.get 0
                i32.load offset=4
                local.set 1
                local.get 0
                local.get 3
                i32.store offset=4
                local.get 0
                i32.load
                local.set 5
                local.get 0
                local.get 9
                i32.store
                i32.const 2
                local.set 6
                local.get 5
                i32.eqz
                br_if 5 (;@1;)
                i32.const 0
                local.set 3
                block  ;; label = @7
                  local.get 5
                  i32.const 1
                  i32.add
                  i64.extend_i32_u
                  i64.const 48
                  i64.mul
                  local.tee 16
                  i64.const 32
                  i64.shr_u
                  i32.wrap_i64
                  i32.eqz
                  br_if 0 (;@7;)
                  local.get 1
                  i32.const 0
                  i32.const 0
                  call $__rust_dealloc
                  br 6 (;@1;)
                end
                block  ;; label = @7
                  local.get 5
                  i32.const 12
                  i32.add
                  i32.const -8
                  i32.and
                  local.tee 17
                  local.get 5
                  i32.const 5
                  i32.add
                  i32.lt_u
                  br_if 0 (;@7;)
                  i32.const 0
                  local.get 17
                  local.get 16
                  i32.wrap_i64
                  i32.add
                  local.tee 9
                  i32.const -7
                  i32.lt_u
                  i32.const 3
                  i32.shl
                  local.get 9
                  local.get 17
                  i32.lt_u
                  select
                  local.set 3
                end
                local.get 1
                local.get 9
                local.get 3
                call $__rust_dealloc
                br 5 (;@1;)
              end
              local.get 5
              i32.const 1
              i32.add
              local.set 6
              i32.const 0
              local.set 1
              i32.const 0
              local.set 5
              block  ;; label = @6
                loop  ;; label = @7
                  block  ;; label = @8
                    block  ;; label = @9
                      local.get 1
                      i32.const 1
                      i32.and
                      br_if 0 (;@9;)
                      local.get 5
                      local.get 6
                      i32.ge_u
                      br_if 3 (;@6;)
                      local.get 5
                      local.set 1
                      local.get 5
                      i32.const 1
                      i32.add
                      local.set 5
                      br 1 (;@8;)
                    end
                    local.get 5
                    i32.const 3
                    i32.add
                    local.tee 1
                    local.get 5
                    i32.lt_u
                    local.tee 3
                    br_if 2 (;@6;)
                    local.get 1
                    local.get 6
                    i32.lt_u
                    local.tee 9
                    i32.eqz
                    br_if 2 (;@6;)
                    local.get 6
                    local.get 5
                    i32.const 4
                    i32.add
                    local.get 3
                    select
                    local.get 6
                    local.get 9
                    select
                    local.set 5
                  end
                  local.get 0
                  i32.const 4
                  i32.add
                  i32.load
                  local.get 1
                  i32.add
                  local.tee 1
                  local.get 1
                  i32.load
                  local.tee 1
                  i32.const 7
                  i32.shr_u
                  i32.const -1
                  i32.xor
                  i32.const 16843009
                  i32.and
                  local.get 1
                  i32.const 2139062143
                  i32.or
                  i32.add
                  i32.store
                  i32.const 1
                  local.set 1
                  br 0 (;@7;)
                end
              end
              local.get 0
              i32.const 4
              i32.add
              i32.load
              local.set 5
              local.get 0
              i32.load
              i32.const 1
              i32.add
              local.tee 1
              i32.const 4
              i32.ge_u
              br_if 2 (;@3;)
              local.get 5
              i32.const 4
              i32.add
              local.get 5
              local.get 1
              call $memmove
              drop
              br 3 (;@2;)
            end
            i32.const 1049092
            call $_ZN4core9panicking5panic17h1fb303f1c113605dE
            unreachable
          end
          local.get 4
          i32.load8_u offset=41
          local.set 6
          br 2 (;@1;)
        end
        local.get 5
        local.get 1
        i32.add
        local.get 5
        i32.load align=1
        i32.store align=1
      end
      i32.const -1
      local.set 5
      block  ;; label = @2
        block  ;; label = @3
          local.get 0
          i32.load
          local.tee 1
          i32.const 1
          i32.add
          local.tee 11
          local.get 1
          i32.lt_u
          br_if 0 (;@3;)
          local.get 0
          i32.const 4
          i32.add
          local.set 15
          local.get 0
          i32.const 8
          i32.add
          local.set 8
          i32.const 0
          local.set 13
          loop  ;; label = @4
            local.get 13
            local.tee 10
            i32.const 1
            i32.add
            local.set 13
            block  ;; label = @5
              local.get 10
              local.get 15
              i32.load
              local.tee 3
              i32.add
              i32.load8_u
              i32.const 128
              i32.ne
              br_if 0 (;@5;)
              block  ;; label = @6
                loop  ;; label = @7
                  local.get 0
                  i32.load
                  local.set 9
                  i32.const 0
                  local.set 5
                  local.get 8
                  i32.load
                  local.get 10
                  i32.const 48
                  i32.mul
                  i32.add
                  local.tee 14
                  i64.load
                  local.tee 16
                  i64.const 255
                  i64.and
                  i64.const -3750763034362895579
                  i64.xor
                  i64.const 1099511628211
                  i64.mul
                  local.get 16
                  i64.const 8
                  i64.shr_u
                  i64.const 255
                  i64.and
                  i64.xor
                  i64.const 1099511628211
                  i64.mul
                  local.get 16
                  i64.const 16
                  i64.shr_u
                  i64.const 255
                  i64.and
                  i64.xor
                  i64.const 1099511628211
                  i64.mul
                  local.get 16
                  i64.const 24
                  i64.shr_u
                  i64.const 255
                  i64.and
                  i64.xor
                  i64.const 1099511628211
                  i64.mul
                  local.get 16
                  i64.const 32
                  i64.shr_u
                  i64.const 255
                  i64.and
                  i64.xor
                  i64.const 1099511628211
                  i64.mul
                  local.get 16
                  i64.const 40
                  i64.shr_u
                  i64.const 255
                  i64.and
                  i64.xor
                  i64.const 1099511628211
                  i64.mul
                  local.get 16
                  i64.const 48
                  i64.shr_u
                  i64.const 255
                  i64.and
                  i64.xor
                  i64.const 1099511628211
                  i64.mul
                  local.get 16
                  i64.const 56
                  i64.shr_u
                  i64.xor
                  i64.const 1099511628211
                  i64.mul
                  local.tee 16
                  i32.wrap_i64
                  local.tee 12
                  local.set 1
                  loop  ;; label = @8
                    local.get 5
                    i32.const 4
                    i32.add
                    local.tee 5
                    local.get 1
                    local.get 9
                    i32.and
                    local.tee 6
                    i32.add
                    local.set 1
                    local.get 3
                    local.get 6
                    i32.add
                    i32.load align=1
                    i32.const -2139062144
                    i32.and
                    local.tee 17
                    i32.eqz
                    br_if 0 (;@8;)
                  end
                  block  ;; label = @8
                    local.get 3
                    local.get 17
                    i32.ctz
                    i32.const 3
                    i32.shr_u
                    local.get 6
                    i32.add
                    local.get 9
                    i32.and
                    local.tee 5
                    i32.add
                    i32.load8_s
                    i32.const 0
                    i32.lt_s
                    br_if 0 (;@8;)
                    local.get 3
                    i32.load
                    i32.const -2139062144
                    i32.and
                    i32.ctz
                    i32.const 3
                    i32.shr_u
                    local.set 5
                  end
                  local.get 5
                  local.get 9
                  local.get 12
                  i32.and
                  local.tee 1
                  i32.sub
                  local.get 10
                  local.get 1
                  i32.sub
                  i32.xor
                  local.get 9
                  i32.and
                  i32.const 4
                  i32.lt_u
                  br_if 1 (;@6;)
                  local.get 3
                  local.get 5
                  i32.add
                  local.tee 1
                  i32.load8_u
                  local.set 6
                  local.get 1
                  local.get 16
                  i32.wrap_i64
                  i32.const 25
                  i32.shr_u
                  local.tee 17
                  i32.store8
                  local.get 5
                  i32.const -4
                  i32.add
                  local.get 9
                  i32.and
                  local.get 3
                  i32.add
                  i32.const 4
                  i32.add
                  local.get 17
                  i32.store8
                  block  ;; label = @8
                    local.get 6
                    i32.const 255
                    i32.eq
                    br_if 0 (;@8;)
                    local.get 8
                    i32.load
                    local.get 5
                    i32.const 48
                    i32.mul
                    i32.add
                    local.tee 5
                    i64.load
                    local.set 16
                    local.get 5
                    local.get 14
                    i64.load
                    i64.store
                    local.get 5
                    i32.const 24
                    i32.add
                    local.tee 1
                    i64.load
                    local.set 18
                    local.get 1
                    local.get 14
                    i32.const 24
                    i32.add
                    local.tee 6
                    i64.load
                    i64.store
                    local.get 5
                    i32.const 16
                    i32.add
                    local.tee 1
                    i64.load
                    local.set 19
                    local.get 1
                    local.get 14
                    i32.const 16
                    i32.add
                    local.tee 3
                    i64.load
                    i64.store
                    local.get 5
                    i32.const 8
                    i32.add
                    local.tee 1
                    i64.load
                    local.set 20
                    local.get 1
                    local.get 14
                    i32.const 8
                    i32.add
                    local.tee 9
                    i64.load
                    i64.store
                    local.get 9
                    local.get 20
                    i64.store
                    local.get 3
                    local.get 19
                    i64.store
                    local.get 6
                    local.get 18
                    i64.store
                    local.get 14
                    local.get 16
                    i64.store
                    local.get 5
                    i32.const 40
                    i32.add
                    local.tee 1
                    i64.load align=4
                    local.set 16
                    local.get 1
                    local.get 14
                    i32.const 40
                    i32.add
                    local.tee 6
                    i64.load align=4
                    i64.store align=4
                    local.get 5
                    i64.load offset=32 align=4
                    local.set 18
                    local.get 5
                    local.get 14
                    i64.load offset=32 align=4
                    i64.store offset=32 align=4
                    local.get 14
                    local.get 18
                    i64.store offset=32 align=4
                    local.get 6
                    local.get 16
                    i64.store align=4
                    local.get 15
                    i32.load
                    local.set 3
                    br 1 (;@7;)
                  end
                end
                local.get 15
                i32.load
                local.tee 1
                local.get 10
                i32.add
                i32.const 255
                i32.store8
                local.get 1
                local.get 0
                i32.load
                local.get 10
                i32.const -4
                i32.add
                i32.and
                i32.add
                i32.const 4
                i32.add
                i32.const 255
                i32.store8
                local.get 8
                i32.load
                local.get 5
                i32.const 48
                i32.mul
                i32.add
                local.tee 5
                local.get 14
                i64.load
                i64.store
                local.get 5
                i32.const 8
                i32.add
                local.get 14
                i32.const 8
                i32.add
                i64.load
                i64.store
                local.get 5
                i32.const 16
                i32.add
                local.get 14
                i32.const 16
                i32.add
                i64.load
                i64.store
                local.get 5
                i32.const 24
                i32.add
                local.get 14
                i32.const 24
                i32.add
                i64.load
                i64.store
                local.get 5
                i32.const 32
                i32.add
                local.get 14
                i32.const 32
                i32.add
                i64.load
                i64.store
                local.get 5
                i32.const 40
                i32.add
                local.get 14
                i32.const 40
                i32.add
                i64.load
                i64.store
                br 1 (;@5;)
              end
              local.get 3
              local.get 10
              i32.add
              local.get 16
              i32.wrap_i64
              i32.const 25
              i32.shr_u
              local.tee 5
              i32.store8
              local.get 9
              local.get 10
              i32.const -4
              i32.add
              i32.and
              local.get 3
              i32.add
              i32.const 4
              i32.add
              local.get 5
              i32.store8
            end
            local.get 13
            local.get 11
            i32.ne
            br_if 0 (;@4;)
          end
          local.get 0
          i32.load
          local.tee 5
          i32.const 8
          i32.lt_u
          br_if 1 (;@2;)
        end
        local.get 5
        i32.const 1
        i32.add
        i32.const 3
        i32.shr_u
        i32.const 7
        i32.mul
        local.set 5
      end
      local.get 0
      local.get 5
      local.get 0
      i32.load offset=16
      i32.sub
      i32.store offset=12
      i32.const 2
      local.set 6
    end
    local.get 4
    i32.const 64
    i32.add
    global.set 0
    local.get 6)
  (func $_ZN3std11collections4hash3map24HashMap$LT$K$C$V$C$S$GT$3get17h5e2dfe0c5e2017b2E.llvm.16168865174730590251 (type 2) (param i32 i32) (result i32)
    (local i64 i32 i32 i32 i32 i32 i32 i32 i32)
    local.get 1
    i64.load
    local.tee 2
    i64.const 255
    i64.and
    i64.const -3750763034362895579
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 8
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 16
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 24
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 32
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 40
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 48
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 56
    i64.shr_u
    i64.xor
    i32.wrap_i64
    i32.const 435
    i32.mul
    local.tee 1
    i32.const 25
    i32.shr_u
    local.tee 3
    i32.const 8
    i32.shl
    local.get 3
    i32.or
    local.tee 3
    i32.const 16
    i32.shl
    local.get 3
    i32.or
    local.set 4
    local.get 0
    i32.load
    local.tee 5
    local.get 1
    i32.and
    local.set 1
    local.get 0
    i32.const 8
    i32.add
    i32.load
    local.set 6
    local.get 0
    i32.const 4
    i32.add
    i32.load
    local.set 7
    i32.const 0
    local.set 3
    block  ;; label = @1
      loop  ;; label = @2
        local.get 7
        local.get 1
        i32.add
        i32.load align=1
        local.tee 8
        local.get 4
        i32.xor
        local.tee 0
        i32.const -1
        i32.xor
        local.get 0
        i32.const -16843009
        i32.add
        i32.and
        i32.const -2139062144
        i32.and
        local.set 0
        local.get 3
        i32.const 4
        i32.add
        local.tee 3
        local.get 1
        i32.add
        local.get 5
        i32.and
        local.set 9
        loop  ;; label = @3
          block  ;; label = @4
            local.get 0
            br_if 0 (;@4;)
            i32.const 0
            local.set 0
            local.get 9
            local.set 1
            local.get 8
            local.get 8
            i32.const 1
            i32.shl
            i32.and
            i32.const -2139062144
            i32.and
            i32.eqz
            br_if 2 (;@2;)
            br 3 (;@1;)
          end
          local.get 0
          i32.ctz
          local.set 10
          local.get 0
          i32.const -1
          i32.add
          local.get 0
          i32.and
          local.set 0
          local.get 2
          local.get 6
          local.get 10
          i32.const 3
          i32.shr_u
          local.get 1
          i32.add
          local.get 5
          i32.and
          local.tee 10
          i32.const 48
          i32.mul
          i32.add
          i64.load
          i64.ne
          br_if 0 (;@3;)
        end
      end
      local.get 6
      local.get 10
      i32.const 48
      i32.mul
      i32.add
      i32.const 8
      i32.add
      local.set 0
    end
    local.get 0)
  (func $_ZN3std11collections4hash3map24HashMap$LT$K$C$V$C$S$GT$6insert17h7ea479b26ececd8eE.llvm.16168865174730590251 (type 10) (param i32 i32 i64 i32)
    (local i32 i64 i32 i32 i32 i64 i32 i32 i64 i64 i64 i64 i32 i32 i32 i32 i32 i32 i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 4
    global.set 0
    local.get 2
    i64.const 255
    i64.and
    i64.const -3750763034362895579
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 8
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 16
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 24
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 32
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 40
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 48
    i64.shr_u
    i64.const 255
    i64.and
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.get 2
    i64.const 56
    i64.shr_u
    i64.xor
    i64.const 1099511628211
    i64.mul
    local.tee 5
    i64.const 25
    i64.shr_u
    i32.wrap_i64
    local.tee 6
    i32.const 127
    i32.and
    local.tee 7
    i32.const 8
    i32.shl
    local.get 7
    i32.or
    local.tee 7
    i32.const 16
    i32.shl
    local.get 7
    i32.or
    local.set 8
    local.get 3
    i32.const 24
    i32.add
    i64.load
    local.set 9
    local.get 1
    i32.const 8
    i32.add
    i32.load
    local.set 10
    local.get 1
    i32.const 4
    i32.add
    i32.load
    local.set 11
    local.get 3
    i32.const 32
    i32.add
    i64.load
    local.set 12
    local.get 3
    i64.load offset=16
    local.set 13
    local.get 3
    i64.load offset=8
    local.set 14
    local.get 3
    i64.load
    local.set 15
    i32.const 0
    local.set 16
    local.get 1
    i32.load
    local.tee 7
    local.get 5
    i32.wrap_i64
    local.tee 17
    i32.and
    local.tee 18
    local.set 19
    block  ;; label = @1
      loop  ;; label = @2
        local.get 11
        local.get 19
        i32.add
        i32.load align=1
        local.tee 20
        local.get 8
        i32.xor
        local.tee 3
        i32.const -1
        i32.xor
        local.get 3
        i32.const -16843009
        i32.add
        i32.and
        i32.const -2139062144
        i32.and
        local.set 3
        local.get 16
        i32.const 4
        i32.add
        local.tee 16
        local.get 19
        i32.add
        local.get 7
        i32.and
        local.set 21
        loop  ;; label = @3
          block  ;; label = @4
            local.get 3
            br_if 0 (;@4;)
            local.get 21
            local.set 19
            local.get 20
            local.get 20
            i32.const 1
            i32.shl
            i32.and
            i32.const -2139062144
            i32.and
            i32.eqz
            br_if 2 (;@2;)
            local.get 4
            local.get 1
            i32.store offset=12
            block  ;; label = @5
              local.get 1
              i32.load offset=12
              br_if 0 (;@5;)
              local.get 1
              i32.const 1
              local.get 4
              i32.const 12
              i32.add
              i32.const 1
              call $_ZN9hashbrown3raw17RawTable$LT$T$GT$14reserve_rehash17ha147baa928635926E
              drop
              local.get 1
              i32.load
              local.tee 7
              local.get 17
              i32.and
              local.set 18
              local.get 1
              i32.const 4
              i32.add
              i32.load
              local.set 11
            end
            i32.const 4
            local.set 3
            loop  ;; label = @5
              local.get 18
              local.tee 19
              local.get 3
              i32.add
              local.get 7
              i32.and
              local.set 18
              local.get 3
              i32.const 4
              i32.add
              local.set 3
              local.get 11
              local.get 19
              i32.add
              i32.load align=1
              i32.const -2139062144
              i32.and
              local.tee 16
              i32.eqz
              br_if 0 (;@5;)
            end
            block  ;; label = @5
              local.get 11
              local.get 16
              i32.ctz
              i32.const 3
              i32.shr_u
              local.get 19
              i32.add
              local.get 7
              i32.and
              local.tee 3
              i32.add
              i32.load8_s
              local.tee 19
              i32.const 0
              i32.lt_s
              br_if 0 (;@5;)
              local.get 11
              local.get 11
              i32.load
              i32.const -2139062144
              i32.and
              i32.ctz
              i32.const 3
              i32.shr_u
              local.tee 3
              i32.add
              i32.load8_u
              local.set 19
            end
            local.get 1
            local.get 1
            i32.load offset=12
            local.get 19
            i32.const 1
            i32.and
            i32.sub
            i32.store offset=12
            local.get 1
            i32.const 8
            i32.add
            i32.load
            local.set 19
            local.get 11
            local.get 3
            i32.add
            local.get 6
            i32.const 127
            i32.and
            local.tee 18
            i32.store8
            local.get 3
            i32.const -4
            i32.add
            local.get 7
            i32.and
            local.get 11
            i32.add
            i32.const 4
            i32.add
            local.get 18
            i32.store8
            local.get 19
            local.get 3
            i32.const 48
            i32.mul
            i32.add
            local.tee 3
            i32.const 32
            i32.add
            local.get 9
            i64.store
            local.get 3
            i32.const 24
            i32.add
            local.get 13
            i64.store
            local.get 3
            i32.const 16
            i32.add
            local.get 14
            i64.store
            local.get 3
            local.get 15
            i64.store offset=8
            local.get 3
            local.get 12
            i64.store offset=40
            local.get 3
            local.get 2
            i64.store
            local.get 0
            i32.const 6
            i32.store
            local.get 1
            local.get 1
            i32.load offset=16
            i32.const 1
            i32.add
            i32.store offset=16
            br 3 (;@1;)
          end
          local.get 3
          i32.ctz
          local.set 22
          local.get 3
          i32.const -1
          i32.add
          local.get 3
          i32.and
          local.set 3
          local.get 10
          local.get 22
          i32.const 3
          i32.shr_u
          local.get 19
          i32.add
          local.get 7
          i32.and
          local.tee 22
          i32.const 48
          i32.mul
          i32.add
          i64.load
          local.get 2
          i64.ne
          br_if 0 (;@3;)
        end
      end
      local.get 10
      local.get 22
      i32.const 48
      i32.mul
      i32.add
      local.tee 3
      i64.load offset=8
      local.set 2
      local.get 3
      local.get 15
      i64.store offset=8
      local.get 0
      local.get 2
      i64.store
      local.get 3
      i64.load offset=40 align=4
      local.set 2
      local.get 3
      local.get 12
      i64.store offset=40 align=4
      local.get 0
      i32.const 32
      i32.add
      local.get 2
      i64.store
      local.get 3
      i32.const 32
      i32.add
      local.tee 1
      i64.load
      local.set 2
      local.get 1
      local.get 9
      i64.store
      local.get 3
      i32.const 24
      i32.add
      local.tee 1
      i64.load
      local.set 5
      local.get 1
      local.get 13
      i64.store
      local.get 3
      i32.const 16
      i32.add
      local.tee 3
      i64.load
      local.set 9
      local.get 3
      local.get 14
      i64.store
      local.get 0
      i32.const 24
      i32.add
      local.get 2
      i64.store
      local.get 0
      local.get 5
      i64.store offset=16
      local.get 0
      local.get 9
      i64.store offset=8
    end
    local.get 4
    i32.const 16
    i32.add
    global.set 0)
  (func $_ZN4core3ptr18real_drop_in_place17hf6e451b2d0b4c37cE.llvm.16168865174730590251 (type 5) (param i32)
    (local i32 i32 i32 i32 i32 i64)
    block  ;; label = @1
      local.get 0
      i32.load
      i32.const -1
      i32.add
      local.tee 1
      i32.const 3
      i32.gt_u
      br_if 0 (;@1;)
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            local.get 1
            br_table 0 (;@4;) 3 (;@1;) 1 (;@3;) 2 (;@2;) 0 (;@4;)
          end
          local.get 0
          i32.const 8
          i32.add
          i32.load
          local.tee 1
          i32.eqz
          br_if 2 (;@1;)
          local.get 0
          i32.load offset=4
          local.get 1
          i32.const 1
          call $__rust_dealloc
          return
        end
        local.get 0
        i32.const 24
        i32.add
        i32.load
        local.tee 1
        i32.eqz
        br_if 1 (;@1;)
        local.get 0
        i32.const 28
        i32.add
        i32.load
        local.tee 2
        i32.eqz
        br_if 1 (;@1;)
        local.get 1
        local.get 2
        i32.const 3
        i32.shl
        i32.const 8
        call $__rust_dealloc
        br 1 (;@1;)
      end
      local.get 0
      i32.load offset=4
      local.tee 3
      i32.eqz
      br_if 0 (;@1;)
      local.get 0
      i32.const 8
      i32.add
      i32.load
      local.tee 2
      i32.const 4
      i32.add
      local.set 1
      local.get 3
      local.get 2
      i32.add
      i32.const 1
      i32.add
      local.set 4
      local.get 2
      i32.load
      i32.const -1
      i32.xor
      i32.const -2139062144
      i32.and
      local.set 3
      local.get 0
      i32.const 12
      i32.add
      i32.load
      local.set 2
      block  ;; label = @2
        loop  ;; label = @3
          block  ;; label = @4
            local.get 3
            br_if 0 (;@4;)
            loop  ;; label = @5
              local.get 1
              local.get 4
              i32.ge_u
              br_if 3 (;@2;)
              local.get 2
              i32.const 192
              i32.add
              local.set 2
              local.get 1
              i32.load
              local.set 3
              local.get 1
              i32.const 4
              i32.add
              local.tee 5
              local.set 1
              local.get 3
              i32.const -2139062144
              i32.and
              local.tee 3
              i32.const -2139062144
              i32.eq
              br_if 0 (;@5;)
            end
            local.get 3
            i32.const -2139062144
            i32.xor
            local.set 3
            local.get 5
            local.set 1
          end
          local.get 2
          local.get 3
          i32.ctz
          i32.const 3
          i32.shr_u
          i32.const 48
          i32.mul
          i32.add
          i32.const 8
          i32.add
          call $_ZN4core3ptr18real_drop_in_place17hf6e451b2d0b4c37cE.llvm.16168865174730590251
          local.get 3
          i32.const -1
          i32.add
          local.get 3
          i32.and
          local.set 3
          br 0 (;@3;)
        end
      end
      i32.const 0
      local.set 1
      block  ;; label = @2
        block  ;; label = @3
          local.get 0
          i32.load offset=4
          local.tee 2
          i32.const 1
          i32.add
          i64.extend_i32_u
          i64.const 48
          i64.mul
          local.tee 6
          i64.const 32
          i64.shr_u
          i32.wrap_i64
          i32.eqz
          br_if 0 (;@3;)
          br 1 (;@2;)
        end
        block  ;; label = @3
          local.get 2
          i32.const 12
          i32.add
          i32.const -8
          i32.and
          local.tee 3
          local.get 2
          i32.const 5
          i32.add
          i32.ge_u
          br_if 0 (;@3;)
          br 1 (;@2;)
        end
        local.get 3
        local.get 6
        i32.wrap_i64
        i32.add
        local.tee 2
        local.get 3
        i32.lt_u
        br_if 0 (;@2;)
        local.get 2
        i32.const -7
        i32.lt_u
        i32.const 3
        i32.shl
        local.set 1
      end
      local.get 0
      i32.load offset=8
      local.get 2
      local.get 1
      call $__rust_dealloc
      return
    end)
  (func $_ZN4core3ptr18real_drop_in_place17hf6e451b2d0b4c37cE (type 5) (param i32)
    (local i32 i32 i32 i32 i32 i64)
    block  ;; label = @1
      local.get 0
      i32.load
      i32.const -1
      i32.add
      local.tee 1
      i32.const 3
      i32.gt_u
      br_if 0 (;@1;)
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            local.get 1
            br_table 0 (;@4;) 3 (;@1;) 1 (;@3;) 2 (;@2;) 0 (;@4;)
          end
          local.get 0
          i32.const 8
          i32.add
          i32.load
          local.tee 1
          i32.eqz
          br_if 2 (;@1;)
          local.get 0
          i32.load offset=4
          local.get 1
          i32.const 1
          call $__rust_dealloc
          return
        end
        local.get 0
        i32.const 24
        i32.add
        i32.load
        local.tee 1
        i32.eqz
        br_if 1 (;@1;)
        local.get 0
        i32.const 28
        i32.add
        i32.load
        local.tee 2
        i32.eqz
        br_if 1 (;@1;)
        local.get 1
        local.get 2
        i32.const 3
        i32.shl
        i32.const 8
        call $__rust_dealloc
        br 1 (;@1;)
      end
      local.get 0
      i32.load offset=4
      local.tee 3
      i32.eqz
      br_if 0 (;@1;)
      local.get 0
      i32.const 8
      i32.add
      i32.load
      local.tee 2
      i32.const 4
      i32.add
      local.set 1
      local.get 3
      local.get 2
      i32.add
      i32.const 1
      i32.add
      local.set 4
      local.get 2
      i32.load
      i32.const -1
      i32.xor
      i32.const -2139062144
      i32.and
      local.set 3
      local.get 0
      i32.const 12
      i32.add
      i32.load
      local.set 2
      block  ;; label = @2
        loop  ;; label = @3
          block  ;; label = @4
            local.get 3
            br_if 0 (;@4;)
            loop  ;; label = @5
              local.get 1
              local.get 4
              i32.ge_u
              br_if 3 (;@2;)
              local.get 2
              i32.const 192
              i32.add
              local.set 2
              local.get 1
              i32.load
              local.set 3
              local.get 1
              i32.const 4
              i32.add
              local.tee 5
              local.set 1
              local.get 3
              i32.const -2139062144
              i32.and
              local.tee 3
              i32.const -2139062144
              i32.eq
              br_if 0 (;@5;)
            end
            local.get 3
            i32.const -2139062144
            i32.xor
            local.set 3
            local.get 5
            local.set 1
          end
          local.get 2
          local.get 3
          i32.ctz
          i32.const 3
          i32.shr_u
          i32.const 48
          i32.mul
          i32.add
          i32.const 8
          i32.add
          call $_ZN4core3ptr18real_drop_in_place17hf6e451b2d0b4c37cE
          local.get 3
          i32.const -1
          i32.add
          local.get 3
          i32.and
          local.set 3
          br 0 (;@3;)
        end
      end
      i32.const 0
      local.set 1
      block  ;; label = @2
        block  ;; label = @3
          local.get 0
          i32.load offset=4
          local.tee 2
          i32.const 1
          i32.add
          i64.extend_i32_u
          i64.const 48
          i64.mul
          local.tee 6
          i64.const 32
          i64.shr_u
          i32.wrap_i64
          i32.eqz
          br_if 0 (;@3;)
          br 1 (;@2;)
        end
        block  ;; label = @3
          local.get 2
          i32.const 12
          i32.add
          i32.const -8
          i32.and
          local.tee 3
          local.get 2
          i32.const 5
          i32.add
          i32.ge_u
          br_if 0 (;@3;)
          br 1 (;@2;)
        end
        local.get 3
        local.get 6
        i32.wrap_i64
        i32.add
        local.tee 2
        local.get 3
        i32.lt_u
        br_if 0 (;@2;)
        local.get 2
        i32.const -7
        i32.lt_u
        i32.const 3
        i32.shl
        local.set 1
      end
      local.get 0
      i32.load offset=8
      local.get 2
      local.get 1
      call $__rust_dealloc
      return
    end)
  (func $__av_add (type 11) (param i32 i64 i64) (result i64)
    (local i32 f64 i64 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    global.get 0
    i32.const 160
    i32.sub
    local.tee 3
    global.set 0
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
                            local.get 1
                            f64.reinterpret_i64
                            local.tee 4
                            local.get 4
                            f64.eq
                            br_if 0 (;@12;)
                            i64.const -1970311952072704
                            local.set 5
                            local.get 1
                            i64.const -3940649673949184
                            i64.and
                            i64.const -3940649673949184
                            i64.eq
                            br_if 1 (;@11;)
                            br 11 (;@1;)
                          end
                          local.get 3
                          i32.const 8
                          i32.add
                          local.get 1
                          i64.store
                          br 1 (;@10;)
                        end
                        local.get 3
                        local.get 1
                        i64.store offset=120
                        block  ;; label = @11
                          block  ;; label = @12
                            local.get 0
                            i32.const 8
                            i32.add
                            local.get 3
                            i32.const 120
                            i32.add
                            call $_ZN3std11collections4hash3map24HashMap$LT$K$C$V$C$S$GT$3get17h5e2dfe0c5e2017b2E.llvm.16168865174730590251
                            local.tee 6
                            br_if 0 (;@12;)
                            local.get 3
                            i32.const 8
                            i32.add
                            local.get 1
                            i64.store
                            br 1 (;@11;)
                          end
                          block  ;; label = @12
                            block  ;; label = @13
                              block  ;; label = @14
                                block  ;; label = @15
                                  block  ;; label = @16
                                    block  ;; label = @17
                                      block  ;; label = @18
                                        local.get 6
                                        i32.load
                                        br_table 0 (;@18;) 5 (;@13;) 1 (;@17;) 2 (;@16;) 3 (;@15;) 4 (;@14;) 0 (;@18;)
                                      end
                                      local.get 3
                                      i32.const 8
                                      i32.add
                                      local.get 6
                                      i64.load offset=8
                                      i64.store
                                      br 7 (;@10;)
                                    end
                                    local.get 3
                                    i32.const 8
                                    i32.add
                                    local.get 6
                                    i64.load offset=8
                                    i64.store
                                    br 5 (;@11;)
                                  end
                                  local.get 6
                                  i64.load offset=16
                                  local.set 1
                                  local.get 6
                                  i64.load offset=8
                                  local.set 5
                                  block  ;; label = @16
                                    block  ;; label = @17
                                      local.get 6
                                      i32.load offset=24
                                      local.tee 7
                                      br_if 0 (;@17;)
                                      i32.const 0
                                      local.set 6
                                      br 1 (;@16;)
                                    end
                                    local.get 6
                                    i32.load offset=32
                                    local.tee 8
                                    i32.const 536870911
                                    i32.and
                                    local.get 8
                                    i32.ne
                                    br_if 8 (;@8;)
                                    local.get 8
                                    i32.const 3
                                    i32.shl
                                    local.tee 9
                                    i32.const -1
                                    i32.le_s
                                    br_if 9 (;@7;)
                                    block  ;; label = @17
                                      block  ;; label = @18
                                        local.get 9
                                        br_if 0 (;@18;)
                                        i32.const 8
                                        local.set 6
                                        br 1 (;@17;)
                                      end
                                      local.get 9
                                      i32.const 8
                                      call $__rust_alloc
                                      local.tee 6
                                      i32.eqz
                                      br_if 5 (;@12;)
                                    end
                                    local.get 6
                                    local.get 8
                                    local.get 7
                                    local.get 8
                                    call $_ZN4core5slice29_$LT$impl$u20$$u5b$T$u5d$$GT$15copy_from_slice17h66a985877caaf92eE
                                  end
                                  local.get 3
                                  i32.const 32
                                  i32.add
                                  local.get 8
                                  i32.store
                                  local.get 3
                                  i32.const 28
                                  i32.add
                                  local.get 8
                                  i32.store
                                  local.get 3
                                  i32.const 24
                                  i32.add
                                  local.get 6
                                  i32.store
                                  local.get 3
                                  i32.const 16
                                  i32.add
                                  local.get 1
                                  i64.store
                                  local.get 3
                                  i32.const 8
                                  i32.add
                                  local.get 5
                                  i64.store
                                  i32.const 3
                                  local.set 8
                                  local.get 3
                                  i32.const 3
                                  i32.store
                                  br 6 (;@9;)
                                end
                                i32.const 4
                                local.set 8
                                local.get 3
                                i32.const 120
                                i32.add
                                local.get 6
                                i32.const 4
                                i32.add
                                call $_ZN72_$LT$hashbrown..raw..RawTable$LT$T$GT$$u20$as$u20$core..clone..Clone$GT$5clone17habb655206efa7990E
                                local.get 3
                                i32.const 20
                                i32.add
                                local.get 3
                                i32.const 136
                                i32.add
                                i32.load
                                i32.store
                                local.get 3
                                i32.const 12
                                i32.add
                                local.get 3
                                i32.const 128
                                i32.add
                                i64.load
                                i64.store align=4
                                local.get 3
                                i32.const 4
                                i32.store
                                local.get 3
                                local.get 3
                                i64.load offset=120
                                i64.store offset=4 align=4
                                br 5 (;@9;)
                              end
                              i32.const 5
                              local.set 8
                              local.get 3
                              i32.const 5
                              i32.store
                              local.get 3
                              local.get 6
                              i64.load offset=4 align=4
                              i64.store offset=4 align=4
                              br 4 (;@9;)
                            end
                            local.get 3
                            i32.const 120
                            i32.add
                            local.get 6
                            i32.const 4
                            i32.add
                            call $_ZN60_$LT$alloc..string..String$u20$as$u20$core..clone..Clone$GT$5clone17hcaceec0319ee7974E
                            local.get 3
                            i32.const 12
                            i32.add
                            local.get 3
                            i32.const 128
                            i32.add
                            i32.load
                            i32.store
                            i32.const 1
                            local.set 8
                            local.get 3
                            i32.const 1
                            i32.store
                            local.get 3
                            local.get 3
                            i64.load offset=120
                            i64.store offset=4 align=4
                            br 3 (;@9;)
                          end
                          local.get 9
                          i32.const 8
                          call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
                          unreachable
                        end
                        i32.const 2
                        local.set 8
                        local.get 3
                        i32.const 2
                        i32.store
                        br 1 (;@9;)
                      end
                      i32.const 0
                      local.set 8
                      local.get 3
                      i32.const 0
                      i32.store
                    end
                    block  ;; label = @9
                      block  ;; label = @10
                        local.get 2
                        f64.reinterpret_i64
                        local.tee 4
                        local.get 4
                        f64.eq
                        br_if 0 (;@10;)
                        local.get 2
                        i64.const -3940649673949184
                        i64.and
                        i64.const -3940649673949184
                        i64.eq
                        br_if 1 (;@9;)
                        i64.const -1970311952072704
                        local.set 5
                        i32.const 1
                        local.set 0
                        br 8 (;@2;)
                      end
                      local.get 3
                      i32.const 48
                      i32.add
                      local.get 2
                      i64.store
                      br 5 (;@4;)
                    end
                    local.get 3
                    local.get 2
                    i64.store offset=120
                    block  ;; label = @9
                      local.get 0
                      i32.const 8
                      i32.add
                      local.get 3
                      i32.const 120
                      i32.add
                      call $_ZN3std11collections4hash3map24HashMap$LT$K$C$V$C$S$GT$3get17h5e2dfe0c5e2017b2E.llvm.16168865174730590251
                      local.tee 6
                      br_if 0 (;@9;)
                      local.get 3
                      i32.const 40
                      i32.add
                      i32.const 8
                      i32.add
                      local.get 2
                      i64.store
                      br 4 (;@5;)
                    end
                    block  ;; label = @9
                      block  ;; label = @10
                        block  ;; label = @11
                          block  ;; label = @12
                            block  ;; label = @13
                              block  ;; label = @14
                                local.get 6
                                i32.load
                                br_table 0 (;@14;) 1 (;@13;) 2 (;@12;) 3 (;@11;) 4 (;@10;) 5 (;@9;) 0 (;@14;)
                              end
                              local.get 3
                              i32.const 48
                              i32.add
                              local.get 6
                              i64.load offset=8
                              i64.store
                              br 9 (;@4;)
                            end
                            local.get 3
                            i32.const 120
                            i32.add
                            local.get 6
                            i32.const 4
                            i32.add
                            call $_ZN60_$LT$alloc..string..String$u20$as$u20$core..clone..Clone$GT$5clone17hcaceec0319ee7974E
                            local.get 3
                            i32.const 52
                            i32.add
                            local.get 3
                            i32.const 128
                            i32.add
                            i32.load
                            i32.store
                            i32.const 1
                            local.set 8
                            local.get 3
                            i32.const 1
                            i32.store offset=40
                            local.get 3
                            local.get 3
                            i64.load offset=120
                            i64.store offset=44 align=4
                            br 9 (;@3;)
                          end
                          local.get 3
                          i32.const 48
                          i32.add
                          local.get 6
                          i64.load offset=8
                          i64.store
                          br 6 (;@5;)
                        end
                        local.get 6
                        i64.load offset=16
                        local.set 1
                        local.get 6
                        i64.load offset=8
                        local.set 2
                        block  ;; label = @11
                          block  ;; label = @12
                            local.get 6
                            i32.load offset=24
                            local.tee 7
                            br_if 0 (;@12;)
                            i32.const 0
                            local.set 6
                            br 1 (;@11;)
                          end
                          local.get 6
                          i32.load offset=32
                          local.tee 8
                          i32.const 536870911
                          i32.and
                          local.get 8
                          i32.ne
                          br_if 3 (;@8;)
                          local.get 8
                          i32.const 3
                          i32.shl
                          local.tee 9
                          i32.const -1
                          i32.le_s
                          br_if 4 (;@7;)
                          block  ;; label = @12
                            block  ;; label = @13
                              local.get 9
                              br_if 0 (;@13;)
                              i32.const 8
                              local.set 6
                              br 1 (;@12;)
                            end
                            local.get 9
                            i32.const 8
                            call $__rust_alloc
                            local.tee 6
                            i32.eqz
                            br_if 6 (;@6;)
                          end
                          local.get 6
                          local.get 8
                          local.get 7
                          local.get 8
                          call $_ZN4core5slice29_$LT$impl$u20$$u5b$T$u5d$$GT$15copy_from_slice17h66a985877caaf92eE
                        end
                        local.get 3
                        i32.const 72
                        i32.add
                        local.get 8
                        i32.store
                        local.get 3
                        i32.const 68
                        i32.add
                        local.get 8
                        i32.store
                        local.get 3
                        i32.const 64
                        i32.add
                        local.get 6
                        i32.store
                        local.get 3
                        i32.const 56
                        i32.add
                        local.get 1
                        i64.store
                        local.get 3
                        i32.const 48
                        i32.add
                        local.get 2
                        i64.store
                        i32.const 3
                        local.set 8
                        local.get 3
                        i32.const 3
                        i32.store offset=40
                        br 7 (;@3;)
                      end
                      i32.const 4
                      local.set 8
                      local.get 3
                      i32.const 120
                      i32.add
                      local.get 6
                      i32.const 4
                      i32.add
                      call $_ZN72_$LT$hashbrown..raw..RawTable$LT$T$GT$$u20$as$u20$core..clone..Clone$GT$5clone17habb655206efa7990E
                      local.get 3
                      i32.const 60
                      i32.add
                      local.get 3
                      i32.const 136
                      i32.add
                      i32.load
                      i32.store
                      local.get 3
                      i32.const 52
                      i32.add
                      local.get 3
                      i32.const 128
                      i32.add
                      i64.load
                      i64.store align=4
                      local.get 3
                      i32.const 4
                      i32.store offset=40
                      local.get 3
                      local.get 3
                      i64.load offset=120
                      i64.store offset=44 align=4
                      br 6 (;@3;)
                    end
                    i32.const 5
                    local.set 8
                    local.get 3
                    i32.const 5
                    i32.store offset=40
                    local.get 3
                    local.get 6
                    i64.load offset=4 align=4
                    i64.store offset=44 align=4
                    br 5 (;@3;)
                  end
                  call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17h356d4b685803bd7bE.llvm.118960385785549565
                  unreachable
                end
                call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17h356d4b685803bd7bE.llvm.118960385785549565
                unreachable
              end
              local.get 9
              i32.const 8
              call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
              unreachable
            end
            i32.const 2
            local.set 8
            local.get 3
            i32.const 2
            i32.store offset=40
            br 1 (;@3;)
          end
          i32.const 0
          local.set 8
          local.get 3
          i32.const 0
          i32.store offset=40
        end
        i64.const -1970311952072704
        local.set 5
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                block  ;; label = @7
                  block  ;; label = @8
                    block  ;; label = @9
                      local.get 3
                      i32.load
                      local.tee 6
                      i32.const 1
                      i32.le_u
                      br_if 0 (;@9;)
                      i32.const 1
                      local.set 6
                      i32.const 1
                      local.set 0
                      br 1 (;@8;)
                    end
                    block  ;; label = @9
                      block  ;; label = @10
                        local.get 6
                        br_table 0 (;@10;) 1 (;@9;) 0 (;@10;)
                      end
                      i32.const 1
                      local.set 6
                      i32.const 1
                      local.set 0
                      local.get 8
                      br_if 1 (;@8;)
                      local.get 3
                      i32.const 8
                      i32.add
                      f64.load
                      local.get 3
                      i32.const 40
                      i32.add
                      i32.const 8
                      i32.add
                      f64.load
                      f64.add
                      i64.reinterpret_f64
                      local.set 5
                      i32.const 1
                      local.set 0
                      br 5 (;@4;)
                    end
                    i32.const 1
                    local.set 6
                    local.get 3
                    i32.const 8
                    i32.add
                    i32.load
                    local.set 7
                    i64.const -1970290477236224
                    local.set 5
                    local.get 3
                    i32.load offset=4
                    local.set 10
                    block  ;; label = @9
                      local.get 8
                      i32.const 1
                      i32.ne
                      br_if 0 (;@9;)
                      i32.const 1
                      local.set 9
                      local.get 3
                      i32.const 40
                      i32.add
                      i32.const 12
                      i32.add
                      i32.load
                      local.tee 11
                      local.get 3
                      i32.const 12
                      i32.add
                      i32.load
                      local.tee 6
                      i32.add
                      local.tee 12
                      i32.const 1
                      i32.add
                      local.tee 8
                      i32.const -1
                      i32.le_s
                      br_if 3 (;@6;)
                      local.get 3
                      i32.const 40
                      i32.add
                      i32.const 8
                      i32.add
                      i32.load
                      local.set 13
                      local.get 3
                      i32.load offset=44
                      local.set 14
                      block  ;; label = @10
                        local.get 8
                        i32.eqz
                        br_if 0 (;@10;)
                        local.get 8
                        i32.const 1
                        call $__rust_alloc
                        local.tee 9
                        i32.eqz
                        br_if 5 (;@5;)
                      end
                      block  ;; label = @10
                        block  ;; label = @11
                          block  ;; label = @12
                            block  ;; label = @13
                              block  ;; label = @14
                                local.get 8
                                local.get 6
                                i32.ge_u
                                br_if 0 (;@14;)
                                local.get 8
                                i32.const 1
                                i32.shl
                                local.tee 15
                                local.get 6
                                local.get 6
                                local.get 15
                                i32.lt_u
                                select
                                local.tee 15
                                i32.const 0
                                i32.lt_s
                                br_if 1 (;@13;)
                                block  ;; label = @15
                                  block  ;; label = @16
                                    local.get 8
                                    br_if 0 (;@16;)
                                    local.get 15
                                    i32.const 1
                                    call $__rust_alloc
                                    local.set 9
                                    br 1 (;@15;)
                                  end
                                  local.get 9
                                  local.get 8
                                  i32.const 1
                                  local.get 15
                                  call $__rust_realloc
                                  local.set 9
                                end
                                local.get 9
                                i32.eqz
                                br_if 2 (;@12;)
                                local.get 15
                                local.set 8
                              end
                              local.get 9
                              local.get 6
                              local.get 10
                              local.get 6
                              call $_ZN4core5slice29_$LT$impl$u20$$u5b$T$u5d$$GT$15copy_from_slice17h2ac8d46f96f9c8eaE
                              local.get 8
                              local.get 6
                              i32.sub
                              local.get 11
                              i32.ge_u
                              br_if 3 (;@10;)
                              local.get 12
                              local.get 6
                              i32.lt_u
                              br_if 0 (;@13;)
                              local.get 8
                              i32.const 1
                              i32.shl
                              local.tee 15
                              local.get 12
                              local.get 12
                              local.get 15
                              i32.lt_u
                              select
                              local.tee 15
                              i32.const 0
                              i32.ge_s
                              br_if 2 (;@11;)
                            end
                            call $_ZN5alloc7raw_vec17capacity_overflow17hb65cc35880b7f060E
                            unreachable
                          end
                          local.get 15
                          i32.const 1
                          call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
                          unreachable
                        end
                        block  ;; label = @11
                          block  ;; label = @12
                            local.get 8
                            br_if 0 (;@12;)
                            local.get 15
                            i32.const 1
                            call $__rust_alloc
                            local.set 9
                            br 1 (;@11;)
                          end
                          local.get 9
                          local.get 8
                          i32.const 1
                          local.get 15
                          call $__rust_realloc
                          local.set 9
                        end
                        local.get 9
                        i32.eqz
                        br_if 3 (;@7;)
                        local.get 15
                        local.set 8
                      end
                      local.get 9
                      local.get 6
                      i32.add
                      local.get 11
                      local.get 14
                      local.get 11
                      call $_ZN4core5slice29_$LT$impl$u20$$u5b$T$u5d$$GT$15copy_from_slice17h2ac8d46f96f9c8eaE
                      local.get 0
                      i64.load
                      local.set 1
                      local.get 3
                      i32.const 132
                      i32.add
                      local.get 12
                      i32.store
                      local.get 3
                      i32.const 120
                      i32.add
                      i32.const 8
                      i32.add
                      local.get 8
                      i32.store
                      local.get 3
                      local.get 9
                      i32.store offset=124
                      local.get 3
                      i32.const 1
                      i32.store offset=120
                      local.get 3
                      i32.const 80
                      i32.add
                      local.get 0
                      i32.const 8
                      i32.add
                      local.get 1
                      i64.const -844424930131968
                      i64.or
                      local.tee 5
                      local.get 3
                      i32.const 120
                      i32.add
                      call $_ZN3std11collections4hash3map24HashMap$LT$K$C$V$C$S$GT$6insert17h7ea479b26ececd8eE.llvm.16168865174730590251
                      block  ;; label = @10
                        local.get 3
                        i32.load offset=80
                        i32.const 6
                        i32.eq
                        br_if 0 (;@10;)
                        local.get 3
                        i32.const 80
                        i32.add
                        call $_ZN4core3ptr18real_drop_in_place17hf6e451b2d0b4c37cE.llvm.16168865174730590251
                      end
                      local.get 0
                      local.get 0
                      i64.load
                      i64.const 1
                      i64.add
                      i64.store
                      i32.const 0
                      local.set 6
                      local.get 13
                      i32.eqz
                      br_if 0 (;@9;)
                      local.get 14
                      local.get 13
                      i32.const 1
                      call $__rust_dealloc
                    end
                    block  ;; label = @9
                      local.get 7
                      i32.eqz
                      br_if 0 (;@9;)
                      local.get 10
                      local.get 7
                      i32.const 1
                      call $__rust_dealloc
                    end
                    i32.const 0
                    local.set 0
                    local.get 3
                    i32.load offset=40
                    local.set 8
                  end
                  local.get 8
                  i32.const 1
                  i32.ne
                  br_if 3 (;@4;)
                  local.get 6
                  i32.eqz
                  br_if 4 (;@3;)
                  local.get 3
                  i32.const 48
                  i32.add
                  i32.load
                  local.tee 8
                  i32.eqz
                  br_if 4 (;@3;)
                  local.get 3
                  i32.load offset=44
                  local.get 8
                  i32.const 1
                  call $__rust_dealloc
                  local.get 3
                  i32.load
                  local.set 8
                  br 5 (;@2;)
                end
                local.get 15
                i32.const 1
                call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
                unreachable
              end
              call $_ZN5alloc7raw_vec19RawVec$LT$T$C$A$GT$11allocate_in28_$u7b$$u7b$closure$u7d$$u7d$17h356d4b685803bd7bE.llvm.118960385785549565
              unreachable
            end
            local.get 8
            i32.const 1
            call $_ZN5alloc5alloc18handle_alloc_error17h309bf80f59bd41c4E
            unreachable
          end
          local.get 3
          i32.const 40
          i32.add
          call $_ZN4core3ptr18real_drop_in_place17hf6e451b2d0b4c37cE
        end
        local.get 3
        i32.load
        local.set 8
      end
      block  ;; label = @2
        local.get 8
        i32.const 1
        i32.eq
        br_if 0 (;@2;)
        local.get 3
        call $_ZN4core3ptr18real_drop_in_place17hf6e451b2d0b4c37cE
        br 1 (;@1;)
      end
      local.get 0
      i32.eqz
      br_if 0 (;@1;)
      local.get 3
      i32.const 8
      i32.add
      i32.load
      local.tee 8
      i32.eqz
      br_if 0 (;@1;)
      local.get 3
      i32.load offset=4
      local.get 8
      i32.const 1
      call $__rust_dealloc
    end
    local.get 3
    i32.const 160
    i32.add
    global.set 0
    local.get 5)
  (func $__av_sub (type 11) (param i32 i64 i64) (result i64)
    (local i64 f64 f64)
    i64.const -1970311952072704
    local.set 3
    block  ;; label = @1
      local.get 1
      f64.reinterpret_i64
      local.tee 4
      local.get 4
      f64.ne
      br_if 0 (;@1;)
      local.get 2
      f64.reinterpret_i64
      local.tee 5
      local.get 5
      f64.ne
      br_if 0 (;@1;)
      local.get 4
      local.get 5
      f64.sub
      i64.reinterpret_f64
      local.set 3
    end
    local.get 3)
  (func $__av_mul (type 11) (param i32 i64 i64) (result i64)
    (local i64 f64 f64)
    i64.const -1970311952072704
    local.set 3
    block  ;; label = @1
      local.get 1
      f64.reinterpret_i64
      local.tee 4
      local.get 4
      f64.ne
      br_if 0 (;@1;)
      local.get 2
      f64.reinterpret_i64
      local.tee 5
      local.get 5
      f64.ne
      br_if 0 (;@1;)
      local.get 4
      local.get 5
      f64.mul
      i64.reinterpret_f64
      local.set 3
    end
    local.get 3)
  (func $__av_div (type 11) (param i32 i64 i64) (result i64)
    (local i64 f64 f64)
    i64.const -1970311952072704
    local.set 3
    block  ;; label = @1
      local.get 1
      f64.reinterpret_i64
      local.tee 4
      local.get 4
      f64.ne
      br_if 0 (;@1;)
      local.get 2
      f64.reinterpret_i64
      local.tee 5
      local.get 5
      f64.ne
      br_if 0 (;@1;)
      i64.const -1970286182268928
      local.set 3
      local.get 5
      f64.const 0x0p+0 (;=0;)
      f64.eq
      br_if 0 (;@1;)
      local.get 4
      local.get 5
      f64.div
      i64.reinterpret_f64
      local.set 3
    end
    local.get 3)
  (func $__av_and (type 11) (param i32 i64 i64) (result i64)
    (local f64)
    i64.const -281474976710528
    i64.const -281474976710528
    i64.const -1407374883553216
    local.get 2
    f64.reinterpret_i64
    local.tee 3
    f64.const 0x0p+0 (;=0;)
    f64.ne
    local.get 3
    local.get 3
    f64.eq
    i32.and
    select
    local.get 2
    i64.const -3377699720527872
    i64.and
    i64.const -3377699720527872
    i64.eq
    select
    local.tee 2
    local.get 2
    i64.const -1407374883553216
    local.get 1
    f64.reinterpret_i64
    local.tee 3
    f64.const 0x0p+0 (;=0;)
    f64.ne
    local.get 3
    local.get 3
    f64.eq
    i32.and
    select
    local.get 1
    i64.const -3377699720527872
    i64.and
    i64.const -3377699720527872
    i64.eq
    select)
  (func $__av_or (type 11) (param i32 i64 i64) (result i64)
    (local f64)
    i64.const -281474976710528
    i64.const -281474976710528
    i64.const -281474976710528
    i64.const -281474976710528
    i64.const -1407374883553216
    local.get 2
    f64.reinterpret_i64
    local.tee 3
    f64.const 0x0p+0 (;=0;)
    f64.ne
    local.get 3
    local.get 3
    f64.eq
    i32.and
    select
    local.get 2
    i64.const -3377699720527872
    i64.and
    i64.const -3377699720527872
    i64.eq
    select
    local.get 1
    f64.reinterpret_i64
    local.tee 3
    f64.const 0x0p+0 (;=0;)
    f64.ne
    local.get 3
    local.get 3
    f64.eq
    i32.and
    select
    local.get 1
    i64.const -3377699720527872
    i64.and
    i64.const -3377699720527872
    i64.eq
    select)
  (func $__av_not (type 12) (param i32 i64) (result i64)
    (local f64)
    i64.const -1407374883553216
    i64.const -1407374883553216
    i64.const -281474976710528
    local.get 1
    f64.reinterpret_i64
    local.tee 2
    f64.const 0x0p+0 (;=0;)
    f64.ne
    local.get 2
    local.get 2
    f64.eq
    i32.and
    select
    local.get 1
    i64.const -3377699720527872
    i64.and
    i64.const -3377699720527872
    i64.eq
    select)
  (func $__av_gt (type 11) (param i32 i64 i64) (result i64)
    (local i64 f64 f64)
    i64.const -1970311952072704
    local.set 3
    block  ;; label = @1
      local.get 1
      f64.reinterpret_i64
      local.tee 4
      local.get 4
      f64.ne
      br_if 0 (;@1;)
      local.get 2
      f64.reinterpret_i64
      local.tee 5
      local.get 5
      f64.ne
      br_if 0 (;@1;)
      i64.const -281474976710528
      i64.const -1407374883553216
      local.get 4
      local.get 5
      f64.gt
      select
      local.set 3
    end
    local.get 3)
  (func $__av_gte (type 11) (param i32 i64 i64) (result i64)
    (local i64 f64 f64)
    i64.const -1970311952072704
    local.set 3
    block  ;; label = @1
      local.get 1
      f64.reinterpret_i64
      local.tee 4
      local.get 4
      f64.ne
      br_if 0 (;@1;)
      local.get 2
      f64.reinterpret_i64
      local.tee 5
      local.get 5
      f64.ne
      br_if 0 (;@1;)
      i64.const -281474976710528
      i64.const -1407374883553216
      local.get 4
      local.get 5
      f64.ge
      select
      local.set 3
    end
    local.get 3)
  (func $__av_lt (type 11) (param i32 i64 i64) (result i64)
    (local i64 f64 f64)
    i64.const -1970311952072704
    local.set 3
    block  ;; label = @1
      local.get 1
      f64.reinterpret_i64
      local.tee 4
      local.get 4
      f64.ne
      br_if 0 (;@1;)
      local.get 2
      f64.reinterpret_i64
      local.tee 5
      local.get 5
      f64.ne
      br_if 0 (;@1;)
      i64.const -281474976710528
      i64.const -1407374883553216
      local.get 4
      local.get 5
      f64.lt
      select
      local.set 3
    end
    local.get 3)
  (func $__av_lte (type 11) (param i32 i64 i64) (result i64)
    (local i64 f64 f64)
    i64.const -1970311952072704
    local.set 3
    block  ;; label = @1
      local.get 1
      f64.reinterpret_i64
      local.tee 4
      local.get 4
      f64.ne
      br_if 0 (;@1;)
      local.get 2
      f64.reinterpret_i64
      local.tee 5
      local.get 5
      f64.ne
      br_if 0 (;@1;)
      i64.const -281474976710528
      i64.const -1407374883553216
      local.get 4
      local.get 5
      f64.le
      select
      local.set 3
    end
    local.get 3)
  (func $_ZN4core5slice29_$LT$impl$u20$$u5b$T$u5d$$GT$15copy_from_slice17h2ac8d46f96f9c8eaE (type 13) (param i32 i32 i32 i32)
    (local i32)
    global.get 0
    i32.const 96
    i32.sub
    local.tee 4
    global.set 0
    local.get 4
    local.get 1
    i32.store offset=8
    local.get 4
    local.get 3
    i32.store offset=12
    block  ;; label = @1
      local.get 1
      local.get 3
      i32.ne
      br_if 0 (;@1;)
      local.get 0
      local.get 2
      local.get 1
      call $memcpy
      drop
      local.get 4
      i32.const 96
      i32.add
      global.set 0
      return
    end
    local.get 4
    i32.const 40
    i32.add
    i32.const 20
    i32.add
    i32.const 7
    i32.store
    local.get 4
    i32.const 52
    i32.add
    i32.const 8
    i32.store
    local.get 4
    i32.const 16
    i32.add
    i32.const 20
    i32.add
    i32.const 3
    i32.store
    local.get 4
    local.get 4
    i32.const 8
    i32.add
    i32.store offset=64
    local.get 4
    local.get 4
    i32.const 12
    i32.add
    i32.store offset=68
    local.get 4
    i32.const 72
    i32.add
    i32.const 20
    i32.add
    i32.const 0
    i32.store
    local.get 4
    i64.const 3
    i64.store offset=20 align=4
    local.get 4
    i32.const 1049204
    i32.store offset=16
    local.get 4
    i32.const 8
    i32.store offset=44
    local.get 4
    i32.const 1049288
    i32.store offset=88
    local.get 4
    i64.const 1
    i64.store offset=76 align=4
    local.get 4
    i32.const 1049280
    i32.store offset=72
    local.get 4
    local.get 4
    i32.const 40
    i32.add
    i32.store offset=32
    local.get 4
    local.get 4
    i32.const 72
    i32.add
    i32.store offset=56
    local.get 4
    local.get 4
    i32.const 68
    i32.add
    i32.store offset=48
    local.get 4
    local.get 4
    i32.const 64
    i32.add
    i32.store offset=40
    local.get 4
    i32.const 16
    i32.add
    i32.const 1049288
    call $_ZN4core9panicking9panic_fmt17h52bd9c4c06b66d8dE
    unreachable)
  (func $_ZN4core5slice29_$LT$impl$u20$$u5b$T$u5d$$GT$15copy_from_slice17h66a985877caaf92eE (type 13) (param i32 i32 i32 i32)
    (local i32)
    global.get 0
    i32.const 96
    i32.sub
    local.tee 4
    global.set 0
    local.get 4
    local.get 1
    i32.store offset=8
    local.get 4
    local.get 3
    i32.store offset=12
    block  ;; label = @1
      local.get 1
      local.get 3
      i32.ne
      br_if 0 (;@1;)
      local.get 0
      local.get 2
      local.get 1
      i32.const 3
      i32.shl
      call $memcpy
      drop
      local.get 4
      i32.const 96
      i32.add
      global.set 0
      return
    end
    local.get 4
    i32.const 40
    i32.add
    i32.const 20
    i32.add
    i32.const 7
    i32.store
    local.get 4
    i32.const 52
    i32.add
    i32.const 8
    i32.store
    local.get 4
    i32.const 16
    i32.add
    i32.const 20
    i32.add
    i32.const 3
    i32.store
    local.get 4
    local.get 4
    i32.const 8
    i32.add
    i32.store offset=64
    local.get 4
    local.get 4
    i32.const 12
    i32.add
    i32.store offset=68
    local.get 4
    i32.const 72
    i32.add
    i32.const 20
    i32.add
    i32.const 0
    i32.store
    local.get 4
    i64.const 3
    i64.store offset=20 align=4
    local.get 4
    i32.const 1049204
    i32.store offset=16
    local.get 4
    i32.const 8
    i32.store offset=44
    local.get 4
    i32.const 1049288
    i32.store offset=88
    local.get 4
    i64.const 1
    i64.store offset=76 align=4
    local.get 4
    i32.const 1049280
    i32.store offset=72
    local.get 4
    local.get 4
    i32.const 40
    i32.add
    i32.store offset=32
    local.get 4
    local.get 4
    i32.const 72
    i32.add
    i32.store offset=56
    local.get 4
    local.get 4
    i32.const 68
    i32.add
    i32.store offset=48
    local.get 4
    local.get 4
    i32.const 64
    i32.add
    i32.store offset=40
    local.get 4
    i32.const 16
    i32.add
    i32.const 1049288
    call $_ZN4core9panicking9panic_fmt17h52bd9c4c06b66d8dE
    unreachable)
  (func $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1 (type 2) (param i32 i32) (result i32)
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
          i32.const 1049416
          i32.const 37
          i32.const 1049400
          call $_ZN3std9panicking11begin_panic17h6f5191b790a90319E
          unreachable
        end
        i32.const 1049508
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
  (func $_ZN11flatbuffers7builder17FlatBufferBuilder13create_string17ha9feb9fb9873ab3eE (type 1) (param i32 i32 i32) (result i32)
    (local i32 i32 i32)
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
    local.get 2
    local.get 0
    i32.const 8
    i32.add
    local.tee 3
    i32.load
    local.get 0
    i32.load offset=12
    i32.sub
    i32.add
    i32.const -1
    i32.xor
    i32.const 3
    i32.and
    call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
    drop
    local.get 0
    local.get 0
    i32.load offset=40
    local.tee 4
    i32.const 1
    local.get 4
    i32.const 1
    i32.gt_u
    select
    i32.store offset=40
    local.get 0
    i32.const 0
    call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
    drop
    local.get 0
    i32.const 1
    call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
    drop
    block  ;; label = @1
      block  ;; label = @2
        block  ;; label = @3
          block  ;; label = @4
            block  ;; label = @5
              block  ;; label = @6
                local.get 3
                i32.load
                local.tee 4
                local.get 0
                i32.load offset=12
                local.tee 3
                i32.lt_u
                br_if 0 (;@6;)
                local.get 4
                local.get 3
                i32.eq
                br_if 1 (;@5;)
                local.get 0
                i32.load
                local.get 3
                i32.add
                i32.const 0
                i32.store8
                local.get 0
                local.get 2
                call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
                local.tee 3
                local.get 2
                i32.add
                local.tee 4
                local.get 3
                i32.lt_u
                br_if 2 (;@4;)
                local.get 0
                i32.const 8
                i32.add
                i32.load
                local.tee 5
                local.get 4
                i32.lt_u
                br_if 3 (;@3;)
                local.get 0
                i32.load
                local.get 3
                i32.add
                local.get 1
                local.get 2
                call $memcpy
                drop
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
                call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
                drop
                local.get 0
                i32.const 4
                call $_ZN11flatbuffers7builder17FlatBufferBuilder10make_space17h7677b6a895cc37e4E.1
                drop
                local.get 3
                i32.load
                local.tee 1
                local.get 0
                i32.load offset=12
                local.tee 3
                i32.lt_u
                br_if 4 (;@2;)
                local.get 1
                local.get 3
                i32.sub
                i32.const 3
                i32.le_u
                br_if 5 (;@1;)
                local.get 0
                i32.load
                local.get 3
                i32.add
                local.get 2
                i32.store
                local.get 0
                i32.const 8
                i32.add
                i32.load
                local.get 0
                i32.load offset=12
                i32.sub
                return
              end
              local.get 3
              local.get 4
              call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
              unreachable
            end
            i32.const 1049508
            call $_ZN4core9panicking5panic17h1fb303f1c113605dE
            unreachable
          end
          local.get 3
          local.get 4
          call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
          unreachable
        end
        local.get 4
        local.get 5
        call $_ZN4core5slice20slice_index_len_fail17h9458be78f79058caE
        unreachable
      end
      local.get 3
      local.get 1
      call $_ZN4core5slice22slice_index_order_fail17he2ead4974460398eE
      unreachable
    end
    i32.const 1049508
    call $_ZN4core9panicking5panic17h1fb303f1c113605dE
    unreachable)
  (func $__av_save (type 14) (param i32 i64 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    (local i32)
    global.get 0
    i32.const 80
    i32.sub
    local.tee 12
    global.set 0
    local.get 12
    i32.const 76
    i32.add
    local.get 11
    i32.store
    local.get 12
    i32.const 72
    i32.add
    local.get 10
    i32.store
    local.get 12
    i32.const 68
    i32.add
    local.get 9
    i32.store
    local.get 12
    i32.const 64
    i32.add
    local.get 8
    i32.store
    local.get 12
    i32.const 60
    i32.add
    local.get 7
    i32.store
    local.get 12
    i32.const 56
    i32.add
    local.get 6
    i32.store
    local.get 12
    i32.const 52
    i32.add
    local.get 5
    i32.store
    local.get 12
    i32.const 40
    i32.add
    i32.const 8
    i32.add
    local.get 4
    i32.store
    local.get 12
    local.get 3
    i32.store offset=44
    local.get 12
    local.get 2
    i32.store offset=40
    local.get 12
    local.get 0
    i32.const 8
    i32.add
    local.get 1
    local.get 12
    i32.const 40
    i32.add
    call $_ZN3std11collections4hash3map24HashMap$LT$K$C$V$C$S$GT$6insert17h7ea479b26ececd8eE.llvm.16168865174730590251
    block  ;; label = @1
      local.get 12
      i32.load
      i32.const 6
      i32.eq
      br_if 0 (;@1;)
      local.get 12
      call $_ZN4core3ptr18real_drop_in_place17hf6e451b2d0b4c37cE.llvm.16168865174730590251
    end
    local.get 12
    i32.const 80
    i32.add
    global.set 0)
  (func $__av_get (type 15) (param i32 i64) (result i32)
    (local i32)
    global.get 0
    i32.const 16
    i32.sub
    local.tee 2
    global.set 0
    local.get 2
    local.get 1
    i64.store offset=8
    local.get 0
    i32.const 8
    i32.add
    local.get 2
    i32.const 8
    i32.add
    call $_ZN3std11collections4hash3map24HashMap$LT$K$C$V$C$S$GT$3get17h5e2dfe0c5e2017b2E.llvm.16168865174730590251
    local.set 0
    local.get 2
    i32.const 16
    i32.add
    global.set 0
    local.get 0)
  (func $__av_inject (type 5) (param i32)

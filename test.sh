#!/bin/bash
RUSTC="./target/debug/mini-rustc"
TMP="./tmp.s"
EXE="./tmp"
CC="gcc"

assert() {
  expected="$1"
  input="$2"

  rm $TMP $EXE
  $RUSTC "$input" >$TMP
  $CC -o $EXE $TMP
  chmod +x $EXE
  $EXE
  actual="$?"

  if [ "$actual" = "$expected" ]; then
    echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

compile_fail() {
  input="$1"
  $RUSTC "$input" >&/dev/null
  code="$?"
  if [ "$code" = 1 ]; then
    echo "$input => Failed to compile"
  else
    echo "$input => Unexpectedly exit with code $code"
    exit 1
  fi
}

cargo build

QT="'"

assert 6 'fn main() -> i32 { let arr: [i32; 5]; arr[3] = 4; 0 }'
# arithmetic
assert 42 'fn main() -> i32 { return 42; }'
assert 6 'fn main() -> i32 { return 1+2+3; }'
assert 80 'fn main() -> i32 { return 20*4; }'
assert 5 'fn main() -> i32 { return 2*5+4-3*3; }'
assert 150 'fn main() -> i32 { return 10*(4+5+6); }'
assert 13 'fn main() -> i32 { return (((1))+(((4*((((3)))))))); }'
# unary
assert 5 'fn main() -> i32 { return +3+2; }'
assert 4 'fn main() -> i32 { return -3+7; }'
# let stmt
assert 11 'fn main() -> i32 { return 3+8; return 4+6; }'
assert 0 'fn main() -> i32 { let a: i32; let b: i32; return 0; }'
assert 128 'fn main() -> i32 { let a: i32; a = 120; a = a + 8; return a; }'
assert 1 'fn main() -> i32 { let a: i32; let b: i32; a = 1; b = 100; return a; }'
# let with initalizer
assert 0 'fn main() -> i32 { let a: i32 = 0; a }'
assert 204 'fn main() -> i32 { let b: i32 = 10; let c: i32 = 20; 4 + c * b }'
# func call with no arg
assert 5 'fn five() -> i32 { return 5; } fn main() -> i32 { return five(); }'
assert 0 'fn tru() -> bool { return true; } fn main() -> i32 { tru(); return 0; }'
# block expr
assert 2 'fn main() -> i32 { return { 1; 2 }; }'
assert 3 'fn main() -> i32 { let blo: i32; blo = { 1; 2; 3 }; 4; return blo; }'
assert 10 'fn main() -> i32 { 10 }'
# if
assert 1 'fn main() -> i32 { if true { 1 } else { 0 } }'
assert 4 'fn main() -> i32 { if false { 3 } else { 4 } }'
# func call
assert 1 'fn id(n: i32) -> i32 { n } fn main() -> i32 { id(1) }'
assert 10 'fn id(n: i32) -> i32 { n } fn main() -> i32 { id(4) + id(6) }'
# recursive call
assert 8 'fn fib(n: i32) -> i32 { if n == 0 { 1 } else if n == 1 { 1 } else { fib(n-1) + fib(n-2) } } fn main() -> i32 { fib(5) }'
# array
assert 10 'fn main() -> i32 { let arr: [i32; 10]; arr[4] = 10; arr[4] }'
# assert 6 'fn main() -> i32 { let arr: [i32; 5]; let arr2: [i32; 6]; arr[1 + 2] = 4; arr2[arr[3] + 1] = 6; arr2[5] }'
# empty func body
assert 0 'fn emp() -> () { } fn main() -> i32 { 0 }'
# multi-dimension array
assert 10 'fn main() -> i32 { let a: [[i32; 2]; 3]; a[2][1] = 10; a[2][1] }'
# struct
assert 0 'struct Empty {} fn main() -> i32 { Empty {}; let e: Empty; e = Empty {}; 0 }'
assert 0 'struct S { n: i32, b: bool, arr: [i32; 10], } fn main() -> i32 { 0 }'
assert 0 'struct P { x: i32, y: i32, z: i32 } fn main() -> i32 { P { x: 0, y: 1, z: 2 }; 0 }'
assert 3 'struct P { x: i32, y: i32, z: i32 } fn main() -> i32 { let p: P; p = P { x: 0, y: 1, z: 2 }; p.y + p.z }'
# nested struct
assert 31 'struct Pt { x: i32, y: i32 } struct Edge { p1: Pt, p2: Pt }
fn main() -> i32 { let e: Edge; e.p1 = Pt { x: 10, y: 20, }; e.p2.x = 1; e.p2.y = 2; e.p1.x + e.p1.y + e.p2.x }'
# ref type
assert 0 'fn main() -> i32 { let string: &'$QT'static str; 0  }'
# string literal
assert 0 'fn main() -> i32 { "Hello"; "World"; 0 }'
assert 0 'fn main() -> i32 { let s: &'$QT'static str; s = "Hello, World"; 0 }'
# never type
assert 0 'fn main() -> () { let a: i32 = (return ()); a = return (); }'
assert 0 'fn main() -> () { { let never: ! = (return ()) } }'
assert 0 'fn main() -> () { { let unit: () = (return ()) } }'
assert 0 'fn main() -> () { let never: ! = (return ()) }'
assert 0 'fn main() -> () { let unit: () = (return ()) }'

# undeclared var
compile_fail 'fn main() -> i32 { a; return 0; }'
# empty func body returns unit
compile_fail 'fn main() -> i32 { }'
# assign number to bool
compile_fail 'fn main() -> i32 { let b: bool; b = 100; }'
# assign ! to ()
compile_fail 'fn main() -> i32 { let u: (); u = (return 0); }'
# ill-typed arithmetic
compile_fail 'fn main() -> i32 { return (1+true)*2; }'
# unexpected type of return value
compile_fail 'fn main() -> i32 { return true; }'
# unexpected type of block expression
compile_fail 'fn main() -> i32 { let a: i32; a = { 1; true }; }'
# mismatch number of arguments
compile_fail 'fn take_three(a: i32, b: i32, c: i32) -> () { } fn main() -> i32 { take_three(1, 2); 0 }'
# mismatch type of argument
compile_fail 'fn take_bool(b: bool) -> () { } fn main() -> i32 { take_bool(0); 0 }'

echo OK

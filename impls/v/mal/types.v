module mal

import maps

type Type = Atom
	| Closure
	| False
	| Float
	| Fn
	| Hashmap
	| Int
	| Keyword
	| List
	| Nil
	| String
	| Symbol
	| True
	| Vector

type FnDef = fn (args List) !Type

// convert one or both arguments, where such an upward, non-destructive
// conversion would enable their comparison
fn implicit_conv(a_ Type, b_ Type) !(Type, Type) {
	a := a_.resolve_atom()
	b := b_.resolve_atom()
	// same type
	if a.type_idx() == b.type_idx() {
		return a, b
	}
	// automatic conversion
	if a is Int && b is Float {
		return Float{a.val}, b
	}
	if a is Float && b is Int {
		return a, Float{b.val}
	}
	if a is Vector && b is List {
		return List{a.vec}, b
	}
	if a is List && b is Vector {
		return a, List{b.vec}
	}
	// fail
	return error('type mismatch')
}

pub fn make_bool(cond bool) Type {
	return if cond { True{} } else { False{} }
}

pub fn (t Type) truthy() bool {
	return !t.falsey()
}

pub fn (t Type) falsey() bool {
	return t in [False, Nil]
}

pub fn (t Type) call_sym() ?string {
	if t is List {
		if t.list.len > 0 {
			list0 := t.list[0]
			if list0 is Symbol {
				return list0.sym
			}
		}
	}
	return none
}

pub fn (t Type) key() !string {
	return match t {
		String { '"${t.val}' }
		Keyword { ':${t.kw}' }
		else { error('bad key') }
	}
}

pub fn unkey(key string) Type {
	return match key[0] {
		`:` { Keyword{key[1..]} }
		`"` { String{key[1..]} }
		else { Nil{} }
	}
}

pub fn (t Type) numeric() bool {
	return t in [Int, Float]
}

pub fn (t Type) resolve_atom() Type {
	return if t is Atom { t.typ.resolve_atom() } else { t }
}

pub fn (t Type) eq(o Type) bool {
	a, b := implicit_conv(t, o) or { return false }
	match a {
		List {
			if a.list.len != (b as List).list.len {
				return false
			}
			for i, aa in a.list {
				if !aa.eq((b as List).list[i]) {
					return false
				}
			}
			return true
		}
		Vector {
			if a.vec.len != (b as Vector).vec.len {
				return false
			}
			for i, aa in a.vec {
				if !aa.eq((b as Vector).vec[i]) {
					return false
				}
			}
			return true
		}
		Int {
			return a.val == (b as Int).val
		}
		Float {
			return a.val == (b as Float).val
		}
		String {
			return a.val == (b as String).val
		}
		True {
			return b is True
		}
		False {
			return b is False
		}
		Nil {
			return b is Nil
		}
		Keyword {
			return a.kw == (b as Keyword).kw
		}
		Symbol {
			return a.sym == (b as Symbol).sym
		}
		Hashmap {
			if a.hm.len != (b as Hashmap).hm.len {
				return false
			}
			for k, v in a.hm {
				bv := (b as Hashmap).hm[k] or { return false }
				if !v.eq(bv) {
					return false
				}
			}
			return true
		}
		Fn {
			return a.f == (b as Fn).f
		}
		Closure {
			bc := b as Closure
			return a.env == bc.env && a.ast == bc.ast && a.params == bc.params
		}
		Atom {
			panic('unresolved atom')
		}
	}
}

pub fn (t Type) lt(o Type) !bool {
	a, b := implicit_conv(t, o)!
	return match a {
		Int { a.val < (b as Int).val }
		Float { a.val < (b as Float).val }
		String { a.val < (b as String).val }
		else { error('invalid comparison') }
	}
}

pub fn (t Type) sym() !string {
	return if t is Symbol { t.sym } else { error('symbol expected') }
}

pub fn (t Type) fn_() !FnDef {
	return if t is Fn { t.f } else { error('function expected') }
}

pub fn (t Type) cls() !&Closure {
	return if t is Closure { &t } else { error('closure expected') }
}

pub fn (t Type) int_() !i64 {
	return if t is Int { t.val } else { error('integer expected') }
}

pub fn (t Type) str_() !string {
	return if t is String { t.val } else { error('string expected') }
}

pub fn (t Type) list() ![]Type {
	return if t is List { t.list } else { error('list expected') }
}

pub fn (t Type) sequence() ![]Type {
	return match t {
		List { t.list }
		Vector { t.vec }
		Nil { []Type{} }
		else { error('list/vector expected') }
	}
}

pub fn (t &Type) atom() !&Atom {
	return if t is Atom { unsafe { &t } } else { error('atom expected') }
}

pub fn (t &Type) hashmap() !&Hashmap {
	return match t {
		Hashmap { unsafe { &t } }
		Nil { &Hashmap{} }
		else { error('hashmap expected') }
	}
}

// --

pub struct Int {
pub:
	val i64
}

// --

pub struct Float {
pub:
	val f64
}

// --

pub struct String {
pub:
	val string
}

// -

pub struct Keyword {
pub:
	kw string
}

// --

pub struct Nil {}

// --

pub struct True {}

// --

pub struct False {}

// --

pub struct Symbol {
pub:
	sym string
}

// --

pub struct List {
pub:
	list []Type
}

pub fn (l &List) first() !&Type {
	return if l.list.len > 0 { &l.list[0] } else { error('list: empty') }
}

pub fn (l &List) last() !&Type {
	return if l.list.len > 0 { &l.list[l.list.len - 1] } else { error('list: empty') }
}

pub fn (l &List) rest() List {
	return l.from(1)
}

pub fn (l &List) from(n int) List {
	return if l.list.len > n { List{l.list[n..]} } else { List{} }
}

pub fn (l List) len() int {
	return l.list.len
}

pub fn (l &List) nth(n int) &Type {
	return if n < l.list.len { &l.list[n] } else { Nil{} }
}

// --

pub struct Vector {
pub:
	vec []Type
}

// --

pub struct Hashmap {
pub:
	hm map[string]Type
}

pub fn (h &Hashmap) filter(list List) !Hashmap {
	mut list_ := list.list.map(it.key()!)
	return Hashmap{maps.filter(h.hm, fn [list_] (k string, _ Type) bool {
		return k !in list_
	})}
}

pub fn (h &Hashmap) get(key string) Type {
	if val := h.hm[key] {
		return val
	} else {
		return Nil{}
	}
}

pub fn (h &Hashmap) has(key string) bool {
	return if _ := h.hm[key] { true } else { false }
}

pub fn make_hashmap(srcs ...Type) !Hashmap {
	mut hm := map[string]Type{}
	for src in srcs {
		match src {
			List {
				mut list := src.list[0..] // copy
				if list.len % 2 == 1 {
					return error('extra param')
				}
				for list.len > 0 {
					k, v := list[0], list[1]
					hm[k.key()!] = v
					list = list[2..]
				}
			}
			Hashmap {
				for k, v in src.hm {
					hm[k] = v
				}
			}
			else {
				panic('make_hashmap')
			}
		}
	}
	return Hashmap{hm}
}

// --

pub struct Fn {
pub:
	f FnDef
}

pub struct Closure {
pub:
	ast      Type
	params   []string
	env      &Env
	is_macro bool
}

fn (c Closure) str() string {
	disp := if c.is_macro { 'macro' } else { 'closure' }
	return 'mal.Closure{\n    <${disp}>\n}'
}

pub fn (c Closure) to_macro() Closure {
	return Closure{
		ast: c.ast
		params: c.params
		env: c.env
		is_macro: true
	}
}

// --

pub struct Atom {
pub mut:
	typ Type = Nil{}
}

fn (a &Atom) set(t Type) Type {
	mut mut_a := unsafe { a }
	mut_a.typ = t
	return t
}

// --

struct Exception {
	Error
pub:
	typ Type
}

fn (e Exception) msg() string {
	return 'Exception'
}

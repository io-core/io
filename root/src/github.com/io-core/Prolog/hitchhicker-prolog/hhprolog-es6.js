/*
Description: hitchhicker Prolog

Original Java code by Paul Tarau.
The reference document: http://www.cse.unt.edu/~tarau/research/2017/eng.pdf
Rewritten to vanilla Javascript.

Author: Carlo Capelli
Version: 1.0.0
License: MIT
Copyright (c) 2017,2018 Carlo Capelli
*/

;(function(context) {
"use strict";

function pp() {
  var msg = Array.from(arguments).map(
    e => typeof e === 'string' ? e : JSON.stringify(e)
  ).join(' ')
  if (typeof document != 'undefined')
    document.write('<pre>' + msg + '</pre>')
  else
    console.log(msg)
}

const SPACE = '\\s+'
const ATOM  = '[a-z]\\w*'
const VAR   = '[A-Z_]\\w*'
const NUM   = '-?\\d+'
const DOT   = '\\.'

// atom keywords
const IF    = 'if'
const AND   = 'and'
const HOLDS = 'holds'
const NIL   = 'nil'
const LISTS = 'lists'
const IS    = 'is'  // ?

class Toks {
  makeToks(s) {
    const e = new RegExp(`(${SPACE})|(${ATOM})|(${VAR})|(${NUM})|(${DOT})`)
    function token(r) {
      if (r && r.index === 0) {
        function tkAtom(s) {
          const k = [IF, AND, HOLDS, NIL, LISTS, IS].indexOf(s)
          return {t: k < 0 ? ATOM : s, s: s}
        }
        if (r[1]) return { t: SPACE, s: r[0] }
        if (r[2]) return tkAtom(r[0])
        if (r[3]) return { t: VAR, s: r[0] }
        if (r[4]) return { t: NUM, s: r[0], n: parseInt(r[0]) }
        if (r[5]) return { t: DOT, s: r[0] }
      }
    }
    var tokens = [], r
    while (r = token(e.exec(s))) {
      if (r.t !== SPACE)
        tokens.push(r)
      s = s.substring(r.s.length)
    }
    if (s.length)
      throw ` error at '${s}'`
    return tokens
  }

  toSentences(s) {
    var Wsss = []
    var Wss = []
    var Ws = []
    this.makeToks(s).forEach(t => {
      switch (t.t) {
      case DOT:
        Wss.push(Ws)
        Wsss.push(Wss)
        Wss = []
        Ws = []
        break
      case IF:
        Wss.push(Ws)
        Ws = []
        break
      case AND:
        Wss.push(Ws)
        Ws = []
        break
      case HOLDS:
        Ws[0] = "h:" + Ws[0].substring(2)
        break
      case LISTS:
        Ws[0] = "l:" + Ws[0].substring(2)
        break
      case IS:
        Ws[0] = "f:" + Ws[0].substring(2)
        break
      case VAR:
        Ws.push("v:" + t.s)
        break
      case NUM:
        Ws.push((t.n < (1 << 28) ? "n:" : "c:") + t.s)
        break
      case ATOM:
      case NIL:
        Ws.push("c:" + t.s)
        break
      default:
        throw 'unknown token:'+JSON.stringify(t)
      }
    })
    return Wsss
  }
}

/**
 * representation of a clause
 */
function Clause(len, hgs, base, neck, xs) {
  return {
    hgs  : hgs,     // head+goals pointing to cells in cs
    base : base,    // heap where this starts
    len  : len,     // length of heap slice
    neck : neck,    // first after the end of the head
    xs   : xs,      // indexables in head
  }
}

/**
 * runtime representation of an immutable list of goals
 * together with top of heap and trail pointers
 * and current clause tried out by head goal
 * as well as registers associated to it
 *
 * note that parts of this immutable lists
 * are shared among alternative branches
 */
function Spine6(gs0, base, gs, ttop, k, cs) {
    // creates a spine - as a snapshot of some runtime elements
  return {
    hd   : gs0[0],  // head of the clause to which this corresponds
    base : base,    // top of the heap when this was created
    gs   : gs0.concat(gs).slice(1),
    ttop : ttop,    // top of the trail when this was created
    k    : k,
    cs   : cs,      // array of clauses known to be unifiable with top goal in gs
    xs   : [],
  }
}

/**
 * creates a specialized spine returning an answer (with no goals left to solve)
 */
function Spine2(hd, ttop) {
  return {
    hd   : hd,  
    base : 0,   
    gs   : [],  // goals - with the top one ready to unfold
    ttop : ttop,
    k    : -1,
    cs   : null,
    xs   : [],
  }
}

const MINSIZE = 1 << 15
const MAXIND = 3
const START_INDEX = 20

/**
 * tags of our heap cells - that can also be seen as
 * instruction codes in a compiled implementation
 */
const V = 0
const U = 1
const R = 2
const C = 3
const N = 4
const A = 5
const BAD = 7

/**
 * Implements execution mechanism
 */
class Engine {

  // Builds a new engine from a natural-language style assembler.nl file
  constructor(asm_nl_source) {
    this.syms = []
    this.makeHeap(50)
    this.trail = []
    this.ustack = []
    this.spines = []

    // trimmed down clauses ready to be quickly relocated to the heap
    this.clauses = this.dload(asm_nl_source)
    
    this.cls = toNums(this.clauses)
    this.query = this.init()
    this.vmaps = this.vcreate(MAXIND)
    this.imaps = this.index(this.clauses, this.vmaps)
  }
  
  // places an identifier in the symbol table
  addSym(sym) {
    var I = this.syms.indexOf(sym)
    if (I === -1) {
      I = this.syms.length
      this.syms.push(sym)
    }
    return I
  }

  // returns the symbol associated to an integer index
  // in the symbol table
  getSym(w) {
    if (w < 0 || w >= this.syms.length)
      throw "BADSYMREF=" + w
    return this.syms[w]
  }

    /** runtime areas:
     *
     * the heap contains code for clauses and their copies
     * created during execution
     *
     * the trail is an undo list for variable bindings
     * that facilitates retrying failed goals with alternative
     * matching clauses
     *
     * the unification stack ustack helps handling term unification non-recursively
     *
     * the spines stack contains abstractions of clauses and goals and performs the
     * functions of both a choice-point stack and goal stack
     *
     * imaps: contains indexes for up to MAXIND>0 arg positions (0 for pred symbol itself)
     *
     * vmaps: contains clause numbers for which vars occur in indexed arg positions
     */
  makeHeap(size) {
    size = size || MINSIZE
    this.heap = Array(size).fill(0)
    this.clear()
  }
  clear() {
    for (var i = 0; i <= this.top; i++)
      this.heap[i] = 0
    this.top = -1
  }
  
  /**
   * Pushes an element - top is incremented first than the
   * element is assigned. This means top point to the last assigned
   * element - which can be returned with peek().
   */
  push(i) {
    this.heap[++this.top] = i
  }
  
  size() {
    return this.top + 1
  }
  expand() {
    this.heap.length = this.heap.length * 2
  }
  ensureSize(more) {
    if (1 + this.top + more >= this.heap.length)
      this.expand()
  }

  /**
   * loads a program from a .nl file of
   * "natural language" equivalents of Prolog/HiLog statements
   */
  dload(s) {
    var Wsss = (new Toks).toSentences(s)
    var Cs = []
    for (var Wss of Wsss) {
      var refs = {}
      var cs = []
      var gs = []
      var Rss = mapExpand(Wss)
      var k = 0
      for (var ws of Rss) {
        var l = ws.length
        gs.push(tag(R, k++))
        cs.push(tag(A, l))
        for (var w of ws) {
          if (1 == w.length)
            w = "c:" + w
          var L = w.substring(2)
          switch (w[0]) {
          case 'c':
            cs.push(this.encode(C, L))
            k++
            break
          case 'n':
            cs.push(this.encode(N, L))
            k++
            break
          case 'v':
            if (refs[L] === undefined)
              refs[L] = []
            refs[L].push(k)
            cs.push(tag(BAD, k))
            k++
            break
          case 'h':
            if (refs[L] === undefined)
              refs[L] = []
            refs[L].push(k - 1)
            cs[k - 1] = tag(A, l - 1)
            gs.pop()
            break
          default:
            throw "FORGOTTEN=" + w
          }
        }
      }

      for (var kIs in refs) {
        var Is = refs[kIs]
        var leader = -1
        for (var j of Is)
          if (A == tagOf(cs[j])) {
            leader = j
            break
          }
        if (-1 == leader) {
          leader = Is[0]
          for (var i of Is)
            if (i == leader)
              cs[i] = tag(V, i)
            else
              cs[i] = tag(U, leader)
        } else
          for (var i of Is) {
            if (i == leader)
              continue
            cs[i] = tag(R, leader)
          }
      }
      var neck = 1 == gs.length ? cs.length : detag(gs[1])
      var tgs = gs
      Cs.push(this.putClause(cs, tgs, neck))
    }
    return Cs
  }
  
  /**
   * returns the heap cell another cell points to
   */
  getRef(x) { return this.heap[detag(x)] }
  
  /**
   * sets a heap cell to point to another one
   */
  setRef(w, r) { this.heap[detag(w)] = r }
  
  /**
   * encodes string constants into symbols while leaving
   * other data types untouched
   */
  encode(t, s) {
    var w = parseInt(s)
    if (isNaN(w)) {
      if (C == t)
        w = this.addSym(s)
      else
        throw "bad in encode=" + t + ":" + s
    }
    return tag(t, w)
  }

  /**
   * removes binding for variable cells
   * above savedTop
   */
  unwindTrail(savedTop) {
    while (savedTop < this.trail.length - 1) {
      var href = this.trail.pop()
      this.setRef(href, href)
    }
  }

  /**
   * scans reference chains starting from a variable
   * until it points to an unbound root variable or some
   * non-variable cell
   */
  deref(x) {
    while (isVAR(x)) {
      var r = this.getRef(x)
      if (r == x)
        break
      x = r
    }
    return x
  }
  showTerm(x) {
    if (typeof x === 'number')
      return this.showTerm(this.exportTerm(x))
    if (x instanceof Array)
      return x.join(',')
    return '' + x
  }
  ppTrail() {
    for (var i = 0; i <= array_last(this.trail, -1); i++) {
      var t = this.trail[i]
      pp("trail[" + i + "]=" + this.showCell(t) + ":" + this.showTerm(t))
    }
  }

  /**
   * builds an array of embedded arrays from a heap cell
   * representing a term for interaction with an external function
   * including a displayer
   */
  exportTerm(x) {
    x = this.deref(x)
    var t = tagOf(x)
    var w = detag(x)
    var res = null
    switch (t) {
    case C:
      res = this.getSym(w)
      break
    case N:
      res = parseInt(w)
      break
    case V:
    //case U:
      res = "V" + w
      break
    case R: {
      var a = this.heap[w]
      if (A != tagOf(a))
        throw "*** should be A, found=" + this.showCell(a)
      var n = detag(a)
      var arr = Array(n).fill()
      var k = w + 1
      for (var i = 0; i < n; i++) {
        var j = k + i
        arr[i] = this.exportTerm(this.heap[j])
      }
      res = arr
    } break
    default:
      throw "*BAD TERM*" + this.showCell(x)
    }
    return res
  }

  /**
   * raw display of a cell as tag : value
   */
  showCell(w) {
    var t = tagOf(w)
    var val = detag(w)
    var s = null
    switch (t) {
    case V:
      s = "v:" + val
      break
    case U:
      s = "u:" + val
      break
    case N:
      s = "n:" + val
      break
    case C:
      s = "c:" + this.getSym(val)
      break
    case R:
      s = "r:" + val
      break
    case A:
      s = "a:" + val
      break
    default:
      s = "*BAD*=" + w
    }
    return s
  }
  showCells2(base, len) {
    var buf = ''
    for (var k = 0; k < len; k++) {
      var instr = this.heap[base + k]
      buf += "[" + (base + k) + "]" + this.showCell(instr) + " "
    }
    return buf
  }
  showCells1(cs) {
    var buf = ''
    for (var k = 0; k < cs.length; k++)
      buf += "[" + k + "]" + this.showCell(cs[k]) + " "
    return buf
  }

  ppc(C) {}
  ppGoals(gs) {}
  ppSpines() {}

  /**
   * unification algorithm for cells X1 and X2 on ustack that also takes care
   * to trail bindigs below a given heap address "base"
   */
  unify(base) {
    while (this.ustack.length) {
      var x1 = this.deref(this.ustack.pop())
      var x2 = this.deref(this.ustack.pop())
      if (x1 != x2) {
        var t1 = tagOf(x1)
        var t2 = tagOf(x2)
        var w1 = detag(x1)
        var w2 = detag(x2)
        if (isVAR(x1)) {
          if (isVAR(x2) && w2 > w1) {
            this.heap[w2] = x1
            if (w2 <= base)
              this.trail.push(x2)
          } else {
            this.heap[w1] = x2
            if (w1 <= base)
              this.trail.push(x1)
          }
        } else if (isVAR(x2)) {
          this.heap[w2] = x1
          if (w2 <= base)
            this.trail.push(x2)
        } else if (R == t1 && R == t2) {
          if (!this.unify_args(w1, w2))
            return false
        } else
          return false
      }
    }
    return true
  }

  unify_args(w1, w2) {
    var v1 = this.heap[w1]
    var v2 = this.heap[w2]
    // both should be A
    var n1 = detag(v1)
    var n2 = detag(v2)
    if (n1 != n2)
      return false
    var b1 = 1 + w1
    var b2 = 1 + w2
    for (var i = n1 - 1; i >= 0; i--) {
      var i1 = b1 + i
      var i2 = b2 + i
      var u1 = this.heap[i1]
      var u2 = this.heap[i2]
      if (u1 == u2)
        continue
      this.ustack.push(u2)
      this.ustack.push(u1)
    }
    return true
  }

  /**
   * places a clause built by the Toks reader on the heap
   */
  putClause(cs, gs, neck) {
    var base = this.size()
    var b = tag(V, base)
    var len = cs.length
    this.pushCells2(b, 0, len, cs)
    for (var i = 0; i < gs.length; i++)
      gs[i] = relocate(b, gs[i])
    var xs = this.getIndexables(gs[0])
    return Clause(len, gs, base, neck, xs)
  }

  /**
   * pushes slice[from,to] of array cs of cells to heap
   */
  pushCells1(b, from, to, base) {
    this.ensureSize(to - from)
    for (var i = from; i < to; i++)
        this.push(relocate(b, this.heap[base + i]))
  }
  pushCells2(b, from, to, cs) {
    this.ensureSize(to - from)
    for (var i = from; i < to; i++)
        this.push(relocate(b, cs[i]))
  }

  /**
   * copies and relocates head of clause at offset from heap to heap
   */
  pushHead(b, C) {
    this.pushCells1(b, 0, C.neck, C.base)
    return relocate(b, C.hgs[0])
  }

  /**
   * copies and relocates body of clause at offset from heap to heap
   * while also placing head as the first element of array gs that
   * when returned contains references to the toplevel spine of the clause
   */
  pushBody(b, head, C) {
    this.pushCells1(b, C.neck, C.len, C.base)
    var l = C.hgs.length
    var gs = Array(l).fill(0)
    gs[0] = head
    for (var k = 1; k < l; k++) {
      var cell = C.hgs[k]
      gs[k] = relocate(b, cell)
    }
    return gs
  }

  /**
   * makes, if needed, registers associated to top goal of a Spine
   * these registers will be reused when matching with candidate clauses
   * note that regs contains dereferenced cells - this is done once for
   * each goal's toplevel subterms
   */
  makeIndexArgs(G) {
    var goal = G.gs[0]
    if (G.xs.length)
      return
    var p = 1 + detag(goal)
    var n = Math.min(MAXIND, detag(this.getRef(goal)))

    var xs = Array(MAXIND).fill(0)
    for (var i = 0; i < n; i++) {
      var cell = this.deref(this.heap[p + i])
      xs[i] = this.cell2index(cell)
    }
    G.xs = xs
    if (this.imaps) throw "IMap TBD"
  }

  getIndexables(ref) {
    var p = 1 + detag(ref)
    var n = detag(this.getRef(ref))
    var xs = Array(MAXIND).fill(0)
    for (var i = 0; i < MAXIND && i < n; i++) {
      var cell = this.deref(this.heap[p + i])
      xs[i] = this.cell2index(cell)
    }
    return xs
  }
  cell2index(cell) {
    var x = 0
    var t = tagOf(cell)
    switch (t) {
    case R:
      x = this.getRef(cell)
      break
    case C:
    case N:
      x = cell
      break
    }
    return x
  }

  /**
   * tests if the head of a clause, not yet copied to the heap
   * for execution could possibly match the current goal, an
   * abstraction of which has been place in regs
   */
  match(xs, C0) {
    for (var i = 0; i < MAXIND; i++) {
      var x = xs[i]
      var y = C0.xs[i]
      if (0 == x || 0 == y)
        continue
      if (x != y)
        return false
    }
    return true
  }

  /**
   * transforms a spine containing references to choice point and
   * immutable list of goals into a new spine, by reducing the
   * first goal in the list with a clause that successfully
   * unifies with it - in which case places the goals of the
   * clause at the top of the new list of goals, in reverse order
   */
  unfold(G) {
    var ttop = this.trail.length - 1
    var htop = this.top
    var base = htop + 1

    this.makeIndexArgs(G)

    var last = G.cs.length
    for (var k = G.k; k < last; k++) {
      var C0 = this.clauses[G.cs[k]]
      if (!this.match(G.xs, C0))
        continue
      var base0 = base - C0.base
      var b = tag(V, base0)
      var head = this.pushHead(b, C0)
      this.ustack.length = 0
      this.ustack.push(head)
      this.ustack.push(G.gs[0])
      if (!this.unify(base)) {
        this.unwindTrail(ttop)
        this.top = htop
        continue
      }
      var gs = this.pushBody(b, head, C0)
      var newgs = gs.concat(G.gs.slice(1)).slice(1)
      G.k = k + 1
      if (newgs.length)
        return Spine6(gs, base, G.gs.slice(1), ttop, 0, this.cls)
      else
        return this.answer(ttop)
    }
    return null
  }

  /**
   * extracts a query - by convention of the form
   * goal(Vars):-body to be executed by the engine
   */
  getQuery() { return array_last(this.clauses, null) }

  /**
   * returns the initial spine built from the
   * query from which execution starts
   */
  init() {
    var base = this.size()
    var G = this.getQuery()
    var Q = Spine6(G.hgs, base, [], array_last(this.trail, -1), 0, this.cls)
    this.spines.push(Q)
    return Q
  }

  /**
   * returns an answer as a Spine while recording in it
   * the top of the trail to allow the caller to retrieve
   * more answers by forcing backtracking
   */
  answer(ttop) { return Spine2(this.spines[0].hd, ttop) }

  /**
   * removes this spines for the spine stack and
   * resets trail and heap to where they where at its
   * creating time - while undoing variable binding
   * up to that point
   */
  popSpine() {
    var G = this.spines.pop()
    this.unwindTrail(G.ttop)
    this.top = G.base - 1
  }

  /**
   * main interpreter loop: starts from a spine and works
   * though a stream of answers, returned to the caller one
   * at a time, until the spines stack is empty - when it
   * returns null
   */
  yield_() {
    while (this.spines.length) {
      var G = array_last(this.spines, null)
      var C = this.unfold(G)
      if (null == C) {
        this.popSpine() // no matches
        continue
      }
      if (hasGoals(C)) {
        this.spines.push(C)
        continue
      }
      return C // answer
    }
    return null
  }
  heap2s() { return '[' + this.top + ' ' + this.heap.slice(0,this.top).map((x,y) => heapCell(x)).join(',') + ']' }

  /**
   * retrieves an answers and ensure the engine can be resumed
   * by unwinding the trail of the query Spine
   * returns an external "human readable" representation of the answer
   */
  ask() {
    this.query = this.yield_()
    if (null == this.query)
      return null
    var res = this.answer(this.query.ttop).hd
    var R = this.exportTerm(res)
    this.unwindTrail(this.query.ttop)
    return R
  }

  /**
   * initiator and consumer of the stream of answers
   * generated by this engine
   */
  run(print_ans) {
    var ctr = 0
    for (;; ctr++) {
      var A = this.ask()
      if (null == A)
        break
      if (print_ans)
        pp("[" + ctr + "] " + "*** ANSWER=" + this.showTerm(A))
    }
    pp("TOTAL ANSWERS=" + ctr)
  }
  vcreate(l) {
    var vss = []
    for (var i = 0; i < l; i++)
      vss.push([])
    return vss
  }
  put(imaps, vss, keys, val) {
    for (var i = 0; i < imaps.length; i++) {
      var key = keys[i]
      if (key != 0)
        imaps[i][key] = val
      else
        vss[i].add(val)
    }
  }
  index(clauses, vmaps) {
    if (clauses.length < START_INDEX)
      return null
    var T = JSON.stringify
    var imaps = Array(vmaps.length)
    for (var i = 0; i < clauses.length; i++) {
      var c = clauses[i]
      pp("!!!xs=" + T(c.xs) + ":" + this.showCells1(c.xs) + "=>" + i)
      this.put(imaps, vmaps, c.xs, i + 1) // $$$ UGLY INC
      pp(T(imaps))
    }
    pp("INDEX")
    pp(T(imaps))
    pp(T(vmaps))
    pp("")
    return imaps
  }
}

/**
 * tags an integer value while flipping it into a negative
 * number to ensure that untagged cells are always negative and the tagged
 * ones are always positive - a simple way to ensure we do not mix them up
 * at runtime
 */
const tag=(t, w)=> -((w << 3) + t)
/**
 * removes tag after flipping sign
 */
const detag=w=> -w >> 3
/**
 * extracts the tag of a cell
 */
const tagOf=w=> -w & 7
const tagSym=t=>
  t === V ? "V" :
  t === U ? "U" :
  t === R ? "R" :
  t === C ? "C" :
  t === N ? "N" :
  t === A ? "A" : "?"

const heapCell = (w) => tagSym(tagOf(w))+":"+detag(w)+"["+w+"]"

/**
 * true if cell x is a variable
 * assumes that variables are tagged with 0 or 1
 */
const isVAR = (x) => tagOf(x) < 2

/**
 * expands a "Xs lists .." statements to "Xs holds" statements
 */
function maybeExpand(Ws) {
  var W = Ws[0]
  if (W.length < 2 || "l:" !== W.substring(0, 2))
    return null
  var l = Ws.length
  var Rss = []
  var V = W.substring(2)
  for (var i = 1; i < l; i++) {
    var Vi = 1 == i ? V : V + "__" + (i - 1)
    var Vii = V + "__" + i
    var Rs = ["h:" + Vi, "c:list", Ws[i], i == l - 1 ? "c:nil" : "v:" + Vii]
    Rss.push(Rs)
  }
  return Rss
}

/**
 * expands, if needed, "lists" statements in sequence of statements
 */
function mapExpand(Wss) {
  var Rss = []
  for (var Ws of Wss) {
    var Hss = maybeExpand(Ws)
    if (null == Hss)
      Rss.push(Ws)
    else
      for (var X of Hss)
        Rss.push(X)
  }
  return Rss
}

const toNums=(clauses)=>Array(clauses.length).fill().map((_, i) => i)

function getSpine(cs) {
  var a = cs[1]
  var w = detag(a)
  var rs = Array(w - 1).fill()
  for (var i = 0; i < w - 1; i++) {
    var x = cs[3 + i]
    var t = tagOf(x)
    if (R != t)
      throw "*** getSpine: unexpected tag=" + t
    rs[i] = detag(x)
  }
  return rs;
}
const relocate=(b, cell)=>tagOf(cell) < 3 ? cell + b : cell
const array_last=(a, def)=>a.length ? a[a.length - 1] : def
const hasClauses=S=>S.k < S.cs.length
const hasGoals=S=>S.gs.length > 0

class Prog extends Engine {
  constructor(s) {
    super(s)
  }
  
  ppCode() {
    pp("\nSYMS:")
    pp(this.syms)
    pp("\nCLAUSES:\n")
    for (var i = 0; i < this.clauses.length; i++) {
      var C = this.clauses[i]
      pp("[" + i + "]:" + this.showClause(C))
    }
    pp("")
  }
  showClause(s) {
    var r = ''
    var l = s.hgs.length
    r += "---base:[" + s.base + "] neck: " + s.neck + "-----\n"
    r += this.showCells2(s.base, s.len); // TODO
    r += "\n"
    r += this.showCell(s.hgs[0])

    r += " :- ["
    for (var i = 1; i < l; i++) {
      var e = s.hgs[i]
      r += this.showCell(e)
      if (i < l - 1)
        r += ", "
    }
    r += "]\n"
    r += this.showTerm(s.hgs[0])
    if (l > 1) {
      r += " :- \n"
      for (var i = 1; i < l; i++) {
        var e = s.hgs[i]
        r += "  "
        r += this.showTerm(e)
        r += "\n"
      }
    } else
      r += "\n"
    return r
  }
  showTerm(O) {
    if (typeof O === 'number')
      return super.showTerm(O)
    if (O instanceof Array)
      return st0(O)
    return JSON.stringify(O)
  }
  ppGoals(bs) {
    while (bs.length) {
      pp(this.showTerm(bs[0]))
      bs = bs.slice(1);
    }
  }
  ppc(S) {
    var bs = S.gs
    pp("\nppc: t=" + S.ttop + ",k=" + S.k + "len=" + bs.length)
    this.ppGoals(bs)
  }
}

const maybeNull=(O)=>
  null == O ? "$null" :
  O instanceof Array ? st0(O) :
  ''+O
const isListCons=(name)=>"." === name || "[|]" === name || "list" === name
const isOp=(name)=>"/" === name || "-" === name || "+" === name || "=" === name
function st0(args) {
  var r = ''
  var name = ''+args[0]
  if (args.length == 3 && isOp(name)) {
    r += "("
    r += maybeNull(args[0])
    r += " " + name + " "
    r += maybeNull(args[1])
    r += ")"
  } else if (args.length == 3 && isListCons(name)) {
    r += '['
    r += maybeNull(args[1])
    var tail = args[2]
    for (;;) {
      if ("[]" === tail || "nil" === tail)
        break
      if (!(tail instanceof Array)) {
        r += '|'
        r += maybeNull(tail)
        break
      }
      var list = tail
      if (!(list.length == 3 && isListCons(list[0]))) {
        r += '|'
        r += maybeNull(tail)
        break
      } else {
        r += ','
        r += maybeNull(list[1])
        tail = list[2]
      }
    }
    r += ']'
  } else if (args.length == 2 && "$VAR" === name) {
    r += "_" + args[1]
  } else {
    var qname = maybeNull(args[0])
    r += qname
    r += "("
    for (var i = 1; i < args.length; i++) {
      var O = args[i]
      r += maybeNull(O)
      if (i < args.length - 1)
        r += ","
    }
    r += ")"
  }
  return r
}

context.Prog = Prog

})(typeof module !== 'undefined' ? module.exports : self);

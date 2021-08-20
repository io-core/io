/*
 * HitchHicker Prolog
 * 
 * Original Java code by Paul Tarau.
 * The reference document: http://www.cse.unt.edu/~tarau/research/2017/eng.pdf
 * Rewritten to vanilla Javascript.
 * 
 * Author: Carlo Capelli
 * Version: 1.0.0
 * License: MIT
 * Copyright (c) 2017,2018 Carlo Capelli
 */
;(function(context) {

"use strict";

var T = JSON.stringify

var trace = function trace() {
    /*
    var s = ''
    for (var a = 0; a < arguments.length; ++a)
        s += JSON.stringify(arguments[a]) + ' '
    document.write('<pre>' + s + "</pre>")
    */
    //document.write('<pre>' + JSON.stringify(arguments) + "\n</pre>")
    //document.write('<pre>' + JSON.stringify(Array.from(arguments)) + "</pre>")
    /*
    document.write('<pre>' + Array.from(arguments).map(
        e => typeof e === 'string' ? e : JSON.stringify(e)
    ).join(' ') + "</pre>")
    */
    /*
    console.log(Array.from(arguments).map(
        e => typeof e === 'string' ? e : JSON.stringify(e)
    ).join(' '))
    */
    var msg = Array.from(arguments).map(
        e => typeof e === 'string' ? e : JSON.stringify(e)
    ).join(' ')
    if (document)
        document.write('<pre>'+msg+'</pre>')
    else
        console.log(msg)
}
context.trace = trace

// RegExes set
var SPACE = '\\s+'
var ATOM  = '[a-z]\\w*'
var VAR   = '[A-Z_]\\w*'
var NUM   = '-?\\d+'
var DOT   = '\\.'

var IF    = "if"
var AND   = "and"
var HOLDS = "holds"

var NIL   = "nil"
var LISTS = "lists"
var IS    = "is"  // ?

function Toks() {
    
    this.makeToks = function makeToks(s) {
        // accepted sequences
        var e = new RegExp(`(${SPACE})|(${ATOM})|(${VAR})|(${NUM})|(${DOT})`)

        function token(r) {

            if (r && r.index === 0) {

                // qualify atom as keyword
                function tkAtom(s) {
                    var k = [IF, AND, HOLDS, NIL, LISTS, IS].indexOf(s)
                    return {t: k < 0 ? ATOM : s, s: s}
                }
                function tkVar(s) {
                   return { t: VAR, s: r[0] }
                }
                function tkNum(s) {
                    return { t: NUM, s: s, n: parseInt(s) }
                }
                if (r[1]) return { t: SPACE, s: r[0] }
                if (r[2]) return tkAtom(r[0])
                if (r[3]) return tkVar(r[0])
                if (r[4]) return tkNum(r[0])
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

    this.toSentences = function toSentences(s) {
        var Wsss = []
        var Wss = []
        var Ws = []
        for (var t of this.makeToks(s))
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
                if (t.n < (1 << 28))
                    Ws.push("n:" + t.s)
                else
                    Ws.push("c:" + t.s)
                break
            case ATOM:
            case NIL:
                Ws.push("c:" + t.s)
                break

            default:
                throw 'unknown token:'+JSON.stringify(t)
            }
        return Wsss
    }
}

/**
 * representation of a clause
 */
function Clause(len, hgs, base, neck, xs) {
    return {
        hgs    : hgs,   // head+goals pointing to cells in cs
        base   : base,  // heap where this starts
        len    : len,   // length of heap slice
        neck   : neck,  // first after the end of the head
        xs     : xs,    // indexables in head
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
//trace('Spine6', gs0, base, gs, ttop, k, cs)
        /**
         * creates a spine - as a snapshot of some runtime elements
            Spine(final int[] gs0, final int base, final IntList gs, final int ttop, final int k, final int[] cs) {
                hd = gs0[0];
                this.base = base;
                this.gs = IntList.tail(IntList.app(gs0, gs)); // prepends the goals of clause with head hs
                this.ttop = ttop;
                this.k = k;
                this.cs = cs;
            }
         */
    return {
        hd      : gs0[0],
        base    : base,
        gs      : gs0.concat(gs).slice(1), // prepends the goals of clause with head hs
        ttop    : ttop,
        k       : k,
        cs      : cs,
        xs      : [],
    }
}
function Spine2(hd, ttop) {

        /**
         * creates a specialized spine returning an answer (with no goals left to solve)
            Spine(final int hd, final int ttop) {
                this.hd = hd;
                base = 0;
                gs = IntList.empty;
                this.ttop = ttop;

                k = -1;
                cs = null;
            }
         */
//trace('Spine2', hd, ttop)
    return {
        hd      : hd,   // head of the clause to which this corresponds
        base    : 0,    // top of the heap when this was created
        gs      : [],   // goals - with the top one ready to unfold
        ttop    : ttop, // top of the trail when this was created
        k       : -1,
        cs      : null, // array of clauses known to be unifiable with top goal in gs
        xs      : [],
    }
}

//////////// IntStack.java

var MINSIZE = 1 << 15 // power of 2

//////////// IMap.java

var IMap = function IMap() {
    this.map = []
}
IMap.prototype.put = function(key, val) {
    if (!this.map[key])
        this.map[key] = [];
    this.map[key][val] = 666;
}

//////////// Engine.java

var MAXIND = 3 // number of index args
var START_INDEX = 20

var pp = trace

/**
 * tags of our heap cells - that can also be seen as
 * instruction codes in a compiled implementation
 */
var V = 0
var U = 1
var R = 2

var C = 3
var N = 4

var A = 5

// G - ground?
var BAD = 7

/**
 * Implements execution mechanism
 */
var Engine = function Engine(asm_nl_source) {
//trace('Engine', asm_nl_source)
    // switches off indexing for less then START_INDEX clauses e.g. <20

    /**
     * Builds a new engine from a natural-language style assembler.nl file
     */

    this.syms = []

    /**
     * places an identifier in the symbol table
     */
    this.addSym = function(sym) {
        var I = this.syms.indexOf(sym)
        if (I === -1) {
            I = this.syms.length
            this.syms.push(sym)
        }
        return I
    }

    /**
     * returns the symbol associated to an integer index
     * in the symbol table
     */
    this.getSym = function getSym(w) {
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

    this.makeHeap(50)

    this.trail = []
    this.ustack = []
    this.spines = []

    /**
     * trimmed down clauses ready to be quickly relocated to the heap
     */
    this.clauses = this.dload(asm_nl_source)

    /** symbol table made of map + reverse map from ints to syms */
    this.cls = toNums(this.clauses)

    this.query = this.init()

    this.vmaps = this.vcreate(MAXIND)
    this.imaps = this.index(this.clauses, this.vmaps)
    
//trace('Engine', this)
}

/**
 * tags an integer value while flipping it into a negative
 * number to ensure that untagged cells are always negative and the tagged
 * ones are always positive - a simple way to ensure we do not mix them up
 * at runtime
 */
function tag(t, w) {
    return -((w << 3) + t)
}

/**
 * removes tag after flipping sign
 */
function detag(w) {
    return -w >> 3
}

/**
 * extracts the tag of a cell
 */
function tagOf(w) {
    return -w & 7
}

function tagSym(t) {
    switch(t) {
        case V: return "V";
        case U: return "U";
        case R: return "R";
        case C: return "C";
        case N: return "N";
        case A: return "A";
        default: return "?";
    }
  }
function heapCell(w) {
    var t = tagOf(w);
    var v = detag(w);
    return tagSym(t)+":"+v+"["+w+"]";
  }

/**
 * true if cell x is a variable
 * assumes that variables are tagged with 0 or 1
 */
function isVAR(x) {
    //final int t = tagOf(x);
    //return V == t || U == t;
    return tagOf(x) < 2
}

/**
* places an identifier in the symbol table
*
Engine.prototype.addSym = function(sym) {
    var I = this.syms.indexOf(sym)
    if (I === -1) {
        I = this.syms.length
        this.syms.push(sym)
    }
    return I
}
*/

/**
* returns the symbol associated to an integer index
* in the symbol table
*
Engine.prototype.getSym = function getSym(w) {
    if (w < 0 || w >= this.syms.length)
        throw "BADSYMREF=" + w
    return this.syms[w]
}
*/

Engine.prototype.makeHeap = function(size) {
    size = size || MINSIZE
    this.heap = Array(size).fill(0)
    this.clear()
}

Engine.prototype.clear = function() {
    for (var i = 0; i <= this.top; i++)
        this.heap[i] = 0
    this.top = -1
}

/**
 * Pushes an element - top is incremented first than the
 * element is assigned. This means top point to the last assigned
 * element - which can be returned with peek().
 */
Engine.prototype.push = function(i) {
    this.heap[++this.top] = i
}

Engine.prototype.size = function() {
    return this.top + 1
}

/**
 * dynamic array operation: doubles when full
 */
Engine.prototype.expand = function() {
    this.heap.length = this.heap.length * 2
}
Engine.prototype.ensureSize = function(more) {
    if (1 + this.top + more >= this.heap.length)
        this.expand()
}

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
        if (null == Hss) {
            Rss.push(Ws)
        } else
            for (var X of Hss)
                Rss.push(X)
    }
    return Rss
}

/**
 * loads a program from a .nl file of
 * "natural language" equivalents of Prolog/HiLog statements
 */
Engine.prototype.dload = function(s) {
    var Wsss = (new Toks).toSentences(s)
    var Cs = []
    for (var Wss of Wsss) {
        // clause starts here
        var refs = {}
        var cs = []
        var gs = []

        var Rss = mapExpand(Wss)
        var k = 0
        for (var ws of Rss) {
trace("ws", ws);
            // head or body element starts here

            var l = ws.length
            gs.push(tag(R, k++))
            cs.push(tag(A, l))

            for (var w of ws) {

                // head or body subterm starts here
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
                    cs.push(tag(BAD, k))  // just in case we miss this
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
                    pp("FORGOTTEN=" + w)
                } // end subterm
            } // end element
        } // end clause

        // linker
        for (var kIs in refs) {
            var Is = refs[kIs]
            
            // finding the A among refs
            var leader = -1
            for (var j of Is) {
                if (A == tagOf(cs[j])) {
                    leader = j
                    break
                }
            }
            if (-1 == leader) {
                // for vars, first V others U
                leader = Is[0]
                for (var i of Is) {
                    if (i == leader) {
                        cs[i] = tag(V, i)
                    } else {
                        cs[i] = tag(U, leader)
                    }
                }
            } else {
                for (var i of Is) {
                    if (i == leader) {
                        continue
                    }
                    cs[i] = tag(R, leader)
                }
            }
        }

        var neck = 1 == gs.length ? cs.length : detag(gs[1])
        var tgs = gs
        Cs.push(this.putClause(cs, tgs, neck))
    } // end clause set

    return Cs
}

function toNums(clauses) {
    return Array(clauses.length).fill().map((_, i) => i)
}

/**
 * extracts an integer array pointing to
 * the skeleton of a clause: a cell
 * pointing to its head followed by cells pointing to its body's
 * goals
 */
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
//trace('getSpine', cs, rs)
    return rs;
}

/**
 * relocates a variable or array reference cell by b
 * assumes var/ref codes V,U,R are 0,1,2
 */
function relocate(b, cell) {
    return tagOf(cell) < 3 ? cell + b : cell
}

function array_last(a, def) {
    return a.length ? a[a.length - 1] : def
}

/**
 * returns the heap cell another cell points to
 */
Engine.prototype.getRef = function(x) {
    return this.heap[detag(x)]
}

/**
 * sets a heap cell to point to another one
 */
Engine.prototype.setRef = function(w, r) {
    this.heap[detag(w)] = r
}

/**
 * encodes string constants into symbols while leaving
 * other data types untouched
 */
Engine.prototype.encode = function(t, s) {
    var w = parseInt(s)
    if (isNaN(w)) {
        if (C == t) {
            w = this.addSym(s)
        } else {
            throw "bad in encode=" + t + ":" + s
            //return tag(BAD, 666)
        }
    }
    return tag(t, w)
}

/**
 * removes binding for variable cells
 * above savedTop
 */
Engine.prototype.unwindTrail = function(savedTop) {
//trace("unwindTrail", savedTop, this.trail);
    while (savedTop < this.trail.length - 1) {
        var href = this.trail.pop()
        // assert href is var
        this.setRef(href, href)
    }
//trace("after unwindTrail", this.heap2s());
}

/**
 * scans reference chains starting from a variable
 * until it points to an unbound root variable or some
 * non-variable cell
 */
Engine.prototype.deref = function(x) {
    while ((-x & 7) < 2) {
        var r = this.heap[-x >> 3]
        if (r == x)
            break
        x = r
    }
    return x
}
Engine.prototype._orig_deref = function(x) {
//trace("deref", x, tagOf(x), detag(x));
    while (isVAR(x)) {
        var r = this.getRef(x)
//trace("r", r, tagOf(r), detag(r));
        if (r == x)
            break
        x = r
    }

    switch (tagOf(x)) {
    case V:
    case R:
    case C:
    case N:
        break;
    default:
        throw "unexpected deref=" + this.showCell(x)
    }

//trace("x", x, tagOf(x), detag(x));
    return x
}

/**
 * raw display of a term - to be overridden
 */
Engine.prototype.showTerm = function(x) {
//trace('showTerm', x)
    if (typeof x === 'number')
        return this.showTerm(this.exportTerm(x))
    if (x instanceof Array)
        return x.join(',')
    return '' + x
}

/**
 * raw display of a externalized term
 */
function showTerm_extern(O) {
    return JSON.stringify(O)
}

/**
 * prints out content of the trail
 */
Engine.prototype.ppTrail = function() {
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
Engine.prototype.exportTerm = function(x) {
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
    }   break
    default:
        throw "*BAD TERM*" + this.showCell(x)
    }
    return res
}

/**
 * raw display of a cell as tag : value
 */
Engine.prototype.showCell = function(w) {
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

/**
 * a displayer for cells
 */
Engine.prototype.showCells2 = function(base, len) {
    var buf = ''
    for (var k = 0; k < len; k++) {
        var instr = this.heap[base + k]
        buf += "[" + (base + k) + "]" + this.showCell(instr) + " "
    }
    return buf
}

Engine.prototype.showCells1 = function(cs) {
    var buf = ''
    for (var k = 0; k < cs.length; k++)
        buf += "[" + k + "]" + this.showCell(cs[k]) + " "
    return buf
}

/**
 * to be overridden as a printer of a spine
 */
Engine.prototype.ppc = function(C) {
    // override
}

/**
 * to be overridden as a printer for current goals
 * in a spine
 */
Engine.prototype.ppGoals = function(gs) {
    // override
}

/**
 * to be overriden as a printer for spines
 */
Engine.prototype.ppSpines = function() {
    // override
}

/**
 * unification algorithm for cells X1 and X2 on ustack that also takes care
 * to trail bindigs below a given heap address "base"
 */
Engine.prototype.unify = function(base) {
//trace("unify", base, this.heap2s(), this.ustack);
    while (this.ustack.length) {
//trace('ustack', this.ustack)
        var x1 = this.deref(this.ustack.pop())
        var x2 = this.deref(this.ustack.pop())
//trace("x1,x2", x1,x2);
        if (x1 != x2) {
            var t1 = tagOf(x1)
            var t2 = tagOf(x2)
            var w1 = detag(x1)
            var w2 = detag(x2)
//trace('a', x1,x2,t1,t2,w1,w2)
            if (isVAR(x1)) { /* unb. var. v1 */
//trace('b')
                if (isVAR(x2) && w2 > w1) { /* unb. var. v2 */
                    this.heap[w2] = x1
//trace('c', this.heap[w2])
                    if (w2 <= base) {
                        this.trail.push(x2)
//trace('d', this.trail)
                    }
                } else { // x2 nonvar or older
                    this.heap[w1] = x2
//trace('e', this.heap2s())
                    if (w1 <= base) {
                        this.trail.push(x1)
//trace('f', this.trail)
                    }
                }
            } else if (isVAR(x2)) { /* x1 is NONVAR */
                this.heap[w2] = x1
//trace('g', this.heap)
                if (w2 <= base) {
                    this.trail.push(x2)
//trace('h', this.trail)
                }
            } else if (R == t1 && R == t2) { // both should be R
                if (!this.unify_args(w1, w2))
                    return false
//trace("i", this.heap2s());
            } else
                return false
        }
    }
//trace("true");
    return true
}

Engine.prototype.unify_args = function(w1, w2) {
    var v1 = this.heap[w1]
    var v2 = this.heap[w2]
    // both should be A
    var n1 = detag(v1)
    var n2 = detag(v2)
//trace('unify_args', w1,w2,v1,v2,n1,n2, this.heap2s())
    if (n1 != n2)
        return false
    var b1 = 1 + w1
    var b2 = 1 + w2
    for (var i = n1 - 1; i >= 0; i--) {
        var i1 = b1 + i
        var i2 = b2 + i
        var u1 = this.heap[i1]
        var u2 = this.heap[i2]
        if (u1 == u2) {
            continue
        }
        this.ustack.push(u2)
        this.ustack.push(u1)
//trace('ustack', this.ustack)
    }
//trace('TRUE unify_args')
    return true
}

/**
 * places a clause built by the Toks reader on the heap
 */
Engine.prototype.putClause = function(cs, gs, neck) {
    var base = this.size()
    var b = tag(V, base)
    var len = cs.length
    this.pushCells2(b, 0, len, cs)
    for (var i = 0; i < gs.length; i++) {
        gs[i] = relocate(b, gs[i])
    }
    var xs = this.getIndexables(gs[0])
    return Clause(len, gs, base, neck, xs)
}

/**
 * pushes slice[from,to] of array cs of cells to heap
 */
Engine.prototype.pushCells1 = function(b, from, to, base) {
    this.ensureSize(to - from)
    for (var i = from; i < to; i++) {
        this.push(relocate(b, this.heap[base + i]))
    }
}

/**
 * pushes slice[from,to] of array cs of cells to heap
 */
Engine.prototype.pushCells2 = function(b, from, to, cs) {
    this.ensureSize(to - from)
    for (var i = from; i < to; i++) {
        this.push(relocate(b, cs[i]))
    }
}

/**
 * copies and relocates head of clause at offset from heap to heap
 */
Engine.prototype.pushHead = function(b, C) {
    this.pushCells1(b, 0, C.neck, C.base)
    var head = C.hgs[0]
    return relocate(b, head)
}

/**
 * copies and relocates body of clause at offset from heap to heap
 * while also placing head as the first element of array gs that
 * when returned contains references to the toplevel spine of the clause
 */
Engine.prototype.pushBody = function(b, head, C) {
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
Engine.prototype.makeIndexArgs = function(G) {
//trace('makeIndexArgs', G)
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
//trace('this.imaps', this.imaps)
    if (null == this.imaps)
        return
    var cs = IMap.get(imaps, vmaps, xs)
    G.cs = cs
}

Engine.prototype.getIndexables = function(ref) {
    var p = 1 + detag(ref)
    var n = detag(this.getRef(ref))
    var xs = Array(MAXIND).fill(0)
    for (var i = 0; i < MAXIND && i < n; i++) {
        var cell = this.deref(this.heap[p + i])
        xs[i] = this.cell2index(cell)
    }
//trace("getIndexables " + ref + ":", xs)
    return xs
}

Engine.prototype.cell2index = function(cell) {
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
    // 0 otherwise - assert: tagging with R,C,N <>0
    }
    return x
}

/**
 * tests if the head of a clause, not yet copied to the heap
 * for execution could possibly match the current goal, an
 * abstraction of which has been place in regs
 */
Engine.prototype.match = function(xs, C0) {
//trace('match', xs, C0)
    for (var i = 0; i < MAXIND; i++) {
        var x = xs[i]
        var y = C0.xs[i]
//trace('i,x,y', i, x, y)
        if (0 == x || 0 == y) {
            continue
        }
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
Engine.prototype.unfold = function(G) {

    var ttop = this.trail.length - 1
    var htop = this.top
    var base = htop + 1

    this.makeIndexArgs(G)
//trace('after makeIndexArgs', G)
//trace("unfold start", this.trail, ttop, htop, base);

    var last = G.cs.length
    for (var k = G.k; k < last; k++) {
        var C0 = this.clauses[G.cs[k]]
//trace('unfold', k, T(C0))

        if (!this.match(G.xs, C0)) {
//trace("!match")
            continue
        }

        var base0 = base - C0.base
        var b = tag(V, base0)
        var head = this.pushHead(b, C0)
//trace("match", base0, b, head)

        this.ustack.length = 0 // set up unification stack

        this.ustack.push(head)
        this.ustack.push(G.gs[0])

        if (!this.unify(base)) {
            this.unwindTrail(ttop)
            this.top = htop
            continue
        }

        var gs = this.pushBody(b, head, C0)
//trace('gs', gs, G)
        var newgs = gs.concat(G.gs.slice(1)).slice(1)
        G.k = k + 1
//trace('newgs', newgs)
        if (newgs.length)
            return Spine6(gs, base, G.gs.slice(1), ttop, 0, this.cls)
        else
            return this.answer(ttop)
    } // end for
    return null
}

/**
 * extracts a query - by convention of the form
 * goal(Vars):-body to be executed by the engine
 */
Engine.prototype.getQuery = function() {
    return array_last(this.clauses, null)
}

/**
 * returns the initial spine built from the
 * query from which execution starts
 */
Engine.prototype.init = function() {
    var base = this.size()
    var G = this.getQuery()
//trace('G', G, T(this.trail))
    var Q = Spine6(G.hgs, base, [], array_last(this.trail, -1), 0, this.cls)
//trace('Q', Q)
    this.spines.push(Q)
//trace('spines', T(this.spines))
    return Q
}

/**
 * returns an answer as a Spine while recording in it
 * the top of the trail to allow the caller to retrieve
 * more answers by forcing backtracking
 */
Engine.prototype.answer = function(ttop) {
    return Spine2(this.spines[0].hd, ttop)
}

/**
 * detects availability of alternative clauses for the
 * top goal of this spine
 */
function hasClauses(S) {
    return S.k < S.cs.length
}

/**
 * true when there are no more goals left to solve
 */
function hasGoals(S) {
    return S.gs.length > 0
}

/**
 * removes this spines for the spine stack and
 * resets trail and heap to where they where at its
 * creating time - while undoing variable binding
 * up to that point
 */
Engine.prototype.popSpine = function() {
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
Engine.prototype.yield_ = function() {
//trace('spines', this.spines)
    while (this.spines.length) {
        var G = array_last(this.spines, null)
//trace('G', G)
        /*
        if (!hasClauses(G)) {
            this.popSpine() // no clauses left
            continue
        }
        */
        
        var C = this.unfold(G)
//trace('unfolded C', C)
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

Engine.prototype.heap2s = function() {
    return '[' + this.top + ' ' + this.heap.slice(0,this.top).map((x,y) => /*'['+y+']'+*/heapCell(x)).join(',') + ']'
}

/**
 * retrieves an answers and ensure the engine can be resumed
 * by unwinding the trail of the query Spine
 * returns an external "human readable" representation of the answer
 */
Engine.prototype.ask = function() {
//trace('before yield', this.heap2s())
    this.query = this.yield_()
//trace('after yield', this.heap2s())

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
Engine.prototype.run = function(print_ans) {
    var ctr = 0
    for (;; ctr++) {
        var A = this.ask()
        if (null == A) {
            break
        }
        if (print_ans)
            pp("[" + ctr + "] " + "*** ANSWER=" + this.showTerm(A))
    }
    pp("TOTAL ANSWERS=" + ctr)
}

// indexing extensions - ony active if START_INDEX clauses or more

Engine.prototype.vcreate = function(l) {
    var vss = []
    for (var i = 0; i < l; i++)
        vss.push([])
    return vss
}

Engine.prototype.put = function(imaps, vss, keys, val) {
    for (var i = 0; i < imaps.length; i++) {
        var key = keys[i]
        if (key != 0) {
            imaps[i][key] = val
        } else {
            vss[i].add(val)
        }
    }
}

Engine.prototype.index = function(clauses, vmaps) {
    if (clauses.length < START_INDEX)
        return null

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

function Prog(s) {
    Engine.call(this, s)
}
Prog.prototype = Object.create(Engine.prototype)

function maybeNull(O) {
    if (null == O)
        return "$null"
    if (O instanceof Array)
        return st0(O)
    return ''+O
}
function isListCons(name) {
    return "." === name || "[|]" === name || "list" === name
}
function isOp(name) {
    return "/" === name || "-" === name || "+" === name || "=" === name
}
function st0(args) {
    var buf = ''
    var name = ''+args[0]
    if (args.length == 3 && isOp(name)) {
        buf += "("
        buf += maybeNull(args[0])
        buf += " " + name + " "
        buf += maybeNull(args[1])
        buf += ")"
    } else if (args.length == 3 && isListCons(name)) {
        buf += '['
        buf += maybeNull(args[1])
        var tail = args[2]
        for (;;) {
            if ("[]" === tail || "nil" === tail) {
                break
            }
            if (!(tail instanceof Array)) {
                buf += '|'
                buf += maybeNull(tail)
                break
            }
            var list = tail
            if (!(list.length == 3 && isListCons(list[0]))) {
                buf += '|'
                buf += maybeNull(tail)
                break
            } else {
                buf += ','
                buf += maybeNull(list[1])
                tail = list[2]
            }
        }
        buf += ']'
    } else if (args.length == 2 && "$VAR" === name) {
        buf += "_" + args[1]
    } else {
        var qname = maybeNull(args[0])
        buf += qname
        buf += "("
        for (var i = 1; i < args.length; i++) {
            var O = args[i]
            buf += maybeNull(O)
            if (i < args.length - 1) {
                buf += ","
            }
        }
        buf += ")"
    }
    return buf
}

Prog.prototype.ppCode = function() {
    pp("\nSYMS:")
    pp(this.syms)
    pp("\nCLAUSES:\n")
    for (var i = 0; i < this.clauses.length; i++) {
        var C = this.clauses[i]
        pp("[" + i + "]:" + this.showClause(C))
    }
    pp("")
}

Prog.prototype.showClause = function(s) {
    var buf = ''
    var l = s.hgs.length
    buf += "---base:[" + s.base + "] neck: " + s.neck + "-----\n"
    buf += this.showCells2(s.base, s.len); // TODO
    buf += "\n"
    buf += this.showCell(s.hgs[0])

    buf += " :- ["
    for (var i = 1; i < l; i++) {
        var e = s.hgs[i]
        buf += this.showCell(e)
        if (i < l - 1) {
            buf += ", "
        }
    }

    buf += "]\n"

    buf += this.showTerm(s.hgs[0])
    if (l > 1) {
        buf += " :- \n"
        for (var i = 1; i < l; i++) {
            var e = s.hgs[i]
            buf += "  "
            buf += this.showTerm(e)
            buf += "\n"
        }
    } else {
        buf += "\n"
    }
    return buf
  }

  /*
  String showHead(final Cls s) {
    final int h = s.gs[0];
    return showCell(h) + "=>" + showTerm(h);
  }
  */

//@Override
Prog.prototype.showTerm = function(O) {
    if (typeof O === 'number')
        return Engine.prototype.showTerm.call(this, O)
    if (O instanceof Array)
        return st0(O)
    return JSON.stringify(O)
}

// @Override
Prog.prototype.ppGoals = function(bs) {
    while (bs.length) {
        pp(this.showTerm(bs[0]))
        bs = bs.slice(1);
    }
}

//  @Override
Prog.prototype.ppc = function(S) {
    var bs = S.gs
    pp("\nppc: t=" + S.ttop + ",k=" + S.k + "len=" + bs.length)
    this.ppGoals(bs)
}
/////////////// end of show

context.Toks = Toks // for initial debugging
context.Engine = Engine
context.Prog = Prog

})(typeof module !== 'undefined' ? module.exports : self);

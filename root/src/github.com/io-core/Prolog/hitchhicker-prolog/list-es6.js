/*
Description: list data structure

Author: Carlo Capelli
Version: 1.0.0
License: MIT
Copyright (c) 2017,2018 Carlo Capelli
*/
;(function(context) {
"use strict";

class List {
    constructor(h, t) {
        this.h = h
        this.t = t
    }

    forEach(f) {
        for (var s = this, c = 0, r; s; s = s.t, ++c)
            if (f && (r = f(s.h, c, this)))
                return r
        return c
    }
    concat(y) {
        var r = this.copy()
        r.last().t = y.copy()
        return r
    }
    slice(start) {
        var l = this
        while (l.t && start-- > 0)
            l = l.t
        if (l) return l.copy()
    }
    map(f) {
        var p = 0, c = new List(f(this.h, p++, this)), C = c
        for (var l = this.t; l; l = l.t)
            c = c.t = new List(f(l.h, p++, this))
        return C
    }
    
    to(what) {
        if (what == undefined) what = []
        if (what instanceof Array)
            this.forEach(e => { what.push(e) })
        if (typeof what == 'string')
            what += this.toString()
        return what
    }
    toArray() {
        var a = Array(this.len())
        this.forEach((e, i) => { a[i] = e })
        return a
    }
    toString(sep) {
        return this.toArray().join(sep)
    }
    
    len(l, f) {
        const c = this.forEach()
        if (l == undefined)
            return c
        if (l < c) { // trim
            var s = this
            while (--l > 0 && s.t)
                s = s.t
            delete s.t
        }
        if (l > c) { // fill
            var t = this.last()
            if (t.h == undefined && f)
                t.h = f(t.h)
            while (l-- > c)
                t = t.t = f ? new List(f(t.h)) : new List()
        }
        return this
    }
    copy() {
        var c = new List(this.h), C = c
        for (var l = this.t; l; l = l.t)
            c = c.t = new List(l.h)
        return C
    }
    last() {
        var l = this
        while (l.t)
            l = l.t
        return l
    }
    
    static iota(n, from) {
        n = n || N
        from = from || 0
        var l = new List(from), L = l
        for(var i = 1; i < n; ++i)
            l = l.t = new List(i + from)
        return L
    }
    static from(s, sep) {
        if (s instanceof Array && s.length) {
            for (var L = new List(s[0]), l = L, i = 1; i < s.length; ++i)
                l = l.t = new List(s[i])
            return L
        }
        if (typeof s == 'string') {
            if (sep == undefined)
                sep = ','
            else if (sep == '')
                return List.from([... s])
            return List.from(s.split(sep))
        }
    }
}

context.List = List
context.list = function list(h, t) { return new List(h, t) }

})(typeof module !== 'undefined' ? module.exports : self);

/*
Author: Carlo Capelli
Version: 1.0.0
License: MIT
Copyright (c) 2018 Carlo Capelli
*/

#include "hhprolog.h"

#include <map>
#include <sstream>
#include <numeric>
#include <iostream>
#include <algorithm>

namespace hhprolog {

Engine::Engine(string asm_nl_source) {
    makeHeap();

    clauses = dload(asm_nl_source);
    cls = toNums(clauses);

    query = init();

    //vmaps = vcreate(MAXIND);
    //imaps = index(clauses, vmaps);
}
Engine::~Engine() {
}

string Engine::stats() const {
    ostringstream s;
    s   << heap.capacity() << ' '
        << spines_top << " of " << spines.capacity() << ' '
        << trail.capacity() << ' '
        << ustack.capacity();
    s << " [ ";
    for (auto c: c_spine_mem)
        s << c.first << ':' << c.second << ' ';
    s << ']';
    return s.str();
}

Spine* Engine::init() {
    Int base = size();
    Clause G = getQuery();

    trail.reserve(10000);
    ustack.reserve(10000);

    spines.resize(10000);
    spines_top = 0;

    gs_pushBody.resize(100);

    return new_spine(G.hgs, base, IntS(), -1);
}
Spine* Engine::new_spine(const IntS& gs0, Int base, const IntList &rgs, Int ttop) {
    auto *sp = &spines[spines_top++];
    sp->hd = gs0[0];
    sp->cs = cls;
    sp->base = base;
    sp->ttop = ttop;
    sp->xs = t_xs{-1,-1,-1};
    sp->k = 0;
    // note: cannot reuse G because the last spines.push_back could relocate the array
    auto req_size = gs0.size() - 1 + ( rgs.size() > 0 ? rgs.size() -1 : 0 );
#if 0
    sp->gs.reserve(req_size);

    for (size_t x = 1; x < gs.size(); ++x)
        sp->gs.push_back(gs[x]);
    for (size_t x = 1; x < rgs.size(); ++x)
        sp->gs.push_back(rgs[x]);
#else
    sp->gs.resize(req_size);
    size_t y = 0;
    for (size_t x = 1; x < gs0.size(); ++x)
        sp->gs[y++] = gs0[x];
    for (size_t x = 1; x < rgs.size(); ++x)
        sp->gs[y++] = rgs[x];
#endif
    //c_spine_mem[req_size]++;
    return sp;
}

/**
 * transforms a spine containing references to choice point and
 * immutable list of goals into a new spine, by reducing the
 * first goal in the list with a clause that successfully
 * unifies with it - in which case places the goals of the
 * clause at the top of the new list of goals, in reverse order
 */
Spine* Engine::unfold() {
    ++c_inferences;

    Spine& G = spines[spines_top - 1];

    Int ttop = Int(trail.size()) - 1;
    Int htop = top;
    Int base = htop + 1;

    //cout << c_inferences << ' ' << ttop << ' ' << htop << ' ' << base << endl;

    makeIndexArgs(G);

    size_t last = G.cs.size();
    for (size_t k = size_t(G.k); k < last; k++) {
        Clause& C0 = clauses[size_t(G.cs[k])];
        if (!match(G.xs, C0))
            continue;
        Int base0 = base - C0.base;
        Int b = tag(V, base0);
        Int head = pushHead(b, C0);
        ustack.clear();
        ustack.push_back(head);
        ustack.push_back(G.gs[0]);
        if (!unify(base)) {
            unwindTrail(ttop);
            top = htop;
            continue;
        }
        pushBody(b, head, C0);
        G.k = Int(k + 1);
        if (gs_pushBody.size() > 1 || G.gs.size() > 1)
            return new_spine(gs_pushBody, base, G.gs, ttop);
        else
            return answer(ttop);
    }
    return nullptr;
}
void Engine::pushBody(Int b, Int head, Clause& C) {
    pushCells1(b, C.neck, C.len, C.base);
    auto l = C.hgs.size();
    gs_pushBody.resize(l);
    gs_pushBody[0] = head;
    for (size_t k = 1; k < l; k++) {
        auto cell = C.hgs[k];
        gs_pushBody[k] = relocate(b, cell);
    }
}

bool Engine::unify(Int base) {
    while (!ustack.empty()) {
        Int x1 = deref(ustack.back()); ustack.pop_back();
        Int x2 = deref(ustack.back()); ustack.pop_back();
        if (x1 != x2) {
            Int t1 = tagOf(x1);
            Int t2 = tagOf(x2);
            Int w1 = detag(x1);
            Int w2 = detag(x2);
            if (isVAR(x1)) {
                if (isVAR(x2) && w2 > w1) {
                    heap[size_t(w2)] = x1;
                    if (w2 <= base)
                        trail.push_back(x2);
                } else {
                    heap[size_t(w1)] = x2;
                    if (w1 <= base)
                        trail.push_back(x1);
                }
            } else if (isVAR(x2)) {
                heap[size_t(w2)] = x1;
                if (w2 <= base)
                    trail.push_back(x2);
            } else if (R == t1 && R == t2) {
                if (!unify_args(w1, w2))
                    return false;
            } else
                return false;
        }
    }
    return true;
}

bool Engine::unify_args(Int w1, Int w2) {
    Int v1 = heap[size_t(w1)];
    Int v2 = heap[size_t(w2)];
    // both should be A
    Int n1 = detag(v1);
    Int n2 = detag(v2);
    if (n1 != n2)
        return false;
    Int b1 = 1 + w1;
    Int b2 = 1 + w2;
    for (Int i = n1 - 1; i >= 0; i--) {
        Int i1 = b1 + i;
        Int i2 = b2 + i;
        Int u1 = heap[size_t(i1)];
        Int u2 = heap[size_t(i2)];
        if (u1 == u2)
            continue;
        ustack.push_back(u2);
        ustack.push_back(u1);
    }
    return true;
}

void Engine::pp(string s) {
    cout << s << endl;
}

cstr Engine::tagSym(Int t) {
    if (t == V) return "V";
    if (t == U) return "U";
    if (t == R) return "R";
    if (t == C) return "C";
    if (t == N) return "N";
    if (t == A) return "A";
    return "?";
}

void Engine::clear() {
    /*for (Int i = 0; i < top; i++)
        heap[size_t(i)] = 0;*/
    top = -1;
}

cstr Engine::heapCell(Int w) {
    return tagSym(tagOf(w)) + ":" + detag(w) + "[" + w + "]";
}

Int Engine::addSym(cstr sym) {
    auto I = find(syms.begin(), syms.end(), sym);
    if (I == syms.end()) {
        syms.push_back(sym);
        return Int(syms.size() - 1);
    }
    return distance(syms.begin(), I);
}

IntS Engine::getSpine(const IntS& cs) {
    Int a = cs[1];
    Int w = detag(a);
    IntS rs(w - 1);
    for (Int i = 0; i < w - 1; i++) {
        Int x = cs[3 + size_t(i)];
        Int t = tagOf(x);
        if (R != t)
            throw logic_error(cstr("*** getSpine: unexpected tag=") + t);
        rs[size_t(i)] = detag(x);
    }
    return rs;
}

vector<Clause> Engine::dload(cstr s) {
    auto Wsss = Toks::toSentences(s);
    vector<Clause> Cs;
    for (auto Wss: Wsss) {
        map<string, IntS> refs;
        IntS cs;
        IntS gs;
        auto Rss = Toks::mapExpand(Wss);
        Int k = 0;
        for (auto ws: Rss) {
            Int l = Int(ws.size());
            gs.push_back(tag(R, k++));
            cs.push_back(tag(A, l));
            for (auto w: ws) {
                if (1 == w.size())
                    w = "c:" + w;
                auto L = w.substr(2);
                switch (w[0]) {
                case 'c':
                    cs.push_back(encode(C, L));
                    k++;
                    break;
                case 'n':
                    cs.push_back(encode(N, L));
                    k++;
                    break;
                case 'v':
                    refs[L].push_back(k);
                    cs.push_back(tag(BAD, k));
                    k++;
                    break;
                case 'h':
                    refs[L].push_back(k - 1);
                    cs[size_t(k - 1)] = tag(A, l - 1);
                    gs.pop_back();
                    break;
                default:
                    throw logic_error("FORGOTTEN=" + w);
                }
            }
        }

        for (auto kIs: refs) {
            auto Is = kIs.second;
            Int leader = -1;
            for (auto j: Is)
                if (A == tagOf(cs[size_t(j)])) {
                    leader = j;
                    break;
                }
            if (-1 == leader) {
                leader = Is[0];
                for (auto i: Is)
                    if (i == leader)
                        cs[size_t(i)] = tag(V, i);
                    else
                        cs[size_t(i)] = tag(U, leader);
            } else
                for (auto i: Is) {
                    if (i == leader)
                        continue;
                    cs[size_t(i)] = tag(R, leader);
                }
        }
        auto neck = 1 == gs.size() ? Int(cs.size()) : detag(gs[1]);
        auto tgs = gs;
        Cs.push_back(putClause(cs, tgs, neck));
    }
    return Cs;
}

Spine* Engine::answer(Int ttop) {
    return new Spine(spines[0].hd, ttop);
}
Object Engine::ask() {
    query = yield_();
    if (nullptr == query)
        return Object();
    auto ans = answer(query->ttop);
    auto res = ans->hd;
    auto R = exportTerm(res);
    unwindTrail(query->ttop);
    delete ans;

    delete query;
    query = nullptr;

    return R;
}
Spine* Engine::yield_() {
    while (spines_top) {
        auto C = unfold();
        if (nullptr == C) {
            popSpine(); // no matches
            continue;
        }
        if (hasGoals(*C))
            continue;
        return C; // answer
    }
    return nullptr;
}

void Engine::popSpine() {
    --spines_top;
    unwindTrail(spines[spines_top].ttop);
    top = spines[spines_top].base - 1;
}

Object Engine::exportTerm(Int x) {
    x = deref(x);
    Int t = tagOf(x);
    Int w = detag(x);

    switch (t) {
    case C:
        return Object(getSym(w));
    case N:
        return Object(w);
    case V:
        //case U:
        return Object(cstr("V") + w);
    case R: {
        Int a = heap[size_t(w)];
        if (A != tagOf(a))
            throw logic_error(cstr("*** should be A, found=") + showCell(a));
        Int n = detag(a);
        vector<Object> args;
        Int k = w + 1;
        for (Int i = 0; i < n; i++) {
            Int j = k + i;
            args.push_back(exportTerm(heap[size_t(j)]));
        }
        return Object(args);
    }
    default:
        throw logic_error(cstr("*BAD TERM*") + showCell(x));
    }
}

string Engine::showCell(Int w) {
    Int t = tagOf(w);
    Int val = detag(w);
    string s;
    switch (t) {
    case V:
        s = cstr("v:") + val;
        break;
    case U:
        s = cstr("u:") + val;
        break;
    case N:
        s = cstr("n:") + val;
        break;
    case C:
        s = cstr("c:") + getSym(val);
        break;
    case R:
        s = cstr("r:") + val;
        break;
    case A:
        s = cstr("a:") + val;
        break;
    default:
        s = cstr("*BAD*=") + w;
    }
    return s;
}

IntS Engine::toNums(vector<Clause> clauses)
{
    IntS r(Int(clauses.size()));
    iota(r.begin(), r.end(), 0);
    return r;
}

void Engine::makeIndexArgs(Spine& G) {
    if (G.xs[0] != -1)
        return;

    Int goal = G.gs[0];
    Int p = 1 + detag(goal);
    Int n = min(MAXIND, detag(getRef(goal)));
    for (Int i = 0; i < n; i++) {
        Int cell = deref(heap[size_t(p + i)]);
        G.xs[size_t(i)] = cell2index(cell);
    }
    //if (imaps) throw "IMap TBD";
}

Clause Engine::putClause(IntS cs, IntS gs, Int neck) {
    Int base = size();
    Int b = tag(V, base);
    Int len = Int(cs.size());
    pushCells2(b, 0, len, cs);
    for (size_t i = 0; i < gs.size(); i++)
        gs[i] = relocate(b, gs[i]);
    Clause XC;
    getIndexables(gs[0], XC);
    XC.len=len;
    XC.hgs=gs;
    XC.base=base;
    XC.neck=neck;
    return XC;
}
void Engine::getIndexables(Int ref, Clause &c) {
    Int p = 1 + detag(ref);
    Int n = detag(getRef(ref));
    for (Int i = 0; i < MAXIND && i < n; i++) {
        Int cell = deref(heap[size_t(p + i)]);
        c.xs[size_t(i)] = cell2index(cell);
    }
}
Int Engine::cell2index(Int cell) {
    Int x = 0;
    Int t = tagOf(cell);
    switch (t) {
    case R:
        x = getRef(cell);
        break;
    case C:
    case N:
        x = cell;
        break;
    }
    return x;
}

}

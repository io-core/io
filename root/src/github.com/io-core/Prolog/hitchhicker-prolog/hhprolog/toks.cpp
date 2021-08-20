/*
Author: Carlo Capelli
Version: 1.0.0
License: MIT
Copyright (c) 2018 Carlo Capelli
*/

#include "hhprolog.h"
#include <regex>
#include <array>

namespace hhprolog { namespace Toks {

struct tok {
    const string t, s; Int n;
};

// tokens as regex specification
const string
    SPACE = "\\s+",
    ATOM  = "[a-z]\\w*",
    VAR   = "[A-Z_]\\w*",
    NUM   = "-?\\d+",
    DOT   = "\\.";

// atom keywords
const string
    IF    = "if",
    AND   = "and",
    HOLDS = "holds",
  //NIL   = "nil",
    LISTS = "lists",
    IS    = "is";  // ?

vector<tok> makeToks(string s) {
    auto E = "("+SPACE+")|("+ATOM+")|("+VAR+")|("+NUM+")|("+DOT+")";
    auto e = regex(E);
    auto token = [](smatch r) {
        if (!r.empty()) {
            auto tkAtom = [](string s) {
                const array<string, 5> kws = {IF, AND, HOLDS, /*NIL,*/ LISTS, IS};
                auto p = find(kws.cbegin(), kws.cend(), s);
                return tok{p == kws.cend() ? ATOM : s, s, 0};
            };
            if (r[1].matched) return tok{SPACE, r[0], 0};
            if (r[2].matched) return tkAtom(r.str());
            if (r[3].matched) return tok{VAR, r[0], 0};
            if (r[4].matched) return tok{NUM, r[0], stoi(r[0])};
            if (r[5].matched) return tok{DOT, r[0], 0};
        }
        throw runtime_error("no match");
    };
    vector<tok> tokens;

    sregex_iterator f(s.cbegin(), s.cend(), e), l = sregex_iterator();
    while (f != l) {
        auto r = token(*f++);
        if (r.t != SPACE)
            tokens.push_back(r);
    }

    return tokens;
}

Tsss toSentences(string s) {
    Tsss Wsss;
    Tss Wss;
    Ts Ws;
    for (auto t : makeToks(s)) {
        if (t.t == DOT) {
            Wss.push_back(Ws);
            Wsss.push_back(Wss);
            Wss.clear();
            Ws.clear();
            continue;
        }
        if (t.t == IF) {
            Wss.push_back(Ws);
            Ws.clear();
            continue;
        }
        if (t.t == AND) {
            Wss.push_back(Ws);
            Ws.clear();
            continue;
        }
        if (t.t == HOLDS) {
            Ws[0] = "h:" + Ws[0].substr(2);
            continue;
        }
        if (t.t == LISTS) {
            Ws[0] = "l:" + Ws[0].substr(2);
            continue;
        }
        if (t.t == IS) {
            Ws[0] = "f:" + Ws[0].substr(2);
            continue;
        }
        if (t.t == VAR) {
            Ws.push_back("v:" + t.s);
            continue;
        }
        if (t.t == NUM) {
            Ws.push_back((t.n < (1 << 28) ? "n:" : "c:") + t.s);
            continue;
        }
        if (t.t == ATOM) { // || t.t == NIL) {
            Ws.push_back("c:" + t.s);
            continue;
        }
        throw runtime_error("unknown token:" + t.t);
    }
    return Wsss;
}

Tss maybeExpand(Ts Ws) {
    auto W = Ws[0];
    if (W.size() < 2 || "l:" != W.substr(0, 2))
        return Tss();
    Int l = Int(Ws.size());
    Tss Rss;
    auto V = W.substr(2);
    for (Int i = 1; i < l; i++) {
        string Vi = 1 == i ? V : V + "__" + (i - 1);
        string Vii = V + "__" + i;
        Ts Rs = {"h:" + Vi, "c:list", Ws[size_t(i)], i == l - 1 ? "c:nil" : "v:" + Vii};
        Rss.push_back(Rs);
    }
    return Rss;
}

Tss mapExpand(Tss Wss) {
    Tss Rss;
    for (auto Ws: Wss) {
        auto Hss = maybeExpand(Ws);
        if (Hss.empty())
            Rss.push_back(Ws);
        else
            for (auto X: Hss)
                Rss.push_back(X);
    }
    return Rss;
}

}}
